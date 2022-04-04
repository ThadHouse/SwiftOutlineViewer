//
//  NT3WithFramer.swift
//  OutlineViewer
//
//  Created by Thad House on 4/1/22.
//

import Foundation
import Network

class NT3WithFramer: NetworkTables {
    
    private let connection: NWConnection
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    
    init(host: String, port: String) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(port)!
        let params = NWParameters.tcp
        let ip = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
        ip.version = .v4
        let tcp = params.defaultProtocolStack.transportProtocol! as! NWProtocolTCP.Options
        tcp.connectionTimeout = 2
        tcp.noDelay = true
        
        params.defaultProtocolStack.applicationProtocols.insert(NWProtocolFramer.Options(definition: NTProtocolFramer.definition), at: 0)
        
        connection = NWConnection(host: self.host, port: self.port, using: params)
    }
    
    var eventHandler: ((_ event: NetworkTableEvent) -> Void)? = nil
    
    func start(queue: DispatchQueue) {
        
        connection.stateUpdateHandler = {
            [weak self]
            state in
            print("state: \(state)")
            switch (state) {
            case .ready:
                self?.eventHandler!(.connected)
                self?.writeClientHello()
            case .waiting:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.connection.cancel()
                }
            case .cancelled:
                self?.eventHandler!(.disconnected)
                break;
            default:
                break
            }
        }
        readFrame()
        connection.start(queue: queue)
    }
    
    func stop() {
        connection.cancel()
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
            eventHandler!(.updateBool(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! Bool)))
        case .Double:
            eventHandler!(.updateDouble(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! Double)))
        case .String:
            eventHandler!(.updateString(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! String)))
        case .BoolArray:
            eventHandler!(.updateBoolArray(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! [Bool])))
        case .DoubleArray:
            eventHandler!(.updateDoubleArray(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! [Double])))
        case .StringArray:
            eventHandler!(.updateStringArray(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! [String])))
        case .Raw:
            eventHandler!(.updateRaw(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! [UInt8])))
        case .Rpc:
            eventHandler!(.updateRpcDefinition(DataEvent(entryId: entryId, seqNum: sequenceNumber, value: message["value"] as! [UInt8])))
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
                self?.eventHandler!(.newEntry(NewEntryEvent(entryName: data.entryName, entryType: data.entryType, entryId: data.entryId, entryFlags: data.entryFlags, seqNum: data.entrySequenceNumber)))
                self?.handleEntry(entryId: data.entryId, entryType: data.entryType, sequenceNumber: data.entrySequenceNumber, message: message)
            } else if (type == .EntryUpdate) {
                let data = message["data"] as! NT3EntryUpdate
                self?.handleEntry(entryId: data.entryId, entryType: data.entryType, sequenceNumber: data.entrySequenceNumber, message: message)
            }
            
            self?.readFrame()
        }
    }
}
