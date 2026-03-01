import SwiftUI

struct StatPill: View {
    let icon: String
    let count: Int
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(count.formattedCount)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 8) {
        StatPill(icon: "play.circle", count: 1234567)
        StatPill(icon: "heart.circle", count: 89123)
        StatPill(icon: "bubble.right.circle", count: 456)
        StatPill(icon: "arrowshape.turn.up.right.circle", count: 78901)
    }
    .padding()
}
