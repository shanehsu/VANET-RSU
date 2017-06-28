//
//  GameScene.swift
//  VANET
//
//  Created by 徐鵬鈞 on 2017/6/15.
//  Copyright © 2017年 Nameless Apps. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreBluetooth

class GameScene: SKScene {
    static let characteristicsUUID = [
        "fff1": "id",
        "fff2": "speed",
        "fff3": "heading",
        "fff4": "distance"
    ]
    
    var centralManager: CBCentralManager!
    var peripherals: [CBPeripheral] = []
    var vehicles: [CBPeripheral: Vehicle] = [:]
    var trackedVehicles: [VehicleNode: Vehicle] = [:]
    
    private lazy var road: SKTileMapNode = {
        return self.childNode(withName: "Road") as! SKTileMapNode
    }()
    private lazy var normalGroup: SKTileGroup = {
        let tile = SKTileDefinition(texture: SKTexture(image: #imageLiteral(resourceName: "Road/WithoutDash")))
        let group = SKTileGroup(tileDefinition: tile)
        return group
    }()
    private lazy var dashedGroup: SKTileGroup = {
        let tile = SKTileDefinition(texture: SKTexture(image: #imageLiteral(resourceName: "Road/WithDash")))
        let group = SKTileGroup(tileDefinition: tile)
        return group
    }()
    override func didChangeSize(_: CGSize) {
        let newRowCount = Int(ceil(size.height / 32.0))
        road.numberOfRows = newRowCount
        
        let _ = normalGroup
        let _ = dashedGroup
        updateRoad()
    }
    override func didMove(to view: SKView) {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        road.tileSet = SKTileSet(tileGroups: [normalGroup, dashedGroup])
        updateRoad()
    }
    
    func touchDown(atPoint pos: CGPoint) {
    }
    func touchMoved(toPoint pos: CGPoint) {
    }
    func touchUp(atPoint pos: CGPoint) {
        // Find a vehicle!
        let tracked = trackedVehicles.values.filter({ _ in true })
        let untrackedVehicles = vehicles.values.filter({ !tracked.includes($0) })
        guard let vehicle = untrackedVehicles.first else {
            return
        }
        
        let node = VehicleNode(direction: .up, vehicle: vehicle)
        node.position = pos
        self.addChild(node)
        
        trackedVehicles[node] = vehicle
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        default:
            print("keyDown: \(event.characters!) keyCode: \(event.keyCode)")
        }
    }
    override func mouseDown(with event: NSEvent) {
        self.touchDown(atPoint: event.location(in: self))
    }
    override func mouseDragged(with event: NSEvent) {
        self.touchMoved(toPoint: event.location(in: self))
    }
    override func mouseUp(with event: NSEvent) {
        self.touchUp(atPoint: event.location(in: self))
    }
    var lastUpdate: TimeInterval = 0
    override func update(_ currentTime: TimeInterval) {
        let delta = currentTime - lastUpdate
        
        for (node, vehicle) in trackedVehicles {
            let positionDelta = CGFloat(vehicle.speed * delta * 100.0)
            // NSLog("\(node.position)")
            node.position = CGPoint(x: node.position.x, y: node.position.y  + positionDelta)
            // NSLog("\(node.position)")
            node.text = "v = \(vehicle.speed) d = \(vehicle.frontSensorValue)"
        }
        
        lastUpdate = currentTime
    }
    
    func updateRoad() {
        for column in 0..<road.numberOfColumns {
            for row in 0..<road.numberOfRows {
                road.setTileGroup(column == 2 ? dashedGroup : normalGroup, forColumn: column, row: row)
            }
        }
    }
}

extension GameScene: CBCentralManagerDelegate {
    @available(OSX 10.7, *)
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            NSLog("discovering device")
            central.scanForPeripherals(withServices: nil)
        default:
            print("not poweredOn, current state: \(central.state.rawValue)")
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        NSLog("Discovered peripheral, name = \(String(describing: peripheral.name))")
        peripheral.delegate = self
        if peripheral.name != nil && peripheral.name!.starts(with: "rasp")  {
            if peripherals.index(of: peripheral) == nil {
                peripherals.append(peripheral)
            }
            NSLog("will connect to \(peripheral.name!)")
            central.connect(peripheral, options: nil)
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("connected to \(peripheral.name!)")
        peripheral.discoverServices(nil)
    }
}

extension GameScene: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("discovered \(peripheral.services!)")
        guard let service = peripheral.services!.first(where: { (service: CBService) in service.uuid.uuidString.lowercased() == "fff0" }) else {
            peripheral.discoverServices(nil)
            return
        }
        
        NSLog("Discovered services in peripheral")
        peripheral.discoverCharacteristics(nil, for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard service.characteristics?.count == 4 else {
            peripheral.discoverCharacteristics(nil, for: service)
            return
        }
        if vehicles[peripheral] == nil {
            vehicles[peripheral] = Vehicle(direction: .up)
        }
        
        NSLog("Discovered characteristics in service")
        service.characteristics!.forEach { characteristic in
            peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let value = characteristic.value!
        let string = String(data: value, encoding: .utf8)!.trimmingCharacters(in: CharacterSet(charactersIn: "\r\0"))
        guard let _ = vehicles.keys.first(where: { pe in pe.name == peripheral.name }) else {
            NSLog("recived update, but nowhere to go")
            return
        }
        
        switch GameScene.characteristicsUUID[characteristic.uuid.uuidString.lowercased()]! {
        case "id":
            vehicles.values.filter({_ in true})[0].id = Int(string) ?? 0
        case "distance":
            vehicles.values.filter({_ in true})[0].frontSensorValue = Int(string) ?? 0
        case "speed":
            NSLog("updaing speed to \(string), \(Double(string))")
            vehicles.values.filter({_ in true})[0].speed = Double(string) ?? 0.0
        case "heading":
            NSLog("updaing heading to \(string), \(Double(string))")
            vehicles.values.filter({_ in true})[0].heading = Double(string) ?? 0
        default:
            break
        }
    }
}

extension Array where Element: AnyObject {
    func includes(_ value: Element) -> Bool {
        let found = self.index(where: { (element: Element) -> Bool in element === value })
        return found != nil
    }
}
