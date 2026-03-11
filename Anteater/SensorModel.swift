//
//  SensorModel.swift
//  Anteater
//
//  Created by Justin Anderson on 8/1/16.
//  Copyright © 2016 MIT. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

protocol SensorModelDelegate {
    func sensorModel(_ model: SensorModel, didChangeActiveHill hill: Hill?)
    func sensorModel(_ model: SensorModel, didReceiveReadings readings: [Reading], forHill hill: Hill?)
}

extension Notification.Name {
    public static let SensorModelActiveHillChanged = Notification.Name(rawValue: "SensorModelActiveHillChangedNotification")
    public static let SensorModelReadingsChanged = Notification.Name(rawValue: "SensorModelHillReadingsChangedNotification")
}

enum ReadingType: Int {
    case Unknown = -1
    case Humidity = 2
    case Temperature = 1
    case Error = 0
}

struct Reading {
    let type: ReadingType
    let value: Double
    let date: Date = Date()
    let sensorId: String?
    
    func toJson() -> [String: Any] {
        return [
            "value": self.value,
            "type": self.type.rawValue,
            "timestamp": self.date.timeIntervalSince1970,
            "userid": UIDevice.current.identifierForVendor?.uuidString ?? "NONE",
            "sensorid": sensorId ?? "NONE"
        ]
    }
}

extension Reading: CustomStringConvertible {
    var description: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        guard let numberString = formatter.string(from: NSNumber(value: self.value)) else {
            print("Double \"\(value)\" couldn't be formatted by NumberFormatter")
            return "NaN"
        }
        switch type {
        case .Temperature:
            return "\(numberString)°F"
        case .Humidity:
            return "\(numberString)%"
        default:
            return "\(type)"
        }
    }
}

struct Hill {
    var readings: [Reading]
    var name: String
    
    init(name: String) {
        readings = []
        self.name = name
    }
}

extension Hill: CustomStringConvertible, Hashable, Equatable {
    var description: String {
        return name
    }
    
    var hashValue: Int {
        return name.hashValue
    }
}

func ==(lhs: Hill, rhs: Hill) -> Bool {
    return lhs.name == rhs.name
}

class SensorModel: BLEDelegate {
    var bleManager = BLE()
    static let kBLE_SCAN_TIMEOUT = 10000.0
    
    static let shared = SensorModel()

    var delegate: SensorModelDelegate?
    var sensorReadings: [ReadingType: [Reading]] = [.Humidity: [], .Temperature: []]
    var activeHill: Hill?
    var peripheral: CBPeripheral
    
    func ble(didUpdateState state: BLEState) {
        print("[DEBUG] didUpdateState called with state: \(state)")
        if state == .poweredOn{
            bleManager.startScanning(timeout: SensorModel.kBLE_SCAN_TIMEOUT)
        }
        
    }
    
    func ble(didDiscoverPeripheral peripheral: CBPeripheral) {
        print("[DEBUG] didDiscoverPeripheral called, found: \(peripheral.name ?? "unknown")")
        bleManager.connectToPeripheral(peripheral)
        
    }
    
    func ble(didConnectToPeripheral peripheral: CBPeripheral) {
        print("[DEBUG] didConnectToPeripheral called, connected to: \(peripheral.name ?? "unknown")")
        var activePeripheral = peripheral
        self.activeHill = Hill(name: peripheral.name ?? "Unknown Hill")
        delegate?.sensorModel(self, didChangeActiveHill: self.activeHill)

        
    }
    
    func ble(didDisconnectFromPeripheral peripheral: CBPeripheral) {
        print("[DEBUG] didDisconnectFromPeripheral called")

        
    }
    
    func ble(_ peripheral: CBPeripheral, didReceiveData data: Data?) {
        
    }
    
    
    
    
    init() {
        bleManager.delegate = self
        delegate?.sensorModel(<#T##model: SensorModel##SensorModel#>, didChangeActiveHill: <#T##Hill?#>)
        
        
    }
}
