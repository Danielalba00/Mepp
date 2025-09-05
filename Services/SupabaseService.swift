import Foundation
import Supabase

private enum SupabaseConfigKeys {
    static let urlKey = "SUPABASE_URL"
    static let anonKey = "SUPABASE_ANON_KEY"
}

struct CSVRecord: Decodable {
    let id: String
    let vin: String
    let timestamp: String?
    let filename: String?
    let url: String?
}

// Modelo para insert (Encodable)
private struct InsertCSVRecord: Encodable {
    let vin: String
    let filename: String?
    let url: String?
    let timestamp: String?
}

final class SupabaseService {
    
    private let client: SupabaseClient
    private let storageBucketName = "obd2csv"
    private let tableName = "archivos_csv"
    
    init?() {
        // 1) Info.plist
        let info = Bundle.main.infoDictionary ?? [:]
        let urlStringInfo = info[SupabaseConfigKeys.urlKey] as? String
        let anonKeyInfo = info[SupabaseConfigKeys.anonKey] as? String
        
        var urlString: String? = urlStringInfo
        var anonKey: String? = anonKeyInfo
        
        // 2) Config.plist fallback
        if urlString?.isEmpty ?? true || anonKey?.isEmpty ?? true {
            if let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
               let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                if urlString?.isEmpty ?? true { urlString = plist[SupabaseConfigKeys.urlKey] as? String }
                if anonKey?.isEmpty ?? true { anonKey = plist[SupabaseConfigKeys.anonKey] as? String }
            }
        }
        
        guard
            let urlStr = urlString, let url = URL(string: urlStr),
            let anonKey = anonKey, !anonKey.isEmpty
        else {
            return nil
        }
        
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
    
    // MARK: - Storage
    func uploadCSV(data: Data, fileName: String) async throws -> String {
        let path = fileName
        
        _ = try await client
            .storage
            .from(storageBucketName)
            .upload(path, data: data, options: FileOptions(cacheControl: "3600", upsert: true))
        
        do {
            let publicURL: URL = try client
                .storage
                .from(storageBucketName)
                .getPublicURL(path: path)
            return publicURL.absoluteString
        } catch {
            let signedURL: URL = try await client
                .storage
                .from(storageBucketName)
                .createSignedURL(path: path, expiresIn: 3600)
            return signedURL.absoluteString
        }
    }
    
    // MARK: - Tabla
    func insertCSVRecord(vin: String, filename: String, url: String, timestamp: String? = nil) async throws {
        let record = InsertCSVRecord(
            vin: vin,
            filename: filename,
            url: url,
            timestamp: timestamp ?? ISO8601DateFormatter().string(from: Date())
        )
        
        _ = try await client
            .from(tableName)
            .insert(record)
            .execute()
    }
    
    func getPreviousCSVs(for vin: String, limit: Int = 5) async throws -> [CSVRecord] {
        let response = try await client
            .from(tableName)
            .select()
            .eq("vin", value: vin)
            .order("timestamp", ascending: false)
            .limit(limit)
            .execute()
        
        return try JSONDecoder().decode([CSVRecord].self, from: response.data)
    }
}

