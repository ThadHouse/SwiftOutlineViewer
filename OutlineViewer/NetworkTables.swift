//
//  NetworkTables.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import Network

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
    
    var eventHandler: ((_ event: NetworkTableEvent) -> Void)? {get set}
}
