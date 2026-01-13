//
//  NavigationStore.swift
//  KitApp
//
//  状態管理とビジネスロジックを担当するStore
//

import Foundation
import Combine

// MARK: - NavigationStore

@MainActor
final class NavigationStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var state: NavigationViewState

    // MARK: - Dependencies

    // TODO: Phase 2 で追加
    // private let arService: ARSessionService
    // private let repository: RouteRepository

    // MARK: - Initialization

    init() {
        self.state = NavigationViewState()
    }

    // MARK: - Action Handling

    func send(_ action: NavigationAction) {
        switch action {

        // MARK: Recording Actions

        case .startRecording:
            guard state.canStartRecording else { return }
            state.phase = .recording
            state.recordingInfo = RecordingInfo(distance: 0, angle: 0)
            state.statusMessage = "記録中... 歩いてください"
            // TODO: arService.startRecording()

        case .recordTurn:
            guard case .recording = state.phase else { return }
            // TODO: arService.recordTurn()

        case .cancelRecording:
            guard case .recording = state.phase else { return }
            state.phase = .idle
            state.recordingInfo = nil
            state.statusMessage = state.isARReady ? "準備完了" : "準備中..."
            // TODO: arService.reset()

        case .saveRoute:
            guard case .recording = state.phase else { return }
            state.statusMessage = "WorldMap を取得中..."
            // TODO: arService.prepareSaveRoute()

        case .addEvent(let eventType):
            guard case .recording = state.phase else { return }
            state.statusMessage = eventType.displayText
            // TODO: arService.addEvent(eventType)

        // MARK: Replay Actions

        case .startReplay(let routeItem):
            state.phase = .replaying(routeName: routeItem.name)
            state.showRouteList = false
            state.statusMessage = "再生準備中..."
            // TODO: arService.replayRoute(routeItem.id)

        case .stopReplay:
            guard case .replaying = state.phase else { return }
            state.phase = .idle
            state.statusMessage = state.isARReady ? "準備完了" : "準備中..."
            // TODO: arService.reset()

        // MARK: Route Management Actions

        case .deleteRoutes(let indexSet):
            // TODO: repository.deleteRoutes(at: indexSet)
            // 一旦ローカルで削除
            for index in indexSet.sorted().reversed() {
                if index < state.savedRoutes.count {
                    state.savedRoutes.remove(at: index)
                }
            }

        // MARK: UI Actions

        case .setShowRouteList(let show):
            state.showRouteList = show

        case .setShowEventPicker(let show):
            state.showEventPicker = show

        // MARK: AR Session Callbacks

        case .arReadyChanged(let isReady):
            state.isARReady = isReady
            if state.phase == .idle {
                state.statusMessage = isReady ? "準備完了" : "準備中..."
            }

        case .statusMessageChanged(let message):
            state.statusMessage = message

        case .recordingInfoUpdated(let distance, let angle):
            guard case .recording = state.phase else { return }
            state.recordingInfo = RecordingInfo(distance: distance, angle: angle)

        case .routeSaveCompleted(let result):
            switch result {
            case .success(let routeName):
                state.phase = .idle
                state.recordingInfo = nil
                state.statusMessage = "保存完了: \(routeName)"
                // TODO: repository.fetchRoutes() で savedRoutes を更新

            case .failure(let error):
                state.statusMessage = error.localizedDescription
            }

        case .resetCompleted:
            state.recordingInfo = nil
            if state.phase != .idle {
                state.phase = .idle
            }
            state.statusMessage = state.isARReady ? "準備完了" : "準備中..."
        }
    }

    // MARK: - Public Methods

    /// 保存済みルートを読み込む
    func loadSavedRoutes(_ routes: [RouteListItem]) {
        state.savedRoutes = routes
    }
}
