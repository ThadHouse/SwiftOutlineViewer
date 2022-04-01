//
//  ContentView.swift
//  OutlineViewer
//
//  Created by Thad House on 3/26/22.
//

import SwiftUI

class ContentHandler: ObservableObject, EntryHandler {
    var entryDictionaryInt: Dictionary<UInt16, TableEntry> = Dictionary<UInt16, TableEntry>()
    var entryDictionaryString: Dictionary<String, TableEntry> = Dictionary<String, TableEntry>()
    
    func addEntry(entry: TableEntry) {
        entryDictionaryInt[entry.id] = entry
        entryDictionaryString[entry.entryName] = entry
        refreshEntries()
    }
    
    func newEntry(entryName: String, entryType: UInt8, entryId: UInt16, entryFlags: UInt8) {
        if let entry = entryDictionaryString[entryName] {
            entryDictionaryString.removeValue(forKey: entryName)
            entryDictionaryInt.removeValue(forKey: entry.id)
        }
        if (!entryName.starts(with: "/")) {
            return
        }
        let newEntry = TableEntry(entryName: entryName, entryId: entryId, entryType: entryType)
        if (newEntry.keyParents.isEmpty) {
            return
        }
        addEntry(entry: newEntry)
    }
    
    func setDouble(entryId: UInt16, value: Double) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == 1) {
                entry.value = "\(value)"
            }
        }
    }
    
    func setBoolean(entryId: UInt16, value: Bool) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == 0) {
                entry.value = "\(value)"
            }
        }
    }
    
    func setString(entryId: UInt16, value: String) {
        if let entry = entryDictionaryInt[entryId] {
            if (entry.entryType == 2) {
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
        
    }
    
    func deleteEntry(entryId: UInt16) {
        
    }
    
    func deleteAllEntries() {
        
    }
    
    func insertEntry(entry: TableEntry) {
        let root = String(entry.keyParents[0])
        
        for item in items {
            if (item.id == root) {
                item.insertEntry(entry: entry, depth: 1)
                return
            }
        }
        print("Creating root \(root)")
        items.append(EntryStorage(id: root, value: TableEntry(fakeEntry: root)))
        items[items.count - 1].insertEntry(entry: entry, depth: 1)
    }
    
    func refreshEntries() {
        items.removeAll()
        
        for item in entryDictionaryInt {
            insertEntry(entry: item.value)
        }
    }
    
    @Published var ntState: NTState = NTState()
    
    @Published var items: [EntryStorage] = []
    
    var nt: NetworkTables3!
    
    init() {
        nt = NetworkTables3(entryHandler: self)
    }
}

class EntryStorage: Identifiable {
    let id: String
    var value: TableEntry
    var children: [EntryStorage]? = nil // Nil is parent
    
    init(id: String, value: TableEntry) {
        self.id = id;
        self.value = value
    }
    
    func insertEntry(entry: TableEntry, depth: Int) {
        if (depth == entry.keyParents.count) {
            // Leaf
            print("inserted \(entry.entryName) into \(id)")
            value = entry
            return
        }
        if (children == nil) {
            children = []
        }
        let root = String(entry.keyParents[depth])
        for item in children! {
            if (item.id == root) {
                item.insertEntry(entry: entry, depth: depth + 1)
                return
            }
        }
        print("Creating \(root) in \(id)")
        children!.append(EntryStorage(id: root, value: TableEntry(fakeEntry: root)))
        children![children!.count - 1].insertEntry(entry: entry, depth: depth + 1)
        print(children!.count)
    }
}

struct EditorView: View {
    @ObservedObject var entry: TableEntry
    
    var body: some View {
        VStack {
            Text("Name: \(entry.entryName)")
            Text("Id: \(entry.id)")
            Text("Value: \(entry.value)")
        }
    }
}

struct SelectorView: View {
    @ObservedObject var entry: TableEntry
    
    var body: some View {
        Text("\(entry.displayName): \(entry.value)")
    }
}

struct ContentView: View {

    @StateObject var nt = ContentHandler()
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink("Settings") {
                    VStack {
                        Text("Team Number")
                        TextField(
                            "Team Number",
                            text: $nt.ntState.teamNumber)
                        .multilineTextAlignment(.center)
                        Text("Port")
                        TextField(
                            "Port", text: $nt.ntState.port)
                        .multilineTextAlignment(.center)
                        Button("Update") {
                            nt.nt.start(state: nt.ntState)
                        }
                    }
                }
                Text(nt.ntState.connected ? "Connected" : "Disconnected")
                List(nt.items, children: \.children) {entry in
                    if entry.children != nil {
                        SelectorView(entry: entry.value)
                    } else {
                        NavigationLink(destination: EditorView(entry: entry.value)) {
                            SelectorView(entry: entry.value)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
