//
//  AuthViewModel.swift
//  PINEE
//
//  Created by Cássio Nunes on 18/06/25.
//

import SwiftUI
import Foundation
import GoogleSignIn
// import FirebaseAuth // Temporariamente desabilitado

// Modelo de usuário simplificado
struct UserModel {
    let id: String
    let name: String
    let email: String
    let profileImageURL: URL?
    let accountType: AccountType
    let idToken: String
    
    enum AccountType {
        case free
        case premium
        case lifetime
        case exclusive
    
    var displayName: String {
        switch self {
            case .free:
                return "Conta Gratuita"
            case .premium:
                return "Premium"
            case .exclusive:
                return "Licença Exclusiva"
            case .lifetime:
                return "Licença Vitalícia"
            }
        }
        
        var icon: String {
            switch self {
            case .free:
                return "person.circle"
            case .premium:
                return "star.circle.fill"
            case .exclusive:
                return "crown.fill"
            case .lifetime:
                return "infinity.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
            case .free:
                return .gray
            case .premium:
                return Color(hex: "#16A34A")
            case .exclusive:
                return Color(hex: "#7C3AED")
            case .lifetime:
                return Color(hex: "#DC2626")
            }
        }
        
        var isPremium: Bool {
            switch self {
            case .free:
                return false
            case .premium, .lifetime, .exclusive:
                return true
            }
        }
    }
}

// MARK: - Firebase REST Service (Simplified)
class FirebaseRESTService: ObservableObject {
    static let shared = FirebaseRESTService()
    
    private let baseURL = "https://firestore.googleapis.com/v1/projects"
    private var projectId: String = ""
    private var apiKey: String = ""
    
    private init() {
        loadFirebaseConfig()
    }
    
