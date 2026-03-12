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
    var activePeripheral: CBPeripheral?
    
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
        self.activePeripheral = peripheral
        self.activeHill = Hill(name: peripheral.name ?? "Unknown Hill")
        delegate?.sensorModel(self, didChangeActiveHill: self.activeHill)

        
    }
    
    func ble(didDisconnectFromPeripheral peripheral: CBPeripheral) {
        print("[DEBUG] didDisconnectFromPeripheral called")
        // Check if the disconnected peripheral is our active one
        if peripheral == self.activePeripheral {
            print("[DEBUG] Active peripheral disconnected, resetting activeHill")
            
            // Reset active hill to nil
            self.activeHill = nil
            
            // Reset active peripheral to nil
            self.activePeripheral = nil
            
            // Notify delegate that there's no active hill anymore (on main thread)
            DispatchQueue.main.async {
                self.delegate?.sensorModel(self, didChangeActiveHill: nil)
            }
            
            // Start scanning again to look for new connections
            bleManager.startScanning(timeout: SensorModel.kBLE_SCAN_TIMEOUT)
            print("[DEBUG] Started scanning for new peripherals")
        }

        
    }
    
    func ble(_ peripheral: CBPeripheral, didReceiveData data: Data?) {
        print("[DEBUG] didRecieveData called")
        
        // convert a non-nil Data optional into a String
        let str = String(data: data!, encoding: String.Encoding.ascii)!
        // get a substring that excludes the first and last characters
        let substring = str[str.index(after: str.startIndex)..<str.index(before: str.endIndex)]
        
        // convert a Substring to a Double
        let value = Double(substring)!
        // now use them to build the Reading
        print("[DEBUG]", value)
        let type = str.first
        let readingType: ReadingType = (type == "T") ? .Temperature : .Humidity
        let reading = Reading(type: readingType, value: value, sensorId: peripheral.name)
        
        activeHill?.readings.append(reading)
        delegate?.sensorModel(self, didReceiveReadings: activeHill!.readings, forHill: activeHill)

        
        
    }
    
    
    
    
    init() {
        bleManager.delegate = self
        
        
    }
}
