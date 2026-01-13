//
//  StatusBarView.swift
//  KitApp
//
//  ステータスバーコンポーネント
//

import SwiftUI

// MARK: - StatusBarView

/// アプリの状態を表示するステータスバー
struct StatusBarView: View {
    let state: NavigationViewState

    var body: some View {
        HStack {
            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)
            Text(state.statusMessage)
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
        switch state.stateColor {
        case .preparing: return .orange
        case .ready: return .green
        case .recording: return .red
        case .replaying: return .blue
        }
    }
}
