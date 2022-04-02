//
//  NTContentHandler.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import SwiftUI

class NTConnectionHandler: ObservableObject, NTEntryHandler {
    func onConnected() {
        connected = true
        entryDictionaryInt.removeAll()
        entryDictionaryString.removeAll()
        refreshEntries()
    }
    
    func onDisconnected() {
        connected = false
        nt.triggerReconnect()
    }
    
    var entryDictionaryInt: Dictionary<UInt16, NTTableEntry> = Dictionary<UInt16, NTTableEntry>()
    var entryDictionaryString: Dictionary<String, NTTableEntry> = Dictionary<String, NTTableEntry>()
    
    func addEntry(entry: NTTableEntry) {
        entryDictionaryInt[entry.id] = entry
        entryDictionaryString[entry.entryName] = entry
        refreshEntries()
    }
    
    func newEntry(entryName: String, entryType: NTEntryType, entryId: UInt16, entryFlags: UInt8) {
        if let entry = entryDictionaryString[entryName] {
            entryDictionaryString.removeValue(forKey: entryName)
            entryDictionaryInt.removeValue(forKey: entry.id)
        }
        if (!entryName.starts(with: "/")) {
            return
        }
        let newEntry = NTTableEntry(entryName: entryName, entryId: entryId, entryType: entryType, entryFlags: entryFlags)
        if (newEntry.keyParents.isEmpty) {
            return
        }
        addEntry(entry: newEntry)
    }
    
    func setDouble(entryId: UInt16, value: Double) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == .Bool) {
                entry.value = "\(value)"
            }
        }
    }
    
    func setBoolean(entryId: UInt16, value: Bool) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == .Double) {
                entry.value = "\(value)"
            }
        }
    }
    
    func setString(entryId: UInt16, value: String) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == .String) {
                entry.value = "\(value)"
            }
        }
    }
    
    func setDoubleArray(entryId: UInt16, value: [Double]) {
        
    }
    
    func setBooleanArray(entryId: UInt16, value: [Bool]) {
        
    }
    
    func setStringArray(entryId: UInt16, value: [String]) {
        
    }
    
    func setRaw(entryId: UInt16, value: [UInt8]) {
        
    }
    
    func setRpcDefinition(entryId: UInt16, value: [UInt8]) {
        
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
            nt.triggerReconnect()
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
    
    func setTarget() {
        nt.setTarget(host: host, port: port)
        nt.triggerReconnect()
    }
    
    @Published var items: [NTEntryTree] = []
    
    @Published var connected: Bool = false
    
    @AppStorage("HostName") var host: String = "localhost"
    @AppStorage("Port") var port: String = "1735"
    
    var nt: NetworkTables!
    
    init() {
        nt = NT3WithFramer(entryHandler: self)
    }
}
