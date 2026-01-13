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

// MARK: - ARSceneCommand

/// ARSceneViewに送るコマンド
enum ARSceneCommand: Equatable {
    case none
    case startRecording
    case recordTurn
    case saveRoute
    case reset
    case replay(routeID: UUID)
}

// MARK: - ARSceneCallback

/// ARSceneViewからのコールバック
protocol ARSceneCallback: AnyObject {
    func arSceneDidChangeReadyState(_ isReady: Bool)
    func arSceneDidUpdateStatus(_ message: String)
    func arSceneDidUpdateRecordingInfo(distance: Float, angle: Float)
    func arSceneDidPrepareSaveData(
        items: [RouteItem],
        worldMapData: Data?,
        startAnchorID: UUID?,
        startHeading: Float
    )
}

// MARK: - NavARSceneView

struct NavARSceneView: UIViewRepresentable {

    // コマンドベースのインターフェース
    @Binding var command: ARSceneCommand

    // ルート再生用（IDからNavRouteを取得するためのクロージャ）
    var getRouteByID: ((UUID) -> NavRoute?)?

    // コールバック
    weak var callback: ARSceneCallback?

    // レガシーBinding（過渡期 - Step 3.3で削除予定）
    @Binding var legacyNavState: NavState
    @Binding var legacyIsReady: Bool
    @Binding var legacyStatusMessage: String
    @Binding var legacyCurrentDistance: Float
    @Binding var legacyCurrentAngle: Float
    @Binding var legacyShouldStartRecording: Bool
    @Binding var legacyShouldRecordTurn: Bool
    @Binding var legacyShouldSaveRoute: Bool
    @Binding var legacyShouldReset: Bool
    @Binding var legacyRouteToReplay: NavRoute?
    @Binding var legacyPendingSaveItems: [RouteItem]
    @Binding var legacySaveRequestID: UUID?
    @Binding var legacyPendingWorldMapData: Data?
    @Binding var legacyPendingStartAnchorID: UUID?
    @Binding var legacyPendingStartHeading: Float

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

        // 新しいコマンドベースの処理
        switch command {
        case .none:
            break
        case .startRecording:
            coordinator.startRecording()
            DispatchQueue.main.async { command = .none }
        case .recordTurn:
            coordinator.recordTurn()
            DispatchQueue.main.async { command = .none }
        case .saveRoute:
            coordinator.prepareSaveRoute()
            DispatchQueue.main.async { command = .none }
        case .reset:
            coordinator.reset()
            DispatchQueue.main.async { command = .none }
        case .replay(let routeID):
            if let route = getRouteByID?(routeID) {
                coordinator.replayRoute(route)
            }
            DispatchQueue.main.async { command = .none }
        }

        // レガシーBinding処理（過渡期）
        if legacyShouldStartRecording {
            coordinator.startRecording()
            DispatchQueue.main.async {
                legacyShouldStartRecording = false
                legacyNavState = .recording
            }
        }

        if legacyShouldRecordTurn {
            coordinator.recordTurn()
            DispatchQueue.main.async {
                legacyShouldRecordTurn = false
            }
        }

        if legacyShouldSaveRoute {
            coordinator.prepareSaveRoute()
            DispatchQueue.main.async {
                legacyShouldSaveRoute = false
            }
        }

        if legacyShouldReset {
            coordinator.reset()
            DispatchQueue.main.async {
                legacyShouldReset = false
            }
        }

        if let route = legacyRouteToReplay {
            coordinator.replayRoute(route)
            DispatchQueue.main.async {
                legacyRouteToReplay = nil
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

        // 内部でARSessionServiceを使用
        private let arService = ARSessionService()

        init(_ parent: NavARSceneView) {
            self.parent = parent
            super.init()
            arService.delegate = self
        }

        // MARK: - Public Methods (ARSessionServiceに委譲)

        func startRecording() {
            arService.sceneView = sceneView
            arService.startRecording()
        }

        func recordTurn() {
            arService.recordTurn()
        }

        func prepareSaveRoute() {
            arService.prepareSaveRoute()
        }

        func reset() {
            arService.reset()
            updateLegacyUI(distance: 0, angle: 0, message: parent.legacyIsReady ? "準備完了" : "準備中...")
        }

        func replayRoute(_ route: NavRoute) {
            arService.sceneView = sceneView
            arService.replayRoute(route)
        }

        // MARK: - ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let frame = sceneView?.session.currentFrame else { return }
            arService.handleFrameUpdate(frame)
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            arService.handleTrackingStateChange(camera, session: session)
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.parent.legacyStatusMessage = "エラー: \(error.localizedDescription)"
                self.parent.legacyIsReady = false
                self.parent.callback?.arSceneDidUpdateStatus("エラー: \(error.localizedDescription)")
                self.parent.callback?.arSceneDidChangeReadyState(false)
            }
        }

        // MARK: - Legacy UI Update

        private func updateLegacyUI(distance: Float, angle: Float, message: String) {
            DispatchQueue.main.async {
                self.parent.legacyCurrentDistance = distance
                self.parent.legacyCurrentAngle = angle
                self.parent.legacyStatusMessage = message
            }
        }
    }
}

// MARK: - Coordinator + ARSessionServiceDelegate

extension NavARSceneView.Coordinator: ARSessionServiceDelegate {

    func arSessionDidChangeReadyState(_ isReady: Bool) {
        DispatchQueue.main.async {
            self.parent.legacyIsReady = isReady
            self.parent.callback?.arSceneDidChangeReadyState(isReady)
        }
    }

    func arSessionDidUpdateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.parent.legacyStatusMessage = message
            self.parent.callback?.arSceneDidUpdateStatus(message)
        }
    }

    func arSessionDidUpdateRecordingInfo(distance: Float, angle: Float) {
        DispatchQueue.main.async {
            self.parent.legacyCurrentDistance = distance
            self.parent.legacyCurrentAngle = angle
            self.parent.callback?.arSceneDidUpdateRecordingInfo(distance: distance, angle: angle)
        }
    }

    func arSessionDidPrepareSaveData(
        items: [RouteItem],
        worldMapData: Data?,
        startAnchorID: UUID?,
        startHeading: Float
    ) {
        DispatchQueue.main.async {
            // レガシーBinding
            self.parent.legacyPendingSaveItems = items
            self.parent.legacyPendingWorldMapData = worldMapData
            self.parent.legacyPendingStartAnchorID = startAnchorID
            self.parent.legacyPendingStartHeading = startHeading
            self.parent.legacySaveRequestID = UUID()

            // 新しいコールバック
            self.parent.callback?.arSceneDidPrepareSaveData(
                items: items,
                worldMapData: worldMapData,
                startAnchorID: startAnchorID,
                startHeading: startHeading
            )
        }
    }
}
