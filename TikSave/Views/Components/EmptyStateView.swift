import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            // Title and Description
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Optional action button can be added here
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

#Preview {
    EmptyStateView(
        icon: "arrow.down.circle",
        title: "No Downloads Yet",
        description: "Start by pasting a TikTok URL in the Download tab to begin downloading videos."
    )
    .frame(width: 400, height: 300)
}
