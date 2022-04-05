//
//  TableEntry.swift
//  OutlineViewer
//
//  Created by Thad House on 3/26/22.
//

import Foundation
import SwiftUI

public class NTTableEntry: ObservableObject {
    @Published public var id: UInt16
    public let entryName: String
    public let displayName: String
    public var entryType: NTEntryType
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
    
    func updateFromNewConnection(entryName: String, entryType: NTEntryType, entryId: UInt16, entryFlags: UInt8, sequenceNumber: UInt16) {
        self.entryType = entryType
        self.id = entryId
        self.entryFlags = entryFlags
        update(event: EntryUpdateEvent(entryType: entryType, entryId: entryId, seqNum: sequenceNumber))
    }
    
    func update(event: EntryUpdateEvent) {
        if (entryType != event.entryType) {
            return
        }
        entryType = event.entryType
        sequenceNumber = event.seqNum
        switch entryType {
        case .Unknown:
            value = "Unknown"
        case .Bool(let bool):
            value = "\(bool)"
        case .Double(let double):
            value = "\(double)"
        case .String(let string):
            value = "\(string)"
        default:
            value = "Array"
//        case .BoolArray(let array):
//            value = "\(bool)"
//        case .DoubleArray(let array):
//            value = "\(bool)"
//        case .StringArray(let array):
//            value = "\(bool)"
//        case .Raw(let array):
//            value = "\(bool)"
//        case .Rpc(let array):
//            value = "\(bool)"
        }
    }
}
