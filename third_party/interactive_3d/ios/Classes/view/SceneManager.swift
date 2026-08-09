import SceneKit
import GLTFSceneKit
import UIKit

/// Loads 3D models into a SceneKit scene and manages scene lifecycle.
///
/// Handles two loading paths: SCNSceneSource (native) with GLTFSceneSource
/// as fallback. Applies default lighting when the model doesn't include
/// light nodes, and supports HDR/EXR background image loading.
class SceneManager {

    private weak var scnView: SCNView?
    private var resetCameraTransform: SCNMatrix4?
    private var resetCameraTarget: SCNVector3?
    private var resetCameraFieldOfView: CGFloat?
    private var modelNodesForFraming: [SCNNode] = []
    private var shouldCaptureNextZoomAsResetBaseline = false

    var cameraNode: SCNNode?
    var useSolidBackground = false

    /// Node opacity tracking for part group visibility.
    var nodeOpacities: [SCNNode: CGFloat] = [:]

    init(scnView: SCNView) {
        self.scnView = scnView
    }

    /// Removes all nodes, geometry, materials, and textures from the current
    /// scene to prevent memory accumulation across model loads.
    func cleanupPreviousModel() {
        nodeOpacities.removeAll()

        if let scene = scnView?.scene {
            scene.rootNode.enumerateChildNodes { (node, _) in
                if let geometry = node.geometry {
                    for material in geometry.materials {
                        material.diffuse.contents = nil
                        material.normal.contents = nil
                        material.emission.contents = nil
                        material.multiply.contents = nil
                        material.specular.contents = nil
                        material.roughness.contents = nil
                        material.metalness.contents = nil
                        material.ambientOcclusion.contents = nil
                    }
                    geometry.materials = []
                    node.geometry = nil
                }
                node.removeFromParentNode()
            }
            scene.background.contents = nil
            scene.lightingEnvironment.contents = nil
        }

        SCNTransaction.flush()
        cameraNode = nil
        resetCameraTransform = nil
        resetCameraTarget = nil
        resetCameraFieldOfView = nil
        modelNodesForFraming = []
        shouldCaptureNextZoomAsResetBaseline = false
    }

