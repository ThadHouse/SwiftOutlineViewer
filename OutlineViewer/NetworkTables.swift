//
//  NetworkTables.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import Network

protocol NetworkTables {
    func setTarget(host: String, port: String) -> Void
    func triggerReconnect() -> Void
    var hasBeenStarted: Bool {get}
}
