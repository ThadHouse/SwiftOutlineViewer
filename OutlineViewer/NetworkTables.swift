//
//  NetworkTables.swift
//  OutlineViewer
//
//  Created by Thad House on 3/31/22.
//

import Foundation
import Network
import NetworkExtension

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

//    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
//        var value: T = 0
//        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
//        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
//        return value
//    }
//
//    func to<T, R>(type: T.Type, range: R) -> T? where T: ExpressibleByIntegerLiteral, R : RangeExpression, Self.Index == R.Bound {
//        var value: T = 0
//        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
//        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0, from: range)} )
//        return value
//    }
}

public class NetworkTables3 {
    
    var connection: NWConnection? = nil
    let entryHandler: EntryHandler
    
    init(entryHandler: EntryHandler) {
        self.entryHandler = entryHandler
    }
    
    func start(state: NTState) {
        connection = NWConnection(host: NWEndpoint.Host(state.teamNumber), port: NWEndpoint.Port(state.port)!, using: .tcp)
        connection?.stateUpdateHandler = {
            [weak self]
            state in
            print("state: \(state)")
            switch (state) {
            case .ready:
                self?.writeClientHello()
            case .cancelled:
                // TODO Restart
                break;
            default:
                break
            }
        }
        readFrame()
        connection?.start(queue: DispatchQueue.main)
    }
    
    func writeKeepAlive() {
        connection?.send(content: [0x00], completion: .contentProcessed {
            _ in
            //self?.connection?.cancel()
        })
    }
    
    func writeClientHello() {
        connection?.send(content: [0x01, 0x03, 0x00, 0], completion: .contentProcessed {
            _ in
            //self?.connection?.cancel()
        })
    }
    
    func writeClientHelloComplete() {
        connection?.send(content: [0x05], completion: .contentProcessed {
            _ in
            //self?.connection?.cancel()
        })
    }
    
