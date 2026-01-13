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

    private let repository: RouteRepository?

    // MARK: - Initialization

    init(repository: RouteRepository? = nil) {
        self.repository = repository
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

        case .recordTurn:
            guard case .recording = state.phase else { return }

        case .cancelRecording:
            guard case .recording = state.phase else { return }
            state.phase = .idle
            state.recordingInfo = nil
            state.statusMessage = state.idleStatusMessage

        case .saveRoute:
            guard case .recording = state.phase else { return }
            state.statusMessage = "WorldMap を取得中..."

        case .addEvent(let eventType):
            guard case .recording = state.phase else { return }
            state.statusMessage = eventType.displayText

        // MARK: Replay Actions

        case .startReplay(let routeItem):
            state.phase = .replaying(routeName: routeItem.name)
            state.showRouteList = false
            state.statusMessage = "再生準備中..."

        case .stopReplay:
            guard case .replaying = state.phase else { return }
            state.phase = .idle
            state.statusMessage = state.idleStatusMessage

        // MARK: Route Management Actions

        case .deleteRoutes(let indexSet):
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
                state.statusMessage = state.idleStatusMessage
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

            case .failure(let error):
                state.statusMessage = error.localizedDescription
            }

        case .resetCompleted:
            state.recordingInfo = nil
            if state.phase != .idle {
                state.phase = .idle
            }
            state.statusMessage = state.idleStatusMessage
        }
    }

    // MARK: - Public Methods

    /// 保存済みルートを読み込む
    func loadSavedRoutes(_ routes: [RouteListItem]) {
        state.savedRoutes = routes
    }
}
