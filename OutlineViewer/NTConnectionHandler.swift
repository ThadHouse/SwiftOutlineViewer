//
//  NTContentHandler.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import SwiftUI

class NTConnectionHandler: ConnectionHandler {//, NTEntryHandler {
    
    func onStartingInitialEntries() {
        entryDictionaryInt.removeAll(keepingCapacity: true)
        entryDictionaryStringBackup.removeAll(keepingCapacity: true)
        
        let tempString = entryDictionaryStringBackup
        entryDictionaryStringBackup = entryDictionaryString
        entryDictionaryString = tempString

        refreshEntries()
    }
    
    func onConnected() {
        connected = true
        // TODO Pinned Entries
        entryDictionaryStringBackup.removeAll(keepingCapacity: true)
    }
    
    func onDisconnected() {
        connected = false
    }
    
    var entryDictionaryInt: Dictionary<UInt16, NTTableEntry> = Dictionary<UInt16, NTTableEntry>()
    var entryDictionaryString: Dictionary<String, NTTableEntry> = Dictionary<String, NTTableEntry>()
    
    var entryDictionaryStringBackup: Dictionary<String, NTTableEntry> = Dictionary<String, NTTableEntry>()
    
    func addEntry(entry: NTTableEntry) {
        entryDictionaryInt[entry.id] = entry
        entryDictionaryString[entry.entryName] = entry
        refreshEntries()
    }
    
    func newEntry(entryName: String, entryType: NTEntryType, entryId: UInt16, entryFlags: UInt8, sequenceNumber: UInt16) {
        // Check to see if existing entries
        let previousEntry = entryDictionaryStringBackup.removeValue(forKey: entryName)
        if let previousEntry = previousEntry {
            previousEntry.updateFromNewConnection(entryName: entryName, entryType: entryType, entryId: entryId, entryFlags: entryFlags, sequenceNumber: sequenceNumber)
            addEntry(entry: previousEntry)
            return
        }
        
        
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
    
    func entryFlagsUpdated(entryId: UInt16, newFlags: UInt8) {
        if let entry = entryDictionaryInt[entryId] {
            entry.entryFlags = newFlags
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
    
    private var runTask: Task<(), Never>?
    
    @MainActor func runConnection() async {
        let nt = NetworkTables3(host: settings.host, port: settings.port)
        nt.start(queue: DispatchQueue.main)
        do {
            while (!Task.isCancelled) {
                let event = try await nt.readFrameAsync()
                switch event {
                case .startingInitialEntries:
                    onStartingInitialEntries()
                case .connected:
                    onConnected()
                case .disconnected:
                    onDisconnected()
                    nt.stop()
                    return
                case .newEntry(let newEntryEvent):
                    self.newEntry(entryName: newEntryEvent.entryName, entryType: newEntryEvent.entryType, entryId: newEntryEvent.entryId, entryFlags: newEntryEvent.entryFlags, sequenceNumber: newEntryEvent.seqNum)
                    break
                case .updateEntry(let entryUpdateEvent):
                    if let entry = entryDictionaryInt[entryUpdateEvent.entryId] {
                        entry.update(event: entryUpdateEvent)
                    }
                    break
                case .updateFlag(let flagUpdate):
                    entryFlagsUpdated(entryId: flagUpdate.entryId, newFlags: flagUpdate.flags)
                case .deleteEntry(let deleteEntry):
                    self.deleteEntry(entryId: deleteEntry.entryId)
                case .deleteAllEntries:
                    deleteAllEntries()
                case .continueReading:
                    break
                }
            }
        } catch (let err) {
            print("err \(err)")
        }
        connected = false
        nt.stop()
    }
    
    @MainActor func connectionLoop(oldRunTask: Task<(), Never>?) async {
        _ = await oldRunTask?.result
        while (!Task.isCancelled) {
            await runConnection()
        }
    }
    
    override func restartConnection() {
        let oldRunTask = runTask
        oldRunTask?.cancel()
        runTask = Task {
            await connectionLoop(oldRunTask: oldRunTask)
        }
    }
    
    override func stopConnection() {
        runTask?.cancel()
    }
    
   // var nt: NetworkTables?
    
    override init() {
        super.init()
        settings = ConnectionSettings(connectionCreator: self)

    }
}
