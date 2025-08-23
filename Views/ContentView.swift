import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var userInput = ""
    @State private var isDocumentPickerPresented = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Encabezado con tema mecánico
                Text("Mepp: Asistente de Mecánica")
                    .font(.custom(ThemeManager.boldFont, size: 26))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [ThemeManager.primaryColor, Color(hex: "#1C2526")]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ThemeManager.highlightColor, lineWidth: 3)
                    )
                
                // Vista de conversación desplazable
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ResponseView(message: message)
                        }
                    }
                    .padding()
                }
                .background(ThemeManager.secondaryColor.opacity(0.3))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#B0C4DE"), lineWidth: 1)
                )
                
                // Campo de entrada, botón de envío y botón de carga de CSV
                HStack {
                    TextField("Pregunta sobre motores, herramientas o reparaciones...", text: $userInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .font(.custom(ThemeManager.primaryFont, size: 16))
                    
                    Button(action: {
                        guard !userInput.isEmpty else { return }
                        viewModel.sendMessage(content: userInput)
                        userInput = ""
                    }) {
                        Image(systemName: "wrench.fill")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(ThemeManager.accentColor)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(ThemeManager.highlightColor, lineWidth: 2)
                            )
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        isDocumentPickerPresented = true
                    }) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(ThemeManager.accentColor)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(ThemeManager.highlightColor, lineWidth: 2)
                            )
                    }
                    .disabled(viewModel.isLoading)
                    .sheet(isPresented: $isDocumentPickerPresented) {
                        DocumentPicker(viewModel: viewModel)
                    }
                }
                .padding()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#696969"), ThemeManager.secondaryColor]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Mepp")
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ChatViewModel
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let viewModel: ChatViewModel
        
        init(viewModel: ChatViewModel) {
            self.viewModel = viewModel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                viewModel.loadCSV(from: url)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
