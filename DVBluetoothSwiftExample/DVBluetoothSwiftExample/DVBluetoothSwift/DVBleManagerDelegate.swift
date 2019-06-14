//
//  DVBleManagerDelegate.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/6.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import Foundation

protocol DVBleManagerDelegate : NSObjectProtocol{
    // MARK: - 状态发生改变
    /// 蓝牙状态发生改变
    ///
    /// - Parameter state: 当前蓝牙的状态
    func manager(_ manager:DVBleManager, didBluetoothStateChanged state:DVBleManagerState)

    //MARK: - 连接反馈
    /// 扫描设备
    ///
    /// - Parameters:
    ///   - newPeripheral: 新的设备
    ///   - state: 当前扫描的状态
    func manager(_ manager:DVBleManager, didScanPeripheral newPeripheral:DVBlePeripheral?, state:DVBleManagerScanState)
    
    /// 已连接到外设
    ///
    /// - Parameters:
    ///   - peripheral: 外设
    ///   - state: 连接状态
    func manager(_ manager:DVBleManager, didConnectToPeripheral peripheral:DVBlePeripheral, state:DVBleManagerConnectState)
    
    /// 连接外设失败
    ///
    /// - Parameters:
    ///   - peripheral: 外设
    ///   - error: 失败理由
    func manager(_ manager:DVBleManager, didConnectFailedToPeripheral peripheral:DVBlePeripheral, error:DVBleManagerConnectError)
    
    /// 外设断开连接
    ///
    /// - Parameters:
    ///   - peripheral: 外设
    ///   - isActive: 是否是主动断开连接的
    func manager(_ manager:DVBleManager, didDisConnectToPeripheral peripheral:DVBlePeripheral, isActive:Bool)
    
    /// 外设重连
    ///
    /// - Parameters:
    ///   - peripherals: 需要重连的设备列表
    ///   - state: 重连状态
    func manager(_ manager:DVBleManager, didReconnectToPeripherals peripherals:[DVBlePeripheral]?, state:DVBleManagerReconnectState)
}
