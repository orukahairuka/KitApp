//
//  NavigationAction.swift
//  KitApp
//
//  Storeに送信するアクションの定義
//

import Foundation

// MARK: - NavigationAction

/// ユーザー操作やシステムイベントを表すアクション
enum NavigationAction {

    // MARK: - Recording Actions

    /// 記録を開始
    case startRecording

    /// 曲がり地点を記録
    case recordTurn

    /// 記録をキャンセル
    case cancelRecording

    /// ルートを保存
    case saveRoute

    /// イベントを追加（階段など）
    case addEvent(EventType)

    // MARK: - Replay Actions

    /// ルートを選択して再生開始
    case startReplay(RouteListItem)

    /// 再生を終了
    case stopReplay

    // MARK: - Route Management Actions

    /// ルートを削除
    case deleteRoutes(IndexSet)

    // MARK: - UI Actions

    /// ルートリストシートの表示切替
    case setShowRouteList(Bool)

    /// イベントピッカーシートの表示切替
    case setShowEventPicker(Bool)

    // MARK: - AR Session Callbacks

    /// ARセッションの準備状態が変化
    case arReadyChanged(Bool)

    /// ステータスメッセージが変化
    case statusMessageChanged(String)

    /// 記録中の距離・角度が更新
    case recordingInfoUpdated(distance: Float, angle: Float)

    /// ルート保存が完了
    case routeSaveCompleted(Result<String, NavigationError>)

    /// ARセッションがリセット完了
    case resetCompleted
}

// MARK: - NavigationError

/// ナビゲーション関連のエラー
enum NavigationError: LocalizedError, Equatable {
    /// 記録データがない
    case noRecordingData

    /// WorldMap取得に失敗
    case worldMapUnavailable

    /// 保存に失敗
    case saveFailed(String)

    /// ARセッションが準備できていない
    case arSessionNotReady

    /// データ取得に失敗
    case fetchFailed(String)

    /// 削除に失敗
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRecordingData:
            return "記録データがありません"
        case .worldMapUnavailable:
            return "WorldMapを取得できませんでした"
        case .saveFailed(let message):
            return "保存エラー: \(message)"
        case .arSessionNotReady:
            return "ARセッションが準備できていません"
        case .fetchFailed(let message):
            return "取得エラー: \(message)"
        case .deleteFailed(let message):
            return "削除エラー: \(message)"
        }
    }
}
