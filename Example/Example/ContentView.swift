//
//  ContentView.swift
//  Example
//
//  Created by 熊炬 on 2025/10/31.
//

import SwiftUI
import H3

private struct SampleLocation: Identifiable {
  let id: String
  let name: String
  let latitude: Double
  let longitude: Double
}

struct ContentView: View {
  private let locations: [SampleLocation] = [
    .init(id: "shanghai", name: "Shanghai, CN", latitude: 31.2304, longitude: 121.4737),
    .init(id: "beijing", name: "Beijing, CN", latitude: 39.9042, longitude: 116.4074),
    .init(id: "shenzhen", name: "Shenzhen, CN", latitude: 22.5431, longitude: 114.0579),
    .init(id: "chengdu", name: "Chengdu, CN", latitude: 30.5728, longitude: 104.0668),
    .init(id: "tokyo", name: "Tokyo, JP", latitude: 35.682839, longitude: 139.759455),
  ]

  @State private var selectedLocation = 0
  @State private var resolution = 9

  var body: some View {
    let location = locations[selectedLocation]
    let index = try? H3.index(from: GeoCoord(latitude: location.latitude, longitude: location.longitude), resolution: resolution)
    let indexHex = String(format: "%016llx", index ?? 0)

    return NavigationStack {
      Form {
        Section("Sample Location") {
          Picker("City", selection: $selectedLocation) {
            ForEach(Array(locations.enumerated()), id: \.offset) { entry in
              Text(entry.element.name).tag(entry.offset)
            }
          }
        }

        Section("Resolution") {
          Stepper(value: $resolution, in: 0...15) {
            Text("Resolution \(resolution)")
          }
        }

        Section {
          Text("Index (hex): \(indexHex)")
            .contextMenu {
              Button("Copy") { UIPasteboard.general.string = indexHex }
            }
        } header: {
          Text("H3 Result")
        } footer: {
          Text("Values recompute automatically when you change the location or resolution.")
        }
      }
      .navigationTitle("H3 Demo")
    }
  }
}

#Preview {
  ContentView()
}
