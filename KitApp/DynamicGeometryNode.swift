//
//  DynamicGeometryNode.swift
//  KitApp
//
//  動的にジオメトリを生成する SCNNode サブクラス
//  描画線を三角形ストリップで構築する
//

import SceneKit
import UIKit

// MARK: - SCNVector3 演算子拡張

extension SCNVector3 {
    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
    }

    static func += (left: inout SCNVector3, right: SCNVector3) {
        left = left + right
    }

    static func / (left: SCNVector3, right: Float) -> SCNVector3 {
        return SCNVector3(left.x / right, left.y / right, left.z / right)
    }

    static func /= (left: inout SCNVector3, right: Float) {
        left = left / right
    }
}

// MARK: - DynamicGeometryNode

/// 動的に頂点を追加してジオメトリを構築するノード
/// 空中お絵描きの線を描画するために使用
open class DynamicGeometryNode: SCNNode {

    // MARK: - Properties

    /// 頂点配列
    private var vertices: [SCNVector3] = []

    /// インデックス配列
    private var indices: [Int32] = []

    /// 線の太さ
    private let lineWidth: Float

    /// 描画色
    private let color: UIColor

    /// スムージング用の頂点プール
    private var verticesPool: [SCNVector3] = []

    // MARK: - Initialization

    /// 初期化
    /// - Parameters:
    ///   - color: 描画色
    ///   - lineWidth: 線の太さ
    public init(color: UIColor, lineWidth: Float) {
        self.color = color
        self.lineWidth = lineWidth
        super.init()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// 現在の頂点配列を取得（読み取り専用）
    public var currentVertices: [SCNVector3] {
        return vertices
    }

    /// 頂点を追加する
    /// - Parameter vertice: 追加する頂点座標
    public func addVertice(_ vertice: SCNVector3) {
        // スムージング処理：3点を平均化してなめらかな線にする
        var smoothed = SCNVector3Zero

        if verticesPool.count < 3 {
            // プールに3点溜まるまで追加
            if !SCNVector3EqualToVector3(vertice, SCNVector3Zero) {
                verticesPool.append(vertice)
            }
            return
        } else {
            // 3点の平均を計算
            for v in verticesPool {
                smoothed += v
            }
            smoothed /= Float(verticesPool.count)
            verticesPool.removeAll()
        }

        // 三角形ストリップ用に上下2点を追加
        vertices.append(SCNVector3(smoothed.x, smoothed.y - lineWidth, smoothed.z))
        vertices.append(SCNVector3(smoothed.x, smoothed.y + lineWidth, smoothed.z))

        let count = vertices.count
        indices.append(Int32(count - 2))
        indices.append(Int32(count - 1))

        updateGeometryIfNeeded()
    }

    /// 描画をリセットする
    public func reset() {
        verticesPool.removeAll()
        vertices.removeAll()
        indices.removeAll()
        geometry = nil
    }

    // MARK: - Private Methods

    /// ジオメトリを更新する
    private func updateGeometryIfNeeded() {
        guard vertices.count >= 3 else {
            return
        }

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangleStrip)
        geometry = SCNGeometry(sources: [source], elements: [element])

        if let material = geometry?.firstMaterial {
            material.diffuse.contents = color
            material.isDoubleSided = true
        }
    }
}
