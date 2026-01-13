//
//  ARSessionService.swift
//  KitApp
//
//  AR操作を担当するサービス
//

import Foundation
import ARKit
import SceneKit

// MARK: - ARSessionServiceDelegate

/// ARSessionServiceからのコールバックを受け取るデリゲート
protocol ARSessionServiceDelegate: AnyObject {
    /// ARセッションの準備状態が変化
    func arSessionDidChangeReadyState(_ isReady: Bool)

    /// ステータスメッセージが変化
    func arSessionDidUpdateStatus(_ message: String)

    /// 記録中の距離・角度が更新
    func arSessionDidUpdateRecordingInfo(distance: Float, angle: Float)

    /// ルート保存の準備が完了
    func arSessionDidPrepareSaveData(
        items: [RouteItem],
        worldMapData: Data?,
        startAnchorID: UUID?,
        startHeading: Float
    )
}

// MARK: - ARSessionService

/// AR操作を管理するサービス
final class ARSessionService: NSObject {

    // MARK: - Properties

    weak var delegate: ARSessionServiceDelegate?
    weak var sceneView: ARSCNView?

    // 記録状態
    private(set) var isRecording = false
    private var startPosition: SCNVector3?
    private var startHeading: Float = 0
    private var lastTurnPosition: SCNVector3?
    private var lastMoveDirection: Float = 0
    private var recordedItems: [RouteItem] = []
    private var startAnchorID: UUID?

    // 軌跡描画用
    private var trailNodes: [SCNNode] = []
    private var lastTrailPosition: SCNVector3?

    // 再生用
    private var replayNodes: [SCNNode] = []
    private var pendingReplayRoute: NavRoute?
    private var isRelocalizing = false

    // 最後の状態（requestCurrentStatus用）
    private(set) var lastKnownReadyState: Bool = false
    private(set) var lastKnownStatusMessage: String = "準備中..."

    // MARK: - Recording

    /// 記録を開始
    func startRecording() {
        guard let sceneView = sceneView,
              let frame = sceneView.session.currentFrame else { return }

        let transform = frame.camera.transform
        let position = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let heading = Self.extractYaw(from: transform)

        startPosition = position
        startHeading = heading
        lastTurnPosition = position
        lastMoveDirection = heading
        lastTrailPosition = position

        isRecording = true
        recordedItems = []

        // スタート地点にARAnchorを追加
        let anchorID = UUID()
        let anchor = ARAnchor(name: "start_\(anchorID.uuidString)", transform: transform)
        sceneView.session.add(anchor: anchor)
        startAnchorID = anchorID
        print("📍 Start anchor added: \(anchorID)")

        // スタートマーカーを追加
        let startMarker = NodeFactory.createStartMarker(at: position)
        sceneView.scene.rootNode.addChildNode(startMarker)
        trailNodes.append(startMarker)

        delegate?.arSessionDidUpdateStatus("記録中... 歩いてください")
    }

    /// 曲がり地点を記録
    func recordTurn() {
        guard isRecording,
              let sceneView = sceneView,
              let frame = sceneView.session.currentFrame,
              let lastPos = lastTurnPosition else { return }

        let transform = frame.camera.transform
        let currentPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

        let distance = Self.distanceXZ(from: lastPos, to: currentPos)

        if distance >= NavigationConfig.Recording.minTurnDistance {
            let dx = currentPos.x - lastPos.x
            let dz = currentPos.z - lastPos.z
            let currentMoveDirection = atan2(dx, -dz)

            var angle = currentMoveDirection - lastMoveDirection
            angle = Self.normalizeAngle(angle)

            let item = RouteItem.move(distance: distance, angle: angle)
            recordedItems.append(item)

            // 曲がり地点マーカー
            let turnMarker = NodeFactory.createTurnMarker(at: currentPos)
            sceneView.scene.rootNode.addChildNode(turnMarker)
            trailNodes.append(turnMarker)

            delegate?.arSessionDidUpdateStatus(
                String(format: "記録: %.2fm, %.0f°", distance, angle * 180 / .pi)
            )

            lastTurnPosition = currentPos
            lastMoveDirection = currentMoveDirection
        } else {
            delegate?.arSessionDidUpdateStatus("距離が短い（0.05m以上歩いてください）")
        }
    }

