import ARKit
import Foundation
import GLTFSceneKit

extension URL {
    func containsFile(fileName: String) -> Bool {
        let fileURL = self.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}

func createNode(_ geometry: SCNGeometry?, fromDict dict: Dictionary<String, Any>, forDevice device: MTLDevice?) -> SCNNode {
    let dartType = dict["dartType"] as! String
    
    let node = dartType == "ARKitReferenceNode"
        ? createReferenceNode(dict)
        : SCNNode(geometry: geometry)
  
    updateNode(node, fromDict: dict, forDevice: device)
    
    return node
}

func updateNode(_ node: SCNNode, fromDict dict: Dictionary<String, Any>, forDevice device: MTLDevice?) {
    if let transform = dict["transform"] as? Array<NSNumber> {
        node.transform = deserializeMatrix4(transform)
    }
    
    if let name = dict["name"] as? String {
        node.name = name
    }
    
    if let physicsBody = dict["physicsBody"] as? Dictionary<String, Any> {
        node.physicsBody = createPhysicsBody(physicsBody, forDevice: device)
    }
    
    if let light = dict["light"] as? Dictionary<String, Any> {
        node.light = createLight(light)
    }
    
    if let renderingOrder = dict["renderingOrder"] as? Int {
        node.renderingOrder = renderingOrder
    }
    
    if let isHidden = dict["isHidden"] as? Bool {
        node.isHidden = isHidden
    }
}

fileprivate func createReferenceNode(_ dict: Dictionary<String, Any>) -> SCNNode {
    let modelNameOrUrl = dict["url"] as! String
    let referenceUrl: URL = getReferenceUrlFrom(modelNameOrUrl: modelNameOrUrl)
    if isGLTFFile(fileName: URL(fileURLWithPath: modelNameOrUrl).lastPathComponent) {
        return createGLTFNode(modelUrl: referenceUrl)!
    }
    let node: SCNReferenceNode? = SCNReferenceNode(url: referenceUrl)
    node?.load()
    return node!
}

fileprivate func getReferenceUrlFrom(modelNameOrUrl: String) -> URL {
    let fileName: String = URL(fileURLWithPath: modelNameOrUrl).lastPathComponent
    let documentsDirectory = getDocumentsDirectory()
    if documentsDirectory.containsFile(fileName: fileName) {
      return documentsDirectory.appendingPathComponent(fileName)
    }
    return Bundle.main.url(forResource: modelNameOrUrl, withExtension: nil) ?? URL(fileURLWithPath: modelNameOrUrl)
}

fileprivate func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
}

fileprivate func isGLTFFile(fileName: String) -> Bool {
    let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
    return fileExtension == "gltf" || fileExtension == "glb"
}

fileprivate func doesDirectoryContainFile(directoryUrl: URL, fileName: String) -> Bool {
    let fileURL = directoryUrl.appendingPathComponent(fileName)
    return FileManager.default.fileExists(atPath: fileURL.path)
}

fileprivate func createGLTFNode(modelUrl: URL) -> SCNNode? {
    var node: SCNNode? = SCNNode()
    do {
        let sceneSource = GLTFSceneSource(url: modelUrl)
        let scene = try sceneSource.scene()
        for child in scene.rootNode.childNodes {
            child.scale = SCNVector3(0.01,0.01,0.01)
            node?.addChildNode(child)
        }
    } catch {
        print("\(error.localizedDescription)")
        node = nil
    }
    return node
}



fileprivate func createPhysicsBody(_ dict: Dictionary<String, Any>, forDevice device: MTLDevice?) -> SCNPhysicsBody {
    var shape: SCNPhysicsShape?
    if let shapeDict = dict["shape"] as? Dictionary<String, Any>,
        let shapeGeometry = shapeDict["geometry"] as? Dictionary<String, Any> {
        let geometry = createGeometry(shapeGeometry, withDevice: device)
        shape = SCNPhysicsShape(geometry: geometry!, options: nil)
    }
    let type = dict["type"] as! Int
    let bodyType = SCNPhysicsBodyType(rawValue: type)
    let physicsBody = SCNPhysicsBody(type: bodyType!, shape: shape)
    if let categoryBitMack = dict["categoryBitMask"] as? Int {
        physicsBody.categoryBitMask = categoryBitMack
    }
    return physicsBody
}

fileprivate func createLight(_ dict: Dictionary<String, Any>) -> SCNLight {
    let light = SCNLight()
    if let type = dict["type"] as? Int {
        switch type {
        case 0:
            light.type = .ambient
            break
        case 1:
            light.type = .omni
            break
        case 2:
            light.type = .directional
            break
        case 3:
            light.type = .spot
            break
        case 4:
            light.type = .IES
            break
        case 5:
            light.type = .probe
            break
        case 6:
            if #available(iOS 13.0, *) {
                light.type = .area
            } else {
                // error
                light.type = .omni
            }
            break
        default:
            light.type = .omni
            break
        }
    } else {
        light.type = .omni
    }
    if let temperature = dict["temperature"] as? Double {
        light.temperature = CGFloat(temperature)
    }
    if let intensity = dict["intensity"] as? Double {
        light.intensity = CGFloat(intensity)
    }
    if let spotInnerAngle = dict["spotInnerAngle"] as? Double {
        light.spotInnerAngle = CGFloat(spotInnerAngle)
    }
    if let spotOuterAngle = dict["spotOuterAngle"] as? Double {
        light.spotOuterAngle = CGFloat(spotOuterAngle)
    }
    if let color = dict["color"] as? Int {
        light.color = UIColor(rgb: UInt(color))
    }
    return light
}
