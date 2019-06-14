//
//  DVBleManager.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/6.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import CoreBluetooth

typealias ScannedPeripheralsFilterBlock = (_ peripheral:DVBlePeripheral) -> Bool
typealias ConnectedPeripheralsFilterBlock = (_ peripheral:DVBlePeripheral) -> Bool
typealias NotifyCharacteristicValueBlock = (_ peripheral:DVBlePeripheral) -> Void
typealias WriteDataCallbackBlock = (_ peripheral:DVBlePeripheral,_ result:DVBlePeripheralWriteState,_ uuidStr:String) -> Void
typealias ReadDataCallbackBlock = (_ peripheral:DVBlePeripheral,_ result:DVBlePeripheralReadState,_ uuidStr:String, _ data:Data?) -> Void

class DVBleManager: NSObject {
    /************************
     *       公共属性        *
     ************************/
    // MARK: 公共属性
    ///协议
    open weak var delegate: DVBleManagerDelegate?
    ///当前蓝牙状态
    open var state: DVBleManagerState {
        switch self.manager.state {
        case .poweredOn:
            return .powerOn
        case .poweredOff:
            return .powerOff
        default:
            return .unAvaiable
        }
    }
    /**  连接相关   **/
    ///最大可连接的设备数量, 默认是1 (最大连接数是8 ,如果再次连接时，会断开多余的设备，根据先连先断的原则)
    open var maxConnectedPeripheralsCount: Int = 1 {
        willSet {
            assert(newValue >= 1, "可以连接的外设数量至少1个")
            assert(newValue <= 8, "可以连接的外设数量最多8个")
        }
    }
    ///是否允许自动重连, 默认打开重连
    open var enableReconnect: Bool = true
    ///自动重连次数, 默认重连次数时3. ( -1 表示无限重连 ***谨慎开启, 会有性能损耗)
    open var maxReconnectTimes: Int = 3
    ///重连间隔, 默认是 10s
    open var reconnectDuration: TimeInterval = 10
    ///是否允许打开App时自动重连, 默认是打开的
    open var enableAutoReconnectLastPeripherals: Bool = true
    ///需要搜索所有的服务值和特征值,默认是YES
    open var needDiscoverAllServicesAndCharacteristics: Bool = true
    ///当前是否在重连(对外只读)
    private(set) var isReconnecting: Bool = false

    ///扫描到的设备过滤
    open var scannedPeriFilterBlock: ScannedPeripheralsFilterBlock?
    ///连接到的设备过滤
    open var connectPeriFilterBlock: ConnectedPeripheralsFilterBlock?
    ///监听特征值
    open var notifyPeriCharacteristicBlock: NotifyCharacteristicValueBlock?
    /// 写入回调
    open var writeDataCallbackBlock: WriteDataCallbackBlock?
    /// 读取回调
    open var readDataCallbackBlock: ReadDataCallbackBlock?
    
    ///从第一次扫描开始，每次扫描就保存下所有的设备
    open var allPeripherals: [DVBlePeripheral] {
        return [DVBlePeripheral](self.mAllPeripheralDictionary.values)
    }
    ///扫描到的设备
    open var scannedPeripherals: [DVBlePeripheral] {
        var tempArr = [DVBlePeripheral]()
        for uuid in self.mScannedPeripheralUUIDs {
            if let peripheral = self.mAllPeripheralDictionary[uuid] {
                if peripheral.state != .connected {
                    tempArr.append(peripheral)
                }
            }
        }
        return tempArr
    }
    ///连接中的设备
    open var connectedPeripherals: [DVBlePeripheral] {
        var tempArr = [DVBlePeripheral]()
        var unConnectedUUIDs = [String]()
        for uuidStr in self.mConnectPeripheralUUIDs {
            if let peripheral = self.mAllPeripheralDictionary[uuidStr] {
                if peripheral.state == .connected {
                    tempArr.append(peripheral)
                } else {
                    unConnectedUUIDs.append(uuidStr)
                }
            } else {
                unConnectedUUIDs.append(uuidStr)
            }
        }
        //清掉未连接的
        for uuidStr in unConnectedUUIDs {
            if let idx = self.mConnectPeripheralUUIDs.firstIndex(of: uuidStr) {
                self.mConnectPeripheralUUIDs.remove(at: idx)
            }
        }
        return tempArr
    }
    ///需要重连的设备
    public var reconnectPeripherals: [DVBlePeripheral] {
        var tempArr = [DVBlePeripheral]()
        for uuidStr in self.mReconnectPeripheralUUIDs {
            if let peripheral = self.mAllPeripheralDictionary[uuidStr] {
                tempArr.append(peripheral)
            }
        }
        return tempArr
    }
    
