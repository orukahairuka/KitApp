//
//  RouteRecord.swift
//  KitApp
//
//  ルート記録の SwiftData モデル
//  「方向＋距離」のステップ列を保存する
//

import Foundation
import SwiftData
import SceneKit

// MARK: - RouteStep（Codable 構造体）

/// 1ステップ分の移動データ
/// - direction: 前ステップからの相対角度（ラジアン、Y軸周り）
/// - distance: 移動距離（メートル）
struct RouteStep: Codable, Equatable {
    let direction: Float   // 相対角度（ラジアン）
    let distance: Float    // 距離（メートル）

    init(direction: Float, distance: Float) {
        self.direction = direction
        self.distance = distance
    }
}

// MARK: - RouteRecord（SwiftData モデル）

/// 保存されたルートのレコード
@Model
final class RouteRecord {
    /// ユニーク識別子
    var id: UUID

    /// スタート地点ID（ユーザーが識別するための名前）
    var startPointID: String

    /// 作成日時
    var createdAt: Date

    /// ステップ配列（JSON エンコードして保存）
    var stepsData: Data

    /// 初期の向き（ラジアン、Y軸周り）
    /// 最初のステップの絶対方向を保持
    var initialHeading: Float

    init(startPointID: String, steps: [RouteStep], initialHeading: Float) {
        self.id = UUID()
        self.startPointID = startPointID
        self.createdAt = Date()
        self.initialHeading = initialHeading
        self.stepsData = (try? JSONEncoder().encode(steps)) ?? Data()
    }

    /// ステップ配列を取得
    var steps: [RouteStep] {
        get {
            (try? JSONDecoder().decode([RouteStep].self, from: stepsData)) ?? []
        }
        set {
            stepsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

// MARK: - RouteConverter（頂点 → ステップ変換）

/// 頂点配列をルートステップに変換するユーティリティ
struct RouteConverter {

    /// 頂点配列からルートステップを生成
    /// - Parameter vertices: 3D 座標の配列
    /// - Returns: (steps: ステップ配列, initialHeading: 最初の向き)
    static func convert(from vertices: [SCNVector3]) -> (steps: [RouteStep], initialHeading: Float) {
        guard vertices.count >= 2 else {
            return ([], 0)
        }

        // 中心線を抽出（リボンの上下2点ペアから中心を計算）
        let centerPoints = extractCenterPoints(from: vertices)

        guard centerPoints.count >= 2 else {
            return ([], 0)
        }

        var steps: [RouteStep] = []
        var previousHeading: Float = 0
        var initialHeading: Float = 0

        for i in 1..<centerPoints.count {
            let prev = centerPoints[i - 1]
            let curr = centerPoints[i]

            // 距離を計算
            let dx = curr.x - prev.x
            let dz = curr.z - prev.z
            let distance = sqrt(dx * dx + dz * dz)

            // 微小な移動はスキップ
            guard distance > 0.001 else { continue }

            // 絶対角度を計算（Y軸周り、北を0とする）
            let absoluteHeading = atan2(dx, -dz)

            if steps.isEmpty {
                // 最初のステップ：絶対角度を記録
                initialHeading = absoluteHeading
                steps.append(RouteStep(direction: 0, distance: distance))
            } else {
                // 相対角度を計算
                var relativeDirection = absoluteHeading - previousHeading

                // -π ～ π に正規化
                while relativeDirection > .pi { relativeDirection -= 2 * .pi }
                while relativeDirection < -.pi { relativeDirection += 2 * .pi }

                steps.append(RouteStep(direction: relativeDirection, distance: distance))
            }

            previousHeading = absoluteHeading
        }

        return (steps, initialHeading)
    }

    /// リボンの頂点配列から中心線を抽出
    /// DynamicGeometryNode は上下ペアで頂点を追加するため、
    /// 2点ずつ平均を取って中心線を復元する
    private static func extractCenterPoints(from vertices: [SCNVector3]) -> [SCNVector3] {
        var centers: [SCNVector3] = []

        // 2点ずつペアで処理
        var i = 0
        while i + 1 < vertices.count {
            let lower = vertices[i]
            let upper = vertices[i + 1]
            let center = SCNVector3(
                (lower.x + upper.x) / 2,
                (lower.y + upper.y) / 2,
                (lower.z + upper.z) / 2
            )
            centers.append(center)
            i += 2
        }

        return centers
    }

    /// ルートステップから頂点配列を再構築
    /// - Parameters:
    ///   - steps: ステップ配列
    ///   - initialHeading: 最初の向き
    ///   - startPosition: 開始位置
    /// - Returns: 中心線の座標配列
    static func reconstruct(
        steps: [RouteStep],
        initialHeading: Float,
        startPosition: SCNVector3
    ) -> [SCNVector3] {
        guard !steps.isEmpty else { return [] }

        var points: [SCNVector3] = [startPosition]
        var currentPosition = startPosition
        var currentHeading = initialHeading

        for step in steps {
            // 向きを更新
            currentHeading += step.direction

            // 新しい位置を計算
            let dx = sin(currentHeading) * step.distance
            let dz = -cos(currentHeading) * step.distance

            currentPosition = SCNVector3(
                currentPosition.x + dx,
                currentPosition.y,
                currentPosition.z + dz
            )
            points.append(currentPosition)
        }

        return points
    }
}
