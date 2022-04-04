//
//  NTContentHandler.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import SwiftUI

class NTConnectionHandler: ConnectionHandler, NTEntryHandler {
    func onConnected() {
        connected = true
        entryDictionaryInt.removeAll()
        entryDictionaryString.removeAll()
        refreshEntries()
    }
    
    private var doReconnect = false
    
    func onDisconnected() {
        connected = false
        nt = nil
        if (doReconnect) {
            startConnectionInternal()
        }
    }
    
    var entryDictionaryInt: Dictionary<UInt16, NTTableEntry> = Dictionary<UInt16, NTTableEntry>()
    var entryDictionaryString: Dictionary<String, NTTableEntry> = Dictionary<String, NTTableEntry>()
    
    func addEntry(entry: NTTableEntry) {
        entryDictionaryInt[entry.id] = entry
        entryDictionaryString[entry.entryName] = entry
        refreshEntries()
    }
    
    func newEntry(entryName: String, entryType: NTEntryType, entryId: UInt16, entryFlags: UInt8, sequenceNumber: UInt16) {
        if let entry = entryDictionaryString[entryName] {
            entryDictionaryString.removeValue(forKey: entryName)
            entryDictionaryInt.removeValue(forKey: entry.id)
        }
        if (!entryName.starts(with: "/")) {
            return
        }
        let newEntry = NTTableEntry(entryName: entryName, entryId: entryId, entryType: entryType, entryFlags: entryFlags, sequenceNumber: sequenceNumber)
        if (newEntry.keyParents.isEmpty) {
            return
        }
        addEntry(entry: newEntry)
    }
    
    func setDouble(entryId: UInt16, sequenceNumber: UInt16, value: Double) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == .Double) {
                entry.value = "\(value)"
                entry.sequenceNumber = sequenceNumber
            }
        }
    }
    
    func setBoolean(entryId: UInt16, sequenceNumber: UInt16, value: Bool) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == .Bool) {
                entry.value = "\(value)"
                entry.sequenceNumber = sequenceNumber
            }
        }
    }
    
    func setString(entryId: UInt16, sequenceNumber: UInt16, value: String) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == .String) {
                entry.value = "\(value)"
                entry.sequenceNumber = sequenceNumber
            }
        }
    }
    
    func setDoubleArray(entryId: UInt16, sequenceNumber: UInt16, value: [Double]) {
        
    }
    
    func setBooleanArray(entryId: UInt16, sequenceNumber: UInt16, value: [Bool]) {
        
    }
    
    func setStringArray(entryId: UInt16, sequenceNumber: UInt16, value: [String]) {
        
    }
    
    func setRaw(entryId: UInt16, sequenceNumber: UInt16, value: [UInt8]) {
        
    }
    
    func setRpcDefinition(entryId: UInt16, sequenceNumber: UInt16, value: [UInt8]) {
        
    }
    
    func entryFlagsUpdated(entryId: UInt16, newFlags: UInt8) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == .String) {
                entry.entryFlags = newFlags
            }
        }
    }
    
    func deleteEntry(entryId: UInt16) {
        let entry = entryDictionaryInt.removeValue(forKey: entryId)
        if let entry = entry {
            entryDictionaryString.removeValue(forKey: entry.entryName)
        }
        
        if (entryDictionaryInt.count != entryDictionaryString.count) {
            // Disconnect, bad state
            self.restartConnection()
        } else {
            refreshEntries()
        }
    }
    
    func deleteAllEntries() {
        entryDictionaryInt.removeAll()
        entryDictionaryString.removeAll()
        refreshEntries()
    }
    
    func insertEntry(entry: NTTableEntry) {
        let root = String(entry.keyParents[0])
        
        for item in items {
            if (item.id == root) {
                item.insertEntry(entry: entry, depth: 1)
                return
            }
        }
        items.append(NTEntryTree(id: root, value: NTTableEntry(fakeEntry: root)))
        items[items.count - 1].insertEntry(entry: entry, depth: 1)
    }
    
    func refreshEntries() {
        items.removeAll()
        
        for item in entryDictionaryInt {
            insertEntry(entry: item.value)
        }
    }
    
    func startConnectionInternal() {
        assert(nt == nil)
        doReconnect = false
        nt = NetworkTables3(host: settings.host, port: settings.port)
        guard var nt = nt else {
            assertionFailure()
            return
        }
        nt.eventHandler = {
            [weak self]
            event in
            guard let self = self else {
                return
            }
            switch event {
                
            case .connected:
                self.onConnected()
            case .disconnected:
                self.onDisconnected()
            case .newEntry(let entry):
                self.newEntry(entryName: entry.entryName, entryType: entry.entryType, entryId: entry.entryId, entryFlags: entry.entryFlags, sequenceNumber: entry.seqNum)
            case .updateBool(let entry):
                self.setBoolean(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateDouble(let entry):
                self.setDouble(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateString(let entry):
                self.setString(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateBoolArray(let entry):
                self.setBooleanArray(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateDoubleArray(let entry):
                self.setDoubleArray(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateStringArray(let entry):
                self.setStringArray(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateRaw(let entry):
                self.setRaw(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateRpcDefinition(let entry):
                self.setRpcDefinition(entryId: entry.entryId, sequenceNumber: entry.seqNum, value: entry.value)
            case .updateFlag(let entry):
                self.entryFlagsUpdated(entryId: entry.entryId, newFlags: entry.flags)
            case .deleteEntry(let entry):
                self.deleteEntry(entryId: entry.entryId)
            case .deleteAllEntries:
                self.deleteAllEntries()
            }
        }
        nt.start(queue: DispatchQueue.main)
    }
    
    override func restartConnection() {
        if let nt = nt {
            doReconnect = true
            nt.stop()
        } else {
            startConnectionInternal()
        }
    }
    
    override func startConnectionInitial() {
        startConnectionInternal()
    }
    
    override func stopConnection() {
        if let nt = nt {
            doReconnect = false
            nt.stop()
        } else {
            startConnectionInternal()
        }
    }
    
    var nt: NetworkTables?
    
    override init() {
        super.init()
        settings = ConnectionSettings(connectionCreator: self)

    }
}