    /// ルート保存の準備
    func prepareSaveRoute() {
        guard isRecording,
              let sceneView = sceneView,
              let frame = sceneView.session.currentFrame,
              let lastPos = lastTurnPosition else {
            delegate?.arSessionDidUpdateStatus("保存に失敗しました（記録を開始してください）")
            return
        }

        let transform = frame.camera.transform
        let currentPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

        let distance = Self.distanceXZ(from: lastPos, to: currentPos)

        if distance >= NavigationConfig.Recording.minSaveDistance {
            let dx = currentPos.x - lastPos.x
            let dz = currentPos.z - lastPos.z
            let currentMoveDirection = atan2(dx, -dz)

            var angle = currentMoveDirection - lastMoveDirection
            angle = Self.normalizeAngle(angle)

            recordedItems.append(RouteItem.move(distance: distance, angle: angle))
        }

        guard !recordedItems.isEmpty else {
            delegate?.arSessionDidUpdateStatus("記録がありません（少し歩いてください）")
            return
        }

        delegate?.arSessionDidUpdateStatus("WorldMap を取得中...")

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
                    print("🗺️ WorldMap archived: \(worldMapData?.count ?? 0) bytes")
                } catch {
                    print("⚠️ WorldMap archive failed: \(error)")
                }
            } else {
                print("⚠️ WorldMap not available: \(error?.localizedDescription ?? "unknown")")
            }

            DispatchQueue.main.async {
                self.delegate?.arSessionDidPrepareSaveData(
                    items: itemsToSave,
                    worldMapData: worldMapData,
                    startAnchorID: anchorID,
                    startHeading: heading
                )
            }

            self.stopRecording()
        }
    }

    /// 記録を停止
    func stopRecording() {
        isRecording = false
        recordedItems = []
        lastTrailPosition = nil
        startAnchorID = nil
        lastMoveDirection = 0

        for node in trailNodes {
            node.removeFromParentNode()
        }
        trailNodes.removeAll()
    }

    // MARK: - Replay

    /// ルートを再生
    func replayRoute(_ route: NavRoute) {
        guard let sceneView = sceneView else {
            delegate?.arSessionDidUpdateStatus("AR準備中...")
            return
        }

        clearReplayNodes()

        if let worldMapData = route.worldMapData,
           let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldMapData) {

            print("🗺️ Restoring WorldMap with \(worldMap.anchors.count) anchors")

            pendingReplayRoute = route
            isRelocalizing = true

            let config = ARWorldTrackingConfiguration()
            config.initialWorldMap = worldMap
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

            delegate?.arSessionDidUpdateStatus("再ローカライズ中... カメラを動かしてください")
            return
        }

        print("⚠️ No WorldMap, using fallback positioning")
        displayRouteAtCurrentPosition(route)
    }

    /// 再生ノードをクリア
    private func clearReplayNodes() {
        for node in replayNodes {
            node.removeFromParentNode()
        }
        replayNodes.removeAll()
    }

    // MARK: - Reset

    /// セッションをリセット
    func reset() {
        stopRecording()
        clearReplayNodes()

        pendingReplayRoute = nil
        isRelocalizing = false

        if let sceneView = sceneView {
            let config = ARWorldTrackingConfiguration()
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }
    }

    // MARK: - Route Display

    /// アンカー位置を基準にルートを表示
    func displayRouteFromAnchor(_ route: NavRoute, anchorTransform: simd_float4x4) {
        guard let sceneView = sceneView else { return }

        let anchorPos = SCNVector3(
            anchorTransform.columns.3.x,
            anchorTransform.columns.3.y - NavigationConfig.Positioning.floorOffset,
            anchorTransform.columns.3.z
        )
        let startHeading = Self.extractYaw(from: anchorTransform)

        displayRoute(route, startPosition: anchorPos, startHeading: startHeading, in: sceneView)
        delegate?.arSessionDidUpdateStatus("再生中: \(route.name)")
    }

    /// 現在位置を基準にルートを表示（フォールバック）
    private func displayRouteAtCurrentPosition(_ route: NavRoute) {
        guard let sceneView = sceneView,
              let frame = sceneView.session.currentFrame else {
            delegate?.arSessionDidUpdateStatus("AR準備中...")
            return
        }

        let transform = frame.camera.transform
        let cameraPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let cameraHeading = Self.extractYaw(from: transform)

        let startPos = SCNVector3(
            cameraPos.x + sin(cameraHeading) * NavigationConfig.Positioning.fallbackForwardDistance,
            cameraPos.y - NavigationConfig.Positioning.floorOffset,
            cameraPos.z - cos(cameraHeading) * NavigationConfig.Positioning.fallbackForwardDistance
        )

        displayRoute(route, startPosition: startPos, startHeading: cameraHeading, in: sceneView)
        delegate?.arSessionDidUpdateStatus("再生中: \(route.name)")
    }

    /// ルートを3D表示
    private func displayRoute(_ route: NavRoute, startPosition: SCNVector3, startHeading: Float, in sceneView: ARSCNView) {
        var positions: [SCNVector3] = [startPosition]
        var currentPos = startPosition
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
                let eventNode = NodeFactory.createEventNode(type: eventType, at: currentPos)
                sceneView.scene.rootNode.addChildNode(eventNode)
                replayNodes.append(eventNode)
            }
        }

        // リボンと矢印を描画
        if positions.count >= 2 {
            for i in 0..<(positions.count - 1) {
                let ribbon = NodeFactory.createRibbon(from: positions[i], to: positions[i + 1], color: NavigationConfig.Colors.replayTrail)
                sceneView.scene.rootNode.addChildNode(ribbon)
                replayNodes.append(ribbon)

                let arrow = NodeFactory.createArrow(from: positions[i], to: positions[i + 1])
                sceneView.scene.rootNode.addChildNode(arrow)
                replayNodes.append(arrow)
            }
        }

        // スタート・ゴールマーカー
        let startMarker = NodeFactory.createStartMarker(at: startPosition)
        sceneView.scene.rootNode.addChildNode(startMarker)
        replayNodes.append(startMarker)

        if let lastPos = positions.last {
            let goalMarker = NodeFactory.createGoalMarker(at: lastPos)
            sceneView.scene.rootNode.addChildNode(goalMarker)
            replayNodes.append(goalMarker)
        }
    }

    // MARK: - AR Session Delegate Helpers

    /// トラッキング状態変化時の処理
    func handleTrackingStateChange(_ camera: ARCamera, session: ARSession) {
        let ready: Bool
        var message: String

        switch camera.trackingState {
        case .normal:
            ready = true
            message = "準備完了"

            if isRelocalizing, let route = pendingReplayRoute {
                isRelocalizing = false
                print("✅ Relocalization complete")

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

        // 状態を保存
        lastKnownReadyState = ready
        lastKnownStatusMessage = message

        print("🔄 handleTrackingStateChange: ready=\(ready), message=\(message)")
        delegate?.arSessionDidChangeReadyState(ready)
        delegate?.arSessionDidUpdateStatus(message)
    }

    /// 現在の状態を再通知（Store初期化後の同期用）
    func reportCurrentStatus() {
        print("📢 reportCurrentStatus called: ready=\(lastKnownReadyState), message=\(lastKnownStatusMessage)")
        delegate?.arSessionDidChangeReadyState(lastKnownReadyState)
        delegate?.arSessionDidUpdateStatus(lastKnownStatusMessage)
    }

    /// フレーム更新時の処理（記録中）
    func handleFrameUpdate(_ frame: ARFrame) {
        guard isRecording,
              let lastPos = lastTurnPosition,
              let lastTrail = lastTrailPosition,
              let sceneView = sceneView else { return }

        let transform = frame.camera.transform
        let currentPos = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

        let distance = Self.distanceXZ(from: lastPos, to: currentPos)

        var angle: Float = 0
        if distance >= NavigationConfig.Recording.minDistanceForAngle {
            let dx = currentPos.x - lastPos.x
            let dz = currentPos.z - lastPos.z
            let currentMoveDirection = atan2(dx, -dz)
            angle = Self.normalizeAngle(currentMoveDirection - lastMoveDirection)
        }

        delegate?.arSessionDidUpdateRecordingInfo(distance: distance, angle: angle * 180 / .pi)

        // 軌跡リボンを追加
        let trailDist = Self.distanceXZ(from: lastTrail, to: currentPos)
        if trailDist >= NavigationConfig.Trail.ribbonInterval {
            let floorPos = SCNVector3(currentPos.x, currentPos.y - NavigationConfig.Positioning.floorOffset, currentPos.z)
            let lastFloorPos = SCNVector3(lastTrail.x, lastTrail.y - NavigationConfig.Positioning.floorOffset, lastTrail.z)

            let ribbon = NodeFactory.createRibbon(
                from: lastFloorPos,
                to: floorPos,
                color: NavigationConfig.Colors.recordingTrail.withAlphaComponent(NavigationConfig.Colors.trailAlpha)
            )
            sceneView.scene.rootNode.addChildNode(ribbon)
            trailNodes.append(ribbon)

            lastTrailPosition = currentPos
        }
    }

    // MARK: - Utilities (Static)

    /// カメラのYaw角度を抽出
    static func extractYaw(from transform: simd_float4x4) -> Float {
        let forward = simd_float3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        return atan2(forward.x, -forward.z)
    }

    /// XZ平面上の距離を計算
    static func distanceXZ(from: SCNVector3, to: SCNVector3) -> Float {
        let dx = to.x - from.x
        let dz = to.z - from.z
        return sqrt(dx * dx + dz * dz)
    }

    /// 角度を-π〜πに正規化
    static func normalizeAngle(_ angle: Float) -> Float {
        var a = angle
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }
}

// MARK: - NodeFactory

/// ARノードを生成するファクトリ
enum NodeFactory {

    static func createStartMarker(at position: SCNVector3) -> SCNNode {
        let cylinder = SCNCylinder(
            radius: NavigationConfig.Markers.cylinderRadius,
            height: NavigationConfig.Markers.cylinderHeight
        )
        cylinder.firstMaterial?.diffuse.contents = NavigationConfig.Colors.startMarker
        cylinder.firstMaterial?.emission.contents = NavigationConfig.Colors.startMarker.withAlphaComponent(NavigationConfig.Colors.emissionAlpha)

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(position.x, position.y - 0.3, position.z)
        return node
    }

    static func createGoalMarker(at position: SCNVector3) -> SCNNode {
        let cylinder = SCNCylinder(
            radius: NavigationConfig.Markers.cylinderRadius,
            height: NavigationConfig.Markers.cylinderHeight
        )
        cylinder.firstMaterial?.diffuse.contents = NavigationConfig.Colors.goalMarker
        cylinder.firstMaterial?.emission.contents = NavigationConfig.Colors.goalMarker.withAlphaComponent(NavigationConfig.Colors.emissionAlpha)

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(position.x, position.y + 0.2, position.z)
        return node
    }

    static func createTurnMarker(at position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: NavigationConfig.Markers.turnSphereRadius)
        sphere.firstMaterial?.diffuse.contents = NavigationConfig.Colors.turnMarker
        sphere.firstMaterial?.emission.contents = NavigationConfig.Colors.turnMarker.withAlphaComponent(NavigationConfig.Colors.emissionAlpha)

        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(position.x, position.y - NavigationConfig.Positioning.floorOffset, position.z)
        return node
    }

    static func createRibbon(from: SCNVector3, to: SCNVector3, color: UIColor) -> SCNNode {
        let dx = to.x - from.x
        let dz = to.z - from.z
        let length = sqrt(dx * dx + dz * dz)

        guard length > 0.01 else {
            return SCNNode()
        }

        let box = SCNBox(
            width: NavigationConfig.Trail.ribbonWidth,
            height: NavigationConfig.Trail.ribbonHeight,
            length: CGFloat(length),
            chamferRadius: 0
        )
        box.firstMaterial?.diffuse.contents = color
        box.firstMaterial?.emission.contents = color.withAlphaComponent(NavigationConfig.Colors.emissionWeakAlpha)
        box.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: box)
        node.position = SCNVector3((from.x + to.x) / 2, from.y, (from.z + to.z) / 2)
        node.eulerAngles.y = atan2(dx, dz)

        return node
    }

    static func createArrow(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let cone = SCNCone(
            topRadius: 0,
            bottomRadius: NavigationConfig.Markers.arrowBottomRadius,
            height: NavigationConfig.Markers.arrowHeight
        )
        cone.firstMaterial?.diffuse.contents = NavigationConfig.Colors.arrow
        cone.firstMaterial?.emission.contents = NavigationConfig.Colors.arrow.withAlphaComponent(NavigationConfig.Colors.emissionAlpha)

        let node = SCNNode(geometry: cone)
        node.position = to

        let dx = to.x - from.x
        let dz = to.z - from.z
        let angle = atan2(dx, dz)
        node.eulerAngles = SCNVector3(-Float.pi / 2, angle, 0)

        return node
    }

    static func createEventNode(type: EventType, at position: SCNVector3) -> SCNNode {
        let node = SCNNode()

        let sphere = SCNSphere(radius: NavigationConfig.Markers.eventSphereRadius)
        sphere.firstMaterial?.diffuse.contents = NavigationConfig.Colors.eventMarker
        sphere.firstMaterial?.emission.contents = NavigationConfig.Colors.eventMarker.withAlphaComponent(NavigationConfig.Colors.emissionWeakAlpha)

        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(0, NavigationConfig.Markers.eventSphereYOffset, 0)
        node.addChildNode(sphereNode)

        let text = SCNText(string: type.displayText, extrusionDepth: NavigationConfig.Text.eventExtrusionDepth)
        text.font = UIFont.systemFont(ofSize: NavigationConfig.Text.eventFontSize, weight: .bold)
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.flatness = 0.1

        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(-0.15, 0.35, 0)
        textNode.scale = SCNVector3(
            NavigationConfig.Text.eventTextScale,
            NavigationConfig.Text.eventTextScale,
            NavigationConfig.Text.eventTextScale
        )

        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = .Y
        textNode.constraints = [constraint]
        node.addChildNode(textNode)

        node.position = position
        return node
    }
}
