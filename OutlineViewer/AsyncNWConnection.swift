//
//  AsyncNWConnection.swift
//  OutlineViewer
//
//  Created by Thad House on 4/6/22.
//

import Foundation
import Network

public class AsyncNWConnection {
    let connection: NWConnection;
    
    init(to endpoint: NWEndpoint, using params: NWParameters) {
        connection = NWConnection(to: endpoint, using: params)
    }
    
    init(host: NWEndpoint.Host, port: NWEndpoint.Port, using params: NWParameters) {
        connection = NWConnection(host: host, port: port, using: params)
    }
    
    func cancel() {
        connection.cancel()
    }
    
    func forceCancel() {
        connection.forceCancel()
    }
    
    private var hasBeenStarted = false
    
    private class SingleConnectState {
        var wasSuccessful = false
    }
    
    enum ConnectionError: Error {
        case cancelled
        case alreadyStarted
        case invalidDataLength
    }
    
    private func configureForMulti(index: Int, completion: @escaping (Bool, Int) -> Void) -> Bool {
        if (hasBeenStarted) {
            return false
        }
        hasBeenStarted = true
        let continuationState = SingleConnectState()
        connection.stateUpdateHandler = {
            state in
            print("State: \(state)")
            switch state {
            case .ready:
                completion(true, index)
                continuationState.wasSuccessful = true
            case .cancelled:
                if (!continuationState.wasSuccessful) {
                    completion(false, index)
                }
            default:
                break
            }
        }
        return true
    }
    
    private func connectForMulti(queue: DispatchQueue) {
        connection.start(queue: queue)
    }
    
    private class MultiSuccessState {
        var wasSuccessful = false
        var connections: [AsyncNWConnection] = []
        var failedCount = 0
    }
    
    static func tryConnectAsync(queue: DispatchQueue, timeout: Double, to endpoints:[NWEndpoint], using params: NWParameters) async -> AsyncNWConnection? {
        return await withCheckedContinuation {
            continuation in
            queue.async {
                let state = MultiSuccessState()
                for ep in endpoints {
                    let conn = AsyncNWConnection(to: ep, using: params)
                    if (conn.configureForMulti(index: state.connections.count, completion: {
                        result, index in
                        if (state.wasSuccessful) {
                            return
                        }
                        if (!result) {
                            state.failedCount += 1
                            if (state.failedCount == state.connections.count) {
                                state.wasSuccessful = true
                                continuation.resume(returning: nil)
                            }
                            return
                        }
                        state.wasSuccessful = true
                        // Cancel all but this
                        for i in 0...state.connections.count {
                            if (i == index) {
                                continue
                            }
                            state.connections[index].forceCancel()
                        }
                        
                        continuation.resume(returning: state.connections[index])
                    })) {
                        state.connections.append(conn)
                    }
                }
                if (state.connections.isEmpty) {
                    continuation.resume(returning: nil)
                    return
                }
                for conn in state.connections {
                    conn.connectForMulti(queue: queue)
                }
                queue.asyncAfter(deadline: .now() + timeout) {
                    if (state.wasSuccessful) {
                        return
                    }
                    state.wasSuccessful = true
                    // Cancel everything, return nil
                    for conn in state.connections {
                        conn.forceCancel()
                    }
                    
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func connectAsync(queue: DispatchQueue) async throws {
        if (hasBeenStarted) {
            throw ConnectionError.alreadyStarted
        }
        hasBeenStarted = true
        return try await withCheckedThrowingContinuation {
            continuation in
            let continuationState = SingleConnectState()
            connection.stateUpdateHandler = {
                state in
                print("State: \(state)")
                switch state {
                case .ready:
                    continuation.resume()
                    continuationState.wasSuccessful = true
                case .cancelled:
                    if (!continuationState.wasSuccessful) {
                        continuation.resume(throwing: ConnectionError.cancelled)
                    }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }
    
    func readDataAsync(length: Int) async throws -> Data {
        return try await withCheckedThrowingContinuation {
            continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) {
                data, context, complete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, data.count == length {
                    continuation.resume(returning: data)
                    return
                }
                continuation.resume(throwing: ConnectionError.invalidDataLength)
            }
        }
    }
    
    func readAsync<T>(type: T.Type) async throws -> T where T: ExpressibleByIntegerLiteral {
        return try await withCheckedThrowingContinuation {
            continuation in
            let countToReceive = MemoryLayout<T>.size
            connection.receive(minimumIncompleteLength: countToReceive, maximumLength: countToReceive) {
                data, context, complete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, data.count == countToReceive {
                    let retVal = data.to(type: T.self)
                    if let retVal = retVal {
                        continuation.resume(returning: retVal)
                        return
                    }
                }
                continuation.resume(throwing: ConnectionError.invalidDataLength)
            }
        }
    }
    
    func send(content: Data?) async throws {
        return try await withCheckedThrowingContinuation {
            continuation in
            connection.send(content: content, completion: .contentProcessed {
                error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            })
        }
    }
}
