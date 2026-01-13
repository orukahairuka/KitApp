//
//  ControlButtonsView.swift
//  KitApp
//
//  コントロールボタンコンポーネント
//

import SwiftUI

// MARK: - ControlButtonsView

/// フェーズに応じたコントロールボタンを表示するビュー
struct ControlButtonsView: View {
    let state: NavigationViewState
    let onAction: (NavigationAction) -> Void
    let onARCommand: (ARSceneCommand) -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch state.phase {
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

    // MARK: - Idle Buttons

    private var idleButtons: some View {
        HStack(spacing: 20) {
            Button {
                onAction(.startRecording)
                onARCommand(.startRecording)
            } label: {
                HStack {
                    Image(systemName: "record.circle")
                    Text("スタート")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(state.canStartRecording ? Color.red : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!state.canStartRecording)

            Button {
                onAction(.setShowRouteList(true))
            } label: {
                ZStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)

                    if !state.savedRoutes.isEmpty {
                        Text("\(state.savedRoutes.count)")
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

    // MARK: - Recording Buttons

    private var recordingButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    onAction(.recordTurn)
                    onARCommand(.recordTurn)
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
                    onAction(.setShowEventPicker(true))
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
                    onAction(.saveRoute)
                    onARCommand(.saveRoute)
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
                onAction(.cancelRecording)
                onARCommand(.reset)
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

    // MARK: - Replaying Buttons

    private var replayingButtons: some View {
        Button {
            onAction(.stopReplay)
            onARCommand(.reset)
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
}
