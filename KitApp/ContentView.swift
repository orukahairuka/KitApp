//
//  ContentView.swift
//  KitApp
//
//  歩行ナビプロトタイプのメインビュー
//

import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NavRoute.createdAt, order: .reverse) private var savedRoutes: [NavRoute]

    // Store
    @State private var store: NavigationStore?

    // ARSceneコマンド
    @State private var arCommand: ARSceneCommand = .none

    var body: some View {
        ZStack {
            NavARSceneView(
                command: $arCommand,
                onEvent: handleARSceneEvent
            )
            .ignoresSafeArea()

            if let store = store {
                NavigationOverlayView(
                    store: store,
                    savedRoutes: savedRoutes,
                    arCommand: $arCommand,
                    onDeleteRoutes: deleteRoutesFromContext
                )
            }
        }
        .onAppear {
            setupStore()
        }
        .onChange(of: savedRoutes) { _, newRoutes in
            syncRoutesToStore(newRoutes)
        }
    }

    // MARK: - Setup

    private func setupStore() {
        print("🏪 setupStore: starting")
        let repository = RouteRepository(modelContext: modelContext)
        store = NavigationStore(repository: repository)
        syncRoutesToStore(savedRoutes)
        print("🏪 setupStore: store created, requesting current status")
        // Store初期化後にARの現在状態を要求（初期化前のイベントが失われた場合の対策）
        arCommand = .requestCurrentStatus
    }

    private func syncRoutesToStore(_ routes: [NavRoute]) {
        let items = routes.map { route in
            RouteListItem(
                id: route.id,
                name: route.name,
                totalDistance: route.totalDistance,
                moveCount: route.moveCount,
                eventCount: route.eventCount,
                createdAt: route.createdAt
            )
        }
        store?.loadSavedRoutes(items)
    }

    // MARK: - AR Scene Event Handler

    private func handleARSceneEvent(_ event: ARSceneEvent) {
        guard let store = store else {
            print("⚠️ handleARSceneEvent: store is nil, event ignored: \(event)")
            return
        }

        switch event {
        case .readyChanged(let isReady):
            print("✅ handleARSceneEvent: readyChanged(\(isReady))")
            store.send(.arReadyChanged(isReady))

        case .statusChanged(let message):
            print("✅ handleARSceneEvent: statusChanged(\(message))")
            store.send(.statusMessageChanged(message))

        case .recordingInfoUpdated(let distance, let angle):
            store.send(.recordingInfoUpdated(distance: distance, angle: angle))

        case .saveDataReady(let items, let worldMapData, let startAnchorID, let startHeading):
            let repository = RouteRepository(modelContext: modelContext)
            let result = repository.saveRoute(
                items: items,
                worldMapData: worldMapData,
                startAnchorID: startAnchorID,
                startHeading: startHeading
            )
            store.send(.routeSaveCompleted(result))
        }
    }

    // MARK: - Helper Methods

    private func deleteRoutesFromContext(at offsets: IndexSet) {
        for index in offsets {
            if index < savedRoutes.count {
                modelContext.delete(savedRoutes[index])
            }
        }
    }
}

// MARK: - NavigationOverlayView

/// Store の状態を監視して UI を更新するオーバーレイビュー
private struct NavigationOverlayView: View {
    @ObservedObject var store: NavigationStore
    let savedRoutes: [NavRoute]
    @Binding var arCommand: ARSceneCommand
    let onDeleteRoutes: (IndexSet) -> Void

    var body: some View {
        VStack {
            StatusBarView(state: store.state)
            Spacer()

            if store.state.phase == .recording {
                RecordingInfoView(info: store.state.recordingInfo)
            }

            Spacer()
            ControlButtonsView(
                state: store.state,
                onAction: { store.send($0) },
                onARCommand: { arCommand = $0 }
            )
        }
        .sheet(isPresented: showRouteListBinding) {
            RouteListSheet(
                routes: store.state.savedRoutes,
                onClose: { store.send(.setShowRouteList(false)) },
                onReplay: { item in
                    store.send(.startReplay(item))
                    store.send(.setShowRouteList(false))
                    if let route = savedRoutes.first(where: { $0.id == item.id }) {
                        arCommand = .replay(route: route)
                    }
                },
                onDelete: { indexSet in
                    store.send(.deleteRoutes(indexSet))
                    onDeleteRoutes(indexSet)
                }
            )
        }
        .sheet(isPresented: showEventPickerBinding) {
            EventPickerSheet(
                onSelect: { eventType in
                    store.send(.addEvent(eventType))
                    store.send(.setShowEventPicker(false))
                },
                onCancel: { store.send(.setShowEventPicker(false)) }
            )
        }
    }

    private var showRouteListBinding: Binding<Bool> {
        Binding(
            get: { store.state.showRouteList },
            set: { store.send(.setShowRouteList($0)) }
        )
    }

    private var showEventPickerBinding: Binding<Bool> {
        Binding(
            get: { store.state.showEventPicker },
            set: { store.send(.setShowEventPicker($0)) }
        )
    }
}
