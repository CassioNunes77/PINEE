//
//  NotificationsView.swift
//  PINEE
//
//  View para gerenciar notificações
//

import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var aiService = NotificationAIService.shared
    @StateObject private var dailyChecker = DailyNotificationChecker.shared
    @StateObject private var pushService = PushNotificationService.shared
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("dailyNotificationEnabled") private var dailyNotificationEnabled: Bool = false
    @AppStorage("notificationIntensity") private var notificationIntensity: String = "moderate" // Leve, Moderada, Intensa
    
    // Tipos de notificações habilitados
    @AppStorage("billDueTodayEnabled") private var billDueTodayEnabled: Bool = true
    @AppStorage("billDueTomorrowEnabled") private var billDueTomorrowEnabled: Bool = true
    @AppStorage("billOverdueEnabled") private var billOverdueEnabled: Bool = true
    @AppStorage("lowBalanceEnabled") private var lowBalanceEnabled: Bool = true
    @AppStorage("goalProgressEnabled") private var goalProgressEnabled: Bool = true
    @AppStorage("monthlySummaryEnabled") private var monthlySummaryEnabled: Bool = true
    
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""
    @State private var isLoading = false
    
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: notificationManager.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                    
                    Text("Notificações Inteligentes")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Receba alertas sobre suas finanças")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Status de Permissão
                if notificationManager.authorizationStatus != .authorized {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Notificações Desabilitadas")
                                .fontWeight(.semibold)
                        }
                        
                        Text("Ative as notificações para receber alertas sobre suas contas e metas financeiras.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            Task {
                                await requestNotificationPermission()
                            }
                        }) {
                            Text("Ativar Notificações")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                
                // Configurações
                if notificationManager.notificationsEnabled {
                    VStack(spacing: 16) {
                        // Toggle de Notificações Diárias
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notificações Diárias")
                                    .font(.headline)
                                Text("Verificar contas automaticamente")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $dailyNotificationEnabled)
                                .onChange(of: dailyNotificationEnabled) { newValue in
                                    Task {
                                        if newValue {
                                            await enableDailyNotifications()
                                        } else {
                                            await disableDailyNotifications()
                                        }
                                    }
                                }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Intensidade (quantidade por dia)
                        if dailyNotificationEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Intensidade")
                                    .font(.headline)
                                
                                Text("Quantidade de notificações por dia")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    IntensityOption(
                                        title: "Leve",
                                        description: "1-2 notificações por dia",
                                        icon: "moon.fill",
                                        isSelected: notificationIntensity == "light",
                                        action: {
                                            notificationIntensity = "light"
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                    
                                    IntensityOption(
                                        title: "Moderada",
                                        description: "3-5 notificações por dia",
                                        icon: "sun.max.fill",
                                        isSelected: notificationIntensity == "moderate",
                                        action: {
                                            notificationIntensity = "moderate"
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                    
                                    IntensityOption(
                                        title: "Intensa",
                                        description: "6+ notificações por dia",
                                        icon: "flame.fill",
                                        isSelected: notificationIntensity == "intense",
                                        action: {
                                            notificationIntensity = "intense"
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        
                        // Tipos de Notificações
                        if dailyNotificationEnabled {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Tipos de Notificações")
                                    .font(.headline)
                                
                                VStack(spacing: 12) {
                                    NotificationTypeToggle(
                                        title: "Contas para Pagar Hoje",
                                        description: "Alertas sobre contas vencendo hoje",
                                        icon: "doc.text.fill",
                                        isEnabled: $billDueTodayEnabled,
                                        onChanged: {
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                    
                                    NotificationTypeToggle(
                                        title: "Contas para Pagar Amanhã",
                                        description: "Alertas sobre contas vencendo amanhã",
                                        icon: "calendar.badge.clock",
                                        isEnabled: $billDueTomorrowEnabled,
                                        onChanged: {
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                    
                                    NotificationTypeToggle(
                                        title: "Contas Atrasadas",
                                        description: "Alertas sobre contas em atraso",
                                        icon: "exclamationmark.triangle.fill",
                                        isEnabled: $billOverdueEnabled,
                                        onChanged: {
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                    
                                    NotificationTypeToggle(
                                        title: "Saldo Baixo",
                                        description: "Alertas quando o saldo estiver baixo",
                                        icon: "dollarsign.circle.fill",
                                        isEnabled: $lowBalanceEnabled,
                                        onChanged: {
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                    
                                    NotificationTypeToggle(
                                        title: "Progresso de Metas",
                                        description: "Atualizações sobre suas metas financeiras",
                                        icon: "target",
                                        isEnabled: $goalProgressEnabled,
                                        onChanged: {
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                    
                                    NotificationTypeToggle(
                                        title: "Resumo Mensal",
                                        description: "Resumo financeiro mensal",
                                        icon: "chart.bar.fill",
                                        isEnabled: $monthlySummaryEnabled,
                                        onChanged: {
                                            Task {
                                                await applyNotificationPreferences(runImmediateCheck: true)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Notificações Geradas
                    if !aiService.notifications.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notificações Geradas")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(aiService.notifications) { notification in
                                NotificationCard(notification: notification)
                            }
                        }
                    }
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            notificationManager.checkAuthorizationStatus()
            Task {
                await loadNotifications()
            }
        }
        .alert("Permissão de Notificações", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(permissionMessage)
        }
    }
    
    // MARK: - Actions
    
    private func requestNotificationPermission() async {
        isLoading = true
        let granted = await notificationManager.requestAuthorization()
        isLoading = false
        
        if granted {
            permissionMessage = "Notificações ativadas com sucesso!"
            notificationsEnabled = true
        } else {
            permissionMessage = "Para receber notificações, ative as permissões nas Configurações do iOS."
        }
        showPermissionAlert = true
    }
    
    private func enableDailyNotifications() async {
        guard let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
            return
        }
        
        // Habilitar push notifications
        await pushService.requestPushPermission()
        
        await dailyChecker.startDailyChecks(
            userId: userId,
            idToken: idToken,
            periodicity: "daily", // Sempre diária
            intensity: notificationIntensity
        )
        await applyNotificationPreferences(runImmediateCheck: false)
    }
    
    private func disableDailyNotifications() async {
        await dailyChecker.stopDailyChecks()
        notificationManager.cancelAllNotifications()
    }
    
    private func applyNotificationPreferences(runImmediateCheck: Bool) async {
        guard let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
            return
        }
        
        if dailyNotificationEnabled {
            await dailyChecker.updateSchedule(
                userId: userId,
                idToken: idToken,
                periodicity: nil,
                intensity: notificationIntensity
            )
            await notificationManager.cancelAINotifications()
            if runImmediateCheck {
                await dailyChecker.checkAndGenerateNotifications(userId: userId, idToken: idToken)
            }
        } else {
            await dailyChecker.stopDailyChecks()
            notificationManager.cancelAllNotifications()
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
            return
        }
        
        await dailyChecker.checkAndGenerateNotifications(userId: userId, idToken: idToken)
    }
    
}

// MARK: - Intensity Option

struct IntensityOption: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue) : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                }
            }
            .padding()
            .background(isSelected ? (isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.blue.opacity(0.1)) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue) : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notification Type Toggle

struct NotificationTypeToggle: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isEnabled: Bool
    var onChanged: (() -> Void)? = nil
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    isEnabled = newValue
                    onChanged?()
                }
            ))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: AINotification
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var priorityColor: Color {
        switch notification.priority {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForType(notification.type))
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : priorityColor)
                
                Text(notification.title)
                    .font(.headline)
                
                Spacer()
                
                Text(priorityText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.2))
                    .foregroundColor(priorityColor)
                    .cornerRadius(8)
            }
            
            Text(notification.message)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let scheduledDate = notification.scheduledDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(scheduledDate, style: .relative)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var priorityText: String {
        switch notification.priority {
        case .low: return "Baixa"
        case .medium: return "Média"
        case .high: return "Alta"
        case .urgent: return "Urgente"
        }
    }
    
    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .billDueToday, .billDueTomorrow:
            return "doc.text.fill"
        case .billOverdue:
            return "exclamationmark.triangle.fill"
        case .lowBalance:
            return "dollarsign.circle.fill"
        case .goalProgress:
            return "target"
        case .monthlySummary:
            return "chart.bar.fill"
        case .custom:
            return "bell.fill"
        }
    }
}

// MARK: - Preview

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationsView()
                .environmentObject(AuthViewModel())
        }
    }
}

