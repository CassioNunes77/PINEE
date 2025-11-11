//
//  NotificationAIService.swift
//  PINEE
//
//  Created for AI-powered notifications
//

import Foundation
import Combine

/// Tipo de notificação que pode ser gerada
enum NotificationType: String, Codable {
    case billDueToday = "bill_due_today"
    case billDueTomorrow = "bill_due_tomorrow"
    case billOverdue = "bill_overdue"
    case lowBalance = "low_balance"
    case goalProgress = "goal_progress"
    case monthlySummary = "monthly_summary"
    case custom = "custom"
}

/// Modelo de notificação gerada pela IA
struct AINotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let priority: NotificationPriority
    let scheduledDate: Date?
    let metadata: [String: String]?
    
    enum NotificationPriority: String, Codable {
        case low
        case medium
        case high
        case urgent
    }
}

/// Serviço base para gerar notificações inteligentes usando IA
@MainActor
class NotificationAIService: ObservableObject {
    static let shared = NotificationAIService()
    
    @Published var notifications: [AINotification] = []
    @Published var isProcessing: Bool = false
    
    private let firebaseService = FirebaseRESTService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Analisa transações e gera notificações inteligentes
    func analyzeAndGenerateNotifications(
        userId: String,
        idToken: String,
        transactions: [TransactionModel]
    ) async {
        isProcessing = true
        defer { isProcessing = false }
        
        var generatedNotifications: [AINotification] = []
        
        // 1. Verificar contas para pagar hoje
        if isTypeEnabled(.billDueToday) {
            let billsDueToday = await checkBillsDueToday(
                userId: userId,
                idToken: idToken,
                transactions: transactions
            )
            
            if !billsDueToday.isEmpty {
                let notification = generateBillDueTodayNotification(bills: billsDueToday)
                generatedNotifications.append(notification)
            }
        }
        
        // 2. Verificar contas para pagar amanhã
        if isTypeEnabled(.billDueTomorrow) {
            let billsDueTomorrow = await checkBillsDueTomorrow(
                userId: userId,
                idToken: idToken,
                transactions: transactions
            )
            
            if !billsDueTomorrow.isEmpty {
                let notification = generateBillDueTomorrowNotification(bills: billsDueTomorrow)
                generatedNotifications.append(notification)
            }
        }
        
        // 3. Verificar contas atrasadas
        if isTypeEnabled(.billOverdue) {
            let overdueBills = await checkOverdueBills(
                userId: userId,
                idToken: idToken,
                transactions: transactions
            )
            
            if !overdueBills.isEmpty {
                let notification = generateOverdueBillNotification(bills: overdueBills)
                generatedNotifications.append(notification)
            }
        }
        
        self.notifications = generatedNotifications.filter { isTypeEnabled($0.type) }
    }
    
    // MARK: - Verificação de Contas
    
    /// Verifica contas que vencem hoje
    private func checkBillsDueToday(
        userId: String,
        idToken: String,
        transactions: [TransactionModel]
    ) async -> [TransactionModel] {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)
        
        // Filtrar despesas não pagas que vencem hoje
        let billsDueToday = transactions.filter { transaction in
            guard transaction.isIncome == false,
                  transaction.type == "expense",
                  transaction.status != "paid",
                  transaction.date == todayString else {
                return false
            }
            return true
        }
        
