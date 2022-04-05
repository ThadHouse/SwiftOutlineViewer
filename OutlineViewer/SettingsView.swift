//
//  SettingsView.swift
//  OutlineViewer
//
//  Created by Thad House on 4/3/22.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var nt: ConnectionSettings
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Text("Connection")
                        .font(.largeTitle)
                    Image(systemName: nt.connected ? "circle.fill" : "circle")
                        .foregroundColor(nt.connected ? .green : .red)
                }
                Text("Host")
                    .bold()
                TextField(
                    "Host",
                    text: $nt.host)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
                Text("Port")
                    .bold()
                TextField(
                    "Port", text: $nt.port)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
                HStack {
                    Button("Update") {
                        nt.restartConnection()
                    }
                    .padding()
                    .buttonStyle(.bordered)
                    Button("Disconnect") {
                        nt.stopConnection()
                    }
                    .padding()
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(nt: ConnectionSettings(connectionCreator: MockConnectionCreator()))
    }
}

