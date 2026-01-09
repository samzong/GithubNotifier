import SwiftUI

struct TimeAgoText: View {
    let date: Date

    var body: some View {
        Text(formattedTimeAgo)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
    }

    private var formattedTimeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3_600)
        let days = Int(interval / 86_400)

        if minutes < 1 {
            return "now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else if hours < 24 {
            return "\(hours)h"
        } else if days < 7 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
