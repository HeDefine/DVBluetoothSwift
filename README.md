# DVBluetoothSwift

## 简介
该Manager 主要是在 CoreBluetooth 的基础上再次封装。

## 安装

### 1. 手动安装
1. 下载本项目Zip,并解压.
2. 拖取DVBluetooth/DVBluetooth文件夹到你的项目中
3. 导入本项目 `import DVBluetoothSwift`

### 2.Cocoapod 安装
1. 安装Cocoapod, 并在根目录下运行 `pod init`
2. 在`Podfile`文件中输入
```
pod 'DVBluetoothSwift','~> 0.1.0'
```
3. 命令行运行`pod update`

## 使用方法
建议新建一个类，继承原有的 DVBleManager 以及新建一个 Protocol . 对收到的数据处理后可以通过协议回调

根据自己项目的需求，在这个类里面可以自定义 1. 特征值的UUID  2.对回调数据的处理  3.处理发送数据的方式

#### 1. 配置
```swift
let UUIDWriteDataService = "FFE5"
let UUIDWriteDataCharateristic = "FFE9"
let UUIDReadDataService = "FFE0"
let UUIDReadDataCharateristic = "FFE4"
let UUIDInfoService = "FF90"
let UUIDDeviceNameCharateristic = "FF91"

/**
 初始化配置, 个性化配置
 */
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
        /**
         写入 回调
        */

        self.setWriteDataCallbackBlock { (peri, result, uuidStr) in
            if result == .success && uuidStr == UUIDWriteDataCharateristic {
                //写入成功
            }
        }
        /**
         读取回调. 处理数据
        */
        self.setReadDataCallbackBlock { [weak self](peri, result, uuidStr, data) in
            if result == .success && uuidStr == UUIDReadDataCharateristic {
                //读取成功
                if let data = data {
                    self?.handle(data: data)
                }
            }
        }
    }
```
#### 2. 写入方法
```swift
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

```
