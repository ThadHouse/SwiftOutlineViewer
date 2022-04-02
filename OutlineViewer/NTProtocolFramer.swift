//
//  NTProtocolFramer.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import Network

enum NT3MessageType: UInt8 {
    case KeepAlive = 0
    case ClientHello = 1
    case ProtocolVersionUnsupported = 2
    case ServerHelloComplete = 3
    case ServerHello = 4
    case ClientHelloComplete = 5
    case EntryAssignment = 0x10
    case EntryUpdate = 0x11
    case EntryFlagsUpdate = 0x12
    case EntryDelete = 0x13
    case ClearAllEntries = 0x14
    case ExecuteRpc = 0x20
    case RpcResponse = 0x21
}

enum NT3EntryType: UInt8 {
    case Unknown = 0xFF
    case Boolean = 0x00
    case Double = 0x01
    case String = 0x02
    case Raw = 0x03
    case BooleanArray = 0x10
    case DoubleArray = 0x11
    case StringArray = 0x12
    case RpcDefinition = 0x20
}

struct NT3ServerHello {
    let flags: UInt8;
    let identity: String
}

struct NT3EntryAssignment {
    let entryName: String
    let entryType: NT3EntryType
    let entryId: UInt16
    let entrySequenceNumber: UInt16
    let entryFlags: UInt8
}

struct NT3EntryUpdate {
    let entryId: UInt16
    let entrySequenceNumber: UInt16
    let entryType: NT3EntryType
}

struct NT3EntryFlagsUpdate {
    let entryId: UInt16
    let entryFlags: UInt8
}

struct NT3EntryDelete {
    let entryId: UInt16
}

struct NT3ClearAllEntries {
    let magic: UInt32
}

class StringStorage {
    var length: UInt64 = 0
    var shift: Int = 0
    var string: String?
    var hasLength = false
    
    func reset() {
        length = 0;
        shift = 0
        hasLength = false
        string = nil
    }
}

class RawStorage {
    var length: UInt64 = 0
    var shift: Int = 0
    var string: [UInt8]?
    var hasLength = false
    
    func reset() {
        length = 0;
        shift = 0
        hasLength = false
        string = nil
    }
}

class ValueStorage {
    var entryType: NT3EntryType = .Unknown
    var hasValue = false
    var boolValue: Bool = false
    var doubleValue: Double = 0
    var stringValue: StringStorage = StringStorage()
    var rawValue: RawStorage = RawStorage()
    var boolArrayValue: [Bool] = []
    var doubleArrayValue: [Double] = []
    var stringArrayValue: [StringStorage] = []
    
    func reset() {
        entryType = .Unknown
        hasValue = false
        stringValue.reset()
        rawValue.reset()
        boolArrayValue.removeAll()
        doubleArrayValue.removeAll()
        stringArrayValue.removeAll()
    }
    
    func toValue() -> Any? {
        switch entryType {
        case .Boolean:
            return boolValue
        case .Double:
            return doubleValue
        case .String:
            return stringValue.string!
        case .Raw:
            return rawValue.string!
        case .BooleanArray:
            return boolArrayValue
        case .DoubleArray:
            return doubleArrayValue
        case .StringArray:
            var newArr: [String] = []
            for item in stringArrayValue {
                newArr.append(item.string!)
            }
            return newArr
        case .RpcDefinition:
            return rawValue.string!
        default:
            return nil
        }
    }
}

class ServerHelloStorage {
    var flags: UInt8?
    var string: StringStorage = StringStorage()
    
    func reset() {
        flags = nil
        string.reset()
    }
}

class EntryAssignmentStorage {
    var entryName: StringStorage = StringStorage()
    var entryId: UInt16 = 0
    var entrySequenceNumber: UInt16 = 0
    var entryFlags: UInt8 = 0
    var hasFixedLengthData = false
    var value: ValueStorage = ValueStorage()
    
    func reset() {
        entryName.reset()
        hasFixedLengthData = false
        value.reset()
    }
}

class EntryUpdateStorage {
    var entryId: UInt16 = 0;
    var entrySequenceNumber: UInt16 = 0
    var hasFixedLengthData = false
    var value: ValueStorage = ValueStorage()
    
    func reset() {
        hasFixedLengthData = false
        value.reset()
    }
}

