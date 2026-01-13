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
            }
        }
        .sheet(isPresented: showRouteListBinding) {
            if let store = store {
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
                        deleteRoutesFromContext(at: indexSet)
                    }
                )
            }
        }
        .sheet(isPresented: showEventPickerBinding) {
            if let store = store {
                EventPickerSheet(
                    onSelect: { eventType in
                        store.send(.addEvent(eventType))
                        store.send(.setShowEventPicker(false))
                    },
                    onCancel: { store.send(.setShowEventPicker(false)) }
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
        let repository = RouteRepository(modelContext: modelContext)
        store = NavigationStore(repository: repository)
        syncRoutesToStore(savedRoutes)
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
        guard let store = store else { return }

        switch event {
        case .readyChanged(let isReady):
            store.send(.arReadyChanged(isReady))

        case .statusChanged(let message):
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

    // MARK: - Bindings

    private var showRouteListBinding: Binding<Bool> {
        Binding(
            get: { store?.state.showRouteList ?? false },
            set: { store?.send(.setShowRouteList($0)) }
        )
    }

    private var showEventPickerBinding: Binding<Bool> {
        Binding(
            get: { store?.state.showEventPicker ?? false },
            set: { store?.send(.setShowEventPicker($0)) }
        )
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