    private func loadFirebaseConfig() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            print("❌ Erro: Não foi possível carregar GoogleService-Info.plist")
            return
        }
        
        projectId = plist["PROJECT_ID"] as? String ?? ""
        apiKey = plist["API_KEY"] as? String ?? ""
        
        print("✅ Firebase configurado - Project ID: \(projectId)")
    }
    
    // Busca o ID interno (campo `id`) do documento em `users` pelo email
    func lookupInternalUserId(byEmail email: String) async throws -> String? {
        guard !projectId.isEmpty && !apiKey.isEmpty, !email.isEmpty else { return nil }
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "users"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "email"],
                        "op": "EQUAL",
                        "value": ["stringValue": email]
                    ]
                ],
                "limit": 1
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        let results = (try? JSONDecoder().decode([FirestoreQueryResponse].self, from: data)) ?? []
        guard let document = results.first?.document else { return nil }
        // Campo `id` dentro de users
        if let internalId = document.fields.id?.stringValue, !internalId.isEmpty {
            return internalId
        }
        // Fallback: último segmento do name
        return document.name.components(separatedBy: "/").last
    }
    
    func authenticateUser(email: String, password: String) async throws -> String {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.authenticationFailed
        }
        
        let authResponse = try JSONDecoder().decode(FirebaseAuthResponse.self, from: data)
        return authResponse.idToken
    }
    
    func getTransactions(userId: String, startDate: String, endDate: String, idToken: String) async throws -> [TransactionModel] {
        let cacheKey = "transactions-\(userId)-\(startDate)-\(endDate)"
        if let cached: [TransactionModel] = LocalCacheManager.shared.load([TransactionModel].self, for: cacheKey, maxAge: 60 * 5) {
            print("📦 Retornando transações do cache para período \(startDate) - \(endDate)")
            return cached
        }

        guard !projectId.isEmpty && !apiKey.isEmpty else {
            if let stale: [TransactionModel] = LocalCacheManager.shared.load([TransactionModel].self, for: cacheKey) {
                print("📦 Usando cache antigo de transações por falta de configuração Firebase")
                return stale
            }
            print("❌ Firebase não configurado - projectId: \(projectId), apiKey: \(apiKey.isEmpty ? "vazio" : "configurado")")
            throw FirebaseError.configurationError
        }

        func cacheAndReturn(_ transactions: [TransactionModel]) -> [TransactionModel] {
            LocalCacheManager.shared.save(transactions, for: cacheKey)
            return transactions
        }
        
        print("🔍 Buscando transações no Firebase...")
        print("📊 Project ID: \(projectId)")
        print("👤 User ID: \(userId)")
        print("📅 Período: \(startDate) até \(endDate)")
        
        // Usar API Key em vez de token de autenticação (mais simples)
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Filtra por userId e por intervalo de datas (inclusive), e ordena por data
        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "transactions"]],
                "where": [
                    "compositeFilter": [
                        "op": "AND",
                        "filters": [
                            [
                                "fieldFilter": [
                                    "field": ["fieldPath": "userId"],
                                    "op": "EQUAL",
                                    "value": ["stringValue": userId]
                                ]
                            ],
                            [
                                "fieldFilter": [
                                    "field": ["fieldPath": "date"],
                                    "op": "GREATER_THAN_OR_EQUAL",
                                    "value": ["stringValue": startDate]
                                ]
                            ],
                            [
                                "fieldFilter": [
                                    "field": ["fieldPath": "date"],
                                    "op": "LESS_THAN_OR_EQUAL",
                                    "value": ["stringValue": endDate]
                                ]
                            ]
                        ]
                    ]
                ],
                "orderBy": [[
                    "field": ["fieldPath": "date"],
                    "direction": "ASCENDING"
                ]]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Resposta HTTP inválida")
            throw FirebaseError.fetchFailed
        }
        
        print("📡 Status HTTP: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "Resposta vazia"
            print("❌ Erro HTTP \(httpResponse.statusCode): \(responseString)")
            
            // Tratar erro 429 (Quota Exceeded) com retry
            if httpResponse.statusCode == 429 {
                print("⚠️ Quota do Firebase excedida. Aguardando 3 segundos antes de tentar novamente...")
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 segundos
                print("🔄 Tentando novamente após delay...")
                // Retry uma vez
                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    print("⚠️ Após retry, ainda sem resposta válida. Retornando array vazio.")
                    return cacheAndReturn([])
                }
                if retryHttpResponse.statusCode == 200 {
                    // Sucesso no retry, continuar com o processamento normal
                    print("✅ Retry bem-sucedido!")
                    let results = try JSONDecoder().decode([FirestoreQueryResponse].self, from: retryData)
                    let documents = results.compactMap { $0.document }
                    if documents.isEmpty {
                        print("ℹ️ Nenhuma transação encontrada após retry")
                        return cacheAndReturn([])
                    }
                    let mappedTransactions = documents.map { document in
                        let fields = document.fields
                        let parsedAmount: Double = {
                            if let d = fields.amount?.doubleValue { return d }
                            if let iStr = fields.amount?.integerValue, let i = Double(iStr) { return i }
                            if let s = fields.amount?.stringValue, let d = Double(s.replacingOccurrences(of: ",", with: ".")) { return d }
                            return 0.0
                        }()
                        return TransactionModel(
                            id: document.name.components(separatedBy: "/").last ?? "",
                            userId: fields.userId?.stringValue ?? userId,
                            title: fields.title?.stringValue,
                            description: fields.description?.stringValue,
                            amount: parsedAmount,
                            category: fields.category?.stringValue ?? "Geral",
                            date: fields.date?.stringValue ?? "",
                            isIncome: fields.isIncome?.booleanValue ?? false,
                            type: fields.type?.stringValue ?? "expense",
                            status: fields.status?.stringValue ?? "pending",
                            createdAt: parseTransactionCreatedAt(fields),
                            isRecurring: fields.isRecurring?.booleanValue ?? false,
                            recurringFrequency: fields.recurringFrequency?.stringValue ?? "",
                            recurringEndDate: fields.recurringEndDate?.stringValue ?? "",
                            sourceTransactionId: fields.sourceTransactionId?.stringValue
                        )
                    }
                    return cacheAndReturn(mappedTransactions)
                } else {
                    print("⚠️ Após retry, ainda recebendo erro \(retryHttpResponse.statusCode). Retornando array vazio.")
                    return cacheAndReturn([])
                }
            }
            
            // Fallback: se precisar de índice, buscar apenas por userId e filtrar localmente por data
            if httpResponse.statusCode == 400 && responseString.contains("requires an index") {
                print("⚠️ Índice composto ausente. Aplicando fallback (filtragem local)...")
                let urlFallback = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
                var requestFallback = URLRequest(url: urlFallback)
                requestFallback.httpMethod = "POST"
                requestFallback.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let queryFallback: [String: Any] = [
                    "structuredQuery": [
                        "from": [["collectionId": "transactions"]],
                        "where": [
                            "fieldFilter": [
                                "field": ["fieldPath": "userId"],
                                "op": "EQUAL",
                                "value": ["stringValue": userId]
                            ]
                        ]
                    ]
                ]
                requestFallback.httpBody = try JSONSerialization.data(withJSONObject: queryFallback)
                let (dataFB, responseFB) = try await URLSession.shared.data(for: requestFallback)
                guard let httpFB = responseFB as? HTTPURLResponse, httpFB.statusCode == 200 else {
                    print("⚠️ Fallback também falhou. Retornando array vazio.")
                    return cacheAndReturn([])
                }
                let raw = try JSONDecoder().decode([FirestoreQueryResponse].self, from: dataFB)
                let documents = raw.compactMap { $0.document }
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let filtered = documents.filter { doc in
                    guard let dateStr = doc.fields.date?.stringValue,
                          let d = df.date(from: dateStr),
                          let s = df.date(from: startDate),
                          let e = df.date(from: endDate) else { return false }
                    return d >= s && d <= e
                }
                let sorted = filtered.sorted { (a, b) -> Bool in
                    let da = df.date(from: a.fields.date?.stringValue ?? "0000-01-01") ?? Date.distantPast
                    let db = df.date(from: b.fields.date?.stringValue ?? "0000-01-01") ?? Date.distantPast
                    return da < db
                }
                print("📄 Fallback retornou documentos: \(sorted.count)")
                let mapped = sorted.map { document in
                    let fields = document.fields
                    let parsedAmount: Double = {
                        if let d = fields.amount?.doubleValue { return d }
                        if let iStr = fields.amount?.integerValue, let i = Double(iStr) { return i }
                        if let s = fields.amount?.stringValue, let d = Double(s.replacingOccurrences(of: ",", with: ".")) { return d }
                        return 0.0
                    }()
                    return TransactionModel(
                        id: document.name.components(separatedBy: "/").last ?? "",
                        userId: fields.userId?.stringValue ?? userId,
                        title: fields.title?.stringValue,
                        description: fields.description?.stringValue,
                        amount: parsedAmount,
                        category: fields.category?.stringValue ?? "Geral",
                        date: fields.date?.stringValue ?? "",
                        isIncome: fields.isIncome?.booleanValue ?? false,
                        type: fields.type?.stringValue ?? "expense",
                        status: fields.status?.stringValue ?? "pending",
                        createdAt: parseTransactionCreatedAt(fields),
                        isRecurring: fields.isRecurring?.booleanValue ?? false,
                        recurringFrequency: fields.recurringFrequency?.stringValue ?? "",
                        recurringEndDate: fields.recurringEndDate?.stringValue ?? "",
                        sourceTransactionId: fields.sourceTransactionId?.stringValue
                    )
                }
                return cacheAndReturn(mapped)
            }
            
            // Para outros erros, retornar array vazio em vez de lançar exceção
        print("⚠️ Erro HTTP \(httpResponse.statusCode) não tratado. Retornando array vazio.")
        return cacheAndReturn([])
        }
        
        // Parse da resposta do Firestore (pode vir vazio ou só com readTime)
        let responseString = String(data: data, encoding: .utf8) ?? "Resposta vazia"
        print("📄 Resposta do Firebase: \(responseString)")
        
        var firestoreResponse = try JSONDecoder().decode([FirestoreQueryResponse].self, from: data)
        var documents = firestoreResponse.compactMap { $0.document }
        
        print("📊 Entradas retornadas: \(firestoreResponse.count) | Documentos válidos: \(documents.count)")
        
        // Se não houve resultados, tentar com email do usuário como identificador alternativo
        if documents.isEmpty {
            let altUserId = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? ""
            if !altUserId.isEmpty && altUserId != userId {
                print("🔁 Tentando por identificador alternativo (email)")
                var requestAlt = URLRequest(url: url)
                requestAlt.httpMethod = "POST"
                requestAlt.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let queryAlt: [String: Any] = [
                    "structuredQuery": [
                        "from": [["collectionId": "transactions"]],
                        "where": [
                            "compositeFilter": [
                                "op": "AND",
                                "filters": [
                                    [
                                        "fieldFilter": [
                                            "field": ["fieldPath": "userId"],
                                            "op": "EQUAL",
                                            "value": ["stringValue": altUserId]
                                        ]
                                    ],
                                    [
                                        "fieldFilter": [
                                            "field": ["fieldPath": "date"],
                                            "op": "GREATER_THAN_OR_EQUAL",
                                            "value": ["stringValue": startDate]
                                        ]
                                    ],
                                    [
                                        "fieldFilter": [
                                            "field": ["fieldPath": "date"],
                                            "op": "LESS_THAN_OR_EQUAL",
                                            "value": ["stringValue": endDate]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        "orderBy": [[
                            "field": ["fieldPath": "date"],
                            "direction": "ASCENDING"
                        ]]
                    ]
                ]
                requestAlt.httpBody = try JSONSerialization.data(withJSONObject: queryAlt)
                let (dataAlt, respAlt) = try await URLSession.shared.data(for: requestAlt)
                if let httpAlt = respAlt as? HTTPURLResponse, httpAlt.statusCode == 200 {
                    firestoreResponse = (try? JSONDecoder().decode([FirestoreQueryResponse].self, from: dataAlt)) ?? []
                    documents = firestoreResponse.compactMap { $0.document }
                    print("📊 Documentos pelo email: \(documents.count)")
                }
            }
        }
        
        // Se ainda estiver vazio, fazer fallback: buscar apenas por userId e filtrar localmente por data
        if documents.isEmpty {
            print("🛟 Fallback: buscar por userId e filtrar localmente por data")
            let urlFB = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
            var reqFB = URLRequest(url: urlFB)
            reqFB.httpMethod = "POST"
            reqFB.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let qFB: [String: Any] = [
                "structuredQuery": [
                    "from": [["collectionId": "transactions"]],
                    "where": [
                        "fieldFilter": [
                            "field": ["fieldPath": "userId"],
                            "op": "EQUAL",
                            "value": ["stringValue": userId]
                        ]
                    ]
                ]
            ]
            reqFB.httpBody = try JSONSerialization.data(withJSONObject: qFB)
            let (dFB, rFB) = try await URLSession.shared.data(for: reqFB)
            if let hFB = rFB as? HTTPURLResponse, hFB.statusCode == 200 {
                let r = (try? JSONDecoder().decode([FirestoreQueryResponse].self, from: dFB)) ?? []
                documents = r.compactMap { $0.document }
                print("📄 Fallback por userId trouxe: \(documents.count)")
            }
        }
        
        // Se ainda vazio, mais um fallback por email sem data e filtrando localmente
        if documents.isEmpty {
            let altUserId = GIDSignIn.sharedInstance.currentUser?.profile?.email ?? ""
            if !altUserId.isEmpty {
                print("🛟 Fallback: buscar por email e filtrar localmente por data")
                let urlFB = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
                var reqFB = URLRequest(url: urlFB)
                reqFB.httpMethod = "POST"
                reqFB.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let qFB: [String: Any] = [
                    "structuredQuery": [
                        "from": [["collectionId": "transactions"]],
                        "where": [
                            "fieldFilter": [
                                "field": ["fieldPath": "userId"],
                                "op": "EQUAL",
                                "value": ["stringValue": altUserId]
                            ]
                        ]
                    ]
                ]
                reqFB.httpBody = try JSONSerialization.data(withJSONObject: qFB)
                let (dFB, rFB) = try await URLSession.shared.data(for: reqFB)
                if let hFB = rFB as? HTTPURLResponse, hFB.statusCode == 200 {
                    let r = (try? JSONDecoder().decode([FirestoreQueryResponse].self, from: dFB)) ?? []
                    documents = r.compactMap { $0.document }
                    print("📄 Fallback por email trouxe: \(documents.count)")
                }
            }
        }
        
        // Se aplicamos fallbacks sem data, filtrar por data localmente (string ou timestamp)
        if !documents.isEmpty {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let s = df.date(from: startDate), let e = df.date(from: endDate) {
                documents = documents.filter { doc in
                    // date como string
                    if let ds = doc.fields.date?.stringValue, let d = df.date(from: ds) {
                        return d >= s && d <= e
                    }
                    // date como timestamp
                    if let ts = doc.fields.date?.timestampValue {
                        let iso = ISO8601DateFormatter()
                        if let d = iso.date(from: ts) { return d >= s && d <= e }
                    }
                    return false
                }.sorted { a, b in
                    let da: Date = {
                        if let ds = a.fields.date?.stringValue, let d = df.date(from: ds) { return d }
                        if let ts = a.fields.date?.timestampValue { return ISO8601DateFormatter().date(from: ts) ?? .distantPast }
                        return .distantPast
                    }()
                    let db: Date = {
                        if let ds = b.fields.date?.stringValue, let d = df.date(from: ds) { return d }
                        if let ts = b.fields.date?.timestampValue { return ISO8601DateFormatter().date(from: ts) ?? .distantPast }
                        return .distantPast
                    }()
                    return da < db
                }
            }
        }
        
        // Último fallback: tentar consulta apenas por data no servidor, sem userId
        if documents.isEmpty {
            print("🛟 Fallback final: consulta apenas por data no servidor")
            let urlDateOnly = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
            var req = URLRequest(url: urlDateOnly)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let q: [String: Any] = [
                "structuredQuery": [
                    "from": [["collectionId": "transactions"]],
                    "where": [
                        "compositeFilter": [
                            "op": "AND",
                            "filters": [
                                [
                                    "fieldFilter": [
                                        "field": ["fieldPath": "date"],
                                        "op": "GREATER_THAN_OR_EQUAL",
                                        "value": ["stringValue": startDate]
                                    ]
                                ],
                                [
                                    "fieldFilter": [
                                        "field": ["fieldPath": "date"],
                                        "op": "LESS_THAN_OR_EQUAL",
                                        "value": ["stringValue": endDate]
                                    ]
                                ]
                            ]
                        ]
                    ],
                    "orderBy": [["field": ["fieldPath": "date"], "direction": "ASCENDING"]]
                ]
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: q)
            let (d, r) = try await URLSession.shared.data(for: req)
            if let h = r as? HTTPURLResponse, h.statusCode == 200 {
                let r2 = (try? JSONDecoder().decode([FirestoreQueryResponse].self, from: d)) ?? []
                documents = r2.compactMap { $0.document }
                print("📄 Data-only retornou: \(documents.count)")
                // Filtrar por user localmente
                let possibleIds = [userId, GIDSignIn.sharedInstance.currentUser?.profile?.email ?? ""]
                documents = documents.filter { doc in
                    guard let uid = doc.fields.userId?.stringValue else { return false }
                    return possibleIds.contains(uid)
                }
            }
        }
        
        // Fallback extremo: buscar tudo e filtrar localmente (útil em datasets pequenos de dev)
        if documents.isEmpty {
            print("🛟 Fallback extremo: buscar tudo e filtrar localmente")
            let urlAll = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
            var reqAll = URLRequest(url: urlAll)
            reqAll.httpMethod = "POST"
            reqAll.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let qAll: [String: Any] = [
                "structuredQuery": [
                    "from": [["collectionId": "transactions"]]
                ]
            ]
            reqAll.httpBody = try JSONSerialization.data(withJSONObject: qAll)
            let (dAll, rAll) = try await URLSession.shared.data(for: reqAll)
            if let hAll = rAll as? HTTPURLResponse, hAll.statusCode == 200 {
                let r = (try? JSONDecoder().decode([FirestoreQueryResponse].self, from: dAll)) ?? []
                let allDocs = r.compactMap { $0.document }
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let possibleIds = [userId, GIDSignIn.sharedInstance.currentUser?.profile?.email ?? ""]
                documents = allDocs.filter { doc in
                    guard let uid = doc.fields.userId?.stringValue else { return false }
                    guard possibleIds.contains(uid) else { return false }
                    // filtrar data
                    if let s = df.date(from: startDate), let e = df.date(from: endDate) {
                        if let ds = doc.fields.date?.stringValue, let d = df.date(from: ds) {
                            return d >= s && d <= e
                        }
                        if let ts = doc.fields.date?.timestampValue, let d = ISO8601DateFormatter().date(from: ts) {
                            return d >= s && d <= e
                        }
                    }
                    return true
                }.sorted { a, b in
                    let da: Date = {
                        if let ds = a.fields.date?.stringValue, let d = df.date(from: ds) { return d }
                        if let ts = a.fields.date?.timestampValue { return ISO8601DateFormatter().date(from: ts) ?? .distantPast }
                        return .distantPast
                    }()
                    let db: Date = {
                        if let ds = b.fields.date?.stringValue, let d = df.date(from: ds) { return d }
                        if let ts = b.fields.date?.timestampValue { return ISO8601DateFormatter().date(from: ts) ?? .distantPast }
                        return .distantPast
                    }()
                    return da < db
                }
                print("📄 All-docs após filtros: \(documents.count)")
            }
        }
        
        let mappedTransactions = documents.map { document in
            let fields = document.fields
            
            // amount pode vir como double, integer ou string
            let parsedAmount: Double = {
                if let d = fields.amount?.doubleValue { return d }
                if let iStr = fields.amount?.integerValue, let i = Double(iStr) { return i }
                if let s = fields.amount?.stringValue, let d = Double(s.replacingOccurrences(of: ",", with: ".")) { return d }
                return 0.0
            }()

            let transaction = TransactionModel(
                id: document.name.components(separatedBy: "/").last ?? "",
                userId: fields.userId?.stringValue ?? userId,
                title: fields.title?.stringValue,
                description: fields.description?.stringValue,
                amount: parsedAmount,
                category: fields.category?.stringValue ?? "Geral",
                date: fields.date?.stringValue ?? "",
                isIncome: fields.isIncome?.booleanValue ?? false,
                type: fields.type?.stringValue ?? "expense",
                status: fields.status?.stringValue ?? "pending",
                createdAt: parseTransactionCreatedAt(fields),
                isRecurring: fields.isRecurring?.booleanValue ?? false,
                recurringFrequency: fields.recurringFrequency?.stringValue ?? "",
                recurringEndDate: fields.recurringEndDate?.stringValue ?? "",
                sourceTransactionId: fields.sourceTransactionId?.stringValue
            )
            
            print("📝 Transação: \(transaction.title ?? "Sem título") - R$ \(transaction.amount)")
            return transaction
        }
        return cacheAndReturn(mappedTransactions)
    }
    
    func saveTransaction(_ transaction: TransactionModel, userId: String, idToken: String) async throws {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/transactions?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let document: [String: Any] = [
            "fields": [
                "userId": ["stringValue": userId],
                "title": ["stringValue": transaction.title ?? ""],
                "description": ["stringValue": transaction.description ?? ""],
                "amount": ["doubleValue": transaction.amount],
                "category": ["stringValue": transaction.category],
                "date": ["stringValue": transaction.date],
                "isIncome": ["booleanValue": transaction.isIncome],
                "type": ["stringValue": transaction.type ?? "expense"],
                "status": ["stringValue": transaction.status ?? "pending"],
                "createdAt": ["timestampValue": isoFormatter.string(from: transaction.createdAt)],
                "isRecurring": ["booleanValue": transaction.isRecurring ?? false],
                "recurringFrequency": ["stringValue": transaction.recurringFrequency ?? ""],
                "recurringEndDate": ["stringValue": transaction.recurringEndDate ?? ""],
                "sourceTransactionId": transaction.sourceTransactionId != nil ? ["stringValue": transaction.sourceTransactionId!] : ["nullValue": NSNull()]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: document)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.saveFailed
        }
        LocalCacheManager.shared.removeAll(withPrefix: "transactions-\(userId)")
    }

    func submitFeedback(userId: String, userName: String, userEmail: String, message: String) async throws {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }

        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/feedbacks?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = isoFormatter.string(from: Date())

        let document: [String: Any] = [
            "fields": [
                "userId": ["stringValue": userId],
                "userName": ["stringValue": userName],
                "userEmail": ["stringValue": userEmail],
                "feedback": ["stringValue": message],
                "createdAt": ["timestampValue": now],
                "updatedAt": ["timestampValue": now]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: document)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FirebaseError.saveFailed
        }
    }

    func getDailyFeedbackCount(userId: String, for date: Date = Date()) async throws -> Int {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }

        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startOfDayString = isoFormatter.string(from: startOfDay)

        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "feedbacks"]],
                "where": [
                    "compositeFilter": [
                        "op": "AND",
                        "filters": [
                            [
                                "fieldFilter": [
                                    "field": ["fieldPath": "userId"],
                                    "op": "EQUAL",
                                    "value": ["stringValue": userId]
                                ]
                            ],
                            [
                                "fieldFilter": [
                                    "field": ["fieldPath": "createdAt"],
                                    "op": "GREATER_THAN_OR_EQUAL",
                                    "value": ["timestampValue": startOfDayString]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: query)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.fetchFailed
        }

        let results = (try? JSONDecoder().decode([FirestoreQueryResponse].self, from: data)) ?? []
        return results.compactMap { $0.document }.count
    }
    
    func getFeedbacks(limit: Int = 200) async throws -> [FeedbackRecord] {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var structuredQuery: [String: Any] = [
            "from": [["collectionId": "feedbacks"]],
            "orderBy": [
                [
                    "field": ["fieldPath": "createdAt"],
                    "direction": "DESCENDING"
                ]
            ]
        ]
        
        if limit > 0 {
            structuredQuery["limit"] = limit
        }

        let query: [String: Any] = ["structuredQuery": structuredQuery]
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let results = (try? decoder.decode([FirestoreQueryResponse].self, from: data)) ?? []
        
        return results.compactMap { result in
            guard let document = result.document else { return nil }
            let fields = document.fields
            let documentId = document.name.components(separatedBy: "/").last ?? UUID().uuidString
            
            return FeedbackRecord(
                id: documentId,
                userId: fields.userId?.stringValue ?? "",
                userName: fields.userName?.stringValue ?? "Usuário",
                userEmail: fields.userEmail?.stringValue ?? "-",
                message: fields.feedback?.stringValue ?? "",
                createdAt: parseFirestoreTimestamp(fields.createdAt)
            )
        }
    }
    
    func updateTransaction(_ transaction: TransactionModel, userId: String, idToken: String) async throws -> Bool {
        guard !projectId.isEmpty && !apiKey.isEmpty,
              let transactionId = transaction.id else {
            throw FirebaseError.configurationError
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/transactions/\(transactionId)?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let document: [String: Any] = [
            "fields": [
                "userId": ["stringValue": userId],
                "title": ["stringValue": transaction.title ?? ""],
                "description": ["stringValue": transaction.description ?? ""],
                "amount": ["doubleValue": transaction.amount],
                "category": ["stringValue": transaction.category],
                "date": ["stringValue": transaction.date],
                "isIncome": ["booleanValue": transaction.isIncome],
                "type": ["stringValue": transaction.type ?? "expense"],
                "status": ["stringValue": transaction.status ?? "pending"],
                "createdAt": ["timestampValue": isoFormatter.string(from: transaction.createdAt)],
                "isRecurring": ["booleanValue": transaction.isRecurring ?? false],
                "recurringFrequency": ["stringValue": transaction.recurringFrequency ?? ""],
                "recurringEndDate": ["stringValue": transaction.recurringEndDate ?? ""],
                "sourceTransactionId": transaction.sourceTransactionId != nil ? ["stringValue": transaction.sourceTransactionId!] : ["nullValue": NSNull()]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: document)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.updateFailed
        }
        
        LocalCacheManager.shared.removeAll(withPrefix: "transactions-\(userId)")
        return true
    }
    
    func deleteTransaction(id: String, userId: String) async throws {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/transactions/\(id)?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.deleteFailed
        }
        LocalCacheManager.shared.removeAll(withPrefix: "transactions-\(userId)")
    }
    
    // MARK: - Category Functions
    func saveCategory(_ category: Category, userId: String, idToken: String) async throws {
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        guard !trimmedUserId.isEmpty else {
            throw FirebaseError.authenticationError
        }
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/categories?key=\(apiKey)")!
        _ = idToken
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let ownerId = category.userId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields: [String: Any] = [
            "name": ["stringValue": category.name],
            "icon": ["stringValue": category.icon],
            "color": ["stringValue": category.color],
            "type": ["stringValue": category.type],
            "isSystem": ["booleanValue": category.isSystem],
            "isDefault": ["booleanValue": category.isDefault],
            "userId": ["stringValue": ownerId?.isEmpty == false ? ownerId! : trimmedUserId],
            "createdAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        
        let requestBody: [String: Any] = [
            "fields": fields
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.saveFailed
        }
        LocalCacheManager.shared.removeAll(withPrefix: "categories-\(userId)")
    }
    
    func getCategories(userId: String, idToken: String) async throws -> [Category] {
        let cacheKey = "categories-\(userId)"
        if let cached: [Category] = LocalCacheManager.shared.load([Category].self, for: cacheKey, maxAge: 60 * 10) {
            print("📦 Retornando categorias em cache")
            return cached
        }
        
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            if let stale: [Category] = LocalCacheManager.shared.load([Category].self, for: cacheKey) {
                print("📦 Usando cache de categorias (configuração ausente)")
                return stale
            }
            print("❌ Firebase não configurado para categorias - projectId: \(projectId), apiKey configurada: \(!apiKey.isEmpty)")
            throw FirebaseError.configurationError
        }
        
        func cacheAndReturn(_ categories: [Category]) -> [Category] {
            LocalCacheManager.shared.save(categories, for: cacheKey)
            return categories
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "categories"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "userId"],
                        "op": "EQUAL",
                        "value": ["stringValue": userId]
                    ]
                ],
                "orderBy": [[
                    "field": ["fieldPath": "name"],
                    "direction": "ASCENDING"
                ]]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FirebaseError.fetchFailed
            }
            
            if httpResponse.statusCode == 200 {
                let results = try JSONDecoder().decode([FirestoreQueryResponse].self, from: data)
                let categories = results.compactMap { entry -> Category? in
                    guard let document = entry.document else { return nil }
                    let fields = document.fields
                    guard fields.userId?.stringValue == userId else { return nil }
                    
                    return Category(
                        id: document.name.components(separatedBy: "/").last ?? "",
                        name: fields.name?.stringValue ?? "",
                        icon: fields.icon?.stringValue ?? "folder",
                        color: fields.color?.stringValue ?? "blue",
                        type: fields.type?.stringValue ?? "expense",
                        isSystem: fields.isSystem?.booleanValue ?? false,
                        userId: fields.userId?.stringValue,
                        isDefault: fields.isDefault?.booleanValue ?? false
                    )
                }
                
                return cacheAndReturn(categories)
            } else {
                let responseString = String(data: data, encoding: .utf8) ?? "Resposta vazia"
                print("❌ Erro HTTP \(httpResponse.statusCode) ao buscar categorias: \(responseString)")
                
                if httpResponse.statusCode == 400,
                   responseString.contains("requires an index") {
                    print("⚠️ Índice composto ausente ao buscar categorias. Aplicando fallback sem ordenação remota.")
                    let fallbackCategories = try await fetchCategoriesWithoutOrder(userId: userId)
                    return cacheAndReturn(fallbackCategories)
                }
                
                throw FirebaseError.fetchFailed
            }
        } catch {
            if let stale: [Category] = LocalCacheManager.shared.load([Category].self, for: cacheKey) {
                print("📦 Usando cache de categorias após erro: \(error.localizedDescription)")
                return stale
            }
            throw error
        }
    }
    
    private func fetchCategoriesWithoutOrder(userId: String) async throws -> [Category] {
        let fallbackQuery: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "categories"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "userId"],
                        "op": "EQUAL",
                        "value": ["stringValue": userId]
                    ]
                ]
            ]
        ]
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fallbackQuery)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let responseString = String(data: data, encoding: .utf8) ?? "Resposta vazia"
            print("❌ Erro no fallback de categorias: \(responseString)")
            throw FirebaseError.fetchFailed
        }
        
        let results = try JSONDecoder().decode([FirestoreQueryResponse].self, from: data)
        let categories = results.compactMap { entry -> Category? in
            guard let document = entry.document else { return nil }
            let fields = document.fields
            guard fields.userId?.stringValue == userId else { return nil }
            
            return Category(
                id: document.name.components(separatedBy: "/").last ?? "",
                name: fields.name?.stringValue ?? "",
                icon: fields.icon?.stringValue ?? "folder",
                color: fields.color?.stringValue ?? "blue",
                type: fields.type?.stringValue ?? "expense",
                isSystem: fields.isSystem?.booleanValue ?? false,
                userId: fields.userId?.stringValue,
                isDefault: fields.isDefault?.booleanValue ?? false
            )
        }
        
        return categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func updateCategory(_ category: Category, userId: String, idToken: String) async throws -> Bool {
        guard let documentId = category.id else {
            throw NSError(domain: "CategoryError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Category ID is required"])
        }
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        guard !trimmedUserId.isEmpty else {
            throw FirebaseError.authenticationError
        }
        _ = idToken
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/categories/\(documentId)?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let fields: [String: Any] = [
            "name": ["stringValue": category.name],
            "icon": ["stringValue": category.icon],
            "color": ["stringValue": category.color],
            "type": ["stringValue": category.type],
            "isSystem": ["booleanValue": category.isSystem],
            "isDefault": ["booleanValue": category.isDefault],
            "userId": ["stringValue": trimmedUserId],
            "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        
        let requestBody: [String: Any] = [
            "fields": fields
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.updateFailed
        }
        LocalCacheManager.shared.removeAll(withPrefix: "categories-\(userId)")
        return true
    }
    
    func deleteCategory(id: String, userId: String, idToken: String) async throws {
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        guard !trimmedUserId.isEmpty else {
            throw FirebaseError.authenticationError
        }
        _ = idToken
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/categories/\(id)?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.deleteFailed
        }
        LocalCacheManager.shared.removeAll(withPrefix: "categories-\(trimmedUserId)")
    }
    
    // MARK: - Goals Methods
    func getGoals(userId: String, idToken: String) async throws -> [Goal] {
        let cacheKey = "goals-\(userId)"
        if let cached: [Goal] = LocalCacheManager.shared.load([Goal].self, for: cacheKey, maxAge: 60 * 5) {
            print("📦 Retornando metas em cache")
            return cached
        }
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            if let stale: [Goal] = LocalCacheManager.shared.load([Goal].self, for: cacheKey) {
                print("📦 Usando cache de metas devido a configuração ausente")
                return stale
            }
            print("❌ Firebase não configurado - projectId: \(projectId), apiKey: \(apiKey.isEmpty ? "vazio" : "configurado")")
            throw FirebaseError.configurationError
        }

        func cacheAndReturn(_ goals: [Goal]) -> [Goal] {
            LocalCacheManager.shared.save(goals, for: cacheKey)
            return goals
        }

        do {
        
        print("🔍 Buscando metas no Firebase...")
        print("📊 Project ID: \(projectId)")
        print("👤 User ID: \(userId)")
        print("🔑 Token (primeiros 20 chars): \(String(idToken.prefix(20)))...")
        
        // Usar API Key em vez de token de autenticação (mesmo padrão das transações)
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "goals"]],
                "where": [
                                "fieldFilter": [
                                    "field": ["fieldPath": "userId"],
                                    "op": "EQUAL",
                                    "value": ["stringValue": userId]
                                ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        
        // Log do request body para debug
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 Request Body (query): \(bodyString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Resposta HTTP inválida ao buscar metas")
            throw FirebaseError.fetchFailed
        }
        
        print("📡 Status HTTP ao buscar metas: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "Resposta vazia"
            print("❌ Erro HTTP \(httpResponse.statusCode) ao buscar metas: \(responseString)")
            
            // Tratar erro 429 (Quota Exceeded) com retry
            if httpResponse.statusCode == 429 {
                print("⚠️ Quota do Firebase excedida. Aguardando 3 segundos antes de tentar novamente...")
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 segundos
                print("🔄 Tentando novamente após delay...")
                // Retry uma vez
                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    print("⚠️ Após retry, ainda sem resposta válida. Retornando array vazio.")
                    return cacheAndReturn([])
                }
                if retryHttpResponse.statusCode == 200 {
                    // Sucesso no retry, continuar com o processamento normal
                    print("✅ Retry bem-sucedido!")
                    let results = try JSONDecoder().decode([FirestoreQueryResponse].self, from: retryData)
                    let documents = results.compactMap { $0.document }
                    if documents.isEmpty {
                        print("ℹ️ Nenhuma meta encontrada após retry")
                        return cacheAndReturn([])
                    }
                    let goals = documents.compactMap { document -> Goal? in
                        let fields = document.fields
                        let deadlineDate = parseFirestoreTimestamp(fields.deadline)
                        let createdAtDate = parseFirestoreTimestamp(fields.createdAt)
                        let updatedAtDate = parseFirestoreTimestamp(fields.updatedAt)
                        return Goal(
                            id: document.name.components(separatedBy: "/").last,
                            userId: fields.userId?.stringValue ?? userId,
                            title: fields.title?.stringValue ?? "",
                            description: fields.description?.stringValue ?? "",
                            targetAmount: fields.targetAmount?.doubleValue ?? 0.0,
                            currentAmount: fields.currentAmount?.doubleValue ?? 0.0,
                            deadline: deadlineDate,
                            category: fields.category?.stringValue ?? "Geral",
                            isPredefined: fields.isPredefined?.booleanValue ?? false,
                            predefinedType: fields.predefinedType?.stringValue,
                            createdAt: createdAtDate,
                            updatedAt: updatedAtDate,
                            isActive: fields.isActive?.booleanValue ?? true
                        )
                    }
                    return cacheAndReturn(goals)
                } else {
                    print("⚠️ Após retry, ainda recebendo erro \(retryHttpResponse.statusCode). Retornando array vazio.")
                    return cacheAndReturn([])
                }
            }
            
            // Se for erro de índice, tentar buscar sem filtro de isActive
            if httpResponse.statusCode == 400 && responseString.contains("requires an index") {
                print("⚠️ Índice composto ausente. Tentando busca simplificada...")
                let fallbackGoals = try await getGoalsFallback(userId: userId)
                return cacheAndReturn(fallbackGoals)
            }
            
            // Se não houver metas, retornar array vazio ao invés de erro
            if httpResponse.statusCode == 404 {
                print("ℹ️ Nenhuma meta encontrada (404), retornando array vazio")
                return cacheAndReturn([])
            }
            
            // Para outros erros, retornar array vazio em vez de lançar exceção
            print("⚠️ Erro HTTP \(httpResponse.statusCode) não tratado. Retornando array vazio.")
            return cacheAndReturn([])
        }
        
        // Verificar se a resposta está vazia (pode acontecer quando não há documentos)
        let responseString = String(data: data, encoding: .utf8) ?? ""
        print("📄 Resposta do Firebase (primeiros 1000 chars): \(String(responseString.prefix(1000)))")
        
        // Verificar se a resposta é um array vazio ou apenas contém readTime
        if data.isEmpty || responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
            print("ℹ️ Nenhuma meta encontrada (resposta vazia), retornando array vazio")
            return cacheAndReturn([])
        }
        
        do {
            let results = try JSONDecoder().decode([FirestoreQueryResponse].self, from: data)
            let documents = results.compactMap { $0.document }
            
            print("✅ \(documents.count) documentos de metas encontrados")
            
            // Se não houver documentos, retornar array vazio
            if documents.isEmpty {
                print("ℹ️ Nenhum documento válido encontrado, retornando array vazio")
                return cacheAndReturn([])
            }
            
            let goals = documents.compactMap { document -> Goal? in
                let fields = document.fields
                
                let deadlineDate = parseFirestoreTimestamp(fields.deadline)
                let createdAtDate = parseFirestoreTimestamp(fields.createdAt)
                let updatedAtDate = parseFirestoreTimestamp(fields.updatedAt)
                
                return Goal(
                    id: document.name.components(separatedBy: "/").last,
                    userId: fields.userId?.stringValue ?? userId,
                    title: fields.title?.stringValue ?? "",
                    description: fields.description?.stringValue ?? "",
                    targetAmount: fields.targetAmount?.doubleValue ?? 0,
                    currentAmount: fields.currentAmount?.doubleValue ?? 0,
                    deadline: deadlineDate,
                    category: fields.category?.stringValue ?? "Geral",
                    isPredefined: fields.isPredefined?.booleanValue ?? false,
                    predefinedType: fields.predefinedType?.stringValue,
                    createdAt: createdAtDate,
                    updatedAt: updatedAtDate,
                    isActive: fields.isActive?.booleanValue ?? true
                )
            }
            
            // Ordenar localmente por data de criação (mais recente primeiro)
            return cacheAndReturn(goals.sorted { $0.createdAt > $1.createdAt })
        } catch {
            print("❌ Erro ao decodificar resposta JSON: \(error)")
            print("❌ Resposta completa: \(responseString)")
            
            // Se o erro for de decodificação, pode ser que não existam metas
            // Retornar array vazio ao invés de lançar erro
            if error is DecodingError {
                print("ℹ️ Erro de decodificação - provavelmente não há metas, retornando array vazio")
                return cacheAndReturn([])
            }
             
             throw error
         }
        } catch {
            if let stale: [Goal] = LocalCacheManager.shared.load([Goal].self, for: cacheKey) {
                print("📦 Usando cache de metas após falha geral: \(error.localizedDescription)")
                return stale
            }
            throw error
        }
    }
    
    // Fallback para buscar metas sem filtro de isActive (caso não haja índice)
    private func getGoalsFallback(userId: String) async throws -> [Goal] {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        
        print("🔄 Tentando busca fallback de metas (sem filtro isActive)...")
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Query simplificada apenas com userId
        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "goals"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "userId"],
                        "op": "EQUAL",
                        "value": ["stringValue": userId]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: query)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ Erro no fallback de busca de metas")
            throw FirebaseError.fetchFailed
        }
        
        let results = try JSONDecoder().decode([FirestoreQueryResponse].self, from: data)
        let documents = results.compactMap { $0.document }
        
        // Filtrar localmente por isActive = true
        let activeGoals = documents.compactMap { document -> Goal? in
            let fields = document.fields
            guard fields.isActive?.booleanValue ?? true else { return nil }
            
            let deadlineDate = parseFirestoreTimestamp(fields.deadline)
            let createdAtDate = parseFirestoreTimestamp(fields.createdAt)
            let updatedAtDate = parseFirestoreTimestamp(fields.updatedAt)
            
            return Goal(
                id: document.name.components(separatedBy: "/").last,
                userId: fields.userId?.stringValue ?? userId,
                title: fields.title?.stringValue ?? "",
                description: fields.description?.stringValue ?? "",
                targetAmount: fields.targetAmount?.doubleValue ?? 0,
                currentAmount: fields.currentAmount?.doubleValue ?? 0,
                deadline: deadlineDate,
                category: fields.category?.stringValue ?? "Geral",
                isPredefined: fields.isPredefined?.booleanValue ?? false,
                predefinedType: fields.predefinedType?.stringValue,
                createdAt: createdAtDate,
                updatedAt: updatedAtDate,
                isActive: fields.isActive?.booleanValue ?? true
            )
        }
        
        print("✅ Fallback retornou \(activeGoals.count) metas ativas")
        return activeGoals.sorted { $0.createdAt > $1.createdAt }
    }
    
    func saveGoal(_ goal: Goal, userId: String, idToken: String) async throws -> String {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/goals?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("💾 Salvando meta no Firebase...")
        print("📊 Project ID: \(projectId)")
        print("👤 User ID: \(userId)")
        
        // Formatar timestamps no formato ISO8601 que o Firestore espera (mesmo formato usado em transações)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let deadlineTimestamp = isoFormatter.string(from: goal.deadline)
        let createdAtTimestamp = isoFormatter.string(from: goal.createdAt)
        let updatedAtTimestamp = isoFormatter.string(from: goal.updatedAt)
        
        print("📅 Timestamps formatados:")
        print("   deadline: \(deadlineTimestamp)")
        print("   createdAt: \(createdAtTimestamp)")
        print("   updatedAt: \(updatedAtTimestamp)")
        
        var fields: [String: Any] = [
            "userId": ["stringValue": userId],
            "title": ["stringValue": goal.title],
            "description": ["stringValue": goal.description],
            "targetAmount": ["doubleValue": goal.targetAmount],
            "currentAmount": ["doubleValue": goal.currentAmount],
            "deadline": ["timestampValue": deadlineTimestamp],
            "category": ["stringValue": goal.category],
            "isPredefined": ["booleanValue": goal.isPredefined],
            "createdAt": ["timestampValue": createdAtTimestamp],
            "updatedAt": ["timestampValue": updatedAtTimestamp],
            "isActive": ["booleanValue": goal.isActive]
        ]
        
        // Adicionar predefinedType apenas se não for nil
        if let predefinedType = goal.predefinedType {
            fields["predefinedType"] = ["stringValue": predefinedType]
        }
        
        let requestBody: [String: Any] = [
            "fields": fields
        ]
        
        do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("📤 Request Body (primeiros 500 chars): \(String(bodyString.prefix(500)))")
            }
        } catch {
            print("❌ Erro ao serializar JSON: \(error)")
            throw FirebaseError.saveFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Erro ao salvar meta: Resposta HTTP inválida")
            print("   URL: \(url)")
            print("   Error: \(errorString)")
            throw FirebaseError.saveFailed
        }
        
        print("📡 Status HTTP ao salvar meta: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Erro ao salvar meta:")
            print("   Status Code: \(httpResponse.statusCode)")
            print("   URL: \(url)")
            print("   Error: \(errorString)")
            
            // Log detalhado do request body para debug
            if let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                print("   Request Body completo: \(bodyString)")
            }
            
            // Verificar se é erro de autenticação
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw FirebaseError.authenticationError
            }
            
            throw FirebaseError.saveFailed
        }
        
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let name = responseData?["name"] as? String ?? ""
        LocalCacheManager.shared.removeAll(withPrefix: "goals-\(userId)")
        return name.components(separatedBy: "/").last ?? ""
    }
    
    func updateGoal(_ goal: Goal, userId: String, idToken: String) async throws -> Bool {
        guard let documentId = goal.id else {
            throw NSError(domain: "GoalError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Goal ID is required"])
        }
        
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/goals/\(documentId)?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📝 Atualizando meta no Firebase...")
        print("📊 Document ID: \(documentId)")
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var fields: [String: Any] = [
            "userId": ["stringValue": userId],
            "title": ["stringValue": goal.title],
            "description": ["stringValue": goal.description],
            "targetAmount": ["doubleValue": goal.targetAmount],
            "currentAmount": ["doubleValue": goal.currentAmount],
            "deadline": ["timestampValue": isoFormatter.string(from: goal.deadline)],
            "category": ["stringValue": goal.category],
            "isPredefined": ["booleanValue": goal.isPredefined],
            "createdAt": ["timestampValue": isoFormatter.string(from: goal.createdAt)],
            "updatedAt": ["timestampValue": isoFormatter.string(from: Date())],
            "isActive": ["booleanValue": goal.isActive]
        ]
        
        // Adicionar predefinedType apenas se não for nil
        if let predefinedType = goal.predefinedType {
            fields["predefinedType"] = ["stringValue": predefinedType]
        }
        
        let requestBody: [String: Any] = [
            "fields": fields
        ]
        
        do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Erro ao serializar JSON para atualizar meta: \(error)")
            throw FirebaseError.updateFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Erro ao atualizar meta: Resposta HTTP inválida")
            print("   Error: \(errorString)")
            throw FirebaseError.updateFailed
        }
        
        print("📡 Status HTTP ao atualizar meta: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Erro ao atualizar meta:")
            print("   Status Code: \(httpResponse.statusCode)")
            print("   Error: \(errorString)")
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw FirebaseError.authenticationError
            }
            
            throw FirebaseError.updateFailed
        }
        
        LocalCacheManager.shared.removeAll(withPrefix: "goals-\(userId)")
        return true
    }
    
    func deleteGoal(id: String, userId: String, idToken: String) async throws {
        guard !projectId.isEmpty && !apiKey.isEmpty else {
            throw FirebaseError.configurationError
        }
        
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/goals/\(id)?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseError.deleteFailed
        }
        LocalCacheManager.shared.removeAll(withPrefix: "goals-\(userId)")
    }
}

