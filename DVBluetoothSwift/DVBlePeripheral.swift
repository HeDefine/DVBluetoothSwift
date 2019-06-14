//
//  DVBlePeripheral.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/6.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import UIKit
import CoreBluetooth

/// MARK: - 属性值
class DVBlePeripheral: NSObject {
    /// 协议
    weak open var delegate: DVBlePeripheralDelegate?

    /* ********* 原始数据 ********* */
    ///外设
    open var peripheral: CBPeripheral
    ///蓝牙外设的信号(0:设备离开可连接的范围)
    open var RSSI : Int
    ///广播值
    open var advertisementData: [String : Any]
    
    /* ********* 封装后的数据 ********* */
    /// 外设名
    open var name: String {
        return peripheral.name ?? ""
    }
    /// 外设uuid
    open var identifier: String {
        return peripheral.identifier.uuidString
    }
    /// 当前状态
    open var state: DVBlePeripheralState {
        switch peripheral.state {
        case .connected:
            return .connected
        default:
            return .unConnected
        }
    }
    /// 是否已经连接
    open var isConnected: Bool {
        return state == .connected
    }
    
    /**
     ********** 广播值解析后的值 *********
     *这些值在扫描的时候就可以获取到, 所以筛选扫描到的设备的时候也可以根据这些值来判断
     */
    open var localName: NSString? {
        return advertisementData[CBAdvertisementDataLocalNameKey] as? NSString
    }
    open var manufacturerData: NSData? {
        return advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData
    }
    open var serviceData: [CBUUID : NSData]? {
        return advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID : NSData]
    }
    ///服务UUID数组   这个值和 services 区分开。这个值在扫描的时候就可以获取到的广播值
    open var serviceUUIDs: [CBUUID]? {
        return advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }
    open var overflowServiceUUIDs: [CBUUID]? {
        return advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
    }
    open var txPowerLevel: NSNumber? {
        return advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
    }
    ///是否可连接。 区分 isConnected
    open var isConnectable: NSNumber? {
        return advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
    }
    open var solicitedServiceUUIDs: [CBUUID]? {
        return advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
    }
    
    /* ********* 逻辑值,用于设置的值 ********* */
    /**
     当前尝连连接的次数
     连接成功时 该值会归零。 连接失败时 会尝试重连，并加1
     非正常断开连接时都会进行重连, 重连次数不会超过 最大重连次数(在DVBleOptions.h中设置)
     当超过最大的自动重连次数后，会提示连接失败。
     */
    open var reconnectTimes = 0
    /// 所有的服务值
    open var allServices: [CBService] {
        return [CBService](self.mServices.values)
    }
    /// 所有的特征值
    open var allCharacteristics: [CBCharacteristic] {
        return [CBCharacteristic](self.mCharacteristics.values)
    }
    
    /* ********* 私有值 ********* */
    /// 服务值字典
    private var mServices = [String : CBService]()
    /// 特征值字典
    private var mCharacteristics = [String : CBCharacteristic]()
    
    /// 查找特征值 计时器
    private var mfindCharacteristicsTimer: Timer?
    /// 写数据 计时器
    private var mWriteTimer: Timer?
    /// 读取数据 计时器
    private var mReadTimer: Timer?
    
    /// 初始化方法
    ///
    /// - Parameters:
    ///   - peri: 外设
    ///   - RSSI: 信号值
    ///   - adData: 广播值
    init(withPeripheral peri:CBPeripheral,rssi RSSI:Int = 0 ,advertisementData adData:[String : Any] = [String : Any]()) {
        self.peripheral = peri
        self.RSSI = RSSI
        self.advertisementData = adData
        super.init()
        
        self.peripheral.delegate = self
    }
}


// MARK: - Override 复写
extension DVBlePeripheral: Comparable {
    
    /// 比较两个值的大小
    /// 先通过信号值比较, 再通过姓名比较
    /// - Parameters:
    ///   - lhs: 第一个值
    ///   - rhs: 第二个值
    /// - Returns: 返回结果
    static func < (lhs: DVBlePeripheral, rhs: DVBlePeripheral) -> Bool {
        if lhs.RSSI == rhs.RSSI {
            return lhs.name < rhs.name
        }
        return lhs.RSSI < rhs.RSSI
    }
    
    
    /// 比较两个值是否是同一个值
    /// 只要两个ID相同就是同一个设备
    /// - Parameters:
    ///   - lhs: 第一个值
    ///   - rhs: 第二个值
    /// - Returns: 返回是否是同一个值
    static func == (lhs: DVBlePeripheral, rhs: DVBlePeripheral) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? DVBlePeripheral {
            if other == self {
                return true
            } else {
                return self.identifier == other.identifier
            }
        } else {
            return false
        }
    }
    
    override var hash: Int {
        return self.identifier.hashValue
    }
}

