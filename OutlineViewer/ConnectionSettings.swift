//
//  SettingsProtocol.swift
//  OutlineViewer
//
//  Created by Thad House on 4/3/22.
//

import Foundation
import SwiftUI

class ConnectionSettings: ObservableObject {
    @AppStorage("HostName") var host: String = "localhost"
    @AppStorage("Port") var port: String = "1735"
    @Published var connected: Bool = false
    
    func getHost() -> String {
        if let team = Int(host) {
            return "roborio-\(team)-frc.local"
        } else {
            return host
        }
    }
    
    let connectionCreator: ConnectionCreator
    
    init(connectionCreator: ConnectionCreator) {
        self.connectionCreator = connectionCreator
    }
    
    func restartConnection() {
        connectionCreator.restartConnection()
    }
    
    func stopConnection() {
        connectionCreator.stopConnection()
    }
}
