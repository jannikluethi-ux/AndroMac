import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Andromac")
                .font(.largeTitle.bold())
            
            Text(model.statusMessage)
                .foregroundStyle(.secondary)
            
            Divider()
            
            Text("Connected devices")
                .font(.headline)
            
            if model.devices.isEmpty {
                Text("No Android devices detected.\nConnect a phone via USB and choose File Transfer.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                List(model.devices) { device in
                    VStack(alignment: .leading) {
                        Text(device.displayName)
                            .font(.body.weight(.medium))
                        Text(device.id.value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let err = model.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            Text("M1–M4 ready. Set phone to File transfer. Finder domain registers on connect.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 320)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    
    var body: some View {
        Text(model.statusMessage)
        Divider()
        if model.devices.isEmpty {
            Text("No devices")
        } else {
            ForEach(model.devices) { d in
                Text(d.displayName)
            }
        }
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
