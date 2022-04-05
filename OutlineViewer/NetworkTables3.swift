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
    
    func start(queue: DispatchQueue) {
        
        connection.stateUpdateHandler = {
            [weak self]
            state in
            print("state: \(state)")
            switch (state) {
            case .ready:
                self?.writeClientHello()
            case .waiting:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.connection.cancel()
                }
            case .failed(let err):
                print("err \(err)")
            case .cancelled:
                break;
            default:
                break
            }
        }
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
    
    private func readDoubleAsync() async throws -> Double {
        return try await withCheckedThrowingContinuation {
            continuation in
            
            connection.receive(minimumIncompleteLength: 8, maximumLength: 8, completion: {
                data, context, complete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, data.count == 8 {
                    continuation.resume(returning: data.toDoubleBE()!)
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

    
    private func readRawAsync() async throws -> [UInt8] {
        let length = try await readLEB128Async()
        return try await readBytesAsync(length: length)
    }
    
    private func readStringAsync() async throws -> String {
        let length = try await readLEB128Async()
        return try await readStringWithLengthAsync(length: length)
    }
    
    private func readServerHelloAsync() async throws {
        _ = try await readByteAsync()
        _ = try await readStringAsync()
    }
    
    private func readEntryBooleanAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let value = try await readByteAsync() != 0
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .Bool(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .Bool(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryDoubleAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let value = try await readDoubleAsync()
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .Double(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .Double(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryStringAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let value = try await readStringAsync()
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .String(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .String(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryBooleanArrayAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let length = try await readByteAsync()
        let data = try await readDataAsync(length: Int(length) * 8)
        let value: [Bool] = data.map{ $0 != 0 }
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .BoolArray(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .BoolArray(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryDoubleArrayAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let length = try await readByteAsync()
        let data = try await readDataAsync(length: Int(length) * 8)
        var value: [Double] = []
        for i in 0...Int(length) {
            value.append(data.toDoubleBE(range: (i * 8)...)!)
        }
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .DoubleArray(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .DoubleArray(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryStringArrayAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let length = try await readByteAsync()
        var value: [String] = []
        for _ in 0...length {
            value.append(try await readStringAsync())
        }
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .StringArray(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .StringArray(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryRawAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let value = try await readRawAsync()
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .Raw(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .Raw(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryRpcAsync(entryId: UInt16, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        let value = try await readRawAsync()
        if let entryName = entryName, let entryFlags = entryFlags {
            return .newEntry(NewEntryEvent(entryName: entryName, entryType: .Rpc(value), entryId: entryId, entryFlags: entryFlags, seqNum: sequenceNumber))
        }
        return .updateEntry(EntryUpdateEvent(entryType: .Rpc(value), entryId: entryId, seqNum: sequenceNumber))
    }
    
    private func readEntryValueAsync(entryId: UInt16, entryType: UInt8, sequenceNumber: UInt16, entryName: String? = nil, entryFlags: UInt8? = nil) async throws -> NetworkTableEvent {
        switch entryType {
        case 0x00: // Boolean
            return try await readEntryBooleanAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x01: // Double
            return try await readEntryDoubleAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x02: // String
            return try await readEntryStringAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x03: // Raw
            return try await readEntryRawAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x10: // Boolean Array
            return try await readEntryBooleanArrayAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x11: // Double Array
            return try await readEntryDoubleArrayAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x12: // String Array
            return try await readEntryStringArrayAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        case 0x20: // RPC
            return try await readEntryRpcAsync(entryId: entryId, sequenceNumber: sequenceNumber, entryName: entryName, entryFlags: entryFlags)
        default:
            throw POSIXError(POSIXErrorCode.EINVAL)
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
    
    private func readEntryUpdateAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 5)
        let entryId = data.toU16BE()!
        let entrySeqNum = data.toU16BE(range: 2...)!
        let entryType = data[4]
        return try await readEntryValueAsync(entryId: entryId, entryType: entryType, sequenceNumber: entrySeqNum)
    }
    
    private func readEntryFlagsUpdateAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 3)
        let entryId = data.toU16BE()!
        let entryFlags = data[2]
        return .updateFlag(FlagUpdate(entryId: entryId, flags: entryFlags))
    }
    
    private func readEntryDeleteAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 4)
        return .deleteEntry(DeleteEntry(entryId: data.toU16BE()!))
    }
    
    private func readClearAllEntriesAsync() async throws -> NetworkTableEvent {
        let data = try await readDataAsync(length: 4)
        if (data[0] == 0xD0 && data[1] == 0x6C && data[2] == 0xB2 && data[3] == 0x7A) {
            return .deleteAllEntries
        } else {
            return .continueReading
        }
    }
    
    private func readRpcResponseAsync() async throws -> NetworkTableEvent {
        _ = try await readDataAsync(length: 4) // data
        _ = try await readRawAsync() // raw
//        let entryId = data.toU16BE()!
//        let entrySeqNum = data.toU16BE(range: 2...)!
        return .continueReading
        //return .updateRpcDefinition(DataEvent(entryId: entryId, seqNum: entrySeqNum, value: rpc))
    }
    
    func readFrameAsync() async throws -> NetworkTableEvent {
        let type = try await readByteAsync()
        print("Reading frame \(type)")
        switch type {
        case 0x00: // Keep Alive
            return .continueReading
        case 0x03: // Server Hello Complete
            self.writeClientHelloComplete()
            return .continueReading
        case 0x04: // Server Hello
            try await readServerHelloAsync()
            return .connected
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
}
