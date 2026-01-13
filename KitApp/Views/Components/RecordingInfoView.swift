//
//  RecordingInfoView.swift
//  KitApp
//
//  記録中の情報表示コンポーネント
//

import SwiftUI

// MARK: - RecordingInfoView

/// 記録中の距離と角度を表示するビュー
struct RecordingInfoView: View {
    let info: RecordingInfo?

    var body: some View {
        let displayInfo = info ?? RecordingInfo(distance: 0, angle: 0)

        VStack(spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                Text(String(format: "%.2f m", displayInfo.distance))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)

            HStack {
                Image(systemName: "arrow.triangle.turn.up.right.circle")
                    .font(.title3)
                Text(String(format: "%.1f°", displayInfo.angle))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(20)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }
}
