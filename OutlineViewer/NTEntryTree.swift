//
//  NTEntryStorage.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation

class NTEntryTree: Identifiable {
    let id: String
    var value: NTTableEntry
    var children: [NTEntryTree]? = nil // Nil is parent
    
    init(id: String, value: NTTableEntry) {
        self.id = id;
        self.value = value
    }
    
    func insertEntry(entry: NTTableEntry, depth: Int) {
        if (depth == entry.keyParents.count) {
            // Leaf
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
        children!.append(NTEntryTree(id: root, value: NTTableEntry(fakeEntry: root)))
        children![children!.count - 1].insertEntry(entry: entry, depth: depth + 1)
        print(children!.count)
    }
}