    // MARK:  私有属性
    /************************
     *       私有属性        *
     ************************/
    /// 蓝牙总manager
    private lazy var manager: CBCentralManager = {
        var options = [String : Any]()
        options[CBCentralManagerOptionShowPowerAlertKey] = true
        if let backgroundModes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? NSArray {
            if backgroundModes.contains("bluetooth-central") {
                //只有开启了后台才会用到这个重新连接的方法
                options[CBCentralManagerOptionRestoreIdentifierKey] = "dv.bluetooth.restoreId"
            }
        }
        let manager = CBCentralManager.init(delegate: self,
                                            queue: DispatchQueue.main,
                                            options: options)
        
        return manager
    }()
    /// 临时的最后连接的设备
    private var mTempLastConnectedPeripheralUUIDs = [String]()
    /// 最后一次连接的设备列表
    private var mLastConnectedPeripheralUUIDs:[String] {
        set {
            UserDefaults.standard.set(newValue, forKey: "kDVBleManagerLastConnectedPeripheralUUIDsKey")
        }
        get {
            return UserDefaults.standard.value(forKey: "kDVBleManagerLastConnectedPeripheralUUIDsKey") as? Array ?? [String]()
        }
    }
    ///从第一次扫描开始，每次扫描就保存下所有的设备
    private var mAllPeripheralDictionary = [String : DVBlePeripheral]()
    ///当次扫描到的设备UUID
    private var mScannedPeripheralUUIDs = [String]()
    ///已经连接的设备UUID列表
    private var mConnectPeripheralUUIDs = [String]()
    ///需要重连的设备UUID列表。这个数组一般是包括用来打开蓝牙开关的时候，需要重连的设备
    private var mReconnectPeripheralUUIDs = [String]()
    ///连接超时  计时器
    private var mConnectTimer: Timer?
    ///重连间隔  计时器
    private var mReconnectTimer: Timer?
    
    // MARK: - 初始化方法
    override init() {
        super.init()
        self.manager.delegate = self
        self.mTempLastConnectedPeripheralUUIDs = self.mLastConnectedPeripheralUUIDs
    }
}
// MARK: - 公共方法
extension DVBleManager {
    //MARK: 单例
    /// 单例
    public static let instance = DVBleManager()
    