// MARK: - 公共方法
extension DVBlePeripheral {
    /// 重置所有的状态(重连次数和信号量)
    func reset() {
        self.reconnectTimes = 0
        self.resetRSSI()
    }
    
    /// 重置 RSSI 信号量
    func resetRSSI() {
        if self.state == .connected {
            //如果是已经连接的状态, 设备回去读取RSSI
            self.peripheral.readRSSI()
        } else {
            //如果未连接, 重置为0
            self.RSSI = 0
        }
    }
    // MARK: 发现服务和特征值
    /// 发现所有的特征值
    func discoverAllServicesAndCharacteristic() {
        self.mServices.removeAll()
        self.mCharacteristics.removeAll()
        self.peripheral .discoverServices(nil)
    }
    
    // MARK: 筛选数据
    /// 查找是否有服务或特征值.
    /// 两个值都存在的情况下, 会一起查询
    /// - Parameters:
    ///   - serviceUUID: 服务ID
    ///   - characteristicUUID: 特征值ID
    /// - Returns: 是否含有该服务或者该特征值
    func filter(serviceUUID:String = "", characteristicUUIDs:[String] = [String]()) -> Bool {
        //如果都没有的话, 返回不匹配
        if serviceUUID == "" && characteristicUUIDs.count == 0 {
            return false
        }
        //如果有服务值, 没有特征值
        if serviceUUID != "" && characteristicUUIDs.count == 0 {
            return self.mServices[serviceUUID] != nil
        }
        //如果没有服务值, 有特征值
        if serviceUUID == "" && characteristicUUIDs.count > 0 {
            let needSet = Set.init(characteristicUUIDs)
            let uuids = [String](self.mCharacteristics.keys)
            let allSet = Set.init(uuids)
            return needSet.isSubset(of: allSet)
        }
        //如果有服务值 也有特征值
        if serviceUUID != "" && characteristicUUIDs.count > 0 {
            if let chars = self.mServices[serviceUUID]?.characteristics{
                let needSet = Set.init(characteristicUUIDs)
                var allSet = Set.init([String]())
                for characteristic in chars {
                    allSet.insert(characteristic.uuid.uuidString)
                }
                return needSet.isSubset(of: allSet)
            } else {
                return false
            }
        }
        return false
    }
    // MARK: 写入数据
    /// 写入数据
    ///
    /// - Parameters:
    ///   - data: 写数据
    ///   - uuid: 特征值
    ///   - interval: 超时
    func writeData(data:Data?, onCharacteristicUUID uuid:String, timeout interval:TimeInterval = 3) {
        /// 排除外设没有连接
        guard self.state == .connected else {
            self.delegate?.peripheral(self,
                                      didWriteDataOnCharacteristicUUID: uuid,
                                      result: .unConnected)
            return
        }
        /// 排除没有要写入的数据
        guard let data = data else {
            self.delegate?.peripheral(self,
                                      didWriteDataOnCharacteristicUUID: uuid,
                                      result: .noData)
            return
        }
        /// 排除没有特征值
        guard let characteristic = self.mCharacteristics[uuid] else {
            self.delegate?.peripheral(self,
                                      didWriteDataOnCharacteristicUUID: uuid,
                                      result: .noCharacteristic)
            return
        }
        /// 写入数据
        self.peripheral.writeValue(data, for: characteristic, type: .withResponse)
        /// 开启超时
        self.mWriteTimer?.invalidate()
        self.mWriteTimer = Timer.scheduledTimer(timeInterval: interval,
                                                target: self,
                                                selector: #selector(writeTimeout(_:)),
                                                userInfo: uuid,
                                                repeats: false)
    }
    // MARK: 读取数据
    /// 读取数据
    ///
    /// - Parameters:
    ///   - characteristicUUID: 特征值
    ///   - interval: 超时时间
    func readData(characteristicUUID uuid:String, timeout interval:TimeInterval = 3) {
        /// 排除外设没有连接
        guard self.state == .connected else {
            self.delegate?.peripheral(self, didReadData: nil, onCharacteristic: uuid, result: .unConnected)
            return
        }
        /// 排除没有特征值
        guard let characteristic = self.mCharacteristics[uuid] else {
            self.delegate?.peripheral(self,
                                      didWriteDataOnCharacteristicUUID: uuid,
                                      result: .noCharacteristic)
            return
        }
        /// 读取数据
        self.peripheral.readValue(for: characteristic)
        /// 开始读取超时
        self.mReadTimer?.invalidate()
        self.mReadTimer = Timer.scheduledTimer(timeInterval: interval,
                                               target: self,
                                               selector: #selector(readTimeout(_:)),
                                               userInfo: uuid,
                                               repeats: false)
    }
    
