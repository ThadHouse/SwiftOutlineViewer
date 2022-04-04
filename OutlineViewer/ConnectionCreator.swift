//
//  ConnectionMapper.swift
//  OutlineViewer
//
//  Created by Thad House on 4/3/22.
//

import Foundation
import SwiftUI

protocol ConnectionCreator {
    func restartConnection() -> Void
    func stopConnection() -> Void
}

public class MockConnectionCreator: ConnectionCreator {
    func restartConnection() {
        
    }
    
    func stopConnection() {
        
    }
    
    
}
