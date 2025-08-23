import SwiftUI

struct ThemeManager {
    static let primaryColor = Color(hex: "#4A4A4A")
    static let secondaryColor = Color(hex: "#2F4F4F")
    static let accentColor = Color(hex: "#4682B4")
    static let highlightColor = Color(hex: "#FFD700")
    static let primaryFont = "CourierNewPSMT"
    static let boldFont = "CourierNewPS-BoldMT"
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
