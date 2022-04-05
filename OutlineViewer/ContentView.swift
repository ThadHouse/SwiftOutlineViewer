//
//  ContentView.swift
//  OutlineViewer
//
//  Created by Thad House on 3/26/22.
//

import SwiftUI

struct EditorView: View {
    @ObservedObject var entry: NTTableEntry
    
    var body: some View {
        VStack {
            Text("Name: \(entry.entryName)")
            Text("Id: \(entry.id)")
            Text("Value: \(entry.value)")
            Text("Flags: \(String(entry.entryFlags, radix: 2))")
            Text("SeqNum: 0x\(String(entry.sequenceNumber, radix: 16))")
        }
    }
}

struct SelectorView: View {
    @ObservedObject var entry: NTTableEntry
    
    var body: some View {
        Text("\(entry.displayName): \(entry.value)")
    }
}

struct ContentView: View {
    var startNt = true
    @State private var navigateToSettings = false

    @StateObject var nt: ConnectionHandler = NTConnectionHandler()
    
    var body: some View {
        NavigationView {
            VStack {
                List(nt.items, children: \.children) {entry in
                    if entry.children != nil {
                        SelectorView(entry: entry.value)
                    } else {
                        NavigationLink(destination: EditorView(entry: entry.value)) {
                            SelectorView(entry: entry.value)
                        }
                    }
                }
                .listStyle(.grouped)
                NavigationLink(destination: SettingsView(nt: nt.settings),
                               isActive: $navigateToSettings,
                               label: {})
            }
            .ignoresSafeArea(edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("OutlineViewer")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if nt.connected {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { navigateToSettings = true }) {
                        Text("Settings")
                    }
                }
            }
            .onAppear {
                if (startNt) {
                    nt.startConnectionInitial()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(startNt: false)
    }
}
