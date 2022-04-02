//
//  EntryHandler.swift
//  OutlineViewer
//
//  Created by Thad House on 3/31/22.
//

import Foundation

public enum NTEntryType {
    case Unknown
    case Bool
    case Double
    case String
    case BoolArray
    case DoubleArray
    case StringArray
    case Raw
    case Rpc
}

protocol NTEntryHandler {
    func newEntry(entryName: String, entryType: NTEntryType, entryId: UInt16, entryFlags: UInt8, sequenceNumber: UInt16)
    
    func setDouble(entryId: UInt16, sequenceNumber: UInt16, value: Double)
    func setBoolean(entryId: UInt16, sequenceNumber: UInt16, value: Bool)
    func setString(entryId: UInt16, sequenceNumber: UInt16, value: String)
    
    func setDoubleArray(entryId: UInt16, sequenceNumber: UInt16, value: [Double])
    func setBooleanArray(entryId: UInt16, sequenceNumber: UInt16, value: [Bool])
    func setStringArray(entryId: UInt16, sequenceNumber: UInt16, value: [String])
    
    func setRaw(entryId: UInt16, sequenceNumber: UInt16, value: [UInt8])
    
    func setRpcDefinition(entryId: UInt16, sequenceNumber: UInt16, value: [UInt8])
    
    func entryFlagsUpdated(entryId: UInt16, newFlags: UInt8)
    
    func deleteEntry(entryId: UInt16)
    
    func deleteAllEntries()
    
    func onConnected()
    
    func onDisconnected()
}