final class NTProtocolFramer: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: NTProtocolFramer.self)
    
    static let label = "NT"
    
    init(framer: NWProtocolFramer.Instance) {}
    
    func start  (framer: NWProtocolFramer.Instance)
         -> NWProtocolFramer.StartResult { return .ready }
    func stop   (framer: NWProtocolFramer.Instance) -> Bool { return true }
    func wakeup (framer: NWProtocolFramer.Instance) {}
    func cleanup(framer: NWProtocolFramer.Instance) {}
    
    private var messageTypeStore: NT3MessageType? = nil
    
    private var serverHelloStorage: ServerHelloStorage = ServerHelloStorage()
    private var entryAssignmentStorage: EntryAssignmentStorage = EntryAssignmentStorage()
    private var entryUpdateStorage: EntryUpdateStorage = EntryUpdateStorage()
    
    private var failed = false
    
    func reportFailure(framer: NWProtocolFramer.Instance) {
        framer.markFailed(error: .posix(.EINVAL))
        failed = true
    }
    
    func readBool(storage: ValueStorage, framer: NWProtocolFramer.Instance) -> Int? {
        _ = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 1) {
            buffer, complete in
            guard let buffer = buffer, buffer.count == 1 else { return 0 }
            storage.boolValue = buffer.toU8() != 0
            storage.hasValue = true
            return 1
        }
        return storage.hasValue ? nil : 1
    }
    
    func readDouble(storage: ValueStorage, framer: NWProtocolFramer.Instance) -> Int? {
        _ = framer.parseInput(minimumIncompleteLength: 8, maximumLength: 8) {
            buffer, complete in
            guard let buffer = buffer, buffer.count == 8 else { return 0 }
            storage.doubleValue = buffer.toDoubleBE()!
            storage.hasValue = true
            return 8
        }
        return storage.hasValue ? nil : 8
    }
    
    func readValue(storage: ValueStorage, framer: NWProtocolFramer.Instance) -> Int? {
        switch storage.entryType {
            
        case .Unknown:
            reportFailure(framer: framer)
            return 0
        case .Boolean:
            return readBool(storage: storage, framer: framer)
        case .Double:
            return readDouble(storage: storage, framer: framer)
        case .String:
            return readString(storage: storage.stringValue, framer: framer)
//        case .Raw:
//
//        case .BooleanArray:
//
//        case .DoubleArray:
//
//        case .StringArray:
//
//        case .RpcDefinition:
        default:
            break
            
        }
        
        reportFailure(framer: framer)
        return 0
    }
    
    func readString(storage: StringStorage, framer: NWProtocolFramer.Instance) -> Int? {
        if (storage.string != nil) {
            return nil
        }
        
        while (!storage.hasLength) {
            let didParse = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 1) {
                buffer, complete in
                guard let buffer = buffer, buffer.count == 1 else { return 0 }
                let byte: UInt64 = UInt64(buffer.toU8()!)
                storage.length |= (byte & 0x7F) << storage.shift
                storage.shift += 7
                
                if ((byte & 0x80) == 0) {
                    storage.hasLength = true
                }
                
                return 1
            }
            if !didParse {
                return 1
            }
        }
        if (storage.length > Int.max) {
            reportFailure(framer: framer)
            return 0
        }
        let intLen = Int(storage.length)
        
        let didParse = framer.parseInput(minimumIncompleteLength: intLen, maximumLength: intLen) {
            buffer, complete in
            guard let buffer = buffer, buffer.count == intLen else { return 0 }
            let message = String(decoding: buffer, as: UTF8.self)
            storage.string = message
            return intLen
        }
        
        if !didParse {
            return intLen
        }
        
        return nil
    }
    
    func handleKeepAlive(framer:NWProtocolFramer.Instance) -> Int? {
        let metadata = NWProtocolFramer.Message(definition: Self.definition)
        metadata["type"] = NT3MessageType.KeepAlive
        
        framer.deliverInput(data: Data([NT3MessageType.KeepAlive.rawValue]), message: metadata, isComplete: true)
        
        messageTypeStore = nil
        return nil
    }
    
    func handleServerHello(framer: NWProtocolFramer.Instance) -> Int? {
        _ = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 1) {
            buffer, complete in
            guard let buffer = buffer, buffer.count == 1 else { return 0 }
            serverHelloStorage.flags = buffer.toU8()
            return 1
        }
        if (serverHelloStorage.flags == nil) {
            return 1
        }
        let stringRemaining = readString(storage: serverHelloStorage.string, framer: framer)
        if let stringRemaining = stringRemaining {
             return stringRemaining
        }
        
        let metadata = NWProtocolFramer.Message(definition: Self.definition)
        metadata["type"] = NT3MessageType.ServerHello
        metadata["data"] = NT3ServerHello(flags: serverHelloStorage.flags!, identity: serverHelloStorage.string.string!)
        
        framer.deliverInput(data: Data([NT3MessageType.ServerHello.rawValue]), message: metadata, isComplete: true)
        
        messageTypeStore = nil
        serverHelloStorage.reset()
        return nil
    }
    
    func handleServerHelloComplete(framer:NWProtocolFramer.Instance) -> Int? {
        let metadata = NWProtocolFramer.Message(definition: Self.definition)
        metadata["type"] = NT3MessageType.ServerHelloComplete
        
        framer.deliverInput(data: Data([NT3MessageType.ServerHelloComplete.rawValue]), message: metadata, isComplete: true)
        
        messageTypeStore = nil
        return nil
    }
    
    func handleEntryAssignment(framer: NWProtocolFramer.Instance) -> Int? {
        let stringRemaining = readString(storage: entryAssignmentStorage.entryName, framer: framer)
        if let stringRemaining = stringRemaining {
            return stringRemaining
        }
        
        if (!entryAssignmentStorage.hasFixedLengthData) {
            _ = framer.parseInput(minimumIncompleteLength: 6, maximumLength: 6) {
                buffer, complete in
                guard let buffer = buffer, buffer.count == 6 else { return 0 }
                let rawEntry = buffer.toU8()!
                entryAssignmentStorage.value.entryType = NT3EntryType(rawValue: rawEntry)!
                entryAssignmentStorage.entryId = buffer.toU16BE(fromByteOffset: 1)!
                entryAssignmentStorage.entrySequenceNumber = buffer.toU16BE(fromByteOffset: 3)!
                entryAssignmentStorage.entryFlags = buffer.toU8(fromByteOffset: 5)!
                entryAssignmentStorage.hasFixedLengthData = true
                return 6
            }
            if !entryAssignmentStorage.hasFixedLengthData {
                return 6
            }
        }
        
        let valueRemaining = readValue(storage: entryAssignmentStorage.value, framer: framer)
        if let valueRemaining = valueRemaining {
            return valueRemaining
        }
        
        let metadata = NWProtocolFramer.Message(definition: Self.definition)
        metadata["type"] = NT3MessageType.EntryAssignment
        metadata["data"] =
            NT3EntryAssignment(
                entryName: entryAssignmentStorage.entryName.string!,
                entryType: entryAssignmentStorage.value.entryType,
                entryId: entryAssignmentStorage.entryId,
                entrySequenceNumber: entryAssignmentStorage.entrySequenceNumber,
                entryFlags: entryAssignmentStorage.entryFlags)
        metadata["value"] = entryAssignmentStorage.value.toValue()
        
        framer.deliverInput(data: Data([NT3MessageType.EntryAssignment.rawValue]), message: metadata, isComplete: true)
        
        messageTypeStore = nil
        entryAssignmentStorage.reset()
        return nil
    }
    
    func handleEntryUpdate(framer: NWProtocolFramer.Instance) -> Int? {
        if !entryUpdateStorage.hasFixedLengthData {
            _ = framer.parseInput(minimumIncompleteLength: 5, maximumLength: 5) {
                buffer, complete in
                guard let buffer = buffer, buffer.count == 5 else { return 0 }
                entryUpdateStorage.entryId = buffer.toU16BE()!
                entryUpdateStorage.entrySequenceNumber = buffer.toU16BE(fromByteOffset: 2)!
                entryUpdateStorage.value.entryType = NT3EntryType(rawValue: buffer.toU8(fromByteOffset: 4)!)!
                entryUpdateStorage.hasFixedLengthData = true
                return 5
            }
            if !entryUpdateStorage.hasFixedLengthData {
                return 5
            }
        }

        let valueRemaining = readValue(storage: entryUpdateStorage.value, framer: framer)
        if let valueRemaining = valueRemaining {
            return valueRemaining
        }
        
        let metadata = NWProtocolFramer.Message(definition: Self.definition)
        metadata["type"] = NT3MessageType.EntryUpdate
        metadata["data"] =
            NT3EntryUpdate(
                entryId: entryUpdateStorage.entryId,
                entrySequenceNumber: entryUpdateStorage.entrySequenceNumber,
                entryType: entryUpdateStorage.value.entryType)
        metadata["value"] = entryUpdateStorage.value.toValue()
        
        framer.deliverInput(data: Data([NT3MessageType.EntryUpdate.rawValue]), message: metadata, isComplete: true)
        
        messageTypeStore = nil
        entryUpdateStorage.reset()
        return nil
    }

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while !failed {
            framer.parseInput(minimumIncompleteLength: 0, maximumLength: 65535) {
                buffer, complete in
                print("Have \(buffer?.count)")
                return 0
            }
            if messageTypeStore == nil {
                _ = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 1) {
                    buffer, complete in
                    guard let buffer = buffer, buffer.count == 1 else { return 0 }
                    let loadedValue = buffer.toU8()!
                    self.messageTypeStore = NT3MessageType(rawValue: loadedValue)
                    return 1
                }
            }
            guard let messageType = messageTypeStore else {
                return 1
            }
            print("Reading message \(messageType)")
            var moreData: Int? = nil
            switch messageType {
            case .KeepAlive:
                moreData = handleKeepAlive(framer: framer)
                break
            case .ServerHelloComplete:
                moreData = handleServerHelloComplete(framer: framer)
                break
            case .ServerHello:
                moreData = handleServerHello(framer: framer)
                break
            case .EntryAssignment:
                moreData = handleEntryAssignment(framer: framer)
                break
            case .EntryUpdate:
                moreData = handleEntryUpdate(framer: framer)
                break
            case .EntryFlagsUpdate:
                break
            case .EntryDelete:
                break
            case .ClearAllEntries:
                break
            case .ExecuteRpc:
                break
            case .RpcResponse:
                break
//            default:
//                reportFailure(framer: framer)
//                return 0
            case .ClientHello:
                break
            case .ProtocolVersionUnsupported:
                break
            case .ClientHelloComplete:
                break
            }
            
            if let moreData = moreData {
                return moreData
            }
        }
        return 0
    }
    
    func handleOutput(framer     : NWProtocolFramer.Instance,
                      message    : NWProtocolFramer.Message, messageLength: Int,
                      isComplete : Bool)
    {
        try! framer.writeOutputNoCopy(length: messageLength)
    }
}