    // MARK: 监听数据
    func setNotifyValue(_ enable:Bool, characteristicUUID uuid:String) {
        /// 排除外设没有连接
        guard self.state == .connected else {
            self.delegate?.peripheral(self, didReadData: nil, onCharacteristic: uuid, result: .unConnected)
            return
        }
        /// 排除没有特征值
        guard let characteristic = self.mCharacteristics[uuid] else {
            self.delegate?.peripheral(self,
                                      didWriteDataOnCharacteristicUUID: uuid,
                                      result: .noCharacteristic)
            return
        }
        self.peripheral.setNotifyValue(enable, for: characteristic)
    }
}

// MARK: - 私有方法
private extension DVBlePeripheral {
    /// 搜索特征值超时
    @objc func discoverTimeout() {
        self.delegate?.peripheral(self, didFinishDiscoverServicesAndCharacteristics: false)
    }
    
    /// 写入超时
    @objc func writeTimeout(_ timer: Timer) {
        let uuidStr = timer.userInfo as? String ?? ""
        self.delegate?.peripheral(self, didWriteDataOnCharacteristicUUID: uuidStr, result: .timeout)
    }
    
    /// 读取超时
    @objc func readTimeout(_ timer: Timer) {
        let uuidStr = timer.userInfo as? String ?? ""
        self.delegate?.peripheral(self, didReadData: nil, onCharacteristic: uuidStr, result: .timeout)
    }
}

// MARK: - 外设的代理
extension DVBlePeripheral: CBPeripheralDelegate {
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        self.RSSI = RSSI.intValue
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            self.delegate?.peripheral(self, didFinishDiscoverServicesAndCharacteristics: false)
            return
        }
        guard let services = peripheral.services else {
            self.delegate?.peripheral(self, didFinishDiscoverServicesAndCharacteristics: false)
            return
        }
        //遍历所有的服务, 查找服务中特征值
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        self.mfindCharacteristicsTimer?.invalidate()
        guard error == nil else {
            self.delegate?.peripheral(self, didFinishDiscoverServicesAndCharacteristics: false)
            return
        }
        //赋值到mService字典, 方便寻找
        self.mServices[service.uuid.uuidString] = service
        //赋值到mCharacteristics字典, 方便寻找
        if let characteristics = service.characteristics {
            for characteristic in  characteristics{
                self.mCharacteristics[characteristic.uuid.uuidString] = characteristic
            }
        }
        //判断是否已经全部搜索完成
        if self.mServices.count == peripheral.services?.count {
            //已经发现完所有的特征值, 结束搜索
            self.delegate?.peripheral(self, didFinishDiscoverServicesAndCharacteristics: true)
        } else {
            //未发现所有的特征值, 开启新的超时操作。(如果不成功的话, 这个时间会影响连接成功的时间)
            self.mfindCharacteristicsTimer = Timer.scheduledTimer(timeInterval: 3,
                                                                  target: self,
                                                                  selector: #selector(discoverTimeout),
                                                                  userInfo: nil,
                                                                  repeats: false)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        self.mWriteTimer?.invalidate()
        if error != nil {
            print("写入失败: \(String(describing: error))")
        }
        self.delegate?.peripheral(self,
                                  didWriteDataOnCharacteristicUUID: characteristic.uuid.uuidString,
                                  result: error == nil ? .success : .error)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        self.mReadTimer?.invalidate()
        if error != nil {
            print("读取失败: \(String(describing: error))")
        }
        self.delegate?.peripheral(self,
                                  didReadData: characteristic.value,
                                  onCharacteristic: characteristic.uuid.uuidString,
                                  result: error == nil ? .success : .error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        self.delegate?.peripheral(self,
                                  didReadData: nil,
                                  onCharacteristic: characteristic.uuid.uuidString,
                                  result: error == nil ? .notifySuccess : .notifyFailed)
        
    }
    
}
