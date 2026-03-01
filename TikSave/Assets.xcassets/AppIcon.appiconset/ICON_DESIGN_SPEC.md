# TikSave App Icon Design Specification

## Design Concept
A minimalist, elegant app icon representing TikTok video downloading with a "T" symbol and download arrow.

## Visual Requirements
- **Shape**: Rounded square (macOS Big Sur+ design language)
- **Style**: Flat design with subtle gradient and soft shadows
- **Colors**: 
  - Primary: Dark gradient (#1A1A1A to #2D2D2D)
  - Accent: Bright cyan/blue (#00F2EA or #25F4EE) for download elements
  - Secondary: White for symbols and text
- **Typography**: Clean, sans-serif for "T" symbol

## Design Elements
1. **Background**: Rounded square with subtle gradient
2. **Main Symbol**: Stylized "T" representing TikTok (not copying TikTok logo)
3. **Download Arrow**: Downward arrow integrated with "T" design
4. **Optional**: Small video play triangle element

## Size Requirements (macOS)
All sizes must be provided with @1x and @2x variants:

### Required Sizes:
- **16x16px** (@1x, @2x) - Menu bar, Dock (small)
- **32x32px** (@1x, @2x) - Dock (normal)
- **128x128px** (@1x, @2x) - Finder, Spotlight
- **256x256px** (@1x, @2x) - App folder, Launchpad
- **512x512px** (@1x, @2x) - App Store, high-res displays
- **1024x1024px** (@1x) - Source file for scaling

### File Naming Convention:
```
icon_16x16@1x.png
icon_16x16@2x.png
icon_32x32@1x.png
icon_32x32@2x.png
icon_128x128@1x.png
icon_128x128@2x.png
icon_256x256@1x.png
icon_256x256@2x.png
icon_512x512@1x.png
icon_512x512@2x.png
icon_1024x1024@1x.png
```

## Safe Area Guidelines
- Maintain 8px margin from edges for 512x512
- Critical elements within 448x448px center area
- Avoid placing important elements near corners

## Color Palette
```swift
// Primary gradient (dark mode friendly)
let gradientStart = "#1A1A1A"
let gradientEnd = "#2D2D2D"

// Accent color (TikTok-inspired but unique)
let accentColor = "#00F2EA" // or "#25F4EE"

// Symbol color
let symbolColor = "#FFFFFF"

// Shadow color
let shadowColor = "rgba(0, 0, 0, 0.2)"
```

## Design Variations
### Light Mode Variant (Optional):
- Background: Light gradient (#F5F5F7 to #E5E5E7)
- Symbol: Dark gray (#333333)
- Accent: Same cyan color for consistency

### Dark Mode Variant (Primary):
- Background: Dark gradient as above
- Symbol: White
- Accent: Cyan color

## Export Commands (using sips)
```bash
# From 1024x1024 source to all required sizes
sips -z 16 16 icon_1024x1024.png --out icon_16x16@1x.png
sips -z 32 32 icon_1024x1024.png --out icon_16x16@2x.png
sips -z 32 32 icon_1024x1024.png --out icon_32x32@1x.png
sips -z 64 64 icon_1024x1024.png --out icon_32x32@2x.png
sips -z 128 128 icon_1024x1024.png --out icon_128x128@1x.png
sips -z 256 256 icon_1024x1024.png --out icon_128x128@2x.png
sips -z 256 256 icon_1024x1024.png --out icon_256x256@1x.png
sips -z 512 512 icon_1024x1024.png --out icon_256x256@2x.png
sips -z 512 512 icon_1024x1024.png --out icon_512x512@1x.png
sips -z 1024 1024 icon_1024x1024.png --out icon_512x512@2x.png
```

## Implementation Checklist
- [ ] Create 1024x1024 source icon
- [ ] Export all required sizes using sips or design tool
- [ ] Update Contents.json with proper references
- [ ] Test in Xcode: General → App Icons and Launch Screen
- [ ] Verify appearance in Dock, Finder, and Launchpad
- [ ] Test on both light and dark desktop backgrounds

## Design Inspiration
- Modern macOS app icons (Notes, Safari, Music)
- Minimalist design principles
- High contrast for visibility
- Scalable design that works at 16px

## Technical Notes
- Use PNG format with transparency support
- Ensure proper color profile (sRGB)
- Test on Retina and non-Retina displays
- Consider accessibility (high contrast mode compatibility)
