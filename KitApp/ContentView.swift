//
//  ContentView.swift
//  KitApp
//
//  歩行ナビプロトタイプのメインビュー
//

import SwiftUI
import SwiftData

enum NavState {
    case idle
    case recording
    case replaying
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NavRoute.createdAt, order: .reverse) private var savedRoutes: [NavRoute]

    @State private var navState: NavState = .idle
    @State private var isReady = false
    @State private var statusMessage = "準備中..."
    @State private var currentDistance: Float = 0
    @State private var currentAngle: Float = 0

    @State private var shouldStartRecording = false
    @State private var shouldRecordTurn = false
    @State private var shouldSaveRoute = false
    @State private var shouldReset = false
    @State private var routeToReplay: NavRoute?

    @State private var showRouteList = false
    @State private var showEventPicker = false
    @State private var pendingSaveItems: [RouteItem] = []
    @State private var saveRequestID: UUID?

    // WorldMap 関連
    @State private var pendingWorldMapData: Data?
    @State private var pendingStartAnchorID: UUID?
    @State private var pendingStartHeading: Float = 0

    var body: some View {
        ZStack {
            NavARSceneView(
                navState: $navState,
                isReady: $isReady,
                statusMessage: $statusMessage,
                currentDistance: $currentDistance,
                currentAngle: $currentAngle,
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

            VStack {
                statusBar
                Spacer()

                if navState == .recording {
                    recordingInfo
                }

                Spacer()
                controlButtons
            }
        }
        .sheet(isPresented: $showRouteList) {
            routeListSheet
        }
        .sheet(isPresented: $showEventPicker) {
            eventPickerSheet
        }
        .onChange(of: saveRequestID) { _, newID in
            guard newID != nil, !pendingSaveItems.isEmpty else { return }
            print("📦 onChange triggered, items: \(pendingSaveItems.count), worldMap: \(pendingWorldMapData?.count ?? 0) bytes")
            saveRoute(
                items: pendingSaveItems,
                worldMapData: pendingWorldMapData,
                startAnchorID: pendingStartAnchorID,
                startHeading: pendingStartHeading
            )
            pendingSaveItems = []
            pendingWorldMapData = nil
            pendingStartAnchorID = nil
            pendingStartHeading = 0
            saveRequestID = nil
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)
            Text(statusMessage)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .padding(.top, 60)
    }

    private var stateColor: Color {
        switch navState {
        case .idle: return isReady ? .green : .orange
        case .recording: return .red
        case .replaying: return .blue
        }
    }

    // MARK: - Recording Info

    private var recordingInfo: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                Text(String(format: "%.2f m", currentDistance))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)

            HStack {
                Image(systemName: "arrow.triangle.turn.up.right.circle")
                    .font(.title3)
                Text(String(format: "%.1f°", currentAngle))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(20)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        VStack(spacing: 16) {
            switch navState {
            case .idle:
                idleButtons
            case .recording:
                recordingButtons
            case .replaying:
                replayingButtons
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 50)
    }

    private var idleButtons: some View {
        HStack(spacing: 20) {
            Button {
                shouldStartRecording = true
            } label: {
                HStack {
                    Image(systemName: "record.circle")
                    Text("スタート")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(isReady ? Color.red : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isReady)

            Button {
                showRouteList = true
            } label: {
                ZStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)

                    if !savedRoutes.isEmpty {
                        Text("\(savedRoutes.count)")
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

    private var recordingButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
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
                    showEventPicker = true
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
                shouldReset = true
                navState = .idle
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

    private var replayingButtons: some View {
        Button {
            shouldReset = true
            navState = .idle
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

    private var routeListSheet: some View {
        NavigationStack {
            List {
                if savedRoutes.isEmpty {
                    Text("保存されたルートはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(savedRoutes) { route in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.name)
                                    .font(.headline)
                                HStack(spacing: 12) {
                                    Label(String(format: "%.1fm", route.totalDistance), systemImage: "figure.walk")
                                    Label("\(route.moveCount)", systemImage: "arrow.right")
                                    if route.eventCount > 0 {
                                        Label("\(route.eventCount)", systemImage: "star.fill")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                routeToReplay = route
                                navState = .replaying
                                showRouteList = false
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
                    .onDelete(perform: deleteRoutes)
                }
            }
            .navigationTitle("保存済みルート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        showRouteList = false
                    }
                }
            }
        }
    }

    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedRoutes[index])
        }
    }

    private func saveRoute(items: [RouteItem], worldMapData: Data?, startAnchorID: UUID?, startHeading: Float) {
        let routeName = "Route_\(Date().formatted(.dateTime.month().day().hour().minute()))"
        let route = NavRoute(
            name: routeName,
            items: items,
            worldMapData: worldMapData,
            startAnchorID: startAnchorID,
            startHeading: startHeading
        )
        modelContext.insert(route)

        do {
            try modelContext.save()
            let mapStatus = worldMapData != nil ? "WorldMap付き" : "WorldMapなし"
            statusMessage = "保存完了: \(routeName) (\(mapStatus))"
            print("✅ Route saved: \(routeName), items: \(items.count), worldMap: \(worldMapData?.count ?? 0) bytes")
        } catch {
            statusMessage = "保存エラー: \(error.localizedDescription)"
            print("❌ Save error: \(error)")
        }
        navState = .idle
    }

    // MARK: - Event Picker Sheet

    private var eventPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(EventType.allCases, id: \.self) { eventType in
                    Button {
                        // イベントを追加（将来的にはCoordinatorに直接追加）
                        showEventPicker = false
                        statusMessage = eventType.displayText
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
                        showEventPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
