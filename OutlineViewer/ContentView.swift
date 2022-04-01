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

    @StateObject var nt = NTConnectionHandler()
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink("Settings") {
                    VStack {
                        Text("Host")
                        TextField(
                            "Host",
                            text: $nt.host)
                        .multilineTextAlignment(.center)
                        Text("Port")
                        TextField(
                            "Port", text: $nt.port)
                        .multilineTextAlignment(.center)
                        Button("Update") {
                            nt.setTarget()
                        }
                    }
                }
                Text(nt.connected ? "Connected" : "Disconnected")
                List(nt.items, children: \.children) {entry in
                    if entry.children != nil {
                        SelectorView(entry: entry.value)
                    } else {
                        NavigationLink(destination: EditorView(entry: entry.value)) {
                            SelectorView(entry: entry.value)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
