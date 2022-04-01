//
//  DataExtensions.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation

extension Data {

    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
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
