//
//  NavigationConfig.swift
//  KitApp
//
//  ナビゲーション関連の設定値を集約
//

import Foundation
import UIKit

// MARK: - NavigationConfig

/// ナビゲーション機能の設定値
enum NavigationConfig {

    // MARK: - Recording

    /// 記録時の設定
    enum Recording {
        /// 曲がり地点として記録する最小距離（メートル）
        static let minTurnDistance: Float = 0.05

        /// 保存時の最小距離（ノイズ除去用）（メートル）
        static let minSaveDistance: Float = 0.01

        /// 角度計算を開始する最小移動距離（メートル）
        static let minDistanceForAngle: Float = 0.1
    }

    // MARK: - Trail

    /// 軌跡描画の設定
    enum Trail {
        /// 軌跡リボンを追加する間隔（メートル）
        static let ribbonInterval: Float = 0.15

        /// リボンの幅（メートル）
        static let ribbonWidth: CGFloat = 0.08

        /// リボンの厚さ（メートル）
        static let ribbonHeight: CGFloat = 0.005
    }

    // MARK: - Positioning

    /// 位置調整の設定
    enum Positioning {
        /// 床からの高さ調整（メートル）
        static let floorOffset: Float = 0.5

        /// フォールバック時の前方配置距離（メートル）
        static let fallbackForwardDistance: Float = 1.0
    }

    // MARK: - Markers

    /// マーカーノードの設定
    enum Markers {
        /// スタート/ゴールマーカーの半径（メートル）
        static let cylinderRadius: CGFloat = 0.05

        /// スタート/ゴールマーカーの高さ（メートル）
        static let cylinderHeight: CGFloat = 0.4

        /// 曲がり地点マーカーの半径（メートル）
        static let turnSphereRadius: CGFloat = 0.04

        /// 矢印の底面半径（メートル）
        static let arrowBottomRadius: CGFloat = 0.025

        /// 矢印の高さ（メートル）
        static let arrowHeight: CGFloat = 0.06

        /// イベントマーカーの半径（メートル）
        static let eventSphereRadius: CGFloat = 0.1

        /// イベントマーカーのY位置オフセット（メートル）
        static let eventSphereYOffset: Float = 0.2
    }

    // MARK: - Colors

    /// 色の設定
    enum Colors {
        /// スタートマーカーの色
        static let startMarker: UIColor = .green

        /// ゴールマーカーの色
        static let goalMarker: UIColor = .blue

        /// 曲がり地点マーカーの色
        static let turnMarker: UIColor = .orange

        /// 記録中の軌跡の色
        static let recordingTrail: UIColor = .red

        /// 再生時の軌跡の色
        static let replayTrail: UIColor = .cyan

        /// 矢印の色
        static let arrow: UIColor = .yellow

        /// イベントマーカーの色
        static let eventMarker: UIColor = .purple

        /// 発光の透明度
        static let emissionAlpha: CGFloat = 0.5

        /// 軌跡の透明度
        static let trailAlpha: CGFloat = 0.7

        /// 発光（弱）の透明度
        static let emissionWeakAlpha: CGFloat = 0.3
    }

    // MARK: - Text

    /// テキスト表示の設定
    enum Text {
        /// イベントテキストのフォントサイズ
        static let eventFontSize: CGFloat = 0.05

        /// イベントテキストの押し出し深度
        static let eventExtrusionDepth: CGFloat = 0.005

        /// イベントテキストのスケール
        static let eventTextScale: Float = 0.5
    }
}
