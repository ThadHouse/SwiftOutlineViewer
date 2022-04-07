//
//  DataExtensions.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation

extension UnsafeMutableRawBufferPointer {
    
    func toU8() -> UInt8? {
        guard count >= MemoryLayout<UInt8>.size else { return nil }
        return self[0]
    }
    
    func toU8(fromByteOffset: Int) -> UInt8? {
        guard count >= MemoryLayout<UInt8>.size + fromByteOffset else { return nil }
        return self[fromByteOffset]
    }
    
    func toU16BE() -> UInt16? {
        var value: UInt16 = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value) {
            valuePtr in
            valuePtr.copyMemory(from: UnsafeRawBufferPointer(start: self.baseAddress, count: 2))
        }
        return UInt16(bigEndian: value)
    }
    
    func toDoubleBE() -> Double? {
        var value: UInt64 = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value) {
            valuePtr in
            valuePtr.copyMemory(from: UnsafeRawBufferPointer(start: self.baseAddress, count: 8))
        }
        return Double(bitPattern: UInt64(bigEndian: value))
    }
    
    func toU16BE(fromByteOffset: Int) -> UInt16? {
        var value: UInt16 = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value) {
            valuePtr in
            valuePtr.copyMemory(from: UnsafeRawBufferPointer(start: self.baseAddress! + fromByteOffset, count: 2))
        }
        return UInt16(bigEndian: value)
    }
    
    func toDoubleBE(fromByteOffset: Int) -> Double? {
        var value: UInt64 = 0
        guard count >= MemoryLayout.size(ofValue: value) + fromByteOffset else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value) {
            valuePtr in
            valuePtr.copyMemory(from: UnsafeRawBufferPointer(start: self.baseAddress! + fromByteOffset, count: 8))
        }
        return Double(bitPattern: UInt64(bigEndian: value))
    }
}

extension Data {

    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }
    
    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value
    }
    
    func to<T, R>(type: T.Type, range: R) -> T? where T: ExpressibleByIntegerLiteral, R: RangeExpression, Self.Index == R.Bound {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0, from: range)} )
        return value
    }
    
    
    func toU16BE() -> UInt16? {
        var value: UInt16 = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return UInt16(bigEndian: value)
    }
    
    func toDoubleBE() -> Double? {
        var value: UInt64 = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return Double(bitPattern: UInt64(bigEndian: value))
    }
    
    func toU16BE<R>(range: R) -> UInt16? where R: RangeExpression, Self.Index == R.Bound {
        var value: UInt16 = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0, from: range)} )
        return UInt16(bigEndian: value)
    }
    
    func toDoubleBE<R>(range: R) -> Double? where R: RangeExpression, Self.Index == R.Bound {
        var value: UInt64 = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0, from: range)} )
        return Double(bitPattern: UInt64(bigEndian: value))
    }
}