    func readLEB128Internal(value: UInt64, shift: Int, afterFunc: @escaping (_ length: Int) -> Void) {
        var localValue = value
        var localShift = shift
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                let byte: UInt64 = UInt64(data[0])
                localValue |= (byte & 0x7F) << localShift
                localShift += 7
                
                if ((byte & 0x80) != 0) {
                    self?.readLEB128Internal(value: localValue, shift: localShift, afterFunc: afterFunc)
                } else {
                    if (localValue > Int.max) {
                        self?.connection?.cancel()
                    } else {
                        afterFunc(Int(localValue))
                    }
                }
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readLEB128(afterFunc: @escaping (_ length: Int) -> Void) {
        readLEB128Internal(value: 0, shift: 0, afterFunc: afterFunc)
    }
    
    func readRaw(handleRaw: @escaping (_ value: Data) -> Void) -> Void {
        readLEB128(afterFunc: {
            [weak self]
            length in
            self?.connection?.receive(minimumIncompleteLength: length, maximumLength: length, completion: {
                data, context, complete, error in
                if let data = data, !data.isEmpty {
                    handleRaw(data)
                } else {
                    self?.connection?.cancel()
                }
                
            })
        })
    }
    
    func readString(handleString: @escaping (_ value: String) -> Void) -> Void {
        readLEB128(afterFunc: {
            [weak self]
            length in
            self?.connection?.receive(minimumIncompleteLength: length, maximumLength: length, completion: {
                data, context, complete, error in
                if let data = data, !data.isEmpty {
                    let message = String(data: data, encoding: .utf8)
                    if let message = message {
                        handleString(message)
                    } else {
                        self?.connection?.cancel()
                    }
                } else {
                    self?.connection?.cancel()
                }
                
            })
        })
    }
    
    func readServerHello() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if data != nil {
                // Ignore flags
                self?.readString(handleString: {
                    _ in
                    self?.readFrame()
                })
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readEntryBoolean(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                if let entryFlags = entryFlags {
                    self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x0, entryId: entryId, entryFlags: entryFlags)
                }
                self?.entryHandler.setBoolean(entryId: entryId, value: data[0] != 0)
                self?.readFrame()
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readEntryDouble(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection?.receive(minimumIncompleteLength: 8, maximumLength: 8, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 8 {
                if let entryFlags = entryFlags {
                    self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x1, entryId: entryId, entryFlags: entryFlags)
                }
                self?.entryHandler.setDouble(entryId: entryId, value: data.toDoubleBE()!)
                self?.readFrame()
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readEntryString(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        readString(handleString: {
            [weak self]
            string in
            if let entryFlags = entryFlags {
                self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x2, entryId: entryId, entryFlags: entryFlags)
            }
            self?.entryHandler.setString(entryId: entryId, value: string)
            self?.readFrame()
        })
    }
    
    func readEntryRaw(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        readRaw(handleRaw: {
            [weak self]
            raw in
            if let entryFlags = entryFlags {
                self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x3, entryId: entryId, entryFlags: entryFlags)
            }
            self?.entryHandler.setRaw(entryId: entryId, value: [UInt8](raw))
            self?.readFrame()
        })
    }
    
    func readEntryBooleanArray(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                let boolCount: Int = Int(data[0])
                self?.connection?.receive(minimumIncompleteLength: boolCount, maximumLength: boolCount, completion: {
                    data, context, complete, error in
                    if let data = data, data.count == boolCount {
                        var arr: [Bool] = []
                        for d in data {
                            arr.append(d != 0)
                        }
                        if let entryFlags = entryFlags {
                            self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x10, entryId: entryId, entryFlags: entryFlags)
                        }
                        self?.entryHandler.setBooleanArray(entryId: entryId, value: arr)
                        self?.readFrame()
                    } else {
                        self?.connection?.cancel()
                    }
                })
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readEntryDoubleArray(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                let doubleCount: Int = Int(data[0]) * 8
                self?.connection?.receive(minimumIncompleteLength: doubleCount, maximumLength: doubleCount, completion: {
                    data, context, complete, error in
                    if let data = data, data.count == doubleCount {
                        var arr: [Double] = []
                        for i in 0...data.count {
                            arr.append(data.toDoubleBE(range: (i * 8)...)!)
                        }
                        if let entryFlags = entryFlags {
                            self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x11, entryId: entryId, entryFlags: entryFlags)
                        }
                        self?.entryHandler.setDoubleArray(entryId: entryId, value: arr)
                        self?.readFrame()
                    } else {
                        self?.connection?.cancel()
                    }
                })
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readStringForArray(entryId: UInt16, stringCount: Int, data: [String], entryName: String? = nil, entryFlags: UInt8? = nil) {
        var localData = data
        readString(handleString: {
            [weak self]
            string in
            localData.append(string)
            if (localData.count == stringCount) {
                if let entryFlags = entryFlags {
                    self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x12, entryId: entryId, entryFlags: entryFlags)
                }
                self?.entryHandler.setStringArray(entryId: entryId, value: localData)
                self?.readFrame()
            } else {
                self?.readStringForArray(entryId: entryId, stringCount: stringCount, data: localData, entryName: entryName, entryFlags: entryFlags)
            }
        })
    }
    
    func readEntryStringArray(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                let stringCount: Int = Int(data[0])
                let stringData: [String] = []
                self?.readStringForArray(entryId: entryId, stringCount: stringCount, data: stringData, entryName: entryName, entryFlags: entryFlags)
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readEntryRpc(entryId: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        readRaw(handleRaw: {
            [weak self]
            raw in
            if let entryFlags = entryFlags {
                self?.entryHandler.newEntry(entryName: entryName!, entryType: 0x20, entryId: entryId, entryFlags: entryFlags)
            }
            self?.entryHandler.setRpcDefinition(entryId: entryId, value: [UInt8](raw))
            self?.readFrame()
        })
    }
    
    func readEntryValue(entryId: UInt16, entryType: UInt8, entryName: String? = nil, entryFlags: UInt8? = nil) {
        switch entryType {
        case 0x00: // Boolean
            readEntryBoolean(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        case 0x01: // Double
            readEntryDouble(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        case 0x02: // String
            readEntryString(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        case 0x03: // Raw
            readEntryRaw(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        case 0x10: // Boolean Array
            readEntryBooleanArray(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        case 0x11: // Double Array
            readEntryDoubleArray(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        case 0x12: // String Array
            readEntryStringArray(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        case 0x20: // RPC
            readEntryRpc(entryId: entryId, entryName: entryName, entryFlags: entryFlags)
        default:
            connection?.cancel()
        }
    }
    
    func readEntryAssignment() {
        readString(handleString: {
            [weak self]
            entryName in
            self?.connection?.receive(minimumIncompleteLength: 6, maximumLength: 6, completion: {
                data, context, complete, error in
                if let data = data, data.count == 6 {
                    let entryType = data[0]
                    let entryId = data.toU16BE(range: 1...)!
                    let entryFlags = data[5]
                    self?.readEntryValue(entryId: entryId, entryType: entryType, entryName: entryName, entryFlags: entryFlags)
                } else {
                    self?.connection?.cancel()
                }
            })
        })
    }
    
    func readEntryUpdate() {
        connection?.receive(minimumIncompleteLength: 5, maximumLength: 5, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 5 {
                let entryId = data.toU16BE()!
                let entryType = data[4]
                self?.readEntryValue(entryId: entryId, entryType: entryType)
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readEntryFlagsUpdate() {
        connection?.receive(minimumIncompleteLength: 3, maximumLength: 3, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 3 {
                let entryId = data.toU16BE()!
                let entryFlags = data[2]
                self?.entryHandler.entryFlagsUpdated(entryId: entryId, newFlags: entryFlags)
                self?.readFrame()
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readEntryDelete() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 2 {
                self?.entryHandler.deleteEntry(entryId: data.toU16BE()!)
                self?.readFrame()
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readClearAllEntries() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 4 {
                if (data[0] == 0xD0 && data[1] == 0x6C && data[2] == 0xB2 && data[3] == 0x7A) {
                    self?.entryHandler.deleteAllEntries()
                }
                self?.readFrame()
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readRpcResponse() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4, completion: {
            [weak self]
            data, context, complete, error in
            if data != nil {
                self?.readRaw(handleRaw: {
                    _ in
                    self?.readFrame()
                })
            } else {
                self?.connection?.cancel()
            }
        })
    }
    
    func readFrame() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
          data, context, complete, error in
            if let data = data, data.count == 1 {
                switch (data[0]) {
                case 0x0: // Keep Alive
                    self?.readFrame()
                case 0x3: // Server Hello Complete
                    self?.writeClientHelloComplete()
                    self?.readFrame()
                case 0x4: // Server Hello
                    self?.readServerHello()
                case 0x10: // Entry Assignment
                    self?.readEntryAssignment()
                case 0x11: // Entry Update
                    self?.readEntryUpdate()
                case 0x12: // Entry Flags Update
                    self?.readEntryFlagsUpdate()
                case 0x13: // Entry Delete
                    self?.readEntryDelete()
                case 0x14:
                    self?.readClearAllEntries()
                case 0x21:
                    self?.readRpcResponse()
                default:
                    // 0x01 (Client Hello)
                    // 0x02 (Protcol Version Unsupported)
                    // 0x05 (Client Hello Complete)
                    self?.connection?.cancel()
                }
            } else {
                self?.connection?.cancel()
            }
        })
    }
}
