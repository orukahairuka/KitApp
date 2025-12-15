//
//  RouteReplayNode.swift
//  KitApp
//
//  保存されたルートを AR 空間上に表示するノード
//  矢印付きの簡易リボンとして描画する
//

import SceneKit

/// ルート再生用のノード
/// 保存されたステップ配列からパスを再構築して表示する
class RouteReplayNode: SCNNode {

    // MARK: - Properties

    /// 線の色
    private let lineColor: UIColor

    /// 線の太さ
    private let lineWidth: Float

    // MARK: - Initialization

    /// 初期化
    /// - Parameters:
    ///   - record: ルートレコード
    ///   - startPosition: 再生開始位置（カメラの前方など）
    ///   - lineColor: 線の色
    ///   - lineWidth: 線の太さ
    init(
        record: RouteRecord,
        startPosition: SCNVector3,
        lineColor: UIColor = .cyan,
        lineWidth: Float = 0.008
    ) {
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        super.init()

        buildPath(from: record, startPosition: startPosition)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private Methods

    /// ルートからパスを構築
    private func buildPath(from record: RouteRecord, startPosition: SCNVector3) {
        let points = RouteConverter.reconstruct(
            steps: record.steps,
            initialHeading: record.initialHeading,
            startPosition: startPosition
        )

        guard points.count >= 2 else { return }

        // リボン状のジオメトリを作成
        buildRibbonGeometry(from: points)

        // 矢印を追加（進行方向を示す）
        addDirectionArrows(along: points)
    }

    /// リボン状のジオメトリを構築
    private func buildRibbonGeometry(from points: [SCNVector3]) {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []

        for point in points {
            // 上下2点を追加（DynamicGeometryNode と同じ方式）
            vertices.append(SCNVector3(point.x, point.y - lineWidth, point.z))
            vertices.append(SCNVector3(point.x, point.y + lineWidth, point.z))

            let count = vertices.count
            indices.append(Int32(count - 2))
            indices.append(Int32(count - 1))
        }

        guard vertices.count >= 4 else { return }

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangleStrip)
        let geometry = SCNGeometry(sources: [source], elements: [element])

        if let material = geometry.firstMaterial {
            material.diffuse.contents = lineColor
            material.isDoubleSided = true
            material.transparency = 0.8
        }

        let ribbonNode = SCNNode(geometry: geometry)
        addChildNode(ribbonNode)
    }

    /// 進行方向を示す矢印を追加
    private func addDirectionArrows(along points: [SCNVector3]) {
        // 矢印の間隔（ポイント数）
        let arrowInterval = max(1, points.count / 5)

        for i in stride(from: 0, to: points.count - 1, by: arrowInterval) {
            let current = points[i]
            let next = points[min(i + 1, points.count - 1)]

            // 方向を計算
            let dx = next.x - current.x
            let dz = next.z - current.z
            let length = sqrt(dx * dx + dz * dz)

            guard length > 0.001 else { continue }

            let arrowNode = createArrowNode()

            // 位置を設定
            arrowNode.position = current

            // 進行方向に回転
            let angle = atan2(dx, -dz)
            arrowNode.eulerAngles = SCNVector3(-.pi / 2, angle, 0)

            addChildNode(arrowNode)
        }
    }

    /// 矢印ノードを作成
    private func createArrowNode() -> SCNNode {
        // コーン（円錐）を矢印として使用
        let cone = SCNCone(topRadius: 0, bottomRadius: 0.015, height: 0.03)

        if let material = cone.firstMaterial {
            material.diffuse.contents = UIColor.yellow
            material.emission.contents = UIColor.yellow.withAlphaComponent(0.3)
        }

        return SCNNode(geometry: cone)
    }
}
