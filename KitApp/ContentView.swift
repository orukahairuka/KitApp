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
                routeListSheet(store: store)
            }
        }
        .sheet(isPresented: showEventPickerBinding) {
            if let store = store {
                eventPickerSheet(store: store)
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

    // MARK: - Route List Sheet

    private func routeListSheet(store: NavigationStore) -> some View {
        NavigationStack {
            List {
                if store.state.savedRoutes.isEmpty {
                    Text("保存されたルートはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.state.savedRoutes) { item in
                        routeRow(item: item, store: store)
                    }
                    .onDelete { indexSet in
                        store.send(.deleteRoutes(indexSet))
                        deleteRoutesFromContext(at: indexSet)
                    }
                }
            }
            .navigationTitle("保存済みルート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        store.send(.setShowRouteList(false))
                    }
                }
            }
        }
    }

    private func routeRow(item: RouteListItem, store: NavigationStore) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label(String(format: "%.1fm", item.totalDistance), systemImage: "figure.walk")
                    Label("\(item.moveCount)", systemImage: "arrow.right")
                    if item.eventCount > 0 {
                        Label("\(item.eventCount)", systemImage: "star.fill")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                store.send(.startReplay(item))
                store.send(.setShowRouteList(false))
                if let route = savedRoutes.first(where: { $0.id == item.id }) {
                    arCommand = .replay(route: route)
                }
            } label: {
                Image(systemName: "play.fill")
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func deleteRoutesFromContext(at offsets: IndexSet) {
        for index in offsets {
            if index < savedRoutes.count {
                modelContext.delete(savedRoutes[index])
            }
        }
    }

    // MARK: - Event Picker Sheet

    private func eventPickerSheet(store: NavigationStore) -> some View {
        NavigationStack {
            List {
                ForEach(EventType.allCases, id: \.self) { eventType in
                    Button {
                        store.send(.addEvent(eventType))
                        store.send(.setShowEventPicker(false))
                    } label: {
                        HStack {
                            Image(systemName: eventType.iconName)
                                .font(.title2)
                                .foregroundColor(.purple)
                                .frame(width: 40)
                            Text(eventType.displayText)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("イベントを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        store.send(.setShowEventPicker(false))
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
