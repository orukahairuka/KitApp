//
//  NavARSceneView.swift
//  KitApp
//
//  歩行ナビプロトタイプ用の AR View
//
//  【距離の計算方法】
//  - ARKit のカメラ位置（ワールド座標）を毎フレーム取得
//  - 「曲がる」ボタン押下時に、前回の曲がり地点からの距離を記録
//
//  【角度の計算方法】
//  - スタート時のカメラ forward 方向を基準（0°）として記録
//  - 「曲がる」ボタン押下時に、前回の向きからの相対角度を記録
//

import SwiftUI
import ARKit
import SceneKit
import SwiftData

// MARK: - NavARSceneView

struct NavARSceneView: UIViewRepresentable {

    @Binding var navState: NavState
    @Binding var isReady: Bool
    @Binding var statusMessage: String
    @Binding var currentDistance: Float
    @Binding var currentAngle: Float
    @Binding var shouldStartRecording: Bool
    @Binding var shouldRecordTurn: Bool
    @Binding var shouldSaveRoute: Bool
    @Binding var shouldReset: Bool
    @Binding var routeToReplay: NavRoute?
    @Binding var pendingSaveItems: [RouteItem]
    @Binding var saveRequestID: UUID?

    // WorldMap 関連
    @Binding var pendingWorldMapData: Data?
    @Binding var pendingStartAnchorID: UUID?
    @Binding var pendingStartHeading: Float

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = context.coordinator
        sceneView.session.delegate = context.coordinator
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.scene = SCNScene()