// MARK: - Firebase Models
struct FirebaseAuthResponse: Codable {
    let idToken: String
    let refreshToken: String
    let expiresIn: String
    let localId: String
    
    enum CodingKeys: String, CodingKey {
        case idToken
        case refreshToken
        case expiresIn
        case localId
    }
}

enum FirebaseError: Error, LocalizedError {
    case authenticationFailed
    case authenticationError
    case configurationError
    case deleteFailed
    case fetchFailed
    case saveFailed
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Falha na autenticação"
        case .authenticationError:
            return "Token de autenticação não encontrado"
        case .configurationError:
            return "Erro de configuração do Firebase"
        case .deleteFailed:
            return "Falha ao excluir item"
        case .fetchFailed:
            return "Falha ao buscar dados"
        case .saveFailed:
            return "Falha ao salvar dados"
        case .updateFailed:
            return "Falha ao atualizar dados"
        }
    }
}

// MARK: - AuthViewModel
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: UserModel?
    @Published var accountType: UserModel.AccountType = .free
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isFirstLogin: Bool = true
    
    let firebaseService = FirebaseRESTService.shared
    
    init() {
        // Restaurar sessão do Google se disponível e sincronizar com Firestore users
        restoreSession()
    }
    
    // MARK: - Authentication Methods
    func signInWithGoogle() {
        errorMessage = nil
        isLoading = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Erro ao acessar a interface"
            isLoading = false
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Erro no login: \(error.localizedDescription)"
                    return
                }
                
                guard let user = result?.user else {
                    self?.errorMessage = "Erro ao obter dados do usuário"
                    return
                }
                
                // Login bem-sucedido
                Task { [weak self] in
                    let email = user.profile?.email ?? ""
                    let internalId = try? await self?.firebaseService.lookupInternalUserId(byEmail: email)
                    await MainActor.run {
                        self?.isAuthenticated = true
                        self?.isFirstLogin = false
                        self?.user = UserModel(
                            id: (internalId ?? nil) ?? (user.userID ?? "google-user-\(UUID().uuidString)"),
                            name: user.profile?.name ?? "Usuário Google",
                            email: email.isEmpty ? "usuario@gmail.com" : email,
                            profileImageURL: user.profile?.imageURL(withDimension: 200),
                            accountType: .free,
                            idToken: user.idToken?.tokenString ?? ""
                        )
                    }
                }
            }
        }
    }
    
    
    
    func signInWithEmail(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let idToken = try await firebaseService.authenticateUser(email: email, password: password)
            
            await MainActor.run {
            self.isAuthenticated = true
                self.isFirstLogin = false
            self.user = UserModel(
                    id: "firebase-user-123", // Em produção, extrair do token
                    name: "Usuário Firebase",
                    email: email,
                profileImageURL: nil,
                accountType: .free,
                idToken: idToken
            )
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        self.isAuthenticated = false
        self.isFirstLogin = true
        self.user = nil
    }

    // MARK: - Account Testing Helpers
    func setPremiumStatus(isPremium: Bool, source: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let targetType: UserModel.AccountType = isPremium ? .premium : .free
        setAccountType(targetType, source: source, completion: completion)
    }
    
    func setAccountType(_ newType: UserModel.AccountType, source: String? = nil, completion: ((Bool) -> Void)? = nil) {
        guard let currentUser = user else {
            completion?(false)
            return
        }
        let updatedUser = UserModel(
            id: currentUser.id,
            name: currentUser.name,
            email: currentUser.email,
            profileImageURL: currentUser.profileImageURL,
            accountType: newType,
            idToken: currentUser.idToken
        )
        DispatchQueue.main.async {
            self.user = updatedUser
            self.accountType = newType
            self.errorMessage = nil
            if let source {
                print("ℹ️ Tipo de conta atualizado para \(newType.displayName) via \(source)")
            } else {
                print("ℹ️ Tipo de conta atualizado para \(newType.displayName)")
            }
            completion?(true)
        }
    }
    
    // MARK: - Private Methods
    private func restoreSession() {
        // Tenta restaurar sessão silenciosamente
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                if let _ = error {
                    self?.isAuthenticated = false
                    self?.user = nil
                    return
                }
                guard let user = user else {
                    self?.isAuthenticated = false
                    self?.user = nil
                    return
                }
                self?.isAuthenticated = true
                let email = user.profile?.email ?? ""
                let capturedUser = user
                let capturedService = self?.firebaseService
                Task { @MainActor [weak self] in
                    let internalId = try? await capturedService?.lookupInternalUserId(byEmail: email)
                    self?.user = UserModel(
                        id: (internalId ?? nil) ?? (capturedUser.userID ?? "google-user-\(UUID().uuidString)"),
                        name: capturedUser.profile?.name ?? "Usuário Google",
                        email: email.isEmpty ? "usuario@gmail.com" : email,
                        profileImageURL: capturedUser.profile?.imageURL(withDimension: 200),
                        accountType: .free,
                        idToken: capturedUser.idToken?.tokenString ?? ""
                    )
                }
            }
        } else {
            // Sessão não existente
            self.isAuthenticated = false
            self.user = nil
        }
    }
}