    //MARK: 设置块
    /// 设置扫描筛选
    func setScannedPeriFilterBlock(_ block: ScannedPeripheralsFilterBlock?) {
        self.scannedPeriFilterBlock = block
    }
    /// 设置连接筛选
    func setConnectPeriFilterBlock(_ block: ConnectedPeripheralsFilterBlock?) {
        self.connectPeriFilterBlock = block
    }
    /// 设置监听
    func setNotifyPeriCharacteristicBlock(_ block: NotifyCharacteristicValueBlock?) {
        self.notifyPeriCharacteristicBlock = block
    }
    /// 设置写入回调
    func setWriteDataCallbackBlock(_ block:WriteDataCallbackBlock?) {
        self.writeDataCallbackBlock = block
    }
    /// 设置读取回调
    func setReadDataCallbackBlock(_ block:ReadDataCallbackBlock?) {
        self.readDataCallbackBlock = block
    }
    
    
    // MARK: 扫描设备
    /// 扫描设备, 默认是扫描 10s
    /// - Parameters:
    ///   - seconds: 扫描时间, 如果扫描时间 < 0, 会一直扫描(不建议)
    ///   - filterBlock: 筛选新设备
    ///
    /// - # 为什么不建议一直扫描? / 为什么默认扫描是10s?
    ///   因为苹果官方不建议一直扫描,过于消耗电量等,所以应当及时停止扫描.
    /// - # 设置 filterBlock 有什么用?
    ///   可以对扫描到外设进行筛选, 筛选掉不符合规则的外设
    func scanPeripheral(for seconds:TimeInterval = 10,
                        filterBlock:ScannedPeripheralsFilterBlock? = nil) {
        //排除蓝牙未打开的情况
        guard self.state == .powerOn else {
            self.delegate?.manager(self, didBluetoothStateChanged: self.state)
            return
        }
        //设置筛选块
        if let filterBlock = filterBlock {
            self.scannedPeriFilterBlock = filterBlock
        }
        //如果当前设备原本就在扫描, 先停止原先的扫描, 新开一个扫描
        if self.manager.isScanning {
            self.manager.stopScan()
        }
        //清空数据.并重置信号量
        self.mScannedPeripheralUUIDs.removeAll()
        self.mAllPeripheralDictionary.forEach { (_, value) in
            value.resetRSSI()
        }
        //回调开始扫描.(也是为了告诉对方数据已经清空了,防止还在刷新列表的时候, 数据突然没了会发生错误)
        self.delegate?.manager(self, didScanPeripheral: nil, state: .begin)
        self.manager.scanForPeripherals(withServices: nil, options: nil)
        
        //开启定时操作
        Thread.cancelPreviousPerformRequests(withTarget: self, selector: #selector(scanPeripheralTimeout), object: nil)
        if seconds > 0 {
            self.perform(#selector(scanPeripheralTimeout), with: nil, afterDelay: seconds)
        }
    }
    
    /// 停止扫描设备
    func stopScanPeripheral(){
        if self.manager.isScanning {
            self.manager.stopScan()
        }
        self.delegate?.manager(self, didScanPeripheral: nil, state: .end)
    }
    
    //MARK: 连接设备
    /// 连接最后一次连接的设备, 一般是App打开时会用到
    func connectToLastConnectedPeripherals(){
        self.mTempLastConnectedPeripheralUUIDs = self.mLastConnectedPeripheralUUIDs
        self.enableAutoReconnectLastPeripherals = true
        scanPeripheral()
    }
    
    /// 连接外设
    /// 优先通过[peripheral]连接, 如果为空的话, 通过UUID来连接)
    /// - Parameters:
    ///   - peri: 外设
    ///   - interval: 超时时间
    ///   - filterBlock: 筛选特征值, 如果没有设置needDiscoverAllServicesAndCharacteristics, 无效操作
    func connect(to peri:DVBlePeripheral,
                 timeout interval:TimeInterval = 10,
                 filterBlock:ConnectedPeripheralsFilterBlock? = nil) {
        //排除蓝牙未打开的情况
        guard self.state == .powerOn else {
            self.delegate?.manager(self, didBluetoothStateChanged: self.state)
            return
        }
        //设置筛选条件
        if let block = filterBlock {
            self.connectPeriFilterBlock = block
        }
        //停止扫描
        if self.manager.isScanning {
            stopScanPeripheral()
        }
        //主动连接外设的时候, 会停止原来所有的重连
        cancelReconnect()
        //判断是否超过最大可以连接数量
        if self.mConnectPeripheralUUIDs.count >= self.maxConnectedPeripheralsCount {
            if let uuidStr = self.mConnectPeripheralUUIDs.first {
                if let tempPeri = self.mAllPeripheralDictionary[uuidStr] {
                    //断开已经连接的设备。 先连接的先断开
                    print("外设(\(tempPeri.name))......即将断开连接: 超过最大可连接的设备数")
                    self .disConnect(to: tempPeri)
                } else {
                    //保存到内存中
                    self.mConnectPeripheralUUIDs.removeFirst()
                    self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs
                }
            }
        }
        //连接外设
        print("外设(\(peri.name))......开始连接")
        self.manager.connect(peri.peripheral, options: nil)
        //回调开始连接
        self.delegate?.manager(self, didConnectToPeripheral: peri, state: .begin)
        
        //连接超时
        self.mConnectTimer?.invalidate()
        self.mConnectTimer = Timer.scheduledTimer(timeInterval: interval,
                                                  target: self,
                                                  selector: #selector(connectTimeout(_:)),
                                                  userInfo: peri,
                                                  repeats: false)
    }
    
    /// 断开连接
    /// 优先通过[peripheral]断开连接, 如果为空的话, 通过UUID来断开连接)
    /// - Parameters:
    ///   - peri: 外设
    func disConnect(to peri:DVBlePeripheral) {
        self.manager.cancelPeripheralConnection(peri.peripheral)
    }
    
    //MARK: - 数据读写
    /// 写入数据
    ///
    /// - Parameters:
    ///   - peri: 外设
    ///   - uuidStr: 特征值UUID
    ///   - data: 要写入的数据
    ///   - interval: 超时时间
    func writeData(peripheral peri:DVBlePeripheral,
                   characteristicUUID uuidStr:String,
                   data:Data,
                   timeout interval:TimeInterval = 10,
                   callback block:WriteDataCallbackBlock? = nil) {
        //排除蓝牙未打开的情况
        guard self.state == .powerOn else {
            self.delegate?.manager(self, didBluetoothStateChanged: self.state)
            return
        }
        self.writeDataCallbackBlock = block
        //写入数据
        peri.writeData(data: data, onCharacteristicUUID: uuidStr, timeout: interval)
        print("外设\(peri.name) >>>>>> 写入:\(data)")
    }
    
    /// 读取数据
    ///
    /// - Parameters:
    ///   - peri: 外设
    ///   - uuidStr: 特征值UUID
    ///   - interval: 超时时间
    func readData(peripheral peri:DVBlePeripheral,
                  characteristicUUID uuidStr:String,
                  timeout interval:TimeInterval = 10,
                  callback block: ReadDataCallbackBlock? = nil) {
        //排除蓝牙未打开的情况
        guard self.state == .powerOn else {
            self.delegate?.manager(self, didBluetoothStateChanged: self.state)
            return
        }
        self.readDataCallbackBlock = block
        
        //读取数据
        peri.readData(characteristicUUID: uuidStr, timeout: interval)
    }
    
    
    /// 监听数值
    ///
    /// - Parameters:
    ///   - enable: 是否开启
    ///   - peri: 外设
    ///   - uuidStr: 特征值
    func notify(enable:Bool,
                peripheral peri:DVBlePeripheral,
                characteristicUUID uuidStr:String,
                callback block:ReadDataCallbackBlock? = nil) {
        //排除蓝牙未打开的情况
        guard self.state == .powerOn else {
            self.delegate?.manager(self, didBluetoothStateChanged: self.state)
            return
        }
        self.readDataCallbackBlock = block
        //监听
        peri.setNotifyValue(enable, characteristicUUID: uuidStr)
    }
}

// MARK: - 私有方法
private extension DVBleManager {
    /// 扫描超时
    @objc func scanPeripheralTimeout() {
        stopScanPeripheral()
    }
    
    /// 连接超时. 主动连接超时不会开启重连
    @objc func connectTimeout(_ timer:Timer) {
        if let peri = timer.userInfo as? DVBlePeripheral {
            print("外设(\(peri.name))......连接失败(原因: 超时, 可能外设已经超出可连接范围)")
            //断开正在连接的设备
            self.manager.cancelPeripheralConnection(peri.peripheral)
            //回调超时
            self.delegate?.manager(self, didConnectFailedToPeripheral: peri, error: .timeout)
        } else {
            assertionFailure("periphera没有赋值")
        }
    }
    
    /// 开启重连. 会在以前连接失败的设备重连.
    func reconnect(){
        //排除蓝牙未打开的情况
        guard self.state == .powerOn else {
            self.delegate?.manager(self, didBluetoothStateChanged: self.state)
            self.mReconnectTimer?.invalidate()
            self.mReconnectTimer = nil
            return
        }
        //排除未开启重连功能
        guard self.enableReconnect else {
            print("自动重连功能未打开")
            self.mReconnectTimer?.invalidate()
            self.mReconnectTimer = nil
            return
        }
        //排除没有需要重连的设备的时候
        guard self.mReconnectPeripheralUUIDs.count > 0 else {
            print("没有需要重连的设备")
            self.mReconnectTimer?.invalidate()
            self.mReconnectTimer = nil
            return
        }
        print("------ 开始重连 ------")
        self.isReconnecting = true
        //回调开始重连
        self.delegate?.manager(self, didReconnectToPeripherals: self.reconnectPeripherals, state: .begin)
        if self.mReconnectTimer == nil {
            sel_reconnect()
            self.mReconnectTimer = Timer.scheduledTimer(timeInterval: self.reconnectDuration,
                                                        target: self,
                                                        selector: #selector(sel_reconnect),
                                                        userInfo: nil,
                                                        repeats: true)
        }
    }
    
    /// 取消当前重连
    func cancelReconnect() {
        if self.isReconnecting {
            print("------ 结束重连 ------")
            self.isReconnecting = false
            //清除 重连计时器
            self.mReconnectTimer?.invalidate()
            self.mReconnectTimer = nil
            //停止当前所有的正在重连的设备
            for peri in self.reconnectPeripherals {
                self.manager.cancelPeripheralConnection(peri.peripheral)
            }
            //清空重连列表
            self.mReconnectPeripheralUUIDs.removeAll()
            self.delegate?.manager(self, didReconnectToPeripherals: nil, state: .end)
        }
    }
    
    /// 重连操作
    @objc func sel_reconnect() {
        //排除蓝牙未打开的情况
        guard self.state == .powerOn else {
            self.delegate?.manager(self, didBluetoothStateChanged: self.state)
            self .cancelReconnect()
            return
        }
        print("---------------------")
        self.isReconnecting = true
        for peri in self.reconnectPeripherals {
            if self.maxReconnectTimes == -1 || peri.reconnectTimes < self.maxReconnectTimes {
                //无限重连 或 还有重连的机会
                if peri.reconnectTimes != 0 {
                    print("外设\(peri.name)......第 \(peri.reconnectTimes) 次重连失败")
                }
                //尝试重连
                peri.reconnectTimes += 1
                print("外设\(peri.name)......尝试第 \(peri.reconnectTimes) 次重连")
                self.manager.connect(peri.peripheral, options: nil)
                
            } else {
                //超过重连次数
                print("外设\(peri.name)......超过重连次数:\(peri.reconnectTimes),即将结束重连")
                //取消原来的链接
                self.manager.cancelPeripheralConnection(peri.peripheral)
                //从重连列表中移除
                if let idx = self.mReconnectPeripheralUUIDs.firstIndex(of: peri.identifier) {
                    self.mReconnectPeripheralUUIDs.remove(at: idx)
                }
                peri.reconnectTimes = 0
                self.delegate?.manager(self, didConnectFailedToPeripheral: peri, error: .timeout)
            }
        }
        if self.mReconnectPeripheralUUIDs.count > 0 {
            self.delegate?.manager(self, didReconnectToPeripherals: self.reconnectPeripherals, state: .reconnecting)
        } else {
            print("没有需要重连的设备")
            cancelReconnect()
        }
    }
    
}

// MARK: - CBCentralManagerDelegate 协议
extension DVBleManager: CBCentralManagerDelegate {
    /// 蓝牙状态发生改变
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print(">>>>>> 蓝牙已打开 <<<<<<")
            scanPeripheral()
            if (self.enableReconnect && self.mReconnectPeripheralUUIDs.count > 0) {
                //开始重连设备
                reconnect()
            }
            break
        case .poweredOff:
            print(">>>>>> 蓝牙已关闭 <<<<<<")
            //清空所有扫描到的数据
            self.mScannedPeripheralUUIDs.removeAll()
            //取消重连
            cancelReconnect()
            //添加过去已连接的设备到重连列表
//            self.mReconnectPeripheralUUIDs.append(contentsOf: self.mConnectPeripheralUUIDs)  //不用这个方法的原因是可能有极小概率有重复的
            for uuidStr in self.mConnectPeripheralUUIDs {
                if !self.mReconnectPeripheralUUIDs.contains(uuidStr) {
                    self.mReconnectPeripheralUUIDs.append(uuidStr)
                }
            }
            //清空已连接的设备
            self.mConnectPeripheralUUIDs.removeAll()
            //如果大于最大连接数的,一直清空最先建立连接的外设, 直到小于最大连接数
            while self.mReconnectPeripheralUUIDs.count > self.maxConnectedPeripheralsCount {
                self.mReconnectPeripheralUUIDs.removeFirst()
            }
            break
        default:
            print(">>>>>> 蓝牙不可用:\(central.state) <<<<<<")
            break
        }
        self.delegate?.manager(self, didBluetoothStateChanged: self.state)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        
    }
    
