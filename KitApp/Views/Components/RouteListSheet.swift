//
//  RouteListSheet.swift
//  KitApp
//
//  保存済みルート一覧シートコンポーネント
//

import SwiftUI

// MARK: - RouteListSheet

/// 保存済みルートの一覧を表示するシート
struct RouteListSheet: View {
    let routes: [RouteListItem]
    let onClose: () -> Void
    let onReplay: (RouteListItem) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        NavigationStack {
            List {
                if routes.isEmpty {
                    Text("保存されたルートはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(routes) { item in
                        RouteRowView(
                            item: item,
                            onReplay: { onReplay(item) }
                        )
                    }
                    .onDelete { indexSet in
                        onDelete(indexSet)
                    }
                }
            }
            .navigationTitle("保存済みルート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        onClose()
                    }
                }
            }
        }
    }
}

// MARK: - RouteRowView

/// ルート一覧の行ビュー
private struct RouteRowView: View {
    let item: RouteListItem
    let onReplay: () -> Void

    var body: some View {
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
                onReplay()
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
}