    /// Loads a GLB/glTF model from raw bytes into the scene view.
    ///
    /// Tries SCNSceneSource first (faster for simple models), falls back to
    /// GLTFSceneSource for full glTF 2.0 support. Adds default lighting if
    /// the model doesn't include any light nodes.
    func loadModel(modelBytes: Data) throws {
        cleanupPreviousModel()

        let scene: SCNScene
        do {
            let sceneSource = SCNSceneSource(data: modelBytes, options: [
                SCNSceneSource.LoadingOption.createNormalsIfAbsent: true,
                SCNSceneSource.LoadingOption.checkConsistency: true
            ])
            guard let loadedScene = sceneSource?.scene(options: nil) else {
                throw NSError(domain: "SceneManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "SCNSceneSource failed"])
            }
            scene = loadedScene
        } catch {
            // Fallback: write to temp file and load via GLTFSceneSource
            let tempPath = NSTemporaryDirectory().appending("model.glb")
            try modelBytes.write(to: URL(fileURLWithPath: tempPath))
            defer { try? FileManager.default.removeItem(atPath: tempPath) }
            let gltfSource = try GLTFSceneSource(url: URL(fileURLWithPath: tempPath))
            scene = try gltfSource.scene()
        }

        // Apply fallback materials to nodes without diffuse content
        scene.rootNode.enumerateChildNodes { (node, _) in
            if let geometry = node.geometry {
                if geometry.materials.isEmpty || geometry.firstMaterial?.diffuse.contents == nil {
                    let fallback = SCNMaterial()
                    fallback.diffuse.contents = UIColor.green
                    fallback.isDoubleSided = true
                    geometry.materials = [fallback]
                }
            }
        }

        scnView?.scene = scene
        modelNodesForFraming = framableNodes(in: scene)
        configureCamera(for: scene)

        // Add default lighting if model has none
        if !hasLightNodes(in: scene.rootNode) {
            addDefaultLighting(to: scene)
        }

        captureCurrentCameraResetState()
        shouldCaptureNextZoomAsResetBaseline = true
    }

    /// Sets the camera distance from the model origin.
    func setCameraZoomLevel(_ zoomLevel: Float) {
        guard zoomLevel > 0,
              let scnView,
              let cam = cameraNode else { return }

        let controller = scnView.defaultCameraController
        controller.stopInertia()
        controller.pointOfView = cam
        scnView.pointOfView = cam

        let target = controller.target
        let offset = SCNVector3(
            x: cam.worldPosition.x - target.x,
            y: cam.worldPosition.y - target.y,
            z: cam.worldPosition.z - target.z
        )
        let length = sqrt(
            (offset.x * offset.x) +
            (offset.y * offset.y) +
            (offset.z * offset.z)
        )
        let direction = length > 0
            ? SCNVector3(x: offset.x / length, y: offset.y / length, z: offset.z / length)
            : SCNVector3(x: 0, y: 0, z: 1)

        cam.worldPosition = SCNVector3(
            x: target.x + direction.x * zoomLevel,
            y: target.y + direction.y * zoomLevel,
            z: target.z + direction.z * zoomLevel
        )
        cam.look(at: target)
        cam.camera?.zNear = 0.01

        if shouldCaptureNextZoomAsResetBaseline {
            captureCurrentCameraResetState()
            shouldCaptureNextZoomAsResetBaseline = false
        }

        scnView.setNeedsDisplay()
    }

    /// Restores the camera to the initial framed rotation and zoom.
    func resetCamera() {
        guard let scnView,
              let cam = cameraNode,
              let resetTransform = resetCameraTransform else { return }

        let controller = scnView.defaultCameraController
        controller.stopInertia()
        controller.clearRoll()
        controller.pointOfView = cam
        scnView.pointOfView = cam

        if !modelNodesForFraming.isEmpty {
            controller.frameNodes(modelNodesForFraming)
        }

        cam.transform = resetTransform
        if let fieldOfView = resetCameraFieldOfView {
            cam.camera?.fieldOfView = fieldOfView
        }
        if let target = resetCameraTarget {
            controller.target = target
        }

        scnView.setNeedsDisplay()
    }

    /// Loads an HDR/EXR image as the scene background.
    ///
    /// Resizes images larger than 8192px (Metal texture limit) and applies
    /// neutral lighting to avoid HDR color tinting the model. Skipped when
    /// [useSolidBackground] is true.
    func loadHdrBackground(_ backgroundBytes: Data) throws {
        let tempPath = NSTemporaryDirectory().appending("background.hdr")
        try backgroundBytes.write(to: URL(fileURLWithPath: tempPath))
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        guard let image = UIImage(contentsOfFile: tempPath) else {
            throw NSError(domain: "SceneManager", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to load HDR/EXR image"])
        }

        guard let scene = scnView?.scene else {
            throw NSError(domain: "SceneManager", code: -5,
                          userInfo: [NSLocalizedDescriptionKey: "Scene not initialized"])
        }

        if useSolidBackground { return }

        let resized = resizeIfNeeded(image, maxSize: 8192)
        scene.background.contents = resized

        // Neutral white lighting environment avoids HDR color tinting the model
        scene.lightingEnvironment.contents = UIColor.white
        scene.lightingEnvironment.intensity = 1.0

        // Replace existing lights with controlled lighting
        scene.rootNode.enumerateChildNodes { (node, _) in
            if node.light != nil { node.removeFromParentNode() }
        }
        addHdrLighting(to: scene)
    }

    /// Toggles visibility for a named group of model parts.
    func setPartGroupVisibility(group: [String: Any], isVisible: Bool) {
        guard let scene = scnView?.scene,
              let names = group["names"] as? [String] else { return }

        let opacity: CGFloat = isVisible ? 1.0 : 0.0
        scene.rootNode.enumerateChildNodes { (node, _) in
            if let nodeName = node.name, names.contains(nodeName) {
                node.opacity = opacity
                node.isHidden = !isVisible
                self.nodeOpacities[node] = opacity

                node.enumerateChildNodes { (child, _) in
                    if child.geometry != nil {
                        child.opacity = opacity
                        child.isHidden = !isVisible
                        self.nodeOpacities[child] = opacity
                    }
                }
            }
        }
        scnView?.setNeedsDisplay()
    }

    /// Deep-cleans the scene for final disposal.
    func cleanup() {
        cleanupPreviousModel()
        scnView?.scene = nil
        SCNTransaction.flush()
    }

    // MARK: - Private

    private func hasLightNodes(in node: SCNNode) -> Bool {
        if node.light != nil { return true }
        return node.childNodes.contains { hasLightNodes(in: $0) }
    }

    private func addDefaultLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = UIColor.white
        ambient.light!.intensity = 1000
        scene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light!.type = .directional
        directional.light!.color = UIColor.white
        directional.light!.intensity = 2000
        directional.position = SCNVector3(x: 10, y: 10, z: 10)
        directional.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directional)
    }

    private func addHdrLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = UIColor.white
        ambient.light!.intensity = 600
        scene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light!.type = .directional
        directional.light!.color = UIColor.white
        directional.light!.intensity = 1000
        directional.position = SCNVector3(x: 10, y: 10, z: 10)
        directional.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directional)
    }

    private func resizeIfNeeded(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxSize || size.height > maxSize else { return image }

        let aspect = size.width / size.height
        let target: CGSize
        if size.width > size.height {
            target = CGSize(width: maxSize, height: maxSize / aspect)
        } else {
            target = CGSize(width: maxSize * aspect, height: maxSize)
        }

        UIGraphicsBeginImageContextWithOptions(target, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: target))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    private func configureCamera(for scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.name = "__interactive3d_camera__"

        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.automaticallyAdjustsZRange = true
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        self.cameraNode = cameraNode

        guard let scnView else { return }
        scnView.pointOfView = cameraNode

        let controller = scnView.defaultCameraController
        controller.pointOfView = cameraNode
        controller.interactionMode = .orbitTurntable
        controller.automaticTarget = false
        controller.worldUp = SCNVector3(x: 0, y: 1, z: 0)
        controller.stopInertia()
        controller.clearRoll()

        if !modelNodesForFraming.isEmpty {
            controller.frameNodes(modelNodesForFraming)
        } else {
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
            cameraNode.look(at: SCNVector3Zero)
            controller.target = SCNVector3Zero
        }
    }

    private func captureCurrentCameraResetState() {
        guard let scnView,
              let pointOfView = scnView.pointOfView else { return }

        resetCameraTransform = pointOfView.transform
        resetCameraTarget = scnView.defaultCameraController.target
        resetCameraFieldOfView = pointOfView.camera?.fieldOfView
    }

    private func framableNodes(in scene: SCNScene) -> [SCNNode] {
        scene.rootNode.childNodes.filter { node in
            node.camera == nil && node.light == nil
        }
    }
}
