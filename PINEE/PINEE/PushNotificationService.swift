//
//  PushNotificationService.swift
//  PINEE
//
//  Serviço para gerenciar notificações push via Firebase Cloud Messaging
//

import Foundation
import UserNotifications
import Combine
import UIKit

/// Serviço de Push Notifications (via Firebase Cloud Messaging REST API)
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()
    
    @Published var fcmToken: String?
    @Published var isSubscribed: Bool = false
    @Published var pushNotificationsEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let firebaseService = FirebaseRESTService.shared
    
    private override init() {
        super.init()
        setupPushNotifications()
    }
    
    /// Configura push notifications
    private func setupPushNotifications() {
        // Registrar para notificações remotas
        UNUserNotificationCenter.current().delegate = self
        
        // Solicitar autorização para notificações
        Task { @MainActor in
            await requestPushPermission()
        }
    }
    
    /// Solicita permissão para push notifications
    @MainActor
    func requestPushPermission() async {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
        
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)
            self.pushNotificationsEnabled = granted
            
            if granted {
                // Registrar para receber push notifications (não é async)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("❌ Erro ao solicitar permissão para push notifications: \(error.localizedDescription)")
        }
    }
    
    /// Salva o token FCM no servidor (via Firebase REST)
    @MainActor
    func saveFCMToken(userId: String, idToken: String, fcmToken: String) async {
        print("💾 Salvando FCM token para usuário: \(userId)")
        // TODO: Implementar salvamento do token no Firebase
        // Por enquanto, apenas log
        self.fcmToken = fcmToken
        print("📱 FCM Token: \(fcmToken)")
    }
    
    /// Envia notificação push via Firebase Cloud Messaging REST API
    @MainActor
    func sendPushNotification(
        userId: String,
        fcmToken: String,
        title: String,
        body: String,
        data: [String: String]? = nil
    ) async throws {
        // TODO: Implementar envio via Firebase Cloud Messaging REST API
        // Por enquanto, usa notificação local como fallback
        print("📤 Enviando push notification: \(title) - \(body)")
        
        // Usar NotificationManager como fallback
        await NotificationManager.shared.scheduleNotification(
            id: "push_\(UUID().uuidString)",
            title: title,
            body: body,
            date: Date().addingTimeInterval(1)
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Mostrar notificação mesmo quando o app está em foreground
        let options: UNNotificationPresentationOptions
        if #available(iOS 14.0, *) {
            options = [.banner, .sound, .badge]
        } else {
            options = [.alert, .sound, .badge]
        }
        completionHandler(options)
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        print("📬 Notificação recebida: \(userInfo)")
        
        // TODO: Navegar para tela específica baseado no tipo de notificação
        completionHandler()
    }
}

