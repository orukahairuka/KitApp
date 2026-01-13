//
//  NavigationViewState.swift
//  KitApp
//
//  Viewの表示に必要な状態を保持する構造体
//

import Foundation

// MARK: - NavPhase

/// ナビゲーションのフェーズ
enum NavPhase: Equatable {
    case idle
    case recording
    case replaying(routeName: String)
}

// MARK: - NavigationViewState

/// Viewが描画に必要とする状態
struct NavigationViewState: Equatable {
    /// 現在のナビゲーションフェーズ
    var phase: NavPhase = .idle

    /// ARセッションの準備状態
    var isARReady: Bool = false

    /// ステータスメッセージ
    var statusMessage: String = "準備中..."

    /// 記録中の情報（recording フェーズのみ）
    var recordingInfo: RecordingInfo?

    /// 保存済みルート一覧
    var savedRoutes: [RouteListItem] = []

    /// ルートリストシートの表示状態
    var showRouteList: Bool = false

    /// イベントピッカーシートの表示状態
    var showEventPicker: Bool = false
}

// MARK: - RecordingInfo

/// 記録中に表示する情報
struct RecordingInfo: Equatable {
    /// 前回の曲がり地点からの距離（メートル）
    let distance: Float

    /// 前回の移動方向からの角度（度）
    let angle: Float
}

// MARK: - RouteListItem

/// ルートリスト表示用のアイテム
struct RouteListItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let totalDistance: Float
    let moveCount: Int
    let eventCount: Int
    let createdAt: Date
}

// MARK: - Computed Properties

extension NavigationViewState {
    /// ステータスバーの色
    var stateColor: StateColor {
        switch phase {
        case .idle:
            return isARReady ? .ready : .preparing
        case .recording:
            return .recording
        case .replaying:
            return .replaying
        }
    }

    /// スタートボタンが有効か
    var canStartRecording: Bool {
        phase == .idle && isARReady
    }

    /// idle状態でのステータスメッセージ
    var idleStatusMessage: String {
        isARReady ? "準備完了" : "準備中..."
    }
}

// MARK: - StateColor

/// ステータス表示用の色種別
enum StateColor {
    case preparing  // orange
    case ready      // green
    case recording  // red
    case replaying  // blue
}
