//
//  PlanCard.swift
//  KairosAmiqo
//
//  Reusable plan list item card
//  Phase 0 Day 2
//

import SwiftUI

/// Plan card for list views
/// Shows plan status, participants, time, and venue
struct PlanCard: View {
    let title: String
    let participants: [String] // Participant names
    let time: String
    let venue: String?
    let status: PlanStatus
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Status badge + time
                HStack {
                    StatusBadge(status: status)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .medium))
                        Text(time)
                            .font(KairosAuth.Typography.itemSubtitle)
                    }
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                }

                // Title
                Text(title)
                    .font(KairosAuth.Typography.cardTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                    .lineLimit(2)

                // Participants
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text(participantsText)
                        .font(KairosAuth.Typography.bodySmall)
                    .lineLimit(1)
                }
                .foregroundColor(KairosAuth.Color.secondaryText)

                // Venue
                if let venue = venue {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text(venue)
                            .font(KairosAuth.Typography.bodySmall)
                            .lineLimit(1)
                    }
                    .foregroundColor(KairosAuth.Color.secondaryText)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                    .fill(isPressed ? KairosAuth.Color.cardBackground.opacity(0.8) : KairosAuth.Color.cardBackground)
                    .shadow(color: KairosAuth.Color.scrim, radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var participantsText: String {
        switch participants.count {
        case 0:
            return "No participants"
        case 1:
            return participants[0]
        case 2:
            return "\(participants[0]) and \(participants[1])"
        case 3:
            return "\(participants[0]), \(participants[1]), and \(participants[2])"
        default:
            return "\(participants[0]), \(participants[1]), and \(participants.count - 2) others"
        }
    }
}

// MARK: - Plan Status

enum PlanStatus: String, CaseIterable {
    case waitingForYou = "Waiting for You"
    case waitingForOthers = "Waiting for Others"
    case confirmed = "Confirmed"
    case expired = "Expired"

    var color: Color {
        switch self {
        case .waitingForYou: return KairosAuth.Color.warning
        case .waitingForOthers: return KairosAuth.Color.teal
        case .confirmed: return KairosAuth.Color.success
        case .expired: return KairosAuth.Color.error
        }
    }

    var icon: String {
        switch self {
        case .waitingForYou: return "hourglass"
        case .waitingForOthers: return "clock"
        case .confirmed: return "checkmark.circle.fill"
        case .expired: return "xmark.circle.fill"
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: PlanStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .semibold))

            Text(status.rawValue.uppercased())
                .font(KairosAuth.Typography.itemSubtitle)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#if DEBUG
struct PlanCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            KairosAuth.Color.backgroundGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    PlanCard(
                        title: "Coffee with Alex",
                        participants: ["Alex Chen"],
                        time: "Tomorrow at 6 PM",
                        venue: "Café Verona · 1.2 km",
                        status: .waitingForYou
                    ) {
                        print("Plan tapped")
                    }

                    PlanCard(
                        title: "Gym Session",
                        participants: ["Jordan Lee", "Taylor Kim"],
                        time: "Wed at 7 AM",
                        venue: "Iron Pump Gym · 2.5 km",
                        status: .waitingForOthers
                    ) {
                        print("Plan tapped")
                    }

                    PlanCard(
                        title: "Team Lunch",
                        participants: ["Sara", "Morgan", "Pat", "Chris"],
                        time: "Today at 12:30 PM",
                        venue: "Thai Basil · 1.8 km",
                        status: .confirmed
                    ) {
                        print("Plan tapped")
                    }

                    PlanCard(
                        title: "Weekend Brunch",
                        participants: ["Alex Chen", "Jordan Lee"],
                        time: "Sat at 11 AM",
                        venue: "Green Leaf Bistro",
                        status: .expired
                    ) {
                        print("Plan tapped")
                    }
                }
                .padding()
            }
        }
    }
}
#endif