        context.coordinator.sceneView = sceneView

        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)

        return sceneView
    }

    func updateUIView(_ sceneView: ARSCNView, context: Context) {
        let coordinator = context.coordinator

        if shouldStartRecording {
            coordinator.startRecording()
            DispatchQueue.main.async {
                shouldStartRecording = false
                navState = .recording
            }
        }

        if shouldRecordTurn {
            coordinator.recordTurn()
            DispatchQueue.main.async {
                shouldRecordTurn = false
            }
        }

        if shouldSaveRoute {
            coordinator.prepareSaveRoute()
            DispatchQueue.main.async {
                shouldSaveRoute = false
            }
        }

        if shouldReset {
            coordinator.reset()
            DispatchQueue.main.async {
                shouldReset = false
            }
        }

        if let route = routeToReplay {
            coordinator.replayRoute(route)
            DispatchQueue.main.async {
                routeToReplay = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        var parent: NavARSceneView
        weak var sceneView: ARSCNView?

        // 記録状態
        private var isRecording = false
        private var startPosition: SCNVector3?
        private var startHeading: Float = 0
        private var lastTurnPosition: SCNVector3?
        private var lastTurnHeading: Float = 0

        // 記録データ（Coordinator 内部で管理）
        private var recordedItems: [RouteItem] = []

        // 軌跡描画用
        private var trailPositions: [SCNVector3] = []
        private var trailNodes: [SCNNode] = []
        private var lastTrailPosition: SCNVector3?

        // 再生用
        private var replayNodes: [SCNNode] = []

        // WorldMap / Anchor 関連
        private var startAnchorID: UUID?
        private var pendingReplayRoute: NavRoute?
        private var isRelocalizing = false

        init(_ parent: NavARSceneView) {
            self.parent = parent
        }

        // MARK: - Recording

        func startRecording() {
            guard let sceneView = sceneView,
                  let frame = sceneView.session.currentFrame else { return }

            let transform = frame.camera.transform
            let position = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let heading = extractYaw(from: transform)

            startPosition = position
            startHeading = heading
            lastTurnPosition = position
            lastTurnHeading = heading
            lastTrailPosition = position

            isRecording = true
            recordedItems = []
            trailPositions = [position]

            // スタート地点に ARAnchor を追加（WorldMap 復元時に座標の基準となる）
            let anchorID = UUID()
            let anchor = ARAnchor(name: "start_\(anchorID.uuidString)", transform: transform)
            sceneView.session.add(anchor: anchor)
            startAnchorID = anchorID
            print("📍 Start anchor added: \(anchorID)")

            // スタートマーカー
            let startMarker = createStartMarker(at: position)
            sceneView.scene.rootNode.addChildNode(startMarker)
            trailNodes.append(startMarker)

            updateUI(distance: 0, angle: 0, message: "記録中... 歩いてください")
        }

        func recordTurn() {
            guard isRecording,
                  let sceneView = sceneView,
                  let frame = sceneView.session.currentFrame,
                  let lastPos = lastTurnPosition else { return }

            let transform = frame.camera.transform
            let currentPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let currentHeading = extractYaw(from: transform)

            let distance = distanceXZ(from: lastPos, to: currentPos)
            var angle = currentHeading - lastTurnHeading
            angle = normalizeAngle(angle)

            if distance >= 0.05 {
                let item = RouteItem.move(distance: distance, angle: angle)
                recordedItems.append(item)

                // 曲がり地点マーカー
                let turnMarker = createTurnMarker(at: currentPos)
                sceneView.scene.rootNode.addChildNode(turnMarker)
                trailNodes.append(turnMarker)

                updateUI(distance: 0, angle: 0, message: String(format: "記録: %.2fm, %.0f°", distance, angle * 180 / .pi))
            } else {
                updateUI(distance: distance, angle: angle * 180 / .pi, message: "距離が短い（0.05m以上歩いてください）")
            }

            lastTurnPosition = currentPos
            lastTurnHeading = currentHeading
        }

        func prepareSaveRoute() {
            guard isRecording,
                  let sceneView = sceneView,
                  let frame = sceneView.session.currentFrame,
                  let lastPos = lastTurnPosition else {
                updateUI(distance: 0, angle: 0, message: "保存に失敗しました（記録を開始してください）")
                return
            }

            // 最後のセグメントを追加
            let transform = frame.camera.transform
            let currentPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let currentHeading = extractYaw(from: transform)

            let distance = distanceXZ(from: lastPos, to: currentPos)
            var angle = currentHeading - lastTurnHeading
            angle = normalizeAngle(angle)

            // 最小距離（ノイズ除去用）
            let minDistance: Float = 0.01
            if distance >= minDistance {
                recordedItems.append(RouteItem.move(distance: distance, angle: angle))
            }

            guard !recordedItems.isEmpty else {
                updateUI(distance: 0, angle: 0, message: "記録がありません（少し歩いてください）")
                return
            }

            updateUI(distance: 0, angle: 0, message: "WorldMap を取得中...")

            // WorldMap を取得してから保存
            let itemsToSave = recordedItems
            let anchorID = startAnchorID
            let heading = startHeading

            sceneView.session.getCurrentWorldMap { [weak self] worldMap, error in
                guard let self = self else { return }

                var worldMapData: Data? = nil
                if let worldMap = worldMap {
                    do {
                        worldMapData = try NSKeyedArchiver.archivedData(
                            withRootObject: worldMap,
                            requiringSecureCoding: true
                        )
                        print("🗺️ WorldMap archived: \(worldMapData?.count ?? 0) bytes, anchors: \(worldMap.anchors.count)")
                    } catch {
                        print("⚠️ WorldMap archive failed: \(error)")
                    }
                } else {
                    print("⚠️ WorldMap not available: \(error?.localizedDescription ?? "unknown")")
                }

                // ContentView に保存データを渡す
                DispatchQueue.main.async {
                    self.parent.pendingSaveItems = itemsToSave
                    self.parent.pendingWorldMapData = worldMapData
                    self.parent.pendingStartAnchorID = anchorID
                    self.parent.pendingStartHeading = heading
                    self.parent.saveRequestID = UUID()
                    print("🎯 pendingSaveItems set with WorldMap")
                }

                // 記録終了
                self.stopRecording()
            }
        }

        func stopRecording() {
            isRecording = false
            recordedItems = []
            trailPositions = []
            lastTrailPosition = nil
            startAnchorID = nil

            for node in trailNodes {
                node.removeFromParentNode()
            }
            trailNodes.removeAll()
        }

        func reset() {
            stopRecording()

            for node in replayNodes {
                node.removeFromParentNode()
            }
            replayNodes.removeAll()

            // WorldMap 復元状態をリセット
            pendingReplayRoute = nil
            isRelocalizing = false

            // 通常のセッションに戻す
            if let sceneView = sceneView {
                let config = ARWorldTrackingConfiguration()
                sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            }

            updateUI(distance: 0, angle: 0, message: parent.isReady ? "準備完了" : "準備中...")
        }

        // MARK: - Replay

        func replayRoute(_ route: NavRoute) {
            guard let sceneView = sceneView else {
                updateUI(distance: 0, angle: 0, message: "AR準備中...")
                return
            }

            // 既存の再生ノードをクリア
            for node in replayNodes {
                node.removeFromParentNode()
            }
            replayNodes.removeAll()

            // WorldMap がある場合は復元を試みる
            if let worldMapData = route.worldMapData,
               let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldMapData) {

                print("🗺️ Restoring WorldMap with \(worldMap.anchors.count) anchors")

                pendingReplayRoute = route
                isRelocalizing = true

                let config = ARWorldTrackingConfiguration()
                config.initialWorldMap = worldMap
                sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

                updateUI(distance: 0, angle: 0, message: "再ローカライズ中... カメラを動かしてください")
                return
            }

            // WorldMap がない場合は従来の方法（カメラ前方に配置）
            print("⚠️ No WorldMap, using fallback positioning")
            displayRouteAtCurrentPosition(route)
        }

        /// WorldMap 復元後、アンカー位置を基準にルートを表示
        private func displayRouteFromAnchor(_ route: NavRoute, anchorTransform: simd_float4x4) {
            guard let sceneView = sceneView else { return }

            // アンカーの位置と向きを取得
            let anchorPos = SCNVector3(
                anchorTransform.columns.3.x,
                anchorTransform.columns.3.y - 0.5,  // 床付近に調整
                anchorTransform.columns.3.z
            )
            let startHeading = route.startHeading

            print("📍 Displaying route from anchor at (\(anchorPos.x), \(anchorPos.y), \(anchorPos.z)), heading: \(startHeading)")

            // 経路を再構築
            var positions: [SCNVector3] = [anchorPos]
            var currentPos = anchorPos
            var currentHeading = startHeading

            for item in route.items {
                switch item {
                case .move(let distance, let angle):
                    currentHeading += angle
                    let newPos = SCNVector3(
                        currentPos.x + sin(currentHeading) * distance,
                        currentPos.y,
                        currentPos.z - cos(currentHeading) * distance
                    )
                    positions.append(newPos)
                    currentPos = newPos

                case .event(let eventType):
                    let eventNode = createEventNode(type: eventType, at: currentPos)
                    sceneView.scene.rootNode.addChildNode(eventNode)
                    replayNodes.append(eventNode)
                }
            }

            // リボンを描画
            if positions.count >= 2 {
                for i in 0..<(positions.count - 1) {
                    let ribbon = createRibbon(from: positions[i], to: positions[i + 1], color: .cyan)
                    sceneView.scene.rootNode.addChildNode(ribbon)
                    replayNodes.append(ribbon)

                    let arrow = createArrow(from: positions[i], to: positions[i + 1])
                    sceneView.scene.rootNode.addChildNode(arrow)
                    replayNodes.append(arrow)
                }
            }

            // スタートマーカー
            let startMarker = createStartMarker(at: anchorPos)
            sceneView.scene.rootNode.addChildNode(startMarker)
            replayNodes.append(startMarker)

            // ゴールマーカー
            if let lastPos = positions.last {
                let goalMarker = createGoalMarker(at: lastPos)
                sceneView.scene.rootNode.addChildNode(goalMarker)
                replayNodes.append(goalMarker)
            }

            updateUI(distance: 0, angle: 0, message: "再生中: \(route.name)")
        }

        /// WorldMap がない場合のフォールバック（カメラ前方に配置）
        private func displayRouteAtCurrentPosition(_ route: NavRoute) {
            guard let sceneView = sceneView,
                  let frame = sceneView.session.currentFrame else {
                updateUI(distance: 0, angle: 0, message: "AR準備中...")
                return
            }

            let transform = frame.camera.transform
            let cameraPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let cameraHeading = extractYaw(from: transform)

            // スタート位置（カメラの1m前方、床付近）
            let startPos = SCNVector3(
                cameraPos.x + sin(cameraHeading) * 1.0,
                cameraPos.y - 0.5,
                cameraPos.z - cos(cameraHeading) * 1.0
            )

            // 経路を再構築
            var positions: [SCNVector3] = [startPos]
            var currentPos = startPos
            var currentHeading = cameraHeading

            for item in route.items {
                switch item {
                case .move(let distance, let angle):
                    currentHeading += angle
                    let newPos = SCNVector3(
                        currentPos.x + sin(currentHeading) * distance,
                        currentPos.y,
                        currentPos.z - cos(currentHeading) * distance
                    )
                    positions.append(newPos)
                    currentPos = newPos

                case .event(let eventType):
                    let eventNode = createEventNode(type: eventType, at: currentPos)
                    sceneView.scene.rootNode.addChildNode(eventNode)
                    replayNodes.append(eventNode)
                }
            }

            // リボンを描画
            if positions.count >= 2 {
                for i in 0..<(positions.count - 1) {
                    let ribbon = createRibbon(from: positions[i], to: positions[i + 1], color: .cyan)
                    sceneView.scene.rootNode.addChildNode(ribbon)
                    replayNodes.append(ribbon)

                    let arrow = createArrow(from: positions[i], to: positions[i + 1])
                    sceneView.scene.rootNode.addChildNode(arrow)
                    replayNodes.append(arrow)
                }
            }

            // スタートマーカー
            let startMarker = createStartMarker(at: startPos)
            sceneView.scene.rootNode.addChildNode(startMarker)
            replayNodes.append(startMarker)

            // ゴールマーカー
            if let lastPos = positions.last {
                let goalMarker = createGoalMarker(at: lastPos)
                sceneView.scene.rootNode.addChildNode(goalMarker)
                replayNodes.append(goalMarker)
            }

            updateUI(distance: 0, angle: 0, message: "再生中: \(route.name)")
        }

        // MARK: - ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard isRecording,
                  let sceneView = sceneView,
                  let frame = sceneView.session.currentFrame,
                  let lastPos = lastTurnPosition,
                  let lastTrail = lastTrailPosition else { return }

            let transform = frame.camera.transform
            let currentPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let currentHeading = extractYaw(from: transform)

            // UI更新用の距離・角度
            let distance = distanceXZ(from: lastPos, to: currentPos)
            var angle = currentHeading - lastTurnHeading
            angle = normalizeAngle(angle)

            DispatchQueue.main.async {
                self.parent.currentDistance = distance
                self.parent.currentAngle = angle * 180 / .pi
            }

            // 軌跡リボンを追加（0.15m ごと）
            let trailDist = distanceXZ(from: lastTrail, to: currentPos)
            if trailDist >= 0.15 {
                let floorPos = SCNVector3(currentPos.x, currentPos.y - 0.5, currentPos.z)
                let lastFloorPos = SCNVector3(lastTrail.x, lastTrail.y - 0.5, lastTrail.z)

                let ribbon = createRibbon(from: lastFloorPos, to: floorPos, color: UIColor.red.withAlphaComponent(0.7))
                sceneView.scene.rootNode.addChildNode(ribbon)
                trailNodes.append(ribbon)

                trailPositions.append(currentPos)
                lastTrailPosition = currentPos
            }
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let ready: Bool
            var message: String

            switch camera.trackingState {
            case .normal:
                ready = true
                message = "準備完了"

                // リローカライズ完了時にルートを表示
                if isRelocalizing, let route = pendingReplayRoute {
                    isRelocalizing = false
                    print("✅ Relocalization complete, looking for start anchor")

                    // アンカーを探す
                    if let anchorID = route.startAnchorID {
                        let anchorName = "start_\(anchorID.uuidString)"
                        if let anchor = session.currentFrame?.anchors.first(where: { $0.name == anchorName }) {
                            print("📍 Found start anchor: \(anchorName)")
                            displayRouteFromAnchor(route, anchorTransform: anchor.transform)
                        } else {
                            print("⚠️ Start anchor not found, using fallback")
                            displayRouteAtCurrentPosition(route)
                        }
                    } else {
                        print("⚠️ No anchor ID in route, using fallback")
                        displayRouteAtCurrentPosition(route)
                    }
                    pendingReplayRoute = nil
                }

            case .notAvailable:
                ready = false
                message = "AR利用不可"
            case .limited(let reason):
                ready = false
                switch reason {
                case .initializing: message = "初期化中..."
                case .excessiveMotion: message = "動きが速すぎます"
                case .insufficientFeatures: message = "特徴点不足"
                case .relocalizing:
                    message = isRelocalizing ? "再ローカライズ中... カメラを動かしてください" : "再ローカライズ中..."
                @unknown default: message = "制限あり"
                }
            }

            DispatchQueue.main.async {
                self.parent.isReady = ready
                if self.parent.navState == .idle || self.isRelocalizing {
                    self.parent.statusMessage = message
                }
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.parent.statusMessage = "エラー: \(error.localizedDescription)"
                self.parent.isReady = false
            }
        }

        // MARK: - Node Creation

        private func createStartMarker(at position: SCNVector3) -> SCNNode {
            let cylinder = SCNCylinder(radius: 0.05, height: 0.4)
            cylinder.firstMaterial?.diffuse.contents = UIColor.green
            cylinder.firstMaterial?.emission.contents = UIColor.green.withAlphaComponent(0.5)

            let node = SCNNode(geometry: cylinder)
            node.position = SCNVector3(position.x, position.y - 0.3, position.z)
            return node
        }

        private func createGoalMarker(at position: SCNVector3) -> SCNNode {
            let cylinder = SCNCylinder(radius: 0.05, height: 0.4)
            cylinder.firstMaterial?.diffuse.contents = UIColor.blue
            cylinder.firstMaterial?.emission.contents = UIColor.blue.withAlphaComponent(0.5)

            let node = SCNNode(geometry: cylinder)
            node.position = SCNVector3(position.x, position.y + 0.2, position.z)
            return node
        }

        private func createTurnMarker(at position: SCNVector3) -> SCNNode {
            let sphere = SCNSphere(radius: 0.04)
            sphere.firstMaterial?.diffuse.contents = UIColor.orange
            sphere.firstMaterial?.emission.contents = UIColor.orange.withAlphaComponent(0.5)

            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(position.x, position.y - 0.5, position.z)
            return node
        }

        private func createRibbon(from: SCNVector3, to: SCNVector3, color: UIColor) -> SCNNode {
            let dx = to.x - from.x
            let dz = to.z - from.z
            let length = sqrt(dx * dx + dz * dz)

            guard length > 0.01 else {
                return SCNNode()
            }

            let box = SCNBox(width: 0.08, height: 0.005, length: CGFloat(length), chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = color
            box.firstMaterial?.emission.contents = color.withAlphaComponent(0.3)
            box.firstMaterial?.isDoubleSided = true

            let node = SCNNode(geometry: box)
            node.position = SCNVector3((from.x + to.x) / 2, from.y, (from.z + to.z) / 2)
            node.eulerAngles.y = atan2(dx, dz)

            return node
        }

        private func createArrow(from: SCNVector3, to: SCNVector3) -> SCNNode {
            let cone = SCNCone(topRadius: 0, bottomRadius: 0.025, height: 0.06)
            cone.firstMaterial?.diffuse.contents = UIColor.yellow
            cone.firstMaterial?.emission.contents = UIColor.yellow.withAlphaComponent(0.5)

            let node = SCNNode(geometry: cone)
            node.position = to

            let dx = to.x - from.x
            let dz = to.z - from.z
            let angle = atan2(dx, dz)
            node.eulerAngles = SCNVector3(-Float.pi / 2, angle, 0)

            return node
        }

        private func createEventNode(type: EventType, at position: SCNVector3) -> SCNNode {
            let node = SCNNode()

            let sphere = SCNSphere(radius: 0.1)
            sphere.firstMaterial?.diffuse.contents = UIColor.purple
            sphere.firstMaterial?.emission.contents = UIColor.purple.withAlphaComponent(0.3)

            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = SCNVector3(0, 0.2, 0)
            node.addChildNode(sphereNode)

            let text = SCNText(string: type.displayText, extrusionDepth: 0.005)
            text.font = UIFont.systemFont(ofSize: 0.05, weight: .bold)
            text.firstMaterial?.diffuse.contents = UIColor.white
            text.flatness = 0.1

            let textNode = SCNNode(geometry: text)
            textNode.position = SCNVector3(-0.15, 0.35, 0)
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)

            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .Y
            textNode.constraints = [constraint]
            node.addChildNode(textNode)

            node.position = position
            return node
        }

        // MARK: - Utilities

        private func extractYaw(from transform: simd_float4x4) -> Float {
            let forward = simd_float3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
            return atan2(forward.x, -forward.z)
        }

        private func distanceXZ(from: SCNVector3, to: SCNVector3) -> Float {
            let dx = to.x - from.x
            let dz = to.z - from.z
            return sqrt(dx * dx + dz * dz)
        }

        private func normalizeAngle(_ angle: Float) -> Float {
            var a = angle
            while a > .pi { a -= 2 * .pi }
            while a < -.pi { a += 2 * .pi }
            return a
        }

        private func updateUI(distance: Float, angle: Float, message: String) {
            DispatchQueue.main.async {
                self.parent.currentDistance = distance
                self.parent.currentAngle = angle
                self.parent.statusMessage = message
            }
        }
    }
}
