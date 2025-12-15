//
//  ARSceneView.swift
//  KitApp
//
//  ARSCNView を SwiftUI で使用するための UIViewRepresentable ラッパー
//

import SwiftUI
import ARKit
import SceneKit
import SwiftData

/// ARSCNView を SwiftUI で表示するためのラッパー
struct ARSceneView: UIViewRepresentable {

    // MARK: - Bindings（SwiftUI との双方向バインディング）

    /// 描画色（SwiftUI の ColorPicker から受け取る）
    @Binding var drawingColor: Color

    /// タッチ中かどうか
    @Binding var isTouching: Bool

    /// リセットトリガー（true になったらリセット実行）
    @Binding var shouldReset: Bool

    /// ステータスメッセージ（AR の状態を SwiftUI に通知）
    @Binding var statusMessage: String

    /// 描画準備完了かどうか
    @Binding var isReady: Bool

    /// 保存トリガー（true になったら現在の描画を保存）
    @Binding var shouldSave: Bool

    /// 再生するルートレコード（nil 以外で再生実行）
    @Binding var routeToReplay: RouteRecord?

    /// SwiftData の ModelContext
    var modelContext: ModelContext

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = context.coordinator
        sceneView.session.delegate = context.coordinator
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.scene = SCNScene()

        // Coordinator に sceneView の参照を保持
        context.coordinator.sceneView = sceneView

        // AR セッション開始
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)

        return sceneView
    }

    func updateUIView(_ sceneView: ARSCNView, context: Context) {
        // リセット処理
        if shouldReset {
            context.coordinator.reset()
            DispatchQueue.main.async {
                shouldReset = false
            }
        }

        // 保存処理
        if shouldSave {
            context.coordinator.saveCurrentDrawing(modelContext: modelContext)
            DispatchQueue.main.async {
                shouldSave = false
            }
        }

        // 再生処理
        if let route = routeToReplay {
            context.coordinator.replayRoute(route)
            DispatchQueue.main.async {
                routeToReplay = nil
            }
        }

        // 色の更新
        context.coordinator.currentColor = UIColor(drawingColor)

        // タッチ状態の更新
        context.coordinator.isTouching = isTouching
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        var parent: ARSceneView
        weak var sceneView: ARSCNView?

        /// 描画ノードの配列
        private var drawingNodes: [DynamicGeometryNode] = []

        /// 再生ノードの配列
        private var replayNodes: [RouteReplayNode] = []

        /// 現在の描画色
        var currentColor: UIColor = .white

        /// 線の太さ
        let lineWidth: Float = 0.004

        /// タッチ中フラグ
        var isTouching: Bool = false {
            didSet {
                if isTouching && !oldValue {
                    // タッチ開始時に新しい描画ノードを作成
                    startNewDrawing()
                }
            }
        }

        init(_ parent: ARSceneView) {
            self.parent = parent
        }

        // MARK: - Save / Replay Methods

        /// 現在の描画を保存
        func saveCurrentDrawing(modelContext: ModelContext) {
            guard let lastDrawing = drawingNodes.last else {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "保存する描画がありません"
                }
                return
            }

            let vertices = lastDrawing.currentVertices
            guard vertices.count >= 4 else {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "描画が短すぎます"
                }
                return
            }

            // 頂点をステップに変換
            let (steps, initialHeading) = RouteConverter.convert(from: vertices)

            guard !steps.isEmpty else {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "変換に失敗しました"
                }
                return
            }

            // RouteRecord を作成して保存
            let startPointID = "Route_\(Date().formatted(.dateTime.month().day().hour().minute()))"
            let record = RouteRecord(
                startPointID: startPointID,
                steps: steps,
                initialHeading: initialHeading
            )

            modelContext.insert(record)

            do {
                try modelContext.save()
                DispatchQueue.main.async {
                    self.parent.statusMessage = "保存完了: \(startPointID)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "保存エラー: \(error.localizedDescription)"
                }
            }
        }

        /// ルートを再生
        func replayRoute(_ record: RouteRecord) {
            guard let sceneView = sceneView else { return }

            // カメラの前方にルートを配置
            guard let frame = sceneView.session.currentFrame else {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "ARフレームが取得できません"
                }
                return
            }

            // カメラの位置から少し前方に配置
            let cameraTransform = frame.camera.transform
            let forward = SCNVector3(
                -cameraTransform.columns.2.x,
                -cameraTransform.columns.2.y,
                -cameraTransform.columns.2.z
            )
            let cameraPosition = SCNVector3(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )

            // カメラの1m前方、少し下に配置
            let startPosition = SCNVector3(
                cameraPosition.x + forward.x * 1.0,
                cameraPosition.y - 0.3,
                cameraPosition.z + forward.z * 1.0
            )

            let replayNode = RouteReplayNode(
                record: record,
                startPosition: startPosition,
                lineColor: .cyan,
                lineWidth: 0.006
            )

            sceneView.scene.rootNode.addChildNode(replayNode)
            replayNodes.append(replayNode)

            DispatchQueue.main.async {
                self.parent.statusMessage = "再生中: \(record.startPointID)"
            }
        }

        // MARK: - Drawing Methods

        /// 新しい描画を開始
        private func startNewDrawing() {
            guard let sceneView = sceneView,
                  let frame = sceneView.session.currentFrame,
                  isReadyForDrawing(trackingState: frame.camera.trackingState) else {
                return
            }

            let drawingNode = DynamicGeometryNode(color: currentColor, lineWidth: lineWidth)
            sceneView.scene.rootNode.addChildNode(drawingNode)
            drawingNodes.append(drawingNode)

            DispatchQueue.main.async {
                self.parent.statusMessage = "デバイスを動かして描画！"
            }
        }

        /// リセット処理
        func reset() {
            for node in drawingNodes {
                node.removeFromParentNode()
            }
            drawingNodes.removeAll()

            for node in replayNodes {
                node.removeFromParentNode()
            }
            replayNodes.removeAll()
        }

        /// 画面中央のワールド座標を取得
        private func worldPositionForScreenCenter() -> SCNVector3? {
            guard let sceneView = sceneView else { return nil }
            let screenBounds = UIScreen.main.bounds
            let center = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
            let centerVec3 = SCNVector3(Float(center.x), Float(center.y), 0.99)
            return sceneView.unprojectPoint(centerVec3)
        }

        /// トラッキング状態が描画可能か判定
        private func isReadyForDrawing(trackingState: ARCamera.TrackingState) -> Bool {
            switch trackingState {
            case .normal:
                return true
            default:
                return false
            }
        }

        // MARK: - ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard isTouching,
                  let currentDrawing = drawingNodes.last,
                  let vertice = worldPositionForScreenCenter() else {
                return
            }

            DispatchQueue.main.async {
                currentDrawing.addVertice(vertice)
            }
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.parent.statusMessage = "エラー: \(error.localizedDescription)"
                self.parent.isReady = false
            }
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let isReady = isReadyForDrawing(trackingState: camera.trackingState)

            DispatchQueue.main.async {
                self.parent.isReady = isReady
                self.parent.statusMessage = isReady ? "画面をタッチして描画" : "準備中..."
            }
        }
    }
}
