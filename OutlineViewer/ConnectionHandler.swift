//
//  ConnectionHandler.swift
//  OutlineViewer
//
//  Created by Thad House on 4/3/22.
//

import Foundation

class ConnectionHandler: ObservableObject, ConnectionCreator {
    @Published var items: [NTEntryTree] = []
    
    @Published var connected: Bool = false
    
    var settings: ConnectionSettings!
    
    func startConnectionInitial() {
        assertionFailure()
    }
    
    func stopConnection() {
        assertionFailure()
    }
    
    init() {
        settings = ConnectionSettings(connectionCreator: self)
    }
    
    func restartConnection() {
        assertionFailure()
    }
}
