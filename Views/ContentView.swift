import SwiftUI
import UniformTypeIdentifiers
import UIKit

// Picker en modo .import (copia a sandbox)
struct DocumentImporter: UIViewControllerRepresentable {
    var allowedTypes: [UTType]
    var onPick: (URL) -> Void
    var onCancel: () -> Void = {}
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        vc.allowsMultipleSelection = false
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentImporter
        init(_ parent: DocumentImporter) { self.parent = parent }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    // Validador VIN (17 sin I/O/Q)
    private static let vinPattern = try! Regex("^[A-HJ-NPR-Z0-9]{17}$")
    
    // Estados locales
    @State private var vin: String = ""
    @State private var showImporter = false
    @State private var isBusy = false
    @State private var importError: String?
    @State private var draft: String = ""
    
    @FocusState private var vinFocused: Bool
    @FocusState private var chatFocused: Bool
    
    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isVINEntered {
                    // -------- Pantalla 1: VIN --------
                    VStack(spacing: 14) {
                        Text("Ingresa tu VIN")
                            .font(.title3).bold()
                        
                        TextField("VIN (17 caracteres)", text: $vin)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .focused($vinFocused)
                            .onChange(of: vin) { _, newValue in
                                var cleaned = newValue.uppercased()
                                cleaned.removeAll { ch in
                                    "IOQ".contains(ch) ||
                                    !(("A"..."Z").contains(String(ch)) || ("0"..."9").contains(String(ch)))
                                }
                                if cleaned.count > 17 { cleaned = String(cleaned.prefix(17)) }
                                if cleaned != newValue {
                                    DispatchQueue.main.async { self.vin = cleaned }
                                }
                                let valid = cleaned.count == 17 && (cleaned.wholeMatch(of: Self.vinPattern) != nil)
                                viewModel.setUserVIN(cleaned)
                                viewModel.isVINEntered = valid
                                if valid { DispatchQueue.main.async { vinFocused = false } }
                            }
                        
                        Button("Ocultar teclado") { vinFocused = false }
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .padding()
                    
                } else {
                    // -------- Pantalla 2: Conectar OBD + Import CSV + Chat --------
                    VStack(spacing: 12) {
                        // Header: conectar OBD
                        HStack {
                            Button {
                                viewModel.connectToOBDDevice()
                            } label: {
                                Text("Conectar OBD")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            Spacer()
                            if isBusy { ProgressView() }
                        }
                        
                        // Estado BT
                        Text(viewModel.deviceConnectionStatus)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        // VIN + Cerrar sesión
                        HStack {
                            Text("VIN: \(viewModel.userVIN)")
                                .font(.headline)
                            Spacer()
                            Button("Cerrar sesión") {
                                guard !isBusy else { return }
                                viewModel.logout()
                                vin = ""
                                draft = ""
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        
                        // Importar CSV
                        Button {
                            guard !isBusy else { return }
                            chatFocused = false
                            showImporter = true
                        } label: {
                            Text(isBusy ? "Procesando…" : "Importar CSV")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy)
                        
                        if let e = importError {
                            Text(e).foregroundColor(.red).font(.caption)
                        }
                        
                        // Lista de mensajes
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.messages) { msg in
                                    HStack {
                                        if msg.role == "user" { Spacer() }
                                        Text(msg.content)
                                            .font(.subheadline)
                                            .padding(10)
                                            .background(msg.role == "user" ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.78, 500), alignment: .leading)
                                        if msg.role != "user" { Spacer() }
                                    }
                                }
                                if viewModel.isLoading {
                                    HStack {
                                        ProgressView()
                                        Text("Pensando…").font(.footnote).foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        
                        // Input chat
                        HStack(spacing: 8) {
                            TextField("Escribe tu mensaje…", text: $draft, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .focused($chatFocused)
                                .disabled(isBusy)
                            
                            Button {
                                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !text.isEmpty, !isBusy else { return }
                                draft = ""
                                viewModel.sendMessage(content: text)
                            } label: {
                                Text("Enviar")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Mepp")
        }
        .onAppear {
            vin = viewModel.userVIN
            viewModel.isVINEntered = ChatViewModel.isValidVIN(viewModel.userVIN)
        }
        .sheet(isPresented: $showImporter) {
            DocumentImporter(
                allowedTypes: [.commaSeparatedText, .text, .data],
                onPick: { url in
                    importError = nil
                    isBusy = true
                    Task {
                        viewModel.loadCSV(from: url)
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        await MainActor.run { isBusy = false }
                    }
                },
                onCancel: { }
            )
        }
        .interactiveDismissDisabled(showImporter || isBusy)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

