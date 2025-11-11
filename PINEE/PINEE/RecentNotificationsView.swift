//
//  RecentNotificationsView.swift
//  PINEE
//
//  Created by ChatGPT on 08/11/25.
//

import SwiftUI
import UserNotifications

struct RecentNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    @ObservedObject private var aiService = NotificationAIService.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    @State private var isLoading: Bool = true
    @State private var notificationItems: [RecentNotificationItem] = []
    
    var body: some View {
        List {
            if notificationItems.isEmpty && !isLoading {
                emptyState
            } else {
                ForEach(notificationItems) { item in
                    NotificationRow(item: item, isMonochromaticMode: isMonochromaticMode)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if isLoading {
                ProgressView("Carregando notificações...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .navigationTitle("Notificações Recentes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Limpar") {
                    Task {
                        await clearDeliveredNotifications()
                        await loadNotifications()
                    }
                }
                .disabled(notificationItems.isEmpty)
            }
        }
        .refreshable {
            await loadNotifications()
        }
        .task {
            await loadNotifications()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Nenhuma notificação recente")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            Text("Assim que novas notificações forem geradas, elas aparecerão aqui.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
    
    @MainActor
    private func loadNotifications() async {
        isLoading = true
        
        let aiNotifications = aiService.notifications.map {
            RecentNotificationItem(
                id: $0.id,
                title: $0.title.isEmpty ? "Notificação" : $0.title,
                message: $0.message,
                date: $0.scheduledDate ?? Date(),
                source: .internalAI,
                priority: $0.priority,
                metadata: $0.metadata,
                icon: iconFor(aiType: $0.type)
            )
        }
        
        let pendingRequests = await notificationManager.getPendingNotifications()
        let pendingItems: [RecentNotificationItem] = pendingRequests.compactMap { request -> RecentNotificationItem? in
            guard let scheduledDate = request.nextTriggerDate else { return nil }
            return RecentNotificationItem(
                id: request.identifier,
                title: request.content.title.isEmpty ? "Notificação Agendada" : request.content.title,
                message: request.content.body,
                date: scheduledDate,
                source: sourceFor(identifier: request.identifier),
                priority: nil,
                metadata: request.content.userInfo as? [String: String],
                icon: iconFor(identifier: request.identifier)
            )
        }
        
        let delivered = await notificationManager.getDeliveredNotifications()
        let deliveredItems = delivered.map { delivered in
            RecentNotificationItem(
                id: delivered.request.identifier + "_delivered_\(delivered.date.timeIntervalSince1970)",
                title: delivered.request.content.title.isEmpty ? "Notificação Recebida" : delivered.request.content.title,
                message: delivered.request.content.body,
                date: delivered.date,
                source: sourceFor(identifier: delivered.request.identifier),
                priority: nil,
                metadata: delivered.request.content.userInfo as? [String: String],
                icon: iconFor(identifier: delivered.request.identifier)
            )
        }
        
        var combined = aiNotifications + pendingItems + deliveredItems
        combined.sort { $0.date > $1.date }
        
        notificationItems = combined.deduplicated()
        aiService.clearNotifications()
        notificationManager.updateBadgeCount(0)
        isLoading = false
    }
    
    @MainActor
    private func clearDeliveredNotifications() async {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        notificationItems.removeAll { $0.source == .push || $0.source == .scheduled }
        notificationManager.updateBadgeCount(0)
    }
    
    private func iconFor(aiType: NotificationType) -> String {
        switch aiType {
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
            return "bell"
        }
    }
    
    private func iconFor(identifier: String) -> String {
        if identifier.contains("push_") {
            return "paperplane.fill"
        }
        if identifier.contains("check_") {
            return "arrow.triangle.2.circlepath"
        }
        return "bell"
    }
    
    private func sourceFor(identifier: String) -> RecentNotificationItem.Source {
        if identifier.contains("push_") {
            return .push
        }
        if identifier.contains("check_") {
            return .scheduled
        }
        return .internalAI
    }
}

// MARK: - Models & Helpers

private struct RecentNotificationItem: Identifiable, Hashable {
    enum Source {
        case internalAI
        case push
        case scheduled
    }
    
    let id: String
    let title: String
    let message: String
    let date: Date
    let source: Source
    let priority: AINotification.NotificationPriority?
    let metadata: [String: String]?
    let icon: String
}

private extension Array where Element == RecentNotificationItem {
    func deduplicated() -> [Element] {
        var seen = Set<String>()
        return self.filter { item in
            if seen.contains(item.id) {
                return false
            }
            seen.insert(item.id)
            return true
        }
    }
}

private struct NotificationRow: View {
    let item: RecentNotificationItem
    let isMonochromaticMode: Bool
    
    private var badgeColor: Color {
        switch item.priority {
        case .urgent:
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.red
        case .high:
            return isMonochromaticMode ? MonochromaticColorManager.secondaryGreen : Color.orange
        case .medium:
            return isMonochromaticMode ? MonochromaticColorManager.primaryGray : Color.blue
        case .low, .none:
            return isMonochromaticMode ? MonochromaticColorManager.secondaryGray : Color.secondary
        }
    }
    
    private var sourceLabel: String {
        switch item.source {
        case .internalAI: return "PINEE Insights"
        case .push: return "Push"
        case .scheduled: return "Agendada"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(badgeColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(item.date, style: .relative)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text(item.message.isEmpty ? "Sem detalhes adicionais." : item.message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack(spacing: 8) {
                    Text(sourceLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor.opacity(0.12))
                        .cornerRadius(8)
                    
                    if let priority = item.priority {
                        Text(priorityLabel(priority))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func priorityLabel(_ priority: AINotification.NotificationPriority) -> String {
        switch priority {
        case .urgent: return "Urgente"
        case .high: return "Alta"
        case .medium: return "Média"
        case .low: return "Baixa"
        }
    }
}

private extension UNNotificationRequest {
    var nextTriggerDate: Date? {
        guard let trigger = trigger else { return nil }
        switch trigger {
        case let calendarTrigger as UNCalendarNotificationTrigger:
            return calendarTrigger.nextTriggerDate()
        case let intervalTrigger as UNTimeIntervalNotificationTrigger:
            if intervalTrigger.repeats {
                return Date().addingTimeInterval(intervalTrigger.timeInterval)
            } else {
                return Date().addingTimeInterval(intervalTrigger.timeInterval)
            }
        default:
            return nil
        }
    }
}

