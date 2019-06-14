//
//  BedManager.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/13.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import UIKit

let UUIDWriteDataService = "FFE5"
let UUIDWriteDataCharateristic = "FFE9"
let UUIDReadDataService = "FFE0"
let UUIDReadDataCharateristic = "FFE4"
let UUIDInfoService = "FF90"
let UUIDDeviceNameCharateristic = "FF91"

class BedManager: DVBleManager {
    public static let shared = BedManager()
    
    override init() {
        super.init()
        configVariable()
        configBlock()
    }
    
    func configVariable() {
        self.enableReconnect = true
        self.reconnectDuration = 5
        self.maxReconnectTimes = 5
        self.maxConnectedPeripheralsCount = 1
    }
    
    func configBlock() {
        self.setScannedPeriFilterBlock { (peri) -> Bool in
            return peri.name.count > 0
        }
        
        self.setConnectPeriFilterBlock { (peri) -> Bool in
            let filter1 = peri.filter(serviceUUID: UUIDWriteDataService,
                                      characteristicUUIDs: [UUIDWriteDataCharateristic])
            
            let filter2 = peri.filter(serviceUUID: UUIDReadDataService,
                                      characteristicUUIDs: [UUIDReadDataCharateristic])
            
            return filter1 && filter2
        }
        
        self.setNotifyPeriCharacteristicBlock { (peri) in
            peri.setNotifyValue(true, characteristicUUID: UUIDReadDataCharateristic)
        }
        
        self.setWriteDataCallbackBlock { (peri, result, uuidStr) in
            if result == .success && uuidStr == UUIDWriteDataCharateristic {
                //写入成功
            }
        }
        
        self.setReadDataCallbackBlock { [weak self](peri, result, uuidStr, data) in
            if result == .success && uuidStr == UUIDReadDataCharateristic {
                //读取成功
                if let data = data {
                    self?.handle(data: data)
                }
            }
        }
    }
}

// MARK: - 公共方法
extension BedManager {
    func headup() {
        self.write(cmd: "FFFFFFFF")
    }
}
// MARK: - 私有方法
extension BedManager {
    func write(cmd str:String) {
        guard let peri = self.connectedPeripherals.first else {
            print("没有连接的设备")
            return
        }
        let data = HexData.data(from: str)
        self.writeData(peripheral: peri, characteristicUUID: UUIDWriteDataCharateristic, data: data)
    }
    
    func handle(data:Data) {
        
    }
}

