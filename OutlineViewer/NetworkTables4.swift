//
//  NetworkTables4.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import Network

class NetworkTables4 : NetworkTables {
    func readFrameAsync() async throws -> NetworkTableEvent {
        return .continueReading
    }
    
    func start(queue: DispatchQueue) {
        
    }
    
    func restart() {
        
    }
    
    func start() {
        
    }
    
    func stop() {
        
    }
    
    var eventHandler: ((NetworkTableEvent) -> Void)?
    
    var hasBeenStarted: Bool {
        connection != nil
    }
    
    private var connection: NWConnection!
    private let entryHandler: NTEntryHandler
    private var host: NWEndpoint.Host? = nil
    private var port: NWEndpoint.Port? = nil
    
    init(entryHandler: NTEntryHandler) {
        self.entryHandler = entryHandler
    }
    
    func setTarget(host: String, port: String) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(port)!
    }
    
    func triggerReconnect() {
        if let connection = connection {
            connection.cancel()
        } else {
            startConnection()
        }
    }
    
    private func startConnection() {
        
        let task = URLSession.shared.webSocketTask(with: URL(string: "ws://192.168.1.35")!)
        task.resume()
        
        task.receive {
            [weak self]
            result in
            switch result {
                
            case .success(let message):
                switch message {
                case .data(let binary):
                    break
                case .string(let string):
                    break
                @unknown default:
                    break
                }
                break
            case .failure(let err):
                break
            }
        }
        
        let params = NWParameters.tcp
        let ip = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
        ip.version = .v4
        let tcp = params.defaultProtocolStack.transportProtocol! as! NWProtocolTCP.Options
        tcp.connectionTimeout = 2
        
        let options = NWProtocolWebSocket.Options()
        
        params.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        
        connection = NWConnection(host: host!, port: port!, using: params)
        connection.stateUpdateHandler = {
            [weak self]
            state in
            print("state: \(state)")
            switch state {
            case .ready:
                break
            case .waiting:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.connection.cancel()
                }
                break
            case .cancelled:
                self?.entryHandler.onDisconnected()
                self?.startConnection()
                break
            default:
                break
            }
        }
        readFrame()
        connection.start(queue: DispatchQueue.main)
    }
    
    private func handleMessage(data: Data, context: NWConnection.ContentContext) {
        guard let metadata = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata else {
            return
        }
        
        switch metadata.opcode {
            
        case .cont:
            break
        case .text:
            break
        case .binary:
            
            break
        case .close:
            break
        default:
            break
        }
    }
    
    private func readFrame() {
        connection.receiveMessage {
            [weak self]
            data, context, complete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty, let context = context {
                self.handleMessage(data: data, context: context)
            }
            
            self.readFrame()
        }
    }
}
