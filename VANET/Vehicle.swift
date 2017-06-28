import Foundation
import CoreBluetooth
import SpriteKit

enum Direction {
    case up
    case down
    case left
    case right
}

class Vehicle {
    /// 從裝置取得的 id（因為 CoreBluetooth 無法取得硬體位置）
    var id: Int
    /// 方向
    ///
    /// 右轉為正數，左轉為負數，值從 `-1.0...1.0`
    var heading: Double
    /// 速度
    ///
    /// 向前走為正數，向後走為負數，值從 `-1.0...1.0`
    var speed: Double
    /// 由前方超音波得到的距離
    var frontSensorValue: Int
    
    /// 設定的前進方向
    var direction: Direction
    
    init(direction dir: Direction) {
        direction = dir
        self.id = -1
        self.heading = 0
        self.speed = 0
        self.frontSensorValue = Int.max
    }
}

class VehicleNode: SKNode {
    static var iconSize = 120
    static var fontSize = 20
    static var padding = 5
    
    let label: SKLabelNode
    let image: SKSpriteNode
    let vehicle: Vehicle
    var text: String {
        didSet {
            label.text = text
        }
    }
    init(direction: Direction = .up, vehicle v: Vehicle) {
        image = SKSpriteNode(texture: SKTexture(image: #imageLiteral(resourceName: "Vehicle")))
        image.size = CGSize(width: VehicleNode.iconSize, height: VehicleNode.iconSize)
        switch direction {
        case .up:
            break
        case .left:
            image.run(SKAction.rotate(byAngle: CGFloat.pi * 0.5, duration: 0.0))
        case .down:
            image.run(SKAction.rotate(byAngle: CGFloat.pi * 1.0, duration: 0.0))
        case .right:
            image.run(SKAction.rotate(byAngle: CGFloat.pi * 1.5, duration: 0.0))
        }
        
        label = SKLabelNode(text: "")
        label.position = CGPoint(x: 10, y: -(VehicleNode.iconSize / 2 + VehicleNode.fontSize + VehicleNode.padding))
        label.fontName = NSFont.systemFont(ofSize: 14.0).fontName
        label.fontSize = CGFloat(integerLiteral: VehicleNode.fontSize)
        label.fontColor = NSColor.white
        vehicle = v
        text = ""
        super.init()
        
        addChild(image)
        addChild(label)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
