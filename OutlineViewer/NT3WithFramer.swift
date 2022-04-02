//
//  NT3WithFramer.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import Network

class NT3WithFramer: NetworkTables {
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
        let params = NWParameters.tcp
        let ip = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
        ip.version = .v4
        let tcp = params.defaultProtocolStack.transportProtocol! as! NWProtocolTCP.Options
        tcp.connectionTimeout = 2
        tcp.noDelay = true
        
        params.defaultProtocolStack.applicationProtocols.insert(NWProtocolFramer.Options(definition: NTProtocolFramer.definition), at: 0)
        
        connection = NWConnection(host: host!, port: port!, using: params)
        connection.stateUpdateHandler = {
            [weak self]
            state in
            print("state: \(state)")
            switch (state) {
            case .ready:
                self?.entryHandler.onConnected()
                self?.writeClientHello()
            case .waiting:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.connection.cancel()
                }
            case .cancelled:
                self?.entryHandler.onDisconnected()
                self?.startConnection()
                break;
            default:
                break
            }
        }
        readFrame()
        connection.start(queue: DispatchQueue.main)
    }
    
    private func writeClientHello() {
        connection.send(content: [0x01, 0x03, 0x00, 0], completion: .contentProcessed {
            [weak self]
            error in
            if (error != nil) {
                self?.connection.cancel()
            }
        })
    }
    
    private func writeClientHelloComplete() {
        connection.send(content: [0x05], completion: .contentProcessed {
            [weak self]
            error in
            if (error != nil) {
                self?.connection.cancel()
            }
        })
    }
    
    private func handleEntry(entryId: UInt16, entryType: NTEntryType, sequenceNumber: UInt16, message: NWProtocolFramer.Message) {
        switch entryType {
        case .Bool:
            entryHandler.setBoolean(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! Bool)
        case .Double:
            entryHandler.setDouble(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! Double)
        case .String:
            entryHandler.setString(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! String)
        case .BoolArray:
            entryHandler.setBooleanArray(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! [Bool])
        case .DoubleArray:
            entryHandler.setDoubleArray(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! [Double])
        case .StringArray:
            entryHandler.setStringArray(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! [String])
        case .Raw:
            entryHandler.setRaw(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! [UInt8])
        case .Rpc:
            entryHandler.setRpcDefinition(entryId: entryId, sequenceNumber: sequenceNumber, value: message["value"] as! [UInt8])
        default:
            break
        }
    }
    
    private func readFrame() {
        connection.receiveMessage {//(minimumIncompleteLength: 1, maximumLength: 1) {//(completion:
            [weak self]
            data, context, isComplete, error in
            guard let message = context?.protocolMetadata(definition: NTProtocolFramer.definition) as? NWProtocolFramer.Message else {
                self?.connection.cancel()
                return
            }
            let type = message["type"] as! NT3MessageType
            
            if (type == .ServerHelloComplete) {
                self?.writeClientHelloComplete()
            } else if (type == .EntryAssignment) {
                let data = message["data"] as! NT3EntryAssignment
                self?.entryHandler.newEntry(entryName: data.entryName, entryType: data.entryType, entryId: data.entryId, entryFlags: data.entryFlags, sequenceNumber: data.entrySequenceNumber)
                self?.handleEntry(entryId: data.entryId, entryType: data.entryType, sequenceNumber: data.entrySequenceNumber, message: message)
            } else if (type == .EntryUpdate) {
                let data = message["data"] as! NT3EntryUpdate
                self?.handleEntry(entryId: data.entryId, entryType: data.entryType, sequenceNumber: data.entrySequenceNumber, message: message)
            }
            
            self?.readFrame()
        }
    }
}
