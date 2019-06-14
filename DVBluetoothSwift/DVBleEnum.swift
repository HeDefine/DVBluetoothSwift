//
//  DVBleEnum.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/6.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import UIKit

//MARK: - Manager相关
/// 蓝牙状态 枚举
enum DVBleManagerState:Int {
    /// 当前蓝牙未授权,需要到系统设置中允许蓝牙通信
    case unAvaiable
    /// 当前蓝牙已经开启
    case powerOn
    /// 当前蓝牙已经关闭
    case powerOff
}

/// 蓝牙搜索状态 枚举
enum DVBleManagerScanState:Int {
    /// 开始扫描设备
    case begin
    /// 扫描设备中
    case scanning
    /// 扫描设备结束
    case end
}

/// 外设的连接状态
enum DVBleManagerConnectState:Int {
    /// 开始连接
    case begin
    /// 连接成功,开始搜索特征值
    case discovering
    /// 筛选特征值
    case filtering
    /// 连接成功
    case success
}

/// 重连状态 枚举
enum DVBleManagerReconnectState:Int {
    /// 开始重连
    case begin
    /// 重连中
    case reconnecting
    ///重连结束
    case end
}

/// 连接失败原因 枚举
enum DVBleManagerConnectError {
    /// 没有错误
    case none
    /// 连接超时
    case timeout
    /// 连接失败并重连也失败的
    case conenectFailed
    /// 连接失败,因为不是对应的设备(未找到对应的服务值&特征值)
    case notPaired
}


//MARK: - Peripheral外设相关
/// 外设当前状态 枚举
enum DVBlePeripheralState {
    /// 外设未连接
    case unConnected
    /// 外设已连接
    case connected
}

/// 外设写入数据
enum DVBlePeripheralWriteState {
    /// 外设未连接, 写入失败
    case unConnected
    /// 没有找到指定的特征值, 写入失败
    case noCharacteristic
    /// 没有写入的数据，写入失败
    case noData
    /// 写入超时
    case timeout
    /// 写入成功
    case success
    /// 写入失败 系统原因
    case error
}

/// 外设读取数据
enum DVBlePeripheralReadState {
    /// 外设未连接
    case unConnected
    /// 没有找到指定的特征值, 写入失败
    case noCharacteristic
    /// 外设读取超时
    case timeout
    /// 外设读取成功
    case success
    /// 外设读取失败
    case error
    /// 外设订阅失败
    case notifyFailed
    /// 外设订阅成功
    case notifySuccess
}
