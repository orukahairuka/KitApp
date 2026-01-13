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

    // NavARSceneViewとの連携用（過渡期 - Step 3.3で削除予定）
    @State private var legacyNavState: NavState = .idle
    @State private var legacyIsReady = false
    @State private var legacyStatusMessage = "準備中..."
    @State private var legacyCurrentDistance: Float = 0
    @State private var legacyCurrentAngle: Float = 0
    @State private var shouldStartRecording = false
    @State private var shouldRecordTurn = false
    @State private var shouldSaveRoute = false
    @State private var shouldReset = false
    @State private var routeToReplay: NavRoute?
    @State private var pendingSaveItems: [RouteItem] = []
    @State private var saveRequestID: UUID?
    @State private var pendingWorldMapData: Data?
    @State private var pendingStartAnchorID: UUID?
    @State private var pendingStartHeading: Float = 0

    var body: some View {
        ZStack {
            NavARSceneView(
                navState: $legacyNavState,
                isReady: $legacyIsReady,
                statusMessage: $legacyStatusMessage,
                currentDistance: $legacyCurrentDistance,
                currentAngle: $legacyCurrentAngle,
                shouldStartRecording: $shouldStartRecording,
                shouldRecordTurn: $shouldRecordTurn,
                shouldSaveRoute: $shouldSaveRoute,
                shouldReset: $shouldReset,
                routeToReplay: $routeToReplay,
                pendingSaveItems: $pendingSaveItems,
                saveRequestID: $saveRequestID,
                pendingWorldMapData: $pendingWorldMapData,
                pendingStartAnchorID: $pendingStartAnchorID,
                pendingStartHeading: $pendingStartHeading
            )
            .ignoresSafeArea()

            if let store = store {
                VStack {
                    statusBar(store: store)
                    Spacer()

                    if store.state.phase == .recording {
                        recordingInfo(store: store)
                    }

                    Spacer()
                    controlButtons(store: store)
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
        .onChange(of: legacyIsReady) { _, newValue in
            store?.send(.arReadyChanged(newValue))
        }
        .onChange(of: legacyStatusMessage) { _, newValue in
            store?.send(.statusMessageChanged(newValue))
        }
        .onChange(of: legacyCurrentDistance) { _, _ in
            store?.send(.recordingInfoUpdated(distance: legacyCurrentDistance, angle: legacyCurrentAngle))
        }
        .onChange(of: saveRequestID) { _, newID in
            handleSaveRequest(newID)
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

    private func handleSaveRequest(_ newID: UUID?) {
        guard newID != nil, !pendingSaveItems.isEmpty, let store = store else { return }

        print("📦 onChange triggered, items: \(pendingSaveItems.count), worldMap: \(pendingWorldMapData?.count ?? 0) bytes")

        let repository = RouteRepository(modelContext: modelContext)
        let result = repository.saveRoute(
            items: pendingSaveItems,
            worldMapData: pendingWorldMapData,
            startAnchorID: pendingStartAnchorID,
            startHeading: pendingStartHeading
        )

        store.send(.routeSaveCompleted(result))

        pendingSaveItems = []
        pendingWorldMapData = nil
        pendingStartAnchorID = nil
        pendingStartHeading = 0
        saveRequestID = nil
        legacyNavState = .idle
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

    // MARK: - Status Bar

    private func statusBar(store: NavigationStore) -> some View {
        HStack {
            Circle()
                .fill(stateColor(for: store.state))
                .frame(width: 12, height: 12)
            Text(store.state.statusMessage)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .padding(.top, 60)
    }

    private func stateColor(for state: NavigationViewState) -> Color {
        switch state.stateColor {
        case .preparing: return .orange
        case .ready: return .green
        case .recording: return .red
        case .replaying: return .blue
        }
    }

    // MARK: - Recording Info

    private func recordingInfo(store: NavigationStore) -> some View {
        let info = store.state.recordingInfo ?? RecordingInfo(distance: 0, angle: 0)

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                Text(String(format: "%.2f m", info.distance))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)

            HStack {
                Image(systemName: "arrow.triangle.turn.up.right.circle")
                    .font(.title3)
                Text(String(format: "%.1f°", info.angle))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(20)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }

    // MARK: - Control Buttons

    private func controlButtons(store: NavigationStore) -> some View {
        VStack(spacing: 16) {
            switch store.state.phase {
            case .idle:
                idleButtons(store: store)
            case .recording:
                recordingButtons(store: store)
            case .replaying:
                replayingButtons(store: store)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 50)
    }

    private func idleButtons(store: NavigationStore) -> some View {
        HStack(spacing: 20) {
            Button {
                store.send(.startRecording)
                shouldStartRecording = true
                legacyNavState = .recording
            } label: {
                HStack {
                    Image(systemName: "record.circle")
                    Text("スタート")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(store.state.canStartRecording ? Color.red : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!store.state.canStartRecording)

            Button {
                store.send(.setShowRouteList(true))
            } label: {
                ZStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)

                    if !store.state.savedRoutes.isEmpty {
                        Text("\(store.state.savedRoutes.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .offset(x: 18, y: -18)
                    }
                }
            }
        }
    }

    private func recordingButtons(store: NavigationStore) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    store.send(.recordTurn)
                    shouldRecordTurn = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.title)
                        Text("曲がる")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 70)
                    .background(Color.orange)
                    .cornerRadius(12)
                }

                Button {
                    store.send(.setShowEventPicker(true))
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "stairs")
                            .font(.title)
                        Text("イベント")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 70)
                    .background(Color.purple)
                    .cornerRadius(12)
                }

                Button {
                    store.send(.saveRoute)
                    shouldSaveRoute = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                        Text("保存")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 70)
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }

            Button {
                store.send(.cancelRecording)
                shouldReset = true
                legacyNavState = .idle
            } label: {
                Text("キャンセル")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(8)
            }
        }
    }

    private func replayingButtons(store: NavigationStore) -> some View {
        Button {
            store.send(.stopReplay)
            shouldReset = true
            legacyNavState = .idle
        } label: {
            HStack {
                Image(systemName: "stop.fill")
                Text("終了")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color.gray)
            .cornerRadius(12)
        }
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
                // レガシー連携
                if let route = savedRoutes.first(where: { $0.id == item.id }) {
                    routeToReplay = route
                    legacyNavState = .replaying
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

// MARK: - Legacy NavState (過渡期)

enum NavState {
    case idle
    case recording
    case replaying
}
