//
//  ContentView.swift
//  KitApp
//
//  AR お絵描きアプリのメインビュー（SwiftUI）
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RouteRecord.createdAt, order: .reverse) private var savedRoutes: [RouteRecord]

    @State private var drawingColor: Color = .red
    @State private var isTouching: Bool = false
    @State private var shouldReset: Bool = false
    @State private var statusMessage: String = "準備中..."
    @State private var isReady: Bool = false
    @State private var showColorPicker: Bool = false

    // ルート保存・再生用
    @State private var shouldSave: Bool = false
    @State private var routeToReplay: RouteRecord?
    @State private var showRouteList: Bool = false

    var body: some View {
        ZStack {
            ARSceneView(
                drawingColor: $drawingColor,
                isTouching: $isTouching,
                shouldReset: $shouldReset,
                statusMessage: $statusMessage,
                isReady: $isReady,
                shouldSave: $shouldSave,
                routeToReplay: $routeToReplay,
                modelContext: modelContext
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if isReady && !isTouching {
                            isTouching = true
                        }
                    }
                    .onEnded { _ in
                        isTouching = false
                        if isReady {
                            statusMessage = "画面をタッチして描画"
                        }
                    }
            )

            VStack {
                Text(statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.top, 60)

                Spacer()

                if isTouching {
                    Circle()
                        .fill(drawingColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }

                Spacer()

                // 下部ツールバー
                HStack(spacing: 16) {
                    // カラーピッカーボタン
                    Button {
                        showColorPicker.toggle()
                    } label: {
                        Circle()
                            .fill(drawingColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                    }

                    // 保存ボタン
                    Button {
                        shouldSave = true
                    } label: {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Circle())
                    }

                    // ルート一覧ボタン
                    Button {
                        showRouteList = true
                    } label: {
                        ZStack {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())

                            if !savedRoutes.isEmpty {
                                Text("\(savedRoutes.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 16, y: -16)
                            }
                        }
                    }

                    // リセットボタン
                    Button {
                        shouldReset = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 50)
            }

            // カラーピッカーオーバーレイ
            if showColorPicker {
                colorPickerOverlay
            }
        }
        .sheet(isPresented: $showRouteList) {
            routeListSheet
        }
    }

    // MARK: - カラーピッカーオーバーレイ

    private var colorPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showColorPicker = false
                }

            VStack(spacing: 20) {
                Text("描画色を選択")
                    .font(.headline)
                    .foregroundColor(.primary)

                ColorPicker("", selection: $drawingColor, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(1.5)

                HStack(spacing: 16) {
                    ForEach([Color.red, .orange, .yellow, .green, .blue, .purple], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(drawingColor == color ? Color.white : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                drawingColor = color
                            }
                    }
                }

                Button("閉じる") {
                    showColorPicker = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

    // MARK: - ルート一覧シート

    private var routeListSheet: some View {
        NavigationStack {
            List {
                if savedRoutes.isEmpty {
                    Text("保存されたルートはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(savedRoutes) { route in
                        routeRow(route)
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

    /// ルート行の表示
    private func routeRow(_ route: RouteRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.startPointID)
                    .font(.headline)
                Text("\(route.steps.count) ステップ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(route.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                routeToReplay = route
                showRouteList = false
            } label: {
                Image(systemName: "play.fill")
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    /// ルートを削除
    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedRoutes[index])
        }
    }
}