    /// 发现新的外设
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let peri = DVBlePeripheral.init(withPeripheral: peripheral,
                                              rssi: RSSI.intValue,
                                              advertisementData: advertisementData)
        //根据用户自定义的过滤规则过滤扫描到的新设备
        if let filterBlock = self.scannedPeriFilterBlock {
            if !filterBlock(peri) {
                //如果不符合过滤规则, 跳过该设备
                return
            }
        }
        //添加或者更新 所有设备数组
        self.mAllPeripheralDictionary[peri.identifier] = peri
        //添加到 扫描到的设备列表
        if !self.mScannedPeripheralUUIDs.contains(peri.identifier) {
            //新增到扫描到的设备
            self.mScannedPeripheralUUIDs.append(peri.identifier)
            //回调
            self.delegate?.manager(self, didScanPeripheral: peri, state: .scanning)
            //如果开启了打开App就重连的话
            if self.enableAutoReconnectLastPeripherals && self.mTempLastConnectedPeripheralUUIDs.count > 0 {
                if let idx = self.mTempLastConnectedPeripheralUUIDs.firstIndex(of: peri.identifier) {
                    if !self.mReconnectPeripheralUUIDs.contains(peri.identifier) {
                        self.mReconnectPeripheralUUIDs.append(peri.identifier)
                    }
                    //开始重连
                    reconnect()
                    self.mTempLastConnectedPeripheralUUIDs.remove(at: idx)
                    if self.mTempLastConnectedPeripheralUUIDs.count == 0 {
                        self.enableAutoReconnectLastPeripherals = false
                        self.stopScanPeripheral()
                    }
                }
            }
        } else {
            //已经不是新设备了, 就不回调新设备了
            self.delegate?.manager(self, didScanPeripheral: nil, state: .scanning)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let peri = self.mAllPeripheralDictionary[peripheral.identifier.uuidString] ?? DVBlePeripheral.init(withPeripheral: peripheral)
        print("外设\(peri.name)......连接失败(原因:\(String(describing: error))")
        //添加到重连列表中,当超过最多重连次数时, 会自动移除
        if !self.mReconnectPeripheralUUIDs.contains(peri.identifier) {
            self.mReconnectPeripheralUUIDs.append(peri.identifier)
            peri.reset()
        }
        //尝试重连
        if self.enableReconnect && (self.maxReconnectTimes == -1 || peri.reconnectTimes < self.maxReconnectTimes) {
            //开启重连
            reconnect()
            return
        } else {
            //不开启重连 或 重连结束
            self.delegate?.manager(self, didConnectFailedToPeripheral: peri, error: .conenectFailed)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peri = self.mAllPeripheralDictionary[peripheral.identifier.uuidString] ?? DVBlePeripheral.init(withPeripheral: peripheral)
        print("外设\(peri.name)......建立临时连接")
        //清空重连列表中的该设备
        if let idx = self.mReconnectPeripheralUUIDs.firstIndex(of: peri.identifier) {
            self.mReconnectPeripheralUUIDs.remove(at: idx)
            if self.mReconnectPeripheralUUIDs.count == 0 {
                cancelReconnect();
            }
        }
        peri.reset()
        peri.delegate = self

        if self.needDiscoverAllServicesAndCharacteristics {
            self.delegate?.manager(self, didConnectToPeripheral: peri, state: .discovering)
            print("外设\(peri.name)......开始搜索服务和特征值")
            peri.discoverAllServicesAndCharacteristic()
        } else {
            print("外设\(peri.name)......跳过搜索服务和特征值")
            print("外设\(peri.name)......正式连接")
            self.mConnectTimer?.invalidate()
            //添加到已连接的设备, 并保存到缓存中
            if !self.mConnectPeripheralUUIDs.contains(peri.identifier) {
                self.mConnectPeripheralUUIDs.append(peri.identifier)
                self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs
            }
            //监听特征值
            if let block = self.notifyPeriCharacteristicBlock {
                block(peri)
            }
            //回调
            self.delegate?.manager(self, didConnectToPeripheral: peri, state: .success)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let peri = self.mAllPeripheralDictionary[peripheral.identifier.uuidString] ?? DVBlePeripheral.init(withPeripheral: peripheral)
        peri.reset()
        if let err = error {
            //非主动断开连接
            print("外设\(peri.name)......非正常断开连接(原因:\(err)");
            //从当前已连接的设备中删除, 并缓存
            if let idx = self.mConnectPeripheralUUIDs.firstIndex(of: peri.identifier) {
                self.mConnectPeripheralUUIDs.remove(at: idx)
                self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs
            }
            //回调
            self.delegate?.manager(self, didDisConnectToPeripheral: peri, isActive: false)

            /* 非主动断开连接, 会尝试重连 */
            if !self.mReconnectPeripheralUUIDs.contains(peri.identifier) {
                self.mReconnectPeripheralUUIDs.append(peri.identifier)
                if self.mReconnectPeripheralUUIDs.count + self.connectedPeripherals.count > self.maxReconnectTimes {
                    self.mReconnectPeripheralUUIDs.removeFirst()
                }
            }
            if self.enableReconnect && (self.maxReconnectTimes == -1 || peri.reconnectTimes < self.maxReconnectTimes) {
                //打开了重连
                reconnect()
            }
        } else {
            //主动断开连接
            //判断是不是当前连接中的设备
            if let idx = self.mConnectPeripheralUUIDs.firstIndex(of: peri.identifier) {
                //是当前连接中的设备断开连接的话, 就是用户断开连接的
                print("外设\(peri.name)......用户主动断开连接")
                //从当前已连接的设备中删除, 并缓存
                self.mConnectPeripheralUUIDs.remove(at: idx)
                self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs
                //回调
                self.delegate?.manager(self, didDisConnectToPeripheral: peri, isActive: true)
            } else {
                //非连接中的设备断开连接的话, 是在连接中/重连中 取消连接的. 不作处理
                print("外设\(peri.name)......(取消临时连接, 不处理)")
            }
        }
    }
}

extension DVBleManager: DVBlePeripheralDelegate {
    func peripheral(_ peripheral: DVBlePeripheral, didFinishDiscoverServicesAndCharacteristics isSuccess: Bool) {
        //清空连接超时计时器
        self.mConnectTimer?.invalidate()
        if isSuccess {
            print("外设(\(peripheral.name))......已搜索到所有服务和特征值")
            if let block = self.connectPeriFilterBlock {
                //如果有筛选特征值条件的话
                print("外设(\(peripheral.name))......筛选 所需服务和特征值")
                self.delegate?.manager(self, didConnectToPeripheral: peripheral, state: .filtering)
                //判断筛选结果
                if block(peripheral) {
                    //符合筛选条件
                    print("外设(\(peripheral.name))......筛选 服务和特征值 成功")
                    if !self.mConnectPeripheralUUIDs.contains(peripheral.identifier) {
                        self.mConnectPeripheralUUIDs.append(peripheral.identifier)
                        self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs
                    }
                    //监听特征值
                    if let block = self.notifyPeriCharacteristicBlock {
                        block(peripheral)
                    }
                    //回调
                    self.delegate?.manager(self, didConnectToPeripheral: peripheral, state: .success)
                } else {
                    //不符合筛选条件
                    print("外设(\(peripheral.name))......筛选 服务和特征值 失败")
                    print("外设(\(peripheral.name))......连接失败")
                    self.manager.cancelPeripheralConnection(peripheral.peripheral)
                    self.delegate?.manager(self, didConnectFailedToPeripheral: peripheral, error: .notPaired)
                }
            } else {
                //如果不需要筛选特征值的话
                print("外设(\(peripheral.name))......跳过筛选 服务和特征值 ")
                if !self.mConnectPeripheralUUIDs.contains(peripheral.identifier) {
                    self.mConnectPeripheralUUIDs.append(peripheral.identifier)
                    self.mLastConnectedPeripheralUUIDs = self.mConnectPeripheralUUIDs
                }
                //监听特征值
                if let block = self.notifyPeriCharacteristicBlock {
                    block(peripheral)
                }
                //回调
                self.delegate?.manager(self, didConnectToPeripheral: peripheral, state: .success)
            }
        } else {
            // 发现服务和特征值有问题
            //     .......   (如果是因为这个原因而失败的话, 不会开启<重连>的功能. 因为连接是没有问题的.)
            print("外设(\(peripheral.name))......未搜索到所有服务和特征值")
            print("外设(\(peripheral.name))......连接失败")
            self.manager.cancelPeripheralConnection(peripheral.peripheral)
            self.delegate?.manager(self, didConnectFailedToPeripheral: peripheral, error: .notPaired)
        }
    }
    
    func peripheral(_ peripheral: DVBlePeripheral, didWriteDataOnCharacteristicUUID characteristicUUID: String, result: DVBlePeripheralWriteState) {
        if let block = self.writeDataCallbackBlock {
            block(peripheral,result,characteristicUUID)
        }
    }
    
    func peripheral(_ peripheral: DVBlePeripheral, didReadData data: Data?, onCharacteristic: String, result: DVBlePeripheralReadState) {
        print("外设(\(peripheral.name)) <<<<<< 读取: <\(HexData.hexStr(from: data, seperator: " "))>")
        if let block = self.readDataCallbackBlock {
            block(peripheral,result,onCharacteristic,data)
        }
    }
}



