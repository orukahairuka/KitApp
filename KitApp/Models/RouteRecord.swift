//
//  RouteRecord.swift
//  KitApp
//
//  歩行ナビプロトタイプ用データモデル
//  「距離＋相対角度＋イベント」構造でルートを表現する
//

import Foundation
import SwiftData
import SceneKit

// MARK: - EventType（イベント種別）

/// ナビ中に発生するイベントの種類
/// 階段など、AR 描画を中断して別の案内を行う箇所
enum EventType: String, Codable, CaseIterable {
    case stairsUp       // 階段を上る
    case stairsDown     // 階段を下る
    case elevator       // エレベーター
    case door           // ドア通過

    /// 表示用テキスト
    var displayText: String {
        switch self {
        case .stairsUp:   return "階段を上がってください"
        case .stairsDown: return "階段を下りてください"
        case .elevator:   return "エレベーターを使用してください"
        case .door:       return "ドアを通過してください"
        }
    }

    /// SF Symbol 名
    var iconName: String {
        switch self {
        case .stairsUp:   return "arrow.up.right"
        case .stairsDown: return "arrow.down.right"
        case .elevator:   return "arrow.up.arrow.down"
        case .door:       return "door.left.hand.open"
        }
    }
}

// MARK: - RouteItem（ルート要素）

/// ルートを構成する1要素
/// - move: 指定距離を指定角度の方向に進む
/// - event: AR描画を止めてイベント（階段等）を案内
enum RouteItem: Codable, Equatable {
    /// 移動
    /// - distance: 移動距離（メートル）
    /// - angle: 相対角度（ラジアン）- 前の向きから何度回転したか
    ///          正の値 = 右回り（時計回り）
    ///          負の値 = 左回り（反時計回り）
    case move(distance: Float, angle: Float)

    /// イベント（階段など）
    case event(type: EventType)

    // MARK: - Codable 実装

    private enum CodingKeys: String, CodingKey {
        case type, distance, angle, eventType
    }

    private enum ItemType: String, Codable {
        case move, event
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)

        switch type {
        case .move:
            let distance = try container.decode(Float.self, forKey: .distance)
            let angle = try container.decode(Float.self, forKey: .angle)
            self = .move(distance: distance, angle: angle)
        case .event:
            let eventType = try container.decode(EventType.self, forKey: .eventType)
            self = .event(type: eventType)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .move(let distance, let angle):
            try container.encode(ItemType.move, forKey: .type)
            try container.encode(distance, forKey: .distance)
            try container.encode(angle, forKey: .angle)
        case .event(let eventType):
            try container.encode(ItemType.event, forKey: .type)
            try container.encode(eventType, forKey: .eventType)
        }
    }
}

// MARK: - NavRoute（ナビルートレコード）

/// 保存されたナビルートのレコード
@Model
final class NavRoute {
    /// ユニーク識別子
    var id: UUID

    /// ルート名（ユーザーが識別するための名前）
    var name: String

    /// 作成日時
    var createdAt: Date

    /// ルートアイテム配列（JSON エンコードして保存）
    var itemsData: Data

    /// 総移動距離（メートル）- 計算済みキャッシュ
    var totalDistance: Float

    init(name: String, items: [RouteItem]) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.itemsData = (try? JSONEncoder().encode(items)) ?? Data()

        // 総距離を計算
        self.totalDistance = items.reduce(0) { sum, item in
            if case .move(let distance, _) = item {
                return sum + distance
            }
            return sum
        }
    }

    /// ルートアイテム配列を取得
    var items: [RouteItem] {
        get {
            (try? JSONDecoder().decode([RouteItem].self, from: itemsData)) ?? []
        }
        set {
            itemsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            // 総距離を再計算
            totalDistance = newValue.reduce(0) { sum, item in
                if case .move(let distance, _) = item {
                    return sum + distance
                }
                return sum
            }
        }
    }

    /// move 要素の数
    var moveCount: Int {
        items.filter { if case .move = $0 { return true } else { return false } }.count
    }

    /// event 要素の数
    var eventCount: Int {
        items.filter { if case .event = $0 { return true } else { return false } }.count
    }
}

// MARK: - RouteReconstructor（ルート再構築ユーティリティ）

/// 保存されたルートから3D座標を再構築するユーティリティ
struct RouteReconstructor {

