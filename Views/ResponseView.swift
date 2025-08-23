import SwiftUI

struct ResponseView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(ThemeManager.accentColor.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.custom(ThemeManager.primaryFont, size: 14))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text(message.content)
                    .padding()
                    .background(ThemeManager.primaryColor.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.custom(ThemeManager.primaryFont, size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ResponseView_Previews: PreviewProvider {
    static var previews: some View {
        ResponseView(message: ChatMessage(role: "user", content: "Mensaje de ejemplo"))
    }
}
