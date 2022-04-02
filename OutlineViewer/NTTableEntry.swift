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
    @Published public var value: String = ""
    @Published public var sequenceNumber: UInt16
    
    init(entryName: String, entryId: UInt16, entryType: NTEntryType, entryFlags: UInt8, sequenceNumber: UInt16) {
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
        self.sequenceNumber = sequenceNumber
    }
    
    init(fakeEntry: String) {
        self.id = 0
        self.entryName = fakeEntry
        self.displayName = fakeEntry
        self.entryType = .Unknown
        self.keyParents = []
        self.entryFlags = 0
        self.sequenceNumber = 0
    }
}
