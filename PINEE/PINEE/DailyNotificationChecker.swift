//
//  DailyNotificationChecker.swift
//  PINEE
//
//  Serviço que verifica diariamente contas e gera notificações
//

import Foundation
import UserNotifications
import Combine

/// Serviço que verifica diariamente contas e gera notificações
@MainActor
class DailyNotificationChecker: ObservableObject {
    static let shared = DailyNotificationChecker()
    
    @Published var isActive: Bool = false
    
    private let aiService = NotificationAIService.shared
    private let notificationManager = NotificationManager.shared
    private let firebaseService = FirebaseRESTService.shared
    private var checkTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    private var notificationHour: Int = 9
    private var notificationMinute: Int = 0
    private var periodicity: String = "daily" // daily, weekly, monthly
    private var intensity: String = "moderate" // light, moderate, intense
    private var storedUserId: String?
    private var storedIdToken: String?
    
    private init() {}
    
    /// Inicia as verificações diárias
    func startDailyChecks(
        userId: String,
        idToken: String,
        periodicity: String = "daily",
        intensity: String = "moderate"
    ) async {
        guard !isActive else { return }
        
        isActive = true
        self.periodicity = periodicity
        self.intensity = intensity
        self.storedUserId = userId
        self.storedIdToken = idToken
        
        // Fazer uma verificação inicial
        await checkAndGenerateNotifications(userId: userId, idToken: idToken)
        
        // Agendar verificação baseada na periodicidade
        await scheduleCheck(userId: userId, idToken: idToken)
    }
    
    /// Para as verificações diárias
    func stopDailyChecks() async {
        isActive = false
        checkTask?.cancel()
        checkTask = nil
        
        let identifiers = await pendingCheckIdentifiers()
        if !identifiers.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    /// Atualiza o agendamento das notificações
    func updateSchedule(
        userId: String,
        idToken: String,
        periodicity: String? = nil,
        intensity: String? = nil
    ) async {
        if let periodicity = periodicity {
            self.periodicity = periodicity
        }
        if let intensity = intensity {
            self.intensity = intensity
        }
        self.storedUserId = userId
        self.storedIdToken = idToken
        
        // Se já está ativo, reagendar
        if isActive, let userId = storedUserId, let idToken = storedIdToken {
            await scheduleCheck(userId: userId, idToken: idToken)
        }
    }
    
    /// Verifica e gera notificações baseadas nas transações
    func checkAndGenerateNotifications(userId: String, idToken: String) async {
        guard notificationManager.notificationsEnabled else {
            print("⚠️ Notificações não autorizadas")
            return
        }
        
        // Buscar transações do período atual (últimos 7 dias e próximos 7 dias)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let today = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        do {
            print("🔄 Verificando transações para notificações...")
            let transactions = try await firebaseService.getTransactions(
                userId: userId,
                startDate: startDateString,
                endDate: endDateString,
                idToken: idToken
            )
            
            print("✅ \(transactions.count) transações encontradas")
            
            // Analisar e gerar notificações
            await aiService.analyzeAndGenerateNotifications(
                userId: userId,
                idToken: idToken,
                transactions: transactions
            )
            
            // Filtrar e limitar notificações baseado na intensidade
            let filteredNotifications = filterNotificationsByIntensity(aiService.notifications)
            
            // Agendar notificações filtradas
            for notification in filteredNotifications {
                await notificationManager.scheduleAINotification(notification)
            }
            
            // Enviar via push notifications também
            await sendPushNotifications(userId: userId, notifications: filteredNotifications)
            
        } catch {
            print("❌ Erro ao verificar transações: \(error.localizedDescription)")
        }
    }
    
    /// Filtra notificações baseado na intensidade configurada
    private func filterNotificationsByIntensity(_ notifications: [AINotification]) -> [AINotification] {
        let enabledNotifications = notifications.filter { isNotificationTypeEnabled($0.type) }
        let maxNotifications: Int
        switch intensity {
        case "light":
            maxNotifications = 2
        case "moderate":
            maxNotifications = 5
        case "intense":
            maxNotifications = Int.max // Sem limite
        default:
            maxNotifications = 5
        }
        
        // Ordenar por prioridade (urgent > high > medium > low)
        let priorityOrder: [AINotification.NotificationPriority] = [.urgent, .high, .medium, .low]
        let sorted = enabledNotifications.sorted { first, second in
            let firstIndex = priorityOrder.firstIndex(of: first.priority) ?? Int.max
            let secondIndex = priorityOrder.firstIndex(of: second.priority) ?? Int.max
            return firstIndex < secondIndex
        }
        
        return Array(sorted.prefix(maxNotifications))
    }
    
