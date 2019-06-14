//
//  HexData.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/12.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import UIKit

class HexData: NSObject {
    
    /// 将对应16进制String转换为相应Data
    ///
    /// - Parameter str: 16进制字符串
    /// - Returns: Data
    class func data(from hexStr: String?) -> Data {
        guard let hexStr = hexStr else {
            return Data()
        }
        assert(hexStr.count % 2 == 0, "位数不对")

        var data = Data()
        for idx in 0...hexStr.count/2 {
            if let range = Range.init(NSRange.init(location: idx * 2, length: 2), in: hexStr) {
                let c = String.init(hexStr[range])
                var temp:UInt32 = 0
                Scanner(string: c).scanHexInt32(&temp)
                let char = UInt8(temp)
                data.append(char)
            }
        }
        return data
    }
    
    /// 将Data数据转换成相应的十六进制字符串
    ///
    /// - Parameters:
    ///   - data: 数据
    ///   - seperator: 分隔符
    /// - Returns: 16进制字符串
    class func hexStr(from data: Data?, seperator: String? = nil) -> String {
        var hex = String()
        guard let data = data else {
            return hex
        }
        let bytes = [UInt8](data)
        for (idx, byte) in bytes.enumerated() {
            hex += String.init(format: "%02x", byte)
            if idx < (bytes.count - 1) {
                hex += seperator ?? ""
            }
        }
        return hex
    }

    /// 计算校验位，求和取反
    ///
    /// - Parameter data: 数据
    /// - Returns: 校验位
    class func checksum(data:Data) -> UInt8 {
        var sum = UInt8(0)
        let bytes = [UInt8](data)
        for byte in bytes {
            sum += byte
        }
        return ~sum
    }
    
    /// 字节反转
    /// AABBCC ====>   CCBBAA
    /// - Parameter data: 要反转的数据
    /// - Returns: 反转好的数据
    class func reverse(from data:Data) -> Data {
        let bytes = [UInt8](data)
        var newData = Data.init()
        for byte in bytes {
            newData.insert(byte, at: 0)
        }
        return newData
    }
}

extension String {
    static func hexString(from data:Data, seperator:String? = nil) -> String{
        return HexData.hexStr(from: data, seperator: seperator)
    }
}

extension Data {
    static func data(from hexStr:String) -> Data{
        return HexData.data(from: hexStr)
    }
}