    /// ルートアイテムから3D座標を再構築
    /// - Parameters:
    ///   - items: ルートアイテム配列
    ///   - startPosition: 開始位置（ワールド座標）
    ///   - startHeading: 開始時の向き（ラジアン、Y軸周り）
    ///                   0 = -Z方向（デフォルトの forward）
    /// - Returns: 各 move の終点座標と、event の位置を含む配列
    static func reconstruct(
        items: [RouteItem],
        startPosition: SCNVector3,
        startHeading: Float = 0
    ) -> [(position: SCNVector3, item: RouteItem)] {
        var results: [(position: SCNVector3, item: RouteItem)] = []
        var currentPosition = startPosition
        var currentHeading = startHeading

        for item in items {
            switch item {
            case .move(let distance, let angle):
                // 向きを更新（相対角度を加算）
                currentHeading += angle

                // 新しい位置を計算
                // Y軸周りの回転: sin(heading) = X成分, -cos(heading) = Z成分
                let dx = sin(currentHeading) * distance
                let dz = -cos(currentHeading) * distance

                currentPosition = SCNVector3(
                    currentPosition.x + dx,
                    currentPosition.y,  // Y は変更しない（平面移動）
                    currentPosition.z + dz
                )

                results.append((currentPosition, item))

            case .event:
                // イベントは現在位置に挿入
                results.append((currentPosition, item))
            }
        }

        return results
    }

    /// move 要素のみから中心線座標を取得（AR描画用）
    static func getMovePositions(
        items: [RouteItem],
        startPosition: SCNVector3,
        startHeading: Float = 0
    ) -> [SCNVector3] {
        var positions: [SCNVector3] = [startPosition]
        var currentPosition = startPosition
        var currentHeading = startHeading

        for item in items {
            if case .move(let distance, let angle) = item {
                currentHeading += angle
                let dx = sin(currentHeading) * distance
                let dz = -cos(currentHeading) * distance

                currentPosition = SCNVector3(
                    currentPosition.x + dx,
                    currentPosition.y,
                    currentPosition.z + dz
                )
                positions.append(currentPosition)
            }
        }

        return positions
    }
}

// MARK: - 旧モデル互換（必要に応じて削除可能）

/// 1ステップ分の移動データ（旧形式・互換用）
struct RouteStep: Codable, Equatable {
    let direction: Float
    let distance: Float

    init(direction: Float, distance: Float) {
        self.direction = direction
        self.distance = distance
    }
}

/// 保存されたルートのレコード（旧形式・互換用）
@Model
final class RouteRecord {
    var id: UUID
    var startPointID: String
    var createdAt: Date
    var stepsData: Data
    var initialHeading: Float

    init(startPointID: String, steps: [RouteStep], initialHeading: Float) {
        self.id = UUID()
        self.startPointID = startPointID
        self.createdAt = Date()
        self.initialHeading = initialHeading
        self.stepsData = (try? JSONEncoder().encode(steps)) ?? Data()
    }

    var steps: [RouteStep] {
        get {
            (try? JSONDecoder().decode([RouteStep].self, from: stepsData)) ?? []
        }
        set {
            stepsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

/// 頂点配列をルートステップに変換するユーティリティ（旧形式・互換用）
struct RouteConverter {
    static func convert(from vertices: [SCNVector3]) -> (steps: [RouteStep], initialHeading: Float) {
        guard vertices.count >= 2 else {
            return ([], 0)
        }

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

            let dx = curr.x - prev.x
            let dz = curr.z - prev.z
            let distance = sqrt(dx * dx + dz * dz)

            guard distance > 0.001 else { continue }

            let absoluteHeading = atan2(dx, -dz)

            if steps.isEmpty {
                initialHeading = absoluteHeading
                steps.append(RouteStep(direction: 0, distance: distance))
            } else {
                var relativeDirection = absoluteHeading - previousHeading
                while relativeDirection > .pi { relativeDirection -= 2 * .pi }
                while relativeDirection < -.pi { relativeDirection += 2 * .pi }
                steps.append(RouteStep(direction: relativeDirection, distance: distance))
            }

            previousHeading = absoluteHeading
        }

        return (steps, initialHeading)
    }

    private static func extractCenterPoints(from vertices: [SCNVector3]) -> [SCNVector3] {
        var centers: [SCNVector3] = []
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
            currentHeading += step.direction
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
