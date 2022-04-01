//
//  TableEntry.swift
//  OutlineViewer
//
//  Created by Thad House on 3/26/22.
//

import Foundation
import SwiftUI

public class NTTableEntry: ObservableObject {
    public let id: UInt16
    public let entryName: String
    public let displayName: String
    public let entryType: NTEntryType
    public let keyParents: [Substring]
    @Published public var entryFlags: UInt8
    
   // @Published public var children: [TableEntry]? = nil
    @Published public var value: String = ""
    
    init(entryName: String, entryId: UInt16, entryType: NTEntryType, entryFlags: UInt8) {
        self.entryName = entryName
        self.id = entryId
        self.entryType = entryType
        // Find last slash
        let potentialEndSlash = entryName.lastIndex(of: "/")
        if let endSlash = potentialEndSlash {
            self.displayName = String(entryName[endSlash...])
        } else {
            self.displayName = entryName
        }
        self.keyParents = entryName.split(separator: "/")
        self.entryFlags = entryFlags
    }
    
    init(fakeEntry: String) {
        self.id = 0
        self.entryName = fakeEntry
        self.displayName = fakeEntry
        self.entryType = .Unknown
        self.keyParents = []
        self.entryFlags = 0
    }
}
