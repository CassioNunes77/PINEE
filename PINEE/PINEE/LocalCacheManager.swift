import Foundation

struct CategoryDataProvider {
    static let hiddenCategoryIDs: Set<String> = ["uncategorized", "general", "goals", "investment"]
    static let legacyDisplayNames: [String: String] = [
        "services": "Serviços",
        "entertainment": "Entretenimento",
        "investment": "Investimentos",
        "general": "Sem Categoria"
    ]
    static let investmentCategoryID: String = "investment"

    private static func incomeDefaults() -> [Category] {
        return [
            Category(id: "salary", name: "Salário", icon: "dollarsign.circle.fill", color: "green", type: "income", isSystem: true, userId: nil, isDefault: true),
            Category(id: "services_income", name: "Serviços", icon: "briefcase.fill", color: "orange", type: "income", isSystem: true, userId: nil, isDefault: true),
            Category(id: "extra_income", name: "Renda Extra", icon: "gift.fill", color: "blue", type: "income", isSystem: true, userId: nil, isDefault: true)
        ]
    }

    static func defaultIncomeCategories() -> [Category] {
        incomeDefaults()
    }

    private static func expenseDefaults() -> [Category] {
        return [
            Category(id: "home", name: "Casa", icon: "house.fill", color: "brown", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "subscriptions", name: "Assinaturas", icon: "tv.fill", color: "purple", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "transportation", name: "Transporte", icon: "car.fill", color: "blue", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "food", name: "Alimentação", icon: "fork.knife", color: "green", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "shopping", name: "Compras", icon: "bag.fill", color: "pink", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "health", name: "Saúde", icon: "heart.fill", color: "red", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "education", name: "Educação", icon: "book.fill", color: "indigo", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "credit_card", name: "Cartão de Crédito", icon: "creditcard.fill", color: "teal", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "leisure", name: "Lazer", icon: "sparkles", color: "orange", type: "expense", isSystem: true, userId: nil, isDefault: true),
            Category(id: "loans", name: "Empréstimos", icon: "banknote", color: "red", type: "expense", isSystem: true, userId: nil, isDefault: true)
        ]
    }

    static func defaultExpenseCategories() -> [Category] {
        expenseDefaults()
    }

    private static func systemHiddenCategories() -> [Category] {
        return [
            Category(id: "uncategorized", name: "Sem Categoria", icon: "questionmark.folder", color: "gray", type: "system", isSystem: true, userId: nil, isDefault: true),
            Category(id: "goals", name: "Metas", icon: "target", color: "purple", type: "goal", isSystem: true, userId: nil, isDefault: true),
            Category(id: investmentCategoryID, name: "Investimentos", icon: "chart.line.uptrend.xyaxis", color: "blue", type: "investment", isSystem: true, userId: nil, isDefault: true)
        ]
    }

    static func defaultCategories(includeHidden: Bool = true) -> [Category] {
        let base = incomeDefaults() + expenseDefaults() + (includeHidden ? systemHiddenCategories() : [])
        return base
    }

    static func visibleDefaultCategories() -> [Category] {
        return defaultCategories(includeHidden: true).filter { !hiddenCategoryIDs.contains($0.identifiedId) }
    }

    static func categories(for type: String, includeHidden: Bool = false) -> [Category] {
        let normalizedType = type.lowercased()
        return defaultCategories(includeHidden: true).filter { category in
            let categoryId = category.identifiedId
            if hiddenCategoryIDs.contains(categoryId) {
                return includeHidden && matches(type: normalizedType, with: category)
            }
            return matches(type: normalizedType, with: category)
        }
    }

    static func displayName(for categoryId: String) -> String {
        let normalizedId = categoryId.lowercased()

        if normalizedId.isEmpty {
            return "Sem Categoria"
        }

        if let legacy = legacyDisplayNames[normalizedId] {
            return legacy
        }

        if let defaultMatch = defaultCategories(includeHidden: true).first(where: { $0.identifiedId.lowercased() == normalizedId }) {
            return defaultMatch.name
        }

        return categoryId
    }

    static func fallbackCategoryID(for type: String) -> String {
        let normalizedType = type.lowercased()
        if normalizedType == "investment" { return investmentCategoryID }
        return "uncategorized"
    }

    private static func matches(type: String, with category: Category) -> Bool {
        let categoryType = category.type.lowercased()
        if type == "investment" {
            return categoryType == "investment"
        }
        if type == "income" {
            return categoryType == "income"
        }
        if type == "expense" {
            return categoryType == "expense"
        }
        return categoryType == type
    }
}

extension Category {
    var isHiddenSystemCategory: Bool {
        CategoryDataProvider.hiddenCategoryIDs.contains(identifiedId)
    }
}

final class LocalCacheManager {
    static let shared = LocalCacheManager()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "com.pinee.LocalCacheManager", attributes: .concurrent)

    private struct CacheEnvelope<T: Codable>: Codable {
        let timestamp: Date
        let value: T
    }

    private init() {
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let directory = cachesURL.appendingPathComponent("PINEECache", isDirectory: true)
            cacheDirectory = directory
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
        } else {
            cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PINEECache", isDirectory: true)
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    func save<T: Codable>(_ value: T, for key: String) {
        let sanitizedKey = sanitize(key)
        let fileURL = cacheDirectory.appendingPathComponent(sanitizedKey)
        queue.async(flags: .barrier) {
            let envelope = CacheEnvelope(timestamp: Date(), value: value)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(envelope)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("⚠️ Falha ao salvar cache para chave \(key): \(error.localizedDescription)")
            }
        }
    }

    func load<T: Codable>(_ type: T.Type, for key: String, maxAge: TimeInterval? = nil) -> T? {
        let sanitizedKey = sanitize(key)
        let fileURL = cacheDirectory.appendingPathComponent(sanitizedKey)
        var result: T?

        queue.sync {
            guard fileManager.fileExists(atPath: fileURL.path) else { return }
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let envelope = try decoder.decode(CacheEnvelope<T>.self, from: data)

                if let maxAge = maxAge {
                    let age = Date().timeIntervalSince(envelope.timestamp)
                    guard age <= maxAge else { return }
                }

                result = envelope.value
            } catch {
                print("⚠️ Falha ao carregar cache para chave \(key): \(error.localizedDescription)")
            }
        }

        return result
    }

    func remove(for key: String) {
        let sanitizedKey = sanitize(key)
        let fileURL = cacheDirectory.appendingPathComponent(sanitizedKey)
        queue.async(flags: .barrier) {
            if self.fileManager.fileExists(atPath: fileURL.path) {
                try? self.fileManager.removeItem(at: fileURL)
            }
        }
    }

    func removeAll(withPrefix prefix: String) {
        let sanitizedPrefix = sanitize(prefix)
        queue.async(flags: .barrier) {
            guard let files = try? self.fileManager.contentsOfDirectory(atPath: self.cacheDirectory.path) else { return }
            files.filter { $0.hasPrefix(sanitizedPrefix) }.forEach { fileName in
                let url = self.cacheDirectory.appendingPathComponent(fileName)
                try? self.fileManager.removeItem(at: url)
            }
        }
    }

    private func sanitize(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return key.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.reduce("", { $0 + String($1) })
    }
}