// MARK: - Firestore Models
struct FirestoreQueryResponse: Codable {
    let document: FirestoreDocument?
}

struct FirestoreDocument: Codable {
    let name: String
    let fields: FirestoreFields
}

struct FirestoreFields: Codable {
    // Generic / common
    let userId: FirestoreValue?
    let userName: FirestoreValue?
    let userEmail: FirestoreValue?
    let id: FirestoreValue?
    
    // Category fields
    let name: FirestoreValue?
    let icon: FirestoreValue?
    let color: FirestoreValue?
    let isSystem: FirestoreValue?
    let isDefault: FirestoreValue?
    
    // Transaction / Category metadata
    let title: FirestoreValue?
    let description: FirestoreValue?
    let amount: FirestoreValue?
    let category: FirestoreValue?
    let date: FirestoreValue?
    let isIncome: FirestoreValue?
    let type: FirestoreValue?
    let status: FirestoreValue?
    let createdAt: FirestoreValue?
    let isRecurring: FirestoreValue?
    let recurringFrequency: FirestoreValue?
    let recurringEndDate: FirestoreValue?
    let sourceTransactionId: FirestoreValue?
    let feedback: FirestoreValue?
    // Goal fields
    let targetAmount: FirestoreValue?
    let currentAmount: FirestoreValue?
    let deadline: FirestoreValue?
    let isPredefined: FirestoreValue?
    let predefinedType: FirestoreValue?
    let updatedAt: FirestoreValue?
    let isActive: FirestoreValue?
}

