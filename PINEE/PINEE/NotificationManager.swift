//
//  NotificationManager.swift
//  PINEE
//
//  Gerenciador de notificações locais
//

import Foundation
import UserNotifications
import Combine
import UIKit

/// Gerenciador de notificações locais
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var notificationsEnabled: Bool = false
    @Published var badgeCount: Int = UIApplication.shared.applicationIconBadgeNumber
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    /// Verifica o status atual de autorização
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorizationStatus = settings.authorizationStatus
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Solicita permissão para notificações
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
                self.notificationsEnabled = granted
            }
            return granted
        } catch {
            print("❌ Erro ao solicitar permissão de notificações: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Agenda uma notificação local
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool = false
    ) async {
        guard authorizationStatus == .authorized else {
            print("⚠️ Notificações não autorizadas")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Criar trigger baseado na data
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("✅ Notificação agendada: \(title) para \(date)")
            await refreshBadgeCount()
        } catch {
            print("❌ Erro ao agendar notificação: \(error.localizedDescription)")
        }
    }
    
    /// Agenda notificação para hoje às 9h
    func scheduleDailyNotification(
        id: String,
        title: String,
        body: String,
        hour: Int = 9,
        minute: Int = 0
    ) async {
        guard authorizationStatus == .authorized else {
            print("⚠️ Notificações não autorizadas")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("✅ Notificação diária agendada: \(title) às \(hour):\(String(format: "%02d", minute))")
            await refreshBadgeCount()
        } catch {
            print("❌ Erro ao agendar notificação diária: \(error.localizedDescription)")
        }
    }
    
    /// Agenda uma notificação baseada em AINotification
    func scheduleAINotification(_ notification: AINotification) async {
        guard let scheduledDate = notification.scheduledDate else {
            print("⚠️ Notificação sem data agendada")
            return
        }
        
        // Se a data já passou, agendar para hoje às 9h
        let dateToSchedule = scheduledDate < Date() ? 
            Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date() :
            scheduledDate
        
        await scheduleNotification(
            id: notification.id,
            title: notification.title,
            body: notification.message,
            date: dateToSchedule,
            repeats: false
        )
    }
    
    /// Cancela uma notificação específica
    func cancelNotification(id: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        print("✅ Notificação cancelada: \(id)")
    }
    
    /// Cancela todas as notificações pendentes
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("✅ Todas as notificações foram canceladas")
        updateBadgeCount(0)
    }
    
    /// Cancela apenas notificações geradas pela IA (mantém lembretes internos)
    func cancelAINotifications() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let aiIdentifiers = requests
            .map { $0.identifier }
            .filter { !$0.hasPrefix("check_") }
        
        guard !aiIdentifiers.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: aiIdentifiers)
        print("✅ Notificações da IA canceladas: \(aiIdentifiers.count)")
        await refreshBadgeCount()
    }
    
    /// Lista todas as notificações pendentes
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    /// Lista notificações já entregues
    func getDeliveredNotifications() async -> [UNNotification] {
        await notificationCenter.deliveredNotifications()
    }
    
    func updateBadgeCount(_ newValue: Int) {
        let clamped = max(0, newValue)
        badgeCount = clamped
        UIApplication.shared.applicationIconBadgeNumber = clamped
    }
    
    func refreshBadgeCount(includeAINotifications: Bool = true) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let delivered = await notificationCenter.deliveredNotifications()
        var total = pending.count + delivered.count
        if includeAINotifications {
            total += NotificationAIService.shared.notifications.count
        }
        updateBadgeCount(total)
    }
}






