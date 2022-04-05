//
//  NetworkTables.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation

public enum NTEntryType {
    case Unknown
    case Bool(Bool)
    case Double(Double)
    case String(String)
    case BoolArray([Bool])
    case DoubleArray([Double])
    case StringArray([String])
    case Raw([UInt8])
    case Rpc([UInt8])
}

func !=(lhs: NTEntryType, rhs: NTEntryType) -> Bool {
    return !(lhs == rhs)
}

func ==(lhs: NTEntryType, rhs: NTEntryType) -> Bool {
    switch (lhs, rhs) {
    case (.Unknown, .Unknown):
        return true
    case (.Bool(_), .Bool(_)):
        return true
    case ( .Double(_),  .Double(_)):
        return true
    case ( .String(_),  .String(_)):
        return true
    case ( .BoolArray(_),  .BoolArray(_)):
        return true
    case ( .DoubleArray(_),  .DoubleArray(_)):
        return true
    case ( .StringArray(_),  .StringArray(_)):
        return true
    case ( .Raw(_),  .Raw(_)):
        return true
    case ( .Rpc(_),  .Rpc(_)):
        return true
    default:
        return false
    }
}

struct NewEntryEvent {
    let entryName: String
    let entryType: NTEntryType
    let entryId: UInt16
    let entryFlags: UInt8
    let seqNum: UInt16
}

struct EntryUpdateEvent {
    let entryType: NTEntryType
    let entryId: UInt16
    let seqNum: UInt16
}

struct FlagUpdate {
    let entryId: UInt16
    let flags: UInt8
}

struct DeleteEntry {
    let entryId: UInt16
}

enum NetworkTableEvent {
    case startingInitialEntries
    case connected
    case disconnected
    case newEntry(NewEntryEvent)
    case updateEntry(EntryUpdateEvent)
    case updateFlag(FlagUpdate)
    case deleteEntry(DeleteEntry)
    case deleteAllEntries
    case continueReading
}


protocol NetworkTables {
    func start(queue: DispatchQueue) -> Void
    func stop() -> Void
    
    func readFrameAsync() async throws -> NetworkTableEvent
}
