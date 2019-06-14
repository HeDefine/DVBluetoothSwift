//
//  DVBlePeripheralDelegate.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/10.
//  Copyright © 2019 Devine.cn. All rights reserved.
//
import Foundation

/// 蓝牙外设协议
protocol DVBlePeripheralDelegate: NSObjectProtocol {

    /// 发现特征值回调
    ///
    /// - Parameters:
    ///   - peripheral: 外设
    ///   - didFinishDiscoverServicesAndCharacteristics: 是否发现特征值
    func peripheral(_ peripheral:DVBlePeripheral, didFinishDiscoverServicesAndCharacteristics isSuccess: Bool)
    
    /// 写入特征值回调
    ///
    /// - Parameters:
    ///   - peripheral: 外设
    ///   - characteristicUUID: 特征值
    ///   - result: 错误结果
    func peripheral(_ peripheral:DVBlePeripheral, didWriteDataOnCharacteristicUUID characteristicUUID:String, result:DVBlePeripheralWriteState )
    
    /// 读取特征值回调
    ///
    /// - Parameters:
    ///   - peripheral: 外设
    ///   - data: 读取到的数据
    ///   - onCharacteristic: 特征值
    ///   - result: 错误结果
    func peripheral(_ peripheral:DVBlePeripheral, didReadData data:Data?, onCharacteristic: String, result: DVBlePeripheralReadState)
}
