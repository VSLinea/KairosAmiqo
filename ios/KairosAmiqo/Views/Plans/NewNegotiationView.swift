//
//  NewNegotiationView.swift
//  KairosAmiqo
//
//  Created by Lyra AI on 2025-10-05.
//

//
//  NewNegotiationView.swift
//  KairosAmiqo
//
//  Small reusable sheet/form to create a negotiation via Node-RED.
//

import SwiftUI

struct NewNegotiationView: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                }

                Section {
                    Button {
                        Task {
                            await vm.startNegotiation(title: title)
                            dismiss()
                        }
                    } label: {
                        HStack { if vm.busy { ProgressView() }; Text("Create") }
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(vm.busy || vm.jwt == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let err = vm.error {
                    Section("Error") {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Negotiation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NewNegotiationView(vm: AppVM())
}