        return billsDueToday
    }
    
    /// Verifica contas que vencem amanhã
    private func checkBillsDueTomorrow(
        userId: String,
        idToken: String,
        transactions: [TransactionModel]
    ) async -> [TransactionModel] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let tomorrowString = dateFormatter.string(from: tomorrow)
        
        // Filtrar despesas não pagas que vencem amanhã
        let billsDueTomorrow = transactions.filter { transaction in
            guard transaction.isIncome == false,
                  transaction.type == "expense",
                  transaction.status != "paid",
                  transaction.date == tomorrowString else {
                return false
            }
            return true
        }
        
        return billsDueTomorrow
    }
    
    /// Verifica contas atrasadas
    private func checkOverdueBills(
        userId: String,
        idToken: String,
        transactions: [TransactionModel]
    ) async -> [TransactionModel] {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)
        
        // Filtrar despesas não pagas que já passaram da data de vencimento
        let overdueBills = transactions.filter { transaction in
            guard transaction.isIncome == false,
                  transaction.type == "expense",
                  transaction.status != "paid",
                  transaction.date < todayString else {
                return false
            }
            return true
        }
        
        return overdueBills
    }
    
    // MARK: - Geração de Notificações
    
    /// Gera notificação para contas que vencem hoje
    private func generateBillDueTodayNotification(bills: [TransactionModel]) -> AINotification {
        let totalAmount = bills.reduce(0) { $0 + $1.amount }
        let billCount = bills.count
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        let formattedAmount = formatter.string(from: NSNumber(value: totalAmount)) ?? "R$ 0,00"
        
        let title: String
        let message: String
        
        if billCount == 1 {
            let bill = bills.first!
            title = "Conta para pagar hoje"
            message = "Você tem \(bill.title ?? "uma conta") de \(formattedAmount) vencendo hoje."
        } else {
            title = "Contas para pagar hoje"
            message = "Você tem \(billCount) contas totalizando \(formattedAmount) vencendo hoje."
        }
        
        return AINotification(
            id: UUID().uuidString,
            type: .billDueToday,
            title: title,
            message: message,
            priority: .high,
            scheduledDate: Date(),
            metadata: [
                "bill_count": "\(billCount)",
                "total_amount": "\(totalAmount)",
                "notification_type": NotificationType.billDueToday.rawValue
            ]
        )
    }
    
    /// Gera notificação para contas que vencem amanhã
    private func generateBillDueTomorrowNotification(bills: [TransactionModel]) -> AINotification {
        let totalAmount = bills.reduce(0) { $0 + $1.amount }
        let billCount = bills.count
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        let formattedAmount = formatter.string(from: NSNumber(value: totalAmount)) ?? "R$ 0,00"
        
        let title = billCount == 1 ? "Conta vencendo amanhã" : "Contas vencendo amanhã"
        let message = "Você tem \(billCount) conta\(billCount > 1 ? "s" : "") totalizando \(formattedAmount) vencendo amanhã."
        
        return AINotification(
            id: UUID().uuidString,
            type: .billDueTomorrow,
            title: title,
            message: message,
            priority: .medium,
            scheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            metadata: [
                "bill_count": "\(billCount)",
                "total_amount": "\(totalAmount)",
                "notification_type": NotificationType.billDueTomorrow.rawValue
            ]
        )
    }
    
    /// Gera notificação para contas atrasadas
    private func generateOverdueBillNotification(bills: [TransactionModel]) -> AINotification {
        let totalAmount = bills.reduce(0) { $0 + $1.amount }
        let billCount = bills.count
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        let formattedAmount = formatter.string(from: NSNumber(value: totalAmount)) ?? "R$ 0,00"
        
        let title = "Contas atrasadas"
        let message = "⚠️ Você tem \(billCount) conta\(billCount > 1 ? "s" : "") atrasada\(billCount > 1 ? "s" : "") totalizando \(formattedAmount)."
        
        return AINotification(
            id: UUID().uuidString,
            type: .billOverdue,
            title: title,
            message: message,
            priority: .urgent,
            scheduledDate: Date(),
            metadata: [
                "bill_count": "\(billCount)",
                "total_amount": "\(totalAmount)",
                "notification_type": NotificationType.billOverdue.rawValue
            ]
        )
    }
    
    /// Limpa notificações antigas
    func clearNotifications() {
        notifications = []
    }
}

// MARK: - Preferences

extension NotificationAIService {
    func isTypeEnabled(_ type: NotificationType) -> Bool {
        let defaults = UserDefaults.standard
        let key: String
        switch type {
        case .billDueToday:
            key = "billDueTodayEnabled"
        case .billDueTomorrow:
            key = "billDueTomorrowEnabled"
        case .billOverdue:
            key = "billOverdueEnabled"
        case .lowBalance:
            key = "lowBalanceEnabled"
        case .goalProgress:
            key = "goalProgressEnabled"
        case .monthlySummary:
            key = "monthlySummaryEnabled"
        case .custom:
            return true
        }
        
        if defaults.object(forKey: key) == nil {
            return true
        }
        return defaults.bool(forKey: key)
    }
}