    /// Envia notificações via push
    private func sendPushNotifications(userId: String, notifications: [AINotification]) async {
        let pushService = PushNotificationService.shared
        
        for notification in notifications {
            // Enviar via push se o token FCM estiver disponível
            if let fcmToken = pushService.fcmToken {
                do {
                    try await pushService.sendPushNotification(
                        userId: userId,
                        fcmToken: fcmToken,
                        title: notification.title,
                        body: notification.message,
                        data: ["type": notification.type.rawValue]
                    )
                } catch {
                    print("❌ Erro ao enviar push notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Agenda verificação baseada na periodicidade configurada
    private func scheduleCheck(userId: String, idToken: String) async {
        checkTask?.cancel()
        checkTask = nil
        
        await scheduleReminderNotifications(userId: userId)
        
        let intervals = intervalsForCurrentSettings()
        guard !intervals.isEmpty else { return }
        
        checkTask = Task { [weak self] in
            guard let self else { return }
            var index = 0
            while !Task.isCancelled {
                let interval = intervals[index % intervals.count]
                index += 1
                
                let nanoseconds = UInt64(max(interval, 1) * 1_000_000_000)
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    break
                }
                
                if Task.isCancelled { break }
                await self.checkAndGenerateNotifications(userId: userId, idToken: idToken)
            }
        }
    }
}

// MARK: - Scheduling Helpers

extension DailyNotificationChecker {
    private func intervalsForCurrentSettings() -> [TimeInterval] {
        switch periodicity {
        case "daily":
            switch intensity {
            case "light":
                return [24 * 60 * 60] // 1 vez por dia
            case "moderate":
                return Array(repeating: 8 * 60 * 60, count: 3) // 3 vezes por dia
            case "intense":
                return Array(repeating: 4 * 60 * 60, count: 6) // 6 vezes por dia
            default:
                return Array(repeating: 8 * 60 * 60, count: 3)
            }
        case "weekly":
            return [7 * 24 * 60 * 60]
        case "monthly":
            return [30 * 24 * 60 * 60]
        default:
            return [24 * 60 * 60]
        }
    }
    
    private func reminderTimes() -> [(hour: Int, minute: Int)] {
        switch periodicity {
        case "daily":
            switch intensity {
            case "light":
                return [(notificationHour, notificationMinute)]
            case "moderate":
                return [(8, 30), (13, 0), (19, 30)]
            case "intense":
                return [(8, 0), (10, 30), (13, 0), (15, 30), (18, 0), (20, 30)]
            default:
                return [(notificationHour, notificationMinute)]
            }
        case "weekly", "monthly":
            return [(notificationHour, notificationMinute)]
        default:
            return [(notificationHour, notificationMinute)]
        }
    }
    
    private func scheduleReminderNotifications(userId: String) async {
        let identifiers = await pendingCheckIdentifiers()
        if !identifiers.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        
        let content = UNMutableNotificationContent()
        switch periodicity {
        case "daily":
            content.title = "Verificação diária de finanças"
        case "weekly":
            content.title = "Verificação semanal de finanças"
        case "monthly":
            content.title = "Verificação mensal de finanças"
        default:
            content.title = "Verificação de finanças"
        }
        content.body = "O PINEE está analisando suas contas e notificações."
        content.sound = .default
        content.categoryIdentifier = "CHECK_\(periodicity.uppercased())"
        
        let times = reminderTimes()
        for (index, slot) in times.enumerated() {
            var dateComponents = DateComponents()
            dateComponents.hour = slot.hour
            dateComponents.minute = slot.minute
            
            switch periodicity {
            case "weekly":
                dateComponents.weekday = 2 // Segunda-feira
            case "monthly":
                dateComponents.day = 1
            default:
                break
            }
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = "check_\(periodicity)_\(userId)_\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ Lembrete de verificação agendado (\(identifier)) para \(slot.hour):\(String(format: "%02d", slot.minute))")
            } catch {
                print("❌ Erro ao agendar lembrete de verificação: \(error.localizedDescription)")
            }
        }
    }
    
    private func pendingCheckIdentifiers() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests
            .map { $0.identifier }
            .filter { $0.hasPrefix("check_") }
    }
    
    func isNotificationTypeEnabled(_ type: NotificationType) -> Bool {
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

// MARK: - App Lifecycle Extension

extension DailyNotificationChecker {
    /// Chama quando o app entra em foreground
    func onAppBecameActive(userId: String, idToken: String) async {
        if isActive {
            await checkAndGenerateNotifications(userId: userId, idToken: idToken)
        }
    }
}

