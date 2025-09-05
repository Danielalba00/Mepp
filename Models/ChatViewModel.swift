import Foundation
import Combine
import CoreBluetooth

final class ChatViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // UI
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    // VIN
    @Published var userVIN: String {
        didSet { UserDefaults.standard.set(userVIN, forKey: "userVIN") }
    }
    @Published var isVINEntered = false
    
    // Bluetooth / OBD
    @Published var isBluetoothConnected = false
    @Published var obdData: String = ""
    @Published var deviceConnectionStatus: String = "Esperando conexión"
    
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var retryCount = 0
    private let maxRetries = 3
    
    // Servicios
    private let openAIService = OpenAIService()
    private let supabaseService = SupabaseService() // (init? → tipo opcional)
    
    // CSV en memoria (texto procesado)
    private var csvContent: String?
    
    // Prompt interno
    private let systemPrompt = """
    Eres un asistente especializado en mecánica automotriz. Responde con precisión y claridad sobre sistemas automotrices, sensores OBD2, diagnósticos y reparaciones. Si faltan datos, explica qué hace falta y cómo obtenerlo.
    """
    
    // MARK: - Init
    override init() {
        let saved = UserDefaults.standard.string(forKey: "userVIN") ?? ""
        self.userVIN = saved
        super.init()
        self.isVINEntered = Self.isValidVIN(saved)
    }
    
    // MARK: - VIN
    static func isValidVIN(_ vin: String) -> Bool {
        let pattern = try! Regex("^[A-HJ-NPR-Z0-9]{17}$")
        return vin.count == 17 && vin.uppercased().wholeMatch(of: pattern) != nil
    }
    
    func setUserVIN(_ vin: String) { self.userVIN = vin }
    
    func logout() {
        userVIN = ""
        isVINEntered = false
        messages = []
        csvContent = nil
        disconnectBluetooth()
        deviceConnectionStatus = "Desconectado"
    }
    
    // MARK: - Bluetooth
    func connectToOBDDevice() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        if centralManager?.state == .poweredOn {
            deviceConnectionStatus = "Buscando dispositivo OBDLink MX+..."
            centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        } else {
            deviceConnectionStatus = "Error: Bluetooth no está disponible o encendido"
        }
    }
    
    func disconnectBluetooth() {
        if let peripheral = peripheral, let central = centralManager {
            central.cancelPeripheralConnection(peripheral)
        }
        isBluetoothConnected = false
        peripheral = nil
        centralManager = nil
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            deviceConnectionStatus = "Listo para conectar"
        case .poweredOff:
            deviceConnectionStatus = "Error: Bluetooth apagado"
            isBluetoothConnected = false
            disconnectBluetooth()
        case .unsupported:
            deviceConnectionStatus = "Error: Bluetooth no soportado"
        case .unauthorized:
            deviceConnectionStatus = "Error: Acceso a Bluetooth no autorizado"
        case .unknown, .resetting:
            deviceConnectionStatus = "Estado desconocido"
        @unknown default:
            deviceConnectionStatus = "Error: Estado no reconocido"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains("OBDLink MX+") ?? false {
            self.peripheral = peripheral
            central.connect(peripheral, options: nil)
            central.stopScan()
            deviceConnectionStatus = "Conectando a OBDLink MX+..."
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isBluetoothConnected = true
        deviceConnectionStatus = "Conectado a OBDLink MX+ con éxito"
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        retryCount = 0
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        deviceConnectionStatus = "Error al conectar: \(error?.localizedDescription ?? "Desconocido")"
        if retryCount < maxRetries {
            retryCount += 1
            deviceConnectionStatus = "Reintentando conexión (\(retryCount)/\(maxRetries))..."
            connectToOBDDevice()
        } else {
            isBluetoothConnected = false
            deviceConnectionStatus = "Error: Conexión fallida después de \(maxRetries) intentos"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isBluetoothConnected = false
        deviceConnectionStatus = "Desconectado: \(error?.localizedDescription ?? "Sin error")"
        if retryCount < maxRetries {
            retryCount += 1
            deviceConnectionStatus = "Reintentando conexión (\(retryCount)/\(maxRetries))..."
            connectToOBDDevice()
        } else {
            deviceConnectionStatus = "Error: Desconexión permanente después de \(maxRetries) intentos"
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) {
                let command = "ATZ\r".data(using: .utf8)! // Reset
                peripheral.writeValue(command, for: characteristic, type: .withResponse)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value, let string = String(data: value, encoding: .utf8) {
            obdData = string.trimmingCharacters(in: .newlines)
        }
    }
    
    // MARK: - Chat / OpenAI
    func sendMessage(content: String) {
        let userMessage = ChatMessage(role: "user", content: content)
        messages.append(userMessage)
        isLoading = true
        
        guard let apiKey = APIKeyManager.getOpenAIKey(), !apiKey.isEmpty else {
            messages.append(ChatMessage(role: "assistant", content: "Error: OPENAI_API_KEY no está configurada. Revisa Info.plist o Config.plist."))
            isLoading = false
            return
        }
        _ = apiKey
        
        Task {
            var apiMessages: [ChatMessage] = []
            apiMessages.append(ChatMessage(role: "system", content: systemPrompt))
            
            // CSVs previos desde Supabase (usa filename/url)
            if let supabase = supabaseService, !userVIN.isEmpty {
                do {
                    let prev = try await supabase.getPreviousCSVs(for: userVIN, limit: 3)
                    if !prev.isEmpty {
                        let summary = prev
                            .map { "- \($0.filename ?? "(sin nombre)") @ \($0.timestamp ?? "s/f"): \($0.url ?? "(sin url)")" }
                            .joined(separator: "\n")
                        apiMessages.append(ChatMessage(role: "system", content: "Archivos CSV previos para este VIN:\n\(summary)"))
                    }
                } catch {
                    print("Supabase getPreviousCSVs error:", error.localizedDescription)
                }
            }
            
            if !userVIN.isEmpty {
                apiMessages.append(ChatMessage(role: "system", content: "Usuario identificado por VIN: \(userVIN)"))
                if !obdData.isEmpty {
                    apiMessages.append(ChatMessage(role: "system", content: "Datos OBD en tiempo real: \(obdData)"))
                }
            }
            if let csv = csvContent {
                apiMessages.append(ChatMessage(role: "system", content: "Contexto del CSV actual cargado:\n\(csv)"))
            }
            
            apiMessages.append(contentsOf: messages)
            
            do {
                let response = try await openAIService.chat(messages: apiMessages)
                await MainActor.run {
                    if let first = response.choices.first {
                        messages.append(ChatMessage(role: first.message.role, content: first.message.content))
                    } else {
                        messages.append(ChatMessage(role: "assistant", content: "No se recibió respuesta válida de OpenAI"))
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: "Error al contactar OpenAI: \(error.localizedDescription)"))
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - CSV (local + Supabase)
    func loadCSV(from url: URL) {
        guard !userVIN.isEmpty else {
            DispatchQueue.main.async {
                self.messages.append(ChatMessage(role: "system", content: "Error: Debes ingresar un VIN antes de cargar un CSV."))
                self.isLoading = false
            }
            return
        }
        
        let hadToAccess = url.startAccessingSecurityScopedResource()
        defer { if hadToAccess { url.stopAccessingSecurityScopedResource() } }
        
        isLoading = true
        
        Task {
            do {
                let sourceURL = url
                
                // Espera iCloud si aplica
                if let values = try? sourceURL.resourceValues(forKeys: [.isUbiquitousItemKey]),
                   values.isUbiquitousItem == true {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: sourceURL)
                    while true {
                        let v = try? sourceURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                        if v?.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
                            break
                        }
                        try await Task.sleep(nanoseconds: 150_000_000)
                    }
                }
                
                // Copia a Documents/
                let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let localFileName = "\(userVIN)__\(Int(Date().timeIntervalSince1970))__\(sourceURL.lastPathComponent)"
                let localURL = docs.appendingPathComponent(localFileName)
                try? FileManager.default.removeItem(at: localURL)
                
                let fileData = try Data(contentsOf: sourceURL)
                try fileData.write(to: localURL, options: .atomic)
                
                // Lee texto (con fallback de encoding) para el contexto del chat
                var contentStr: String? = String(data: fileData, encoding: .utf8)
                if contentStr == nil { contentStr = String(data: fileData, encoding: .isoLatin1) }
                let processedContent = contentStr?.replacingOccurrences(of: "null", with: "0")
                self.csvContent = processedContent
                
                // Subir a Supabase si está configurado
                if let supabase = self.supabaseService {
                    let uploadData = processedContent?.data(using: .utf8) ?? fileData
                    let remotePath = "\(userVIN)/\(localFileName)" // carpeta por VIN
                    let fileUrl = try await supabase.uploadCSV(data: uploadData, fileName: remotePath)
                    
                    // ⚠️ firma nueva: filename/url/timestamp
                    try await supabase.insertCSVRecord(
                        vin: userVIN,
                        filename: localFileName,
                        url: fileUrl,
                        timestamp: nil
                    )
                    
                    await MainActor.run {
                        self.messages.append(ChatMessage(role: "system", content: "CSV cargado y subido: \(localFileName)"))
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.messages.append(ChatMessage(role: "system", content: "CSV cargado localmente: \(localFileName)"))
                        self.isLoading = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.messages.append(ChatMessage(role: "assistant", content: "Error al cargar/subir CSV: \(error.localizedDescription)"))
                    self.isLoading = false
                }
            }
        }
    }
}

