//
//  NavARSceneView.swift
//  KitApp
//
//  歩行ナビプロトタイプ用の AR View
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
    case replay(route: NavRoute)
    case requestCurrentStatus

    static func == (lhs: ARSceneCommand, rhs: ARSceneCommand) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none),
             (.startRecording, .startRecording),
             (.recordTurn, .recordTurn),
             (.saveRoute, .saveRoute),
             (.reset, .reset),
             (.requestCurrentStatus, .requestCurrentStatus):
            return true
        case (.replay(let l), .replay(let r)):
            return l.id == r.id
        default:
            return false
        }
    }
}

// MARK: - ARSceneEvent

/// ARSceneViewから発生するイベント
enum ARSceneEvent {
    case readyChanged(Bool)
    case statusChanged(String)
    case recordingInfoUpdated(distance: Float, angle: Float)
    case saveDataReady(items: [RouteItem], worldMapData: Data?, startAnchorID: UUID?, startHeading: Float)
}

// MARK: - NavARSceneView

struct NavARSceneView: UIViewRepresentable {

    /// ARSceneに送るコマンド
    @Binding var command: ARSceneCommand

    /// ARSceneからのイベントを受け取るハンドラ
    var onEvent: ((ARSceneEvent) -> Void)?

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
        case .replay(let route):
            coordinator.replayRoute(route)
            DispatchQueue.main.async { command = .none }
        case .requestCurrentStatus:
            coordinator.requestCurrentStatus()
            DispatchQueue.main.async { command = .none }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        var parent: NavARSceneView
        weak var sceneView: ARSCNView?

        private let arService = ARSessionService()

        init(_ parent: NavARSceneView) {
            self.parent = parent
            super.init()
            arService.delegate = self
        }

        // MARK: - Public Methods

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
        }

        func replayRoute(_ route: NavRoute) {
            arService.sceneView = sceneView
            arService.replayRoute(route)
        }

        func requestCurrentStatus() {
            arService.reportCurrentStatus()
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
                self.parent.onEvent?(.statusChanged("エラー: \(error.localizedDescription)"))
                self.parent.onEvent?(.readyChanged(false))
            }
        }
    }
}

// MARK: - Coordinator + ARSessionServiceDelegate

extension NavARSceneView.Coordinator: ARSessionServiceDelegate {

    func arSessionDidChangeReadyState(_ isReady: Bool) {
        DispatchQueue.main.async {
            self.parent.onEvent?(.readyChanged(isReady))
        }
    }

    func arSessionDidUpdateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.parent.onEvent?(.statusChanged(message))
        }
    }

    func arSessionDidUpdateRecordingInfo(distance: Float, angle: Float) {
        DispatchQueue.main.async {
            self.parent.onEvent?(.recordingInfoUpdated(distance: distance, angle: angle))
        }
    }

    func arSessionDidPrepareSaveData(
        items: [RouteItem],
        worldMapData: Data?,
        startAnchorID: UUID?,
        startHeading: Float
    ) {
        DispatchQueue.main.async {
            self.parent.onEvent?(.saveDataReady(
                items: items,
                worldMapData: worldMapData,
                startAnchorID: startAnchorID,
                startHeading: startHeading
            ))
        }
    }
}
