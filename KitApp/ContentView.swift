//
//  ContentView.swift
//  KitApp
//
//  AR お絵描きアプリのメインビュー（SwiftUI）
//

import SwiftUI

struct ContentView: View {

    // MARK: - State

    /// 描画色
    @State private var drawingColor: Color = .red

    /// タッチ中かどうか
    @State private var isTouching: Bool = false

    /// リセットトリガー
    @State private var shouldReset: Bool = false

    /// ステータスメッセージ
    @State private var statusMessage: String = "準備中..."

    /// AR 準備完了フラグ
    @State private var isReady: Bool = false

    /// カラーピッカー表示フラグ
    @State private var showColorPicker: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // MARK: - AR ビュー（全画面）

            ARSceneView(
                drawingColor: $drawingColor,
                isTouching: $isTouching,
                shouldReset: $shouldReset,
                statusMessage: $statusMessage,
                isReady: $isReady
            )
            .ignoresSafeArea()
            // タッチジェスチャー
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

            // MARK: - UI オーバーレイ

            VStack {
                // ステータスラベル（上部）
                Text(statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.top, 60)

                Spacer()

                // ペンインジケーター（中央）
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

                // コントロールパネル（下部）
                HStack(spacing: 24) {
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

            // MARK: - カラーピッカーシート

            if showColorPicker {
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

                    // プリセットカラー
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
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
