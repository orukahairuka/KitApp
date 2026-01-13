//
//  EventPickerSheet.swift
//  KitApp
//
//  イベント選択シートコンポーネント
//

import SwiftUI

// MARK: - EventPickerSheet

/// イベントタイプを選択するシート
struct EventPickerSheet: View {
    let onSelect: (EventType) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(EventType.allCases, id: \.self) { eventType in
                    Button {
                        onSelect(eventType)
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
                        onCancel()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
