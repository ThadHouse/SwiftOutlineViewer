//
//  NetworkTables.swift
//  OutlineViewer
//
//  Created by Thad House on 3/31/22.
//

import Foundation
import Network

public class NetworkTables3: NetworkTables {
    
    private let connection: NWConnection
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    
    init(host: String, port: String) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(port)!
        let params = NWParameters.tcp
        let ip = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
        ip.version = .v4
        let tcp = params.defaultProtocolStack.transportProtocol! as! NWProtocolTCP.Options
        tcp.connectionTimeout = 2
        tcp.noDelay = true
        
        connection = NWConnection(host: self.host, port: self.port, using: params)
    }
    
    var eventHandler: ((_ event: NetworkTableEvent) -> Void)? = nil
    
    func start(queue: DispatchQueue) {
        
        connection.stateUpdateHandler = {
            [weak self]
            state in
            print("state: \(state)")
            switch (state) {
            case .ready:
                self?.eventHandler!(.connected)
                self?.writeClientHello()
            case .waiting:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.connection.cancel()
                }
            case .cancelled:
                self?.eventHandler!(.disconnected)
                break;
            default:
                break
            }
        }
        readFrame()
        connection.start(queue: queue)
    }
    
    func stop() {
        connection.cancel()
    }
    
    private func writeClientHello() {
        connection.send(content: [0x01, 0x03, 0x00, 0], completion: .contentProcessed {
            [weak self]
            error in
            if (error != nil) {
                self?.connection.cancel()
            }
        })
    }
    
    private func writeClientHelloComplete() {
        connection.send(content: [0x05], completion: .contentProcessed {
            [weak self]
            error in
            if (error != nil) {
                self?.connection.cancel()
            }
        })
    }
    
    private func readByteAsync() async throws -> UInt8 {
        return try await withCheckedThrowingContinuation {
            continuation in
            
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
                data, context, complete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, data.count == 1 {
                    continuation.resume(returning: data[0])
                } else {
                    continuation.resume(throwing: POSIXError(POSIXErrorCode.EINVAL))
                }
            })
        }
    }
    
    private func readDataAsync(length: Int) async throws -> Data {
        return try await withCheckedThrowingContinuation {
            continuation in
            
            connection.receive(minimumIncompleteLength: length, maximumLength: length, completion: {
                data, context, complete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, data.count == length {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: POSIXError(POSIXErrorCode.EINVAL))
                }
            })
        }
    }
    
    private func readBytesAsync(length: Int) async throws -> [UInt8] {
        return try await withCheckedThrowingContinuation {
            continuation in
            
            connection.receive(minimumIncompleteLength: length, maximumLength: length, completion: {
                data, context, complete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, data.count == length {
                    continuation.resume(returning: [UInt8](data))
                } else {
                    continuation.resume(throwing: POSIXError(POSIXErrorCode.EINVAL))
                }
            })
        }
    }
    
    private func readStringWithLengthAsync(length: Int) async throws -> String {
        return try await withCheckedThrowingContinuation {
            continuation in
            
            connection.receive(minimumIncompleteLength: length, maximumLength: length, completion: {
                data, context, complete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, data.count == length {
                    let string = String(data: data, encoding: .utf8)
                    if let string = string {
                        continuation.resume(returning: string)
                    } else {
                        continuation.resume(throwing: POSIXError(POSIXErrorCode.EINVAL))
                    }
                } else {
                    continuation.resume(throwing: POSIXError(POSIXErrorCode.EINVAL))
                }
            })
        }
    }
    
    private func readLEB128Async() async throws -> Int {
        var result: UInt64 = 0;
        var shift: Int = 0;
        while (true) {
            let byte = try await readByteAsync()
            result |= UInt64(byte & 0x7f) << shift;
            shift += 7;

            if ((byte & 0x80) == 0) {
              break;
            }
        }
        if (result > Int.max) {
            throw POSIXError(POSIXErrorCode.E2BIG)
        }
        return Int(result)
    }
    
    private func readLEB128Internal(value: UInt64, shift: Int, afterFunc: @escaping (_ length: Int) -> Void) {
        var localValue = value
        var localShift = shift
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
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
                        self?.connection.cancel()
                    } else {
                        afterFunc(Int(localValue))
                    }
                }
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readLEB128(afterFunc: @escaping (_ length: Int) -> Void) {
        readLEB128Internal(value: 0, shift: 0, afterFunc: afterFunc)
    }
    
    private func readRaw(handleRaw: @escaping (_ value: Data) -> Void) -> Void {
        readLEB128(afterFunc: {
            [weak self]
            length in
            self?.connection.receive(minimumIncompleteLength: length, maximumLength: length, completion: {
                data, context, complete, error in
                if let data = data, !data.isEmpty {
                    handleRaw(data)
                } else {
                    self?.connection.cancel()
                }
                
            })
        })
    }
    
    private func readRawAsync() async throws -> [UInt8] {
        let length = try await readLEB128Async()
        return try await readBytesAsync(length: length)
    }
    
    private func readStringAsync() async throws -> String {
        let length = try await readLEB128Async()
        return try await readStringWithLengthAsync(length: length)
    }
    
    private func readString(handleString: @escaping (_ value: String) -> Void) -> Void {
        readLEB128(afterFunc: {
            [weak self]
            length in
            self?.connection.receive(minimumIncompleteLength: length, maximumLength: length, completion: {
                data, context, complete, error in
                if let data = data, !data.isEmpty {
                    let message = String(data: data, encoding: .utf8)
                    if let message = message {
                        handleString(message)
                    } else {
                        self?.connection.cancel()
                    }
                } else {
                    self?.connection.cancel()
                }
                
            })
        })
    }
    
    private func readServerHelloAsync() async throws {
        _ = try await readByteAsync()
        _ = try await readStringAsync()
    }
    
    private func readServerHello() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if data != nil {
                // Ignore flags
                self?.readString(handleString: {
                    _ in
                    self?.readFrame()
                })
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    
    
    private func readEntryBoolean(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                if let entryFlags = entryFlags {
                    self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .Bool, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
                }
                self?.eventHandler!(.updateBool(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: data[0] != 0)))
                self?.readFrame()
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readEntryDouble(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection.receive(minimumIncompleteLength: 8, maximumLength: 8, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 8 {
                if let entryFlags = entryFlags {
                    self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .Double, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
                }
                self?.eventHandler!(.updateDouble(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: data.toDoubleBE()!)))
                self?.readFrame()
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readEntryString(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        readString(handleString: {
            [weak self]
            string in
            if let entryFlags = entryFlags {
                self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .String, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
            }
            self?.eventHandler!(.updateString(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: string)))
            self?.readFrame()
        })
    }
    
    private func readEntryRaw(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        readRaw(handleRaw: {
            [weak self]
            raw in
            if let entryFlags = entryFlags {
                self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .Raw, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
            }
            self?.eventHandler!(.updateRaw(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: [UInt8](raw))))
            self?.readFrame()
        })
    }
    
    private func readEntryBooleanArray(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                let boolCount: Int = Int(data[0])
                self?.connection.receive(minimumIncompleteLength: boolCount, maximumLength: boolCount, completion: {
                    data, context, complete, error in
                    if let data = data, data.count == boolCount {
                        var arr: [Bool] = []
                        for d in data {
                            arr.append(d != 0)
                        }
                        if let entryFlags = entryFlags {
                            self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .BoolArray, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
                        }
                        self?.eventHandler!(.updateBoolArray(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: arr)))
                        self?.readFrame()
                    } else {
                        self?.connection.cancel()
                    }
                })
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readEntryDoubleArray(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                let doubleCount: Int = Int(data[0]) * 8
                self?.connection.receive(minimumIncompleteLength: doubleCount, maximumLength: doubleCount, completion: {
                    data, context, complete, error in
                    if let data = data, data.count == doubleCount {
                        var arr: [Double] = []
                        for i in 0...data.count {
                            arr.append(data.toDoubleBE(range: (i * 8)...)!)
                        }
                        if let entryFlags = entryFlags {
                            self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .DoubleArray, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
                        }
                        self?.eventHandler!(.updateDoubleArray(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: arr)))
                        self?.readFrame()
                    } else {
                        self?.connection.cancel()
                    }
                })
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readStringForArray(entryId: UInt16, sequenceNumber: UInt16, stringCount: Int, data: [String], entryName: String? = nil, entryFlags: UInt8? = nil) {
        var localData = data
        readString(handleString: {
            [weak self]
            string in
            localData.append(string)
            if (localData.count == stringCount) {
                if let entryFlags = entryFlags {
                    self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .StringArray, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
                }
                self?.eventHandler!(.updateStringArray(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: localData)))
                self?.readFrame()
            } else {
                self?.readStringForArray(entryId: entryId, sequenceNumber: sequenceNumber, stringCount: stringCount, data: localData, entryName: entryName, entryFlags: entryFlags)
            }
        })
    }
    
    private func readEntryStringArray(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 1 {
                let stringCount: Int = Int(data[0])
                let stringData: [String] = []
                self?.readStringForArray(entryId: entryId, sequenceNumber: sequenceNumber, stringCount: stringCount, data: stringData, entryName: entryName, entryFlags: entryFlags)
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readEntryRpc(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        readRaw(handleRaw: {
            [weak self]
            raw in
            if let entryFlags = entryFlags {
                self?.eventHandler!(.newEntry(NewEntryEvent(entryName: entryName!, entryType: .Rpc, entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber)))
            }
            self?.eventHandler!(.updateRpcDefinition(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: [UInt8](raw))))
            self?.readFrame()
        })
    }
    
    private func readEntryBooleanAsync(entryId: UInt16, entryType: UInt8, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let value = try await readByteAsync()
        if let entryName = entryName, let entryFlags = entryFlags {
        }
        return .updateBool(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: value))
    }
    
    private func readEntryValueAsync(entryId: UInt16, entryType: UInt8, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        switch entryType {
        case 0x00: // Boolean
            return readEntryBooleanAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x01: // Double
            return readEntryDoubleAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x02: // String
            return readEntryStringAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x03: // Raw
            return readEntryRawAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x10: // Boolean Array
            return readEntryBooleanArrayAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x11: // Double Array
            return readEntryDoubleArrayAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x12: // String Array
            return readEntryStringArrayAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x20: // RPC
            return readEntryRpcAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        default:
            throw POSIXError(POSIXErrorCode.EINVAL)
        }
    }
    
    private func readEntryValue(entryId: UInt16, entryType: UInt8, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) {
        switch entryType {
        case 0x00: // Boolean
            readEntryBoolean(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x01: // Double
            readEntryDouble(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x02: // String
            readEntryString(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x03: // Raw
            readEntryRaw(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x10: // Boolean Array
            readEntryBooleanArray(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x11: // Double Array
            readEntryDoubleArray(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x12: // String Array
            readEntryStringArray(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x20: // RPC
            readEntryRpc(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        default:
            connection.cancel()
        }
    }
    
    private func readEntryAssignmentAsync() async throws -> NetworkTableEvent {
        let entryName = try await readStringAsync()
        let data = try await readDataAsync(length: 6)
        let entryType = data[0]
        let entryId = data.toU16BE(range: 1...)!
        let entrySeqNum = data.toU16BE(range: 3...)!
        let entryFlags = data[5]
        return try await readEntryValueAsync(entryId: entryId, entryType: entryType, sequenceNumber: entrySeqNum, entryName: entryName, entryFlags: entryFlags)
    }
    
    private func readEntryAssignment() {
        readString(handleString: {
            [weak self]
            entryName in
            self?.connection.receive(minimumIncompleteLength: 6, maximumLength: 6, completion: {
                data, context, complete, error in
                if let data = data, data.count == 6 {
                    let entryType = data[0]
                    let entryId = data.toU16BE(range: 1...)!
                    let entrySeqNum = data.toU16BE(range: 3...)!
                    let entryFlags = data[5]
                    self?.readEntryValue(entryId: entryId, entryType: entryType, sequenceNumber: entrySeqNum, entryName: entryName, entryFlags: entryFlags)
                } else {
                    self?.connection.cancel()
                }
            })
        })
    }
    
    private func readEntryUpdateAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 5)
        let entryId = data.toU16BE()!
        let entrySeqNum = data.toU16BE(range: 2...)!
        let entryType = data[4]
        return try await readEntryValueAsync(entryId: entryId, entryType: entryType, sequenceNumber: entrySeqNum)
    }
    
    private func readEntryUpdate() {
        connection.receive(minimumIncompleteLength: 5, maximumLength: 5, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 5 {
                let entryId = data.toU16BE()!
                let entrySeqNum = data.toU16BE(range: 2...)!
                let entryType = data[4]
                self?.readEntryValue(entryId: entryId, entryType: entryType, sequenceNumber: entrySeqNum)
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readEntryFlagsUpdateAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 3)
        let entryId = data.toU16BE()!
        let entryFlags = data[2]
        return .updateFlag(FlagUpdate(entryId: entryId, flags: entryFlags))
    }
    
    private func readEntryFlagsUpdate() {
        connection.receive(minimumIncompleteLength: 3, maximumLength: 3, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 3 {
                let entryId = data.toU16BE()!
                let entryFlags = data[2]
                self?.eventHandler!(.updateFlag(FlagUpdate(entryId: entryId, flags: entryFlags)))
                self?.readFrame()
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readEntryDeleteAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 4)
        return .deleteEntry(DeleteEntry(entryId: data.toU16BE()!))
    }
    
    private func readEntryDelete() {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 2 {
                self?.eventHandler!(.deleteEntry(DeleteEntry(entryId: data.toU16BE()!)))
                self?.readFrame()
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readClearAllEntriesAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 4)
        if (data[0] == 0xD0 && data[1] == 0x6C && data[2] == 0xB2 && data[3] == 0x7A) {
            return .deleteAllEntries
        } else {
            return .continueReading
        }
    }
    
    private func readClearAllEntries() {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4, completion: {
            [weak self]
            data, context, complete, error in
            if let data = data, data.count == 4 {
                if (data[0] == 0xD0 && data[1] == 0x6C && data[2] == 0xB2 && data[3] == 0x7A) {
                    self?.eventHandler!(.deleteAllEntries)
                }
                self?.readFrame()
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readRpcResponseAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 4)
        let entryId = data.toU16BE()!
        let entrySeqNum = data.toU16BE(range: 2...)!
        let rpc = try await readRawAsync()
        return .updateRpcDefinition(DataEvent(entryId: entryId, seqNum: entrySeqNum, value: rpc))
    }
    
    private func readRpcResponse() {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4, completion: {
            [weak self]
            data, context, complete, error in
            if data != nil {
                self?.readRaw(handleRaw: {
                    _ in
                    self?.readFrame()
                })
            } else {
                self?.connection.cancel()
            }
        })
    }
    
    private func readFrameAsync() async throws -> NetworkTableEvent {
        let type = try await readByteAsync()
        switch type {
        case 0x00: // Keep Alive
            return .continueReading
        case 0x03: // Server Hello Complete
            self.writeClientHelloComplete()
            return .connected
        case 0x04: // Server Hello
            try await readServerHelloAsync()
            return .continueReading
        case 0x10: // Entry assignment
            return try await readEntryAssignmentAsync()
        case 0x11:
            return try await readEntryUpdateAsync()
        case 0x12:
            return try await readEntryFlagsUpdateAsync()
        case 0x13:
            return try await readEntryDeleteAsync()
        case 0x14:
            return try await readClearAllEntriesAsync()
        case 0x21:
            return try await readRpcResponseAsync()
        default:
            throw POSIXError(POSIXErrorCode.EINVAL)
        }
    }
    
    private func readFrame() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1, completion: {
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
                    self?.connection.cancel()
                }
            } else {
                self?.connection.cancel()
            }
        })
    }
}
