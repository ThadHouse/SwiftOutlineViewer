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
                Text("Connection")
                    .font(.largeTitle)
                Text("Host")
                    .bold()
                TextField(
                    "Host",
                    text: $nt.host)
                .multilineTextAlignment(.center)
                Text("Port")
                    .bold()
                TextField(
                    "Port", text: $nt.port)
                .multilineTextAlignment(.center)
                Button("Update") {
                    nt.restartConnection()
                }
                Button("Disconnect") {
                    nt.stopConnection()
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(nt: ConnectionSettings(connectionCreator: MockConnectionCreator()))
    }
}

