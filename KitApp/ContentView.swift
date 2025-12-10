//
//  ContentView.swift
//  KitApp
//
//  AR お絵描きアプリのメインビュー（SwiftUI）
//

import SwiftUI

struct ContentView: View {
    @State private var drawingColor: Color = .red
    @State private var isTouching: Bool = false
    @State private var shouldReset: Bool = false
    @State private var statusMessage: String = "準備中..."
    @State private var isReady: Bool = false
    @State private var showColorPicker: Bool = false

    var body: some View {
        ZStack {
            ARSceneView(
                drawingColor: $drawingColor,
                isTouching: $isTouching,
                shouldReset: $shouldReset,
                statusMessage: $statusMessage,
                isReady: $isReady
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

                HStack(spacing: 24) {
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