struct FirestoreValue: Codable {
    let stringValue: String?
    let doubleValue: Double?
    let integerValue: String?
    let booleanValue: Bool?
    let timestampValue: String?
    let nullValue: String?
}

struct FeedbackRecord: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userEmail: String
    let message: String
    let createdAt: Date
}

// MARK: - Category Response Models
struct FirestoreResponse: Codable {
    let documents: [CategoryDocument]
}

struct CategoryDocument: Codable {
    let name: String
    let fields: CategoryFields
}

struct CategoryFields: Codable {
    let name: FirestoreValue?
    let icon: FirestoreValue?
    let color: FirestoreValue?
    let type: FirestoreValue?
    let isSystem: FirestoreValue?
    let isDefault: FirestoreValue?
    let userId: FirestoreValue?
    let createdAt: FirestoreValue?
    let updatedAt: FirestoreValue?
}


// MARK: - Helper Functions
private func parseISO8601TimestampString(_ string: String) -> Date? {
    let formatterWithFractional = ISO8601DateFormatter()
    formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatterWithFractional.date(from: string) {
        return date
    }
    
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: string)
}

private func parseTransactionCreatedAt(_ fields: FirestoreFields) -> Date {
    if let ts = fields.createdAt?.timestampValue, let date = parseISO8601TimestampString(ts) {
        return date
    }
    
    if let stringValue = fields.createdAt?.stringValue, let date = parseISO8601TimestampString(stringValue) {
        return date
    }
    
    if let dateStr = fields.date?.stringValue {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            return date
        }
    }
    
    return Date()
}

private func parseFirestoreTimestamp(_ timestamp: FirestoreValue?) -> Date {
    if let timestampValue = timestamp?.timestampValue, let date = parseISO8601TimestampString(timestampValue) {
        return date
    }
    
    if let stringValue = timestamp?.stringValue, let date = parseISO8601TimestampString(stringValue) {
        return date
    }
    
    return Date()
}