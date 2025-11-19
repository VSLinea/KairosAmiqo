import SwiftUI

/// A view that handles displaying calendar permission states and actions
/// Uses KairosAuth design system
struct CalendarPermissionView: View {
    let status: AppVM.CalendarAccessStatus
    let requestAccess: () -> Void

    var body: some View {
        Group {
            switch status {
            case .notDetermined:
                Section {
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                        Text("Calendar Access")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.white)

                        Text("Allow access to your calendar to add confirmed events automatically.")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.secondaryText)

                        KairosAuth.PrimaryButton(
                            label: "Allow Calendar Access",
                            action: requestAccess
                        )
                    }
                    .padding(.vertical, KairosAuth.Spacing.medium)
                }

            case .denied:
                Section {
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                        Text("Calendar Access Required")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.white)

                        Text("Calendar access was denied. Please enable it in Settings to add events to your calendar.")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.secondaryText)

                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            KairosAuth.PrimaryButton(
                                label: "Open Settings",
                                action: {}
                            )
                        }
                    }
                    .padding(.vertical, KairosAuth.Spacing.medium)
                }

            case .restricted:
                Section {
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                        Text("Calendar Access Restricted")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.white)

                        Text("Calendar access is restricted by device settings or policies.")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                    }
                    .padding(.vertical, KairosAuth.Spacing.medium)
                }

            case .authorized, .fullAccess:
                EmptyView()

            case .writeOnly:
                Section {
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                        Text("Limited Calendar Access")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.white)

                        Text("You have write-only access to the calendar. Full access is recommended for the best experience.")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.secondaryText)

                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            KairosAuth.PrimaryButton(
                                label: "Open Settings",
                                action: {}
                            )
                        }
                    }
                    .padding(.vertical, KairosAuth.Spacing.medium)
                }
            }
        }
    }
}

#Preview("Not Determined") {
    ScrollView {
        CalendarPermissionView(status: .notDetermined) {}
            .padding()
    }
    .background(
        KairosAuth.Color.backgroundGradient(),
        ignoresSafeAreaEdges: .all
    )
}

#Preview("Denied") {
    ScrollView {
        CalendarPermissionView(status: .denied) {}
            .padding()
    }
    .background(
        KairosAuth.Color.backgroundGradient(),
        ignoresSafeAreaEdges: .all
    )
}

#Preview("Restricted") {
    ScrollView {
        CalendarPermissionView(status: .restricted) {}
            .padding()
    }
    .background(
        KairosAuth.Color.backgroundGradient(),
        ignoresSafeAreaEdges: .all
    )
}
