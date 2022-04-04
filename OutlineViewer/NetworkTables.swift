//
//  NetworkTables.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import Network

struct NewEntryEvent {
    let entryName: String
    let entryType: NTEntryType
    let entryId: UInt16
    let entryFlags: UInt8
    let seqNum: UInt16
}

struct DataEvent<T> {
    let entryId: UInt16
    let seqNum: UInt16
    let value: T
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
    case updateBool(DataEvent<Bool>)
    case updateDouble(DataEvent<Double>)
    case updateString(DataEvent<String>)
    case updateBoolArray(DataEvent<[Bool]>)
    case updateDoubleArray(DataEvent<[Double]>)
    case updateStringArray(DataEvent<[String]>)
    case updateRaw(DataEvent<[UInt8]>)
    case updateRpcDefinition(DataEvent<[UInt8]>)
    case updateFlag(FlagUpdate)
    case deleteEntry(DeleteEntry)
    case deleteAllEntries
}

protocol NetworkTables {
    func start(queue: DispatchQueue) -> Void
    func stop() -> Void
    
    var eventHandler: ((_ event: NetworkTableEvent) -> Void)? {get set}
}
