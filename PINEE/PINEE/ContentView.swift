//
//  ContentView.swift
//  PINEE
//
//  Created by Cássio Nunes on 18/06/25.
//

import SwiftUI
// import FirebaseAuth // Temporariamente desabilitado
import UserNotifications
import StoreKit
import AudioToolbox
import GoogleSignIn

// Definição local de DateRange para compatibilidade
struct DateRange {
    var start: Date
    var end: Date
    var displayText: String
    init(start: Date, end: Date, displayText: String) {
        self.start = start
        self.end = end
        self.displayText = displayText
    }
}

struct DashboardChartEntry: Identifiable {
    let date: Date
    let income: Double
    let expense: Double
    
    var id: Date { date }
}

// Classe para gerenciar o estado global do período selecionado
class GlobalDateManager: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var periodType: PeriodType = .monthly
    private let calendar = Calendar.current
    
    enum PeriodType: String, CaseIterable, Hashable {
        case monthly = "monthly"
        case yearly = "yearly"
        case allTime = "allTime"
        
        var displayName: String {
            switch self {
            case .monthly: return "Mensal"
            case .yearly: return "Anual"
            case .allTime: return "Todo o período"
            }
        }
    }
    
    func updateSelectedDate(_ date: Date) {
        selectedDate = date
    }
    
    func updatePeriodType(_ type: PeriodType) {
        periodType = type
    }
    
    func canNavigateBackward() -> Bool {
        return true // Simplificado para sempre permitir navegação
    }
    
    func canNavigateForward() -> Bool {
        return true // Simplificado para sempre permitir navegação
    }
    
    func previousPeriod() {
        switch periodType {
        case .monthly:
            if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                selectedDate = newDate
            }
        case .yearly:
            if let newDate = calendar.date(byAdding: .year, value: -1, to: selectedDate) {
                selectedDate = newDate
            }
        case .allTime:
            break
        }
    }
    
    func nextPeriod() {
        switch periodType {
        case .monthly:
            if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                selectedDate = newDate
            }
        case .yearly:
            if let newDate = calendar.date(byAdding: .year, value: 1, to: selectedDate) {
                selectedDate = newDate
            }
        case .allTime:
            break
        }
    }
    
    func getCurrentDateRange() -> DateRange {
        switch periodType {
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: selectedDate)
            let startOfMonth = calendar.date(from: comps) ?? selectedDate
            var endComponents = DateComponents()
            endComponents.month = 1
            endComponents.day = -1
            let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth) ?? selectedDate
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateFormat = "LLLL yyyy"
            let text = formatter.string(from: startOfMonth).capitalized
            return DateRange(start: startOfMonth, end: endOfMonth, displayText: text)
        case .yearly:
            let year = calendar.component(.year, from: selectedDate)
            let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? selectedDate
            let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? selectedDate
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateFormat = "yyyy"
            let text = formatter.string(from: startOfYear)
            return DateRange(start: startOfYear, end: endOfYear, displayText: text)
        case .allTime:
            // Abrange todo o período possível; o backend deve ignorar o filtro de data
            let distantPast = Date(timeIntervalSince1970: 0)
            let distantFuture = Date(timeIntervalSince1970: 4102444800) // ~2100-01-01
            return DateRange(start: distantPast, end: distantFuture, displayText: "Todo o período")
        }
    }
    
    // Novo método para calcular o período do saldo consolidado
    func getConsolidatedBalanceDateRange() -> DateRange {
        switch periodType {
        case .monthly:
            // Para mensal, incluir todo o histórico até o final do mês selecionado
            let comps = calendar.dateComponents([.year, .month], from: selectedDate)
            let startOfMonth = calendar.date(from: comps) ?? selectedDate
            var endComponents = DateComponents()
            endComponents.month = 1
            endComponents.day = -1
            let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth) ?? selectedDate
            
            // Data de início muito antiga para incluir todo o histórico
            let startDate = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateFormat = "LLLL yyyy"
            let monthText = formatter.string(from: startOfMonth).capitalized
            
            return DateRange(
                start: startDate,
                end: endOfMonth,
                displayText: "Acumulado até \(monthText)"
            )
            
        case .yearly:
            // Para anual, incluir apenas o ano selecionado
            let year = calendar.component(.year, from: selectedDate)
            let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? selectedDate
            let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? selectedDate
            
            return DateRange(
                start: startOfYear,
                end: endOfYear,
                displayText: "Ano \(year)"
            )
            
        case .allTime:
            // Para todo o período, incluir todo o histórico
            let startDate = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
            let endDate = Date()
            
            return DateRange(
                start: startDate,
                end: endDate,
                displayText: "Todo o período"
            )
        }
    }
}

// MARK: - Welcome Notification View
struct WelcomeNotificationView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Bem-vindo ao PINEE!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

// MARK: - Delete Confirmation View
struct DeleteConfirmationView: View {
    let transaction: TransactionModel
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        ZStack {
            // Overlay escuro de fundo
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Card de confirmação
            VStack(spacing: 0) {
                // Header com ícone
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: isMonochromaticMode ?
                                        [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "trash.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Excluir Transação")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(transaction.title ?? "sem título")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Mensagem
                VStack(spacing: 12) {
                    Text("Tem certeza que deseja excluir esta transação?")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Esta ação não pode ser desfeita.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Botões
                HStack(spacing: 12) {
                    // Botão Cancelar
                    Button(action: {
                        onCancel()
                    }) {
                        Text("Cancelar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    
                    // Botão Excluir
                    Button(action: {
                        // Feedback tátil
                        FeedbackService.shared.confirmFeedback()
                        
                        onConfirm()
                    }) {
                        Text("Excluir")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isMonochromaticMode ?
                                        [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 340)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

struct GoalDeleteConfirmationView: View {
    let goal: Goal
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: isMonochromaticMode ?
                                        [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "target")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Excluir Meta")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(goal.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                VStack(spacing: 12) {
                    Text("Tem certeza que deseja excluir esta meta?")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Esta ação não pode ser desfeita.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                HStack(spacing: 12) {
                    Button(action: {
                        onCancel()
                    }) {
                        Text("Cancelar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        FeedbackService.shared.confirmFeedback()
                        onConfirm()
                    }) {
                        Text("Excluir")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isMonochromaticMode ?
                                        [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
                                    ),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 340)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Status Notification View
struct StatusNotificationView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(message)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Goal Model
struct Goal: Identifiable, Codable {
    var id: String?
    var userId: String
    let title: String
    let description: String
    let targetAmount: Double
    let currentAmount: Double
    let deadline: Date
    let category: String
    let isPredefined: Bool
    let predefinedType: String?
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    
    init(id: String? = nil, 
         userId: String,
         title: String, 
         description: String, 
         targetAmount: Double, 
         currentAmount: Double, 
         deadline: Date,
         category: String = "Geral",
         isPredefined: Bool = false,
         predefinedType: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         isActive: Bool = true) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.category = category
        self.isPredefined = isPredefined
        self.predefinedType = predefinedType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }
}
// MARK: - Goals View
struct GoalsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var goals: [Goal] = []
    @State private var goalToEdit: Goal?
    @State private var goalPendingDeletion: Goal?
    @State private var showGoalDeleteConfirmation = false
    @State private var statusFilter: String = "all"
    @State private var totalTargetAmount: Double = 0
    @State private var totalCurrentAmount: Double = 0
    @State private var totalProgress: Double = 0
    @State private var showAddGoalSheet = false
    @State private var showPredefinedGoalSheet = false
    @State private var showStatusNotification = false
    @State private var statusNotificationMessage = ""
    @State private var refreshTimer: Timer?
    private let firebaseService = FirebaseRESTService.shared
    private let feedbackService = FeedbackService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Filtro de status e categoria (fixo no topo)
            filterView
                .background(Color(UIColor.systemBackground))
            
            Divider()
                .opacity(0.3)
            
            // Conteúdo rolável
            Group {
                if goals.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Cards de progresso geral
                            progressCardsView
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            
                            // Filtros de status e categoria
                            filtersView
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            
                            Divider()
                                .opacity(0.3)
                                .padding(.horizontal, 16)
                            
                            // Lista de metas
                            LazyVStack(spacing: 8) {
                                ForEach(filteredGoals) { goal in
                                    SwipeableGoalRow(
                                        goal: goal,
                                        onEdit: { editGoal(goal) },
                                        onDelete: { requestGoalDeletion(goal) },
                                        onUpdateProgress: { updateGoalProgress(goal, newAmount: $0) },
                                        onTap: { editGoal(goal) }
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 12)
                            
                            // Espaçamento extra para evitar sobreposição com menu inferior
                            Spacer(minLength: 120)
                        }
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .overlay(
            ZStack {
                if showStatusNotification {
                    GoalStatusNotificationView(
                        message: statusNotificationMessage,
                        isVisible: $showStatusNotification
                    )
                    .zIndex(1000)
                }
                
                if showGoalDeleteConfirmation, let goal = goalPendingDeletion {
                    GoalDeleteConfirmationView(
                        goal: goal,
                        onConfirm: confirmGoalDeletion,
                        onCancel: cancelGoalDeletion
                    )
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(2000)
                }
            }
        )
        .onAppear {
            loadGoals()
            startPeriodicRefresh()
        }
        .onDisappear {
            stopPeriodicRefresh()
        }
        .sheet(isPresented: $showAddGoalSheet) {
            AddGoalView { newGoal in
                addGoal(newGoal)
            }
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showPredefinedGoalSheet) {
            PredefinedGoalView { newGoal in
                addGoal(newGoal)
            }
            .environmentObject(authViewModel)
        }
        .sheet(item: $goalToEdit) { goal in
            AddGoalView(goalToEdit: goal) { updatedGoal in
                updateGoal(updatedGoal)
            }
            .environmentObject(authViewModel)
        }
    }
    
    // MARK: - View Components
    private var filterView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }
    
    private var progressCardsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Card de Progresso Geral
                NavigationLink(
                    destination: GoalsView()
                        .environmentObject(authViewModel)
                ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .orange)
                        
                        Text("Progresso Geral")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text("\(Int(totalProgress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    ProgressView(value: totalProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: getProgressColor(totalProgress)))
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    feedbackService.triggerLight()
                })
                
                // Card de Valor Total
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "banknote")
                            .font(.system(size: 16))
                            .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                        
                        Text("Total")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    Text(formatCurrency(totalCurrentAmount))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("de " + formatCurrency(totalTargetAmount))
                        .font(.system(size: 12))
            .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private var filtersView: some View {
        VStack(spacing: 12) {
            // Filtro de Status + Novo
            HStack(spacing: 8) {
                FilterButton(
                    title: getStatusText(),
                    icon: getStatusIcon(),
                    isSelected: statusFilter != "all",
                    backgroundColor: getStatusBackground(),
                    borderColor: getStatusBorderColor()
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        statusFilter = statusFilter == "all" ? "active" : statusFilter == "active" ? "completed" : "all"
                    }
                    feedbackService.triggerLight()
                }
                
                Spacer()
                
                Menu {
                    Button {
                        feedbackService.triggerLight()
                        showPredefinedGoalSheet = true
                    } label: {
                        Label("Meta Pré-definida", systemImage: "list.bullet")
                    }
                    
                    Button {
                        feedbackService.triggerLight()
                        showAddGoalSheet = true
                    } label: {
                        Label("Meta Personalizada", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Nova Meta")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ?
                                [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                [Color(hex: "#3B82F6"), Color(hex: "#2563EB")]
                            ),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "target")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("Nenhuma meta encontrada")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Crie sua primeira meta financeira para começar a planejar seu futuro")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showPredefinedGoalSheet = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("Escolher Meta Pré-definida")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ? 
                                [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                [Color.blue, Color(hex: "#3B82F6")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showAddGoalSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Criar Meta Personalizada")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ? 
                                [MonochromaticColorManager.secondaryGreen, MonochromaticColorManager.primaryGreen] :
                                [Color.green, Color(hex: "#16A34A")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Computed Properties
    private var filteredGoals: [Goal] {
        var filtered = goals
        
        if statusFilter != "all" {
            filtered = filtered.filter { goal in
                let progress = goal.currentAmount / goal.targetAmount
                if statusFilter == "active" {
                    return progress < 1.0
                } else if statusFilter == "completed" {
                    return progress >= 1.0
                }
                return true
            }
        }
        
        return filtered
    }
    
    // MARK: - Data Management
    private func loadGoals() {
        guard let userId = authViewModel.user?.id else {
            print("⚠️ Usuário não autenticado para carregar metas")
            return
        }
        
        Task {
            do {
                // Obter token atualizado
                var idToken = authViewModel.user?.idToken ?? ""
                if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                    try await currentUser.refreshTokensIfNeeded()
                    idToken = currentUser.idToken?.tokenString ?? ""
                }
                
                guard !idToken.isEmpty else {
                    print("⚠️ Token inválido para carregar metas")
                    return
                }
                
                let loadedGoals = try await firebaseService.getGoals(userId: userId, idToken: idToken)
                await MainActor.run {
                    self.goals = loadedGoals
                    self.calculateTotals()
                    print("✅ \(loadedGoals.count) metas carregadas")
                    
                    // Se não houver metas, não mostrar erro, apenas manter a lista vazia
                    if loadedGoals.isEmpty {
                        print("ℹ️ Nenhuma meta encontrada para este usuário")
                    }
                }
            } catch {
                print("❌ Erro ao carregar metas: \(error.localizedDescription)")
                await MainActor.run {
                    // Verificar se é um erro de autenticação
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("401") || errorMessage.contains("UNAUTHENTICATED") || errorMessage.contains("autenticação") {
                        displayStatusNotification(message: "Erro de autenticação. Faça login novamente.")
                    } else if errorMessage.contains("Falha ao buscar dados") {
                        // Se não houver metas, não mostrar erro - apenas manter lista vazia
                        print("ℹ️ Nenhuma meta encontrada - mantendo lista vazia")
                    } else {
                        displayStatusNotification(message: "Erro ao carregar metas: \(errorMessage)")
                    }
                }
            }
        }
    }
    
    private func startPeriodicRefresh() {
        // Atualizar a cada 30 segundos para simular tempo real
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.loadGoals()
        }
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func calculateTotals() {
        var targetTotal: Double = 0
        var currentTotal: Double = 0
        
        for goal in goals {
            targetTotal += goal.targetAmount
            currentTotal += goal.currentAmount
        }
        
        totalTargetAmount = targetTotal
        totalCurrentAmount = currentTotal
        totalProgress = targetTotal > 0 ? currentTotal / targetTotal : 0
    }
    
    private func addGoal(_ goal: Goal) {
        guard let userId = authViewModel.user?.id else {
            displayStatusNotification(message: "Erro: Usuário não autenticado")
            return
        }
        
        // Obter token atualizado do Google Sign-In
        Task {
            do {
                // Tentar obter token atualizado
                var idToken = authViewModel.user?.idToken ?? ""
                
                // Se o token estiver vazio, tentar renovar
                if idToken.isEmpty {
                    print("⚠️ Token vazio, tentando renovar...")
                    if let currentUser = GIDSignIn.sharedInstance.currentUser {
                        // Forçar renovação do token
                        try await currentUser.refreshTokensIfNeeded()
                        idToken = currentUser.idToken?.tokenString ?? ""
                    }
                }
                
                guard !idToken.isEmpty else {
                    await MainActor.run {
                        self.displayStatusNotification(message: "Erro: Token de autenticação inválido. Faça login novamente.")
                    }
                    return
                }
                
                let newGoal = Goal(
                    id: goal.id,
                    userId: userId,
                    title: goal.title,
                    description: goal.description,
                    targetAmount: goal.targetAmount,
                    currentAmount: goal.currentAmount,
                    deadline: goal.deadline,
                    category: goal.category,
                    isPredefined: goal.isPredefined,
                    predefinedType: goal.predefinedType,
                    createdAt: goal.createdAt,
                    updatedAt: goal.updatedAt,
                    isActive: goal.isActive
                )
                
                let goalId = try await firebaseService.saveGoal(newGoal, userId: userId, idToken: idToken)
                
                // Recarregar metas do Firebase para garantir sincronização
                loadGoals()
                
                await MainActor.run {
                    self.displayStatusNotification(message: "Meta criada com sucesso!")
                    print("✅ Meta criada com ID: \(goalId)")
                }
            } catch {
                print("❌ Erro ao criar meta: \(error.localizedDescription)")
                await MainActor.run {
                    if error.localizedDescription.contains("401") || error.localizedDescription.contains("UNAUTHENTICATED") {
                        self.displayStatusNotification(message: "Erro de autenticação. Faça login novamente.")
                    } else {
                        self.displayStatusNotification(message: "Erro ao criar meta: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func updateGoal(_ goal: Goal) {
        guard let userId = authViewModel.user?.id else {
            displayStatusNotification(message: "Erro: Usuário não autenticado")
            return
        }
        
        Task {
            do {
                // Obter token atualizado
                var idToken = authViewModel.user?.idToken ?? ""
                if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                    try await currentUser.refreshTokensIfNeeded()
                    idToken = currentUser.idToken?.tokenString ?? ""
                }
                
                guard !idToken.isEmpty else {
                    await MainActor.run {
                        self.displayStatusNotification(message: "Erro: Token inválido. Faça login novamente.")
                    }
                    return
                }
                
                let updatedGoal = Goal(
                    id: goal.id,
                    userId: goal.userId,
                    title: goal.title,
                    description: goal.description,
                    targetAmount: goal.targetAmount,
                    currentAmount: goal.currentAmount,
                    deadline: goal.deadline,
                    category: goal.category,
                    isPredefined: goal.isPredefined,
                    predefinedType: goal.predefinedType,
                    createdAt: goal.createdAt,
                    updatedAt: Date(),
                    isActive: goal.isActive
                )
                
                _ = try await firebaseService.updateGoal(updatedGoal, userId: userId, idToken: idToken)
                
                // Recarregar metas do Firebase para garantir sincronização
                loadGoals()
                
                await MainActor.run {
                        self.displayStatusNotification(message: "Meta atualizada com sucesso!")
                }
            } catch {
                print("❌ Erro ao atualizar meta: \(error.localizedDescription)")
                await MainActor.run {
                    self.displayStatusNotification(message: "Erro ao atualizar meta: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func displayStatusNotification(message: String) {
        statusNotificationMessage = message
        showStatusNotification = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showStatusNotification = false
        }
    }
    
    private func getProgressColor(_ progress: Double) -> Color {
        if isMonochromaticMode {
            return progress >= 0.8 ? MonochromaticColorManager.primaryGreen : MonochromaticColorManager.primaryGray
        }
        
        if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Helper Functions for Status Filter
    private func getStatusText() -> String {
        switch statusFilter {
        case "all":
            return "Status"
        case "active":
            return "Ativas"
        case "completed":
            return "Concluídas"
        default:
            return "Status"
        }
    }
    
    private func getStatusIcon() -> String {
        switch statusFilter {
        case "all":
            return "list.bullet.circle"
        case "active":
            return "clock.circle.fill"
        case "completed":
            return "checkmark.circle.fill"
        default:
            return "list.bullet.circle"
        }
    }
    
    private func getStatusBackground() -> Color {
        switch statusFilter {
        case "all":
            return Color(UIColor.secondarySystemBackground)
        case "active":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.orange.opacity(0.1)
        case "completed":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.green.opacity(0.1)
        default:
            return Color(UIColor.secondarySystemBackground)
        }
    }
    
    private func getStatusBorderColor() -> Color {
        switch statusFilter {
        case "all":
            return Color(UIColor.separator)
        case "active":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.orange.opacity(0.3)
        case "completed":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.green.opacity(0.3)
        default:
            return Color(UIColor.separator)
        }
    }
    
    private func editGoal(_ goal: Goal) {
        goalToEdit = goal
    }
    
    private func requestGoalDeletion(_ goal: Goal) {
        feedbackService.triggerLight()
        goalPendingDeletion = goal
        withAnimation(.easeInOut(duration: 0.2)) {
            showGoalDeleteConfirmation = true
        }
    }
    
    private func cancelGoalDeletion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showGoalDeleteConfirmation = false
        }
        goalPendingDeletion = nil
    }
    
    private func confirmGoalDeletion() {
        guard let goal = goalPendingDeletion else { return }
        goalPendingDeletion = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            showGoalDeleteConfirmation = false
        }
        deleteGoal(goal)
    }
    
    private func deleteGoal(_ goal: Goal) {
        guard let goalId = goal.id,
              let userId = authViewModel.user?.id else {
            displayStatusNotification(message: "Erro: Meta inválida")
            return
        }
        
        Task {
            do {
                // Obter token atualizado
                var idToken = authViewModel.user?.idToken ?? ""
                if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                    try await currentUser.refreshTokensIfNeeded()
                    idToken = currentUser.idToken?.tokenString ?? ""
                }
                
                guard !idToken.isEmpty else {
                    await MainActor.run {
                        self.displayStatusNotification(message: "Erro: Token inválido. Faça login novamente.")
                    }
                    return
                }
                
                try await firebaseService.deleteGoal(id: goalId, userId: userId, idToken: idToken)
                await MainActor.run {
                    self.goals.removeAll { $0.id == goalId }
                    self.calculateTotals()
                    self.displayStatusNotification(message: "Meta excluída!")
                }
            } catch {
                print("❌ Erro ao deletar meta: \(error.localizedDescription)")
                await MainActor.run {
                    self.displayStatusNotification(message: "Erro ao excluir meta")
                }
            }
        }
    }
    
    private func updateGoalProgress(_ goal: Goal, newAmount: Double) {
        guard let userId = authViewModel.user?.id else {
            displayStatusNotification(message: "Erro: Usuário não autenticado")
            return
        }
        
        Task {
            do {
                // Obter token atualizado
                var idToken = authViewModel.user?.idToken ?? ""
                if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                    try await currentUser.refreshTokensIfNeeded()
                    idToken = currentUser.idToken?.tokenString ?? ""
                }
                
                guard !idToken.isEmpty else {
                    await MainActor.run {
                        self.displayStatusNotification(message: "Erro: Token inválido. Faça login novamente.")
                    }
                    return
                }
                
                let updatedGoal = Goal(
                    id: goal.id,
                    userId: goal.userId,
                    title: goal.title,
                    description: goal.description,
                    targetAmount: goal.targetAmount,
                    currentAmount: newAmount,
                    deadline: goal.deadline,
                    category: goal.category,
                    isPredefined: goal.isPredefined,
                    predefinedType: goal.predefinedType,
                    createdAt: goal.createdAt,
                    updatedAt: Date(),
                    isActive: goal.isActive
                )
                
                _ = try await firebaseService.updateGoal(updatedGoal, userId: userId, idToken: idToken)
                await MainActor.run {
                    if let index = self.goals.firstIndex(where: { $0.id == goal.id }) {
                        self.goals[index] = updatedGoal
                        self.calculateTotals()
                        self.displayStatusNotification(message: "Progresso atualizado!")
                    }
                }
            } catch {
                print("❌ Erro ao atualizar progresso: \(error.localizedDescription)")
                await MainActor.run {
                    self.displayStatusNotification(message: "Erro ao atualizar progresso")
                }
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencySymbol = "R$"
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
// MARK: - Swipeable Goal Row
public struct SwipeableGoalRow: View {
    let goal: Goal
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onUpdateProgress: (Double) -> Void
    let onTap: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isShowingActions = false
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    private let actionButtonWidth: CGFloat = 80
    private let maxOffset: CGFloat = -160 // 2 * actionButtonWidth
    
    init(goal: Goal, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, onUpdateProgress: @escaping (Double) -> Void, onTap: @escaping () -> Void = {}) {
        self.goal = goal
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onUpdateProgress = onUpdateProgress
        self.onTap = onTap
    }
    
    public var body: some View {
        ZStack {
            // Background com botões de ação da esquerda (apenas quando offset < 0)
            if offset < 0 {
                HStack(spacing: 0) {
                    Spacer()
                    actionButton(
                        title: "Editar",
                        icon: "pencil",
                        color: isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue,
                        action: onEdit
                    )
                    actionButton(
                        title: "Excluir",
                        icon: "trash",
                        color: isMonochromaticMode ? MonochromaticColorManager.primaryGray : Color.red,
                        action: onDelete
                    )
                }
                .opacity(min(abs(offset) / 80.0, 1.0))
            }
            
            GoalRow(goal: goal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let horizontal = value.translation.width
                            let vertical = abs(value.translation.height)
                            
                            guard abs(horizontal) > vertical else { return }
                            
                            if horizontal < 0 {
                                offset = max(horizontal, maxOffset)
                            } else if isShowingActions && horizontal > 0 && offset < 0 {
                                offset = min(horizontal + maxOffset, 0)
                            }
                        }
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if horizontal < -60 || velocity < -300 {
                                    offset = maxOffset
                                    isShowingActions = true
                                } else {
                                    offset = 0
                                    isShowingActions = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if isShowingActions {
                        withAnimation(.spring(response: 0.3)) {
                            offset = 0
                            isShowingActions = false
                        }
                    } else {
                        onTap()
                    }
                }
        }
        .clipped()
    }
    
    @ViewBuilder
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            offset = 0
            isShowingActions = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth)
            .frame(maxHeight: .infinity)
            .background(color)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Goal Row
public struct GoalRow: View {
    let goal: Goal
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    // Computed properties para quebrar a complexidade
    private var gradientColors: [Color] {
        let progress = goal.currentAmount / goal.targetAmount
        if progress >= 0.8 {
            return isMonochromaticMode ? 
                [MonochromaticColorManager.primaryGreen.opacity(0.8), MonochromaticColorManager.primaryGreen] :
                [Color.green.opacity(0.8), Color.green]
        } else if progress >= 0.5 {
            return isMonochromaticMode ? 
                [MonochromaticColorManager.primaryGray.opacity(0.8), MonochromaticColorManager.primaryGray] :
                [Color.orange.opacity(0.8), Color.orange]
        } else {
            return isMonochromaticMode ? 
                [MonochromaticColorManager.primaryGray.opacity(0.8), MonochromaticColorManager.primaryGray] :
                [Color.red.opacity(0.8), Color.red]
        }
    }
    
    private var iconName: String {
        if goal.isPredefined {
            return "target"
        } else {
            return "flag"
        }
    }
    
    private var amountColor: Color {
        let progress = goal.currentAmount / goal.targetAmount
        if isMonochromaticMode {
            return progress >= 0.8 ? MonochromaticColorManager.primaryGreen : MonochromaticColorManager.primaryGray
        }
        
        if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Ícone da meta
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Informações da meta
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(goal.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if goal.isPredefined {
                        Text("Pré-definida")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .cornerRadius(3)
                    }
                }
                
                HStack {
                    Text(goal.category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatShortDate(goal.deadline))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Valor e progresso da meta
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(goal.currentAmount))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(amountColor)
                
                Text("de " + formatCurrency(goal.targetAmount))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("\(Int((goal.currentAmount / goal.targetAmount) * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(amountColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencySymbol = "R$"
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let backgroundColor: Color
    let borderColor: Color
    let action: () -> Void
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue) : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Goal Status Notification View
struct GoalStatusNotificationView: View {
    let message: String
    @Binding var isVisible: Bool
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

// MARK: - Simple Edit Goal View
struct SimpleEditGoalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    let goal: Goal
    let onSave: (Goal) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetAmount: String = ""
    @State private var currentAmount: String = ""
    @State private var deadline: Date = Date()
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    init(goal: Goal, onSave: @escaping (Goal) -> Void) {
        self.goal = goal
        self.onSave = onSave
        
        // Inicializar os estados com valores da meta
        _title = State(initialValue: goal.title)
        _description = State(initialValue: goal.description)
        _targetAmount = State(initialValue: formatCurrencyValue(goal.targetAmount))
        _currentAmount = State(initialValue: formatCurrencyValue(goal.currentAmount))
        _deadline = State(initialValue: goal.deadline)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Valor Objetivo - Destaque
                    VStack(spacing: 8) {
                        Text("Valor Objetivo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("R$ 0,00", text: $targetAmount)
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                            .onChange(of: targetAmount) { newValue in
                                targetAmount = formatCurrencyInput(newValue)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Campos principais
                    VStack(spacing: 0) {
                        // Título
                        FormFieldRow(
                            icon: "text.alignleft",
                            title: "Título"
                        ) {
                            TextField("Nome da meta", text: $title)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Descrição
                        FormFieldRow(
                            icon: "text.quote",
                            title: "Descrição"
                        ) {
                            TextField("Descreva sua meta", text: $description)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Valor Atual
                        FormFieldRow(
                            icon: "banknote",
                            title: "Valor Atual"
                        ) {
                            TextField("R$ 0,00", text: $currentAmount)
                                .textFieldStyle(PlainTextFieldStyle())
                                .keyboardType(.numberPad)
                                .onChange(of: currentAmount) { newValue in
                                    currentAmount = formatCurrencyInput(newValue)
                                }
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Data Limite
                        FormFieldRow(
                            icon: "calendar",
                            title: "Data Limite"
                        ) {
                            DatePicker("", selection: $deadline, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .accentColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Botão Salvar
                    VStack(spacing: 16) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        Button(action: {
                            saveGoal()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Atualizar")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.green)
                            )
                        }
                        .disabled(targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.isEmpty || isLoading)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                }
            }
            .navigationTitle("Editar Meta")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A")),
                trailing: Button("Atualizar") {
                    saveGoal()
                }
                .disabled(targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.isEmpty || isLoading)
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            )
        }
    }
    
    // MARK: - Functions
    private func saveGoal() {
        // Converter valores formatados brasileiros para Double
        let cleanedTargetAmount = targetAmount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        let cleanedCurrentAmount = currentAmount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        
        guard let targetAmountValue = Double(cleanedTargetAmount) else {
            errorMessage = "Valor objetivo inválido."
            return
        }
        
        guard let currentAmountValue = Double(cleanedCurrentAmount) else {
            errorMessage = "Valor atual inválido."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let now = Date()
        
        // Atualizar meta existente
        let updatedGoal = Goal(
            id: goal.id,
            userId: goal.userId,
            title: title.isEmpty ? "-" : title,
            description: description.isEmpty ? "-" : description,
            targetAmount: targetAmountValue,
            currentAmount: currentAmountValue,
            deadline: deadline,
            category: goal.category,
            isPredefined: goal.isPredefined,
            predefinedType: goal.predefinedType,
            createdAt: goal.createdAt,
            updatedAt: now,
            isActive: true
        )
        
        onSave(updatedGoal)
        isLoading = false
        presentationMode.wrappedValue.dismiss()
    }
    
    private func formatCurrencyInput(_ input: String) -> String {
        // Remover todos os caracteres não numéricos
        let cleanedInput = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Se está vazio, retornar "0,00"
        if cleanedInput.isEmpty {
            return "0,00"
        }
        
        // Converter para número inteiro (representa centavos)
        let centavos = Int(cleanedInput) ?? 0
        
        // Converter centavos para reais e centavos
        let reais = centavos / 100
        let centavosRestantes = centavos % 100
        
        // Formatar parte inteira com pontos para milhares
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        
        let formattedReais = formatter.string(from: NSNumber(value: reais)) ?? "0"
        let formattedCentavos = String(format: "%02d", centavosRestantes)
        
        return "\(formattedReais),\(formattedCentavos)"
    }
    
    private func formatCurrencyValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "0,00"
    }
}
/*
struct AddTransactionView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let transactionToEdit: TransactionModel?
    
    @State private var type: String = "expense"
    @State private var amount: String = "0,00"
    @State private var description: String = ""
    @State private var category: String = "Selecionar categoria"
    @State private var date: Date = Date()
    @State private var isPaid: Bool = false
    @State private var isReceived: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: String = "monthly"
    @State private var recurringEndDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var showCategoryPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var availableCategories: [Category] = []
    
    let frequencies = ["monthly", "weekly", "yearly"]
    
    init(transactionToEdit: TransactionModel? = nil) {
        self.transactionToEdit = transactionToEdit
        
        // Inicializar estados com dados da transação se for edição
        if let transaction = transactionToEdit {
            _type = State(initialValue: transaction.type ?? "expense")
            _amount = State(initialValue: String(format: "%.2f", transaction.amount).replacingOccurrences(of: ".", with: ","))
            _description = State(initialValue: transaction.description ?? "")
            _category = State(initialValue: transaction.category.isEmpty ? "Selecionar categoria" : transaction.category)
            _isPaid = State(initialValue: transaction.status == "paid")
            _isReceived = State(initialValue: transaction.status == "received")
            _isRecurring = State(initialValue: transaction.isRecurring ?? false)
            _recurringFrequency = State(initialValue: transaction.recurringFrequency ?? "monthly")
            
            // Converter data da string para Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let transactionDate = dateFormatter.date(from: transaction.date) ?? Date()
            _date = State(initialValue: transactionDate)
            
            // Data de fim de recorrência
            let endDate = transaction.recurringEndDate != nil ? 
                dateFormatter.date(from: transaction.recurringEndDate!) ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date() :
                Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            _recurringEndDate = State(initialValue: endDate)
        } else {
            _type = State(initialValue: "expense")
            _amount = State(initialValue: "0,00")
            _description = State(initialValue: "")
            _category = State(initialValue: "Selecionar categoria")
            _isPaid = State(initialValue: false)
            _isReceived = State(initialValue: false)
            _isRecurring = State(initialValue: false)
            _recurringFrequency = State(initialValue: "monthly")
            _date = State(initialValue: Date())
            _recurringEndDate = State(initialValue: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        }
    }
    
    // MARK: - Feedback Service
    private let feedbackService = FeedbackService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Seção de seleção de tipo
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Despesa
                        Button(action: { 
                            type = "expense"
                            // Resetar status quando mudar tipo
                            isPaid = false
                            isReceived = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Despesa")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(type == "expense" ? .white : .red)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(type == "expense" ? Color.red : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                        
                        // Receita
                        Button(action: { 
                            type = "income"
                            // Resetar status quando mudar tipo
                            isPaid = false
                            isReceived = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Receita")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(type == "income" ? .white : .green)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(type == "income" ? Color.green : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                        
                        // Investir
                        Button(action: { 
                            type = "investment"
                            // Resetar status quando mudar tipo
                            isPaid = false
                            isReceived = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Investir")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(type == "investment" ? .white : .blue)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(type == "investment" ? Color.blue : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                // Campo de valor - exatamente como na imagem
                VStack(alignment: .leading, spacing: 8) {
                    Text("Valor")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    TextField("0,00", text: $amount)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(type == "expense" ? .red : type == "income" ? .green : .blue)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .onChange(of: amount) { newValue in
                            amount = formatCurrencyInput(newValue)
                        }
                }
                .padding(.top, 24)
                
                // Campos de detalhes
                VStack(spacing: 0) {
                    // Descrição
                    FormFieldRow(
                        icon: "text.alignleft",
                        title: "Descrição"
                    ) {
                        TextField("Adicionar descrição", text: $description)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    // Data
                    FormFieldRow(
                        icon: "calendar",
                        title: "Data"
                    ) {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                            .accentColor(.blue)
                    }
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    // Categoria
                    FormFieldRow(
                        icon: "folder.fill",
                        title: "Categoria",
                        iconColor: .purple
                    ) {
                        Button(action: { showCategoryPicker = true }) {
                            HStack {
                                Text(category)
                                    .foregroundColor(category == "Selecionar categoria" ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 24)
                
                // Opções
                VStack(spacing: 0) {
                    // Status baseado no tipo de transação
                    if type == "expense" {
                    FormFieldRow(
                        icon: "checkmark.circle.fill",
                        title: "Pago",
                        iconColor: .green
                    ) {
                        Toggle("", isOn: $isPaid)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                        }
                    } else if type == "income" {
                        FormFieldRow(
                            icon: "checkmark.circle.fill",
                            title: "Recebido",
                            iconColor: .green
                        ) {
                            Toggle("", isOn: $isReceived)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                        }
                    } else if type == "investment" {
                        FormFieldRow(
                            icon: "checkmark.circle.fill",
                            title: "Sempre ativo",
                            iconColor: .green
                        ) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Sempre ativo")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    
                    // Recorrente (oculto para investimentos)
                    if type != "investment" {
                    Divider()
                        .padding(.leading, 56)
                    
                    FormFieldRow(
                        icon: "arrow.clockwise.circle.fill",
                        title: "Recorrente",
                        iconColor: .blue
                    ) {
                        Toggle("", isOn: $isRecurring)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        
                        // Configurações de recorrência (visível apenas se isRecurring for true)
                        if isRecurring {
                            Divider()
                                .padding(.leading, 56)
                            
                            FormFieldRow(
                                icon: "clock",
                                title: "Frequência"
                            ) {
                                Picker("Frequência", selection: $recurringFrequency) {
                                    ForEach(frequencies, id: \.self) { frequency in
                                        Text(getFrequencyDisplayName(frequency)).tag(frequency)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(.blue)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            FormFieldRow(
                                icon: "calendar.badge.clock",
                                title: "Até"
                            ) {
                                DatePicker("", selection: $recurringEndDate, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .accentColor(.blue)
                            }
                        }
                    }
                }
                .padding(.top, 24)
                
                Spacer()
                
                // Mensagens de feedback
                VStack(spacing: 12) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    if showSuccessMessage {
                        Text("Transação salva com sucesso!")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                // Botão Salvar
                Button(action: saveTransaction) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                    Text("Salvar")
                        .font(.system(size: 18, weight: .semibold))
                        }
                    }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isLoading)
                .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Nova Transação")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.green),
                trailing: Button("Salvar") {
                    saveTransaction()
                }
                .disabled(isLoading)
                .foregroundColor(isLoading ? .gray : .green)
            )
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(selectedCategory: $category, availableCategories: availableCategories)
        }
        .onAppear {
            loadCategories()
        }
    }
    
    
    private func formatCurrencyInput(_ input: String) -> String {
        // Remover todos os caracteres não numéricos
        let cleanedInput = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Se está vazio, retornar "0,00"
        if cleanedInput.isEmpty {
            return "0,00"
        }
        
        // Converter para número inteiro (representa centavos)
        let centavos = Int(cleanedInput) ?? 0
        
        // Converter centavos para reais e centavos
        let reais = centavos / 100
        let centavosRestantes = centavos % 100
        
        // Formatar parte inteira com pontos para milhares
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        
        let formattedReais = formatter.string(from: NSNumber(value: reais)) ?? "0"
        let formattedCentavos = String(format: "%02d", centavosRestantes)
        
        return "\(formattedReais),\(formattedCentavos)"
    }
    
    private func loadCategories() {
        let defaults = CategoryDataProvider.categories(for: type)
        availableCategories = defaults
        guard let userId = authViewModel.user?.id, let idToken = authViewModel.user?.idToken else { return }

        Task {
            do {
                let userCategories = try await authViewModel.firebaseService.getCategories(userId: userId, idToken: idToken)
                let filtered = userCategories.filter { category in
                    if CategoryDataProvider.hiddenCategoryIDs.contains(category.identifiedId) { return false }
                    if type == "investment" { return category.type.lowercased() == "investment" }
                    return category.type.lowercased() == type.lowercased()
                }
                var seen = Set<String>()
                var ordered: [Category] = []
                for category in defaults {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                for category in filtered {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                let finalCategories = ordered
                await MainActor.run {
                    self.availableCategories = finalCategories
                }
            } catch {
                print("❌ Erro ao carregar categorias personalizadas: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveTransaction() {
        // Limpar mensagens anteriores
        errorMessage = nil
        showSuccessMessage = false
        
        // Validar campos obrigatórios
        guard !amount.isEmpty && amount != "0,00" else {
            errorMessage = "Valor não pode ser vazio ou zero"
            feedbackService.errorFeedback()
            return
        }
        
        guard !description.isEmpty else {
            errorMessage = "Descrição é obrigatória"
            feedbackService.errorFeedback()
            return
        }
        
        // Se categoria não foi selecionada, usar "Sem Categoria"
        let finalCategory = category == "Selecionar categoria" ? "Sem Categoria" : category
        
        // Converter valor formatado para Double
        let cleanedAmount = amount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        guard let amountValue = Double(cleanedAmount) else {
            errorMessage = "Valor inválido"
            return
        }
        
        // Determinar se é receita baseado no tipo
        let isIncome = type == "income"
        
        // Determinar status baseado no tipo e se está pago/recebido
        let status: String
        if type == "expense" {
            status = isPaid ? "paid" : "unpaid"
        } else if type == "income" {
            status = isReceived ? "received" : "pending"
        } else if type == "investment" {
            status = "invested"
        } else {
            status = "pending"
        }
        
        // Formatar data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Criar modelo da transação
        let transaction: TransactionModel
        if let editingTransaction = transactionToEdit {
            // Edição: manter ID e createdAt originais
            transaction = TransactionModel(
                id: editingTransaction.id,
                userId: editingTransaction.userId,
                title: description,
                description: description,
                amount: amountValue,
                category: finalCategory,
                date: dateString,
                isIncome: isIncome,
                type: type,
                status: status,
                createdAt: editingTransaction.createdAt,
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : nil,
                recurringEndDate: isRecurring ? dateFormatter.string(from: recurringEndDate) : nil,
                sourceTransactionId: editingTransaction.sourceTransactionId
            )
            print("✏️ Editando transação existente: \(editingTransaction.id ?? "sem ID")")
        } else {
            // Nova transação
            transaction = TransactionModel(
                id: nil,
                userId: authViewModel.user?.id ?? "",
                title: description,
                description: description,
                amount: amountValue,
                category: finalCategory,
                date: dateString,
                isIncome: isIncome,
                type: type,
                status: status,
                createdAt: Date(),
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : nil,
                recurringEndDate: isRecurring ? dateFormatter.string(from: recurringEndDate) : nil,
                sourceTransactionId: nil
            )
            print("➕ Criando nova transação")
        }
        
        print("💾 Salvando transação:")
        print("   - Tipo: \(type)")
        print("   - Valor: R$ \(amount)")
        print("   - Descrição: \(description)")
        print("   - Categoria: \(finalCategory)")
        print("   - Data: \(dateString)")
        print("   - Status: \(status)")
        print("   - Recorrente: \(isRecurring)")
        
        // Iniciar loading
        isLoading = true
        
        // Salvar no Firebase
        Task {
            do {
                guard let userId = authViewModel.user?.id,
                      let idToken = authViewModel.user?.idToken else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Usuário não autenticado"
                    }
                    return
                }
                
                if transactionToEdit != nil {
                    // Edição: usar updateTransaction
                    let success = try await authViewModel.firebaseService.updateTransaction(transaction, userId: userId, idToken: idToken)
                    if !success {
                        throw NSError(domain: "UpdateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Erro ao atualizar transação"])
                    }
                } else {
                    // Nova transação: usar saveTransaction
                    try await authViewModel.firebaseService.saveTransaction(transaction, userId: userId, idToken: idToken)
                }
                
                await MainActor.run {
                    isLoading = false
                    showSuccessMessage = true
                    
                    if transactionToEdit != nil {
                        print("✅ Transação atualizada com sucesso!")
                    } else {
                        print("✅ Transação criada com sucesso!")
                    }
                    
                    // Feedback tátil de sucesso
                    feedbackService.successFeedback()
                    
                    // Enviar notificação para atualizar as telas
                    NotificationCenter.default.post(name: NSNotification.Name("TransactionSaved"), object: nil)
                    
                    // Fechar a tela após um breve delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        presentationMode.wrappedValue.dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Erro ao salvar transação: \(error.localizedDescription)"
                    print("❌ Erro ao salvar transação: \(error.localizedDescription)")
                    
                    // Feedback tátil de erro
                    feedbackService.errorFeedback()
                }
            }
        }
    }
    
    // Função para mapear frequências para português
    private func getFrequencyDisplayName(_ frequency: String) -> String {
        switch frequency {
        case "monthly": return "Mensal"
        case "weekly": return "Semanal"
        case "yearly": return "Anual"
        default: return "Mensal"
        }
    }
}

// MARK: - Form Field Row Component
struct FormFieldRow<Content: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    let content: Content
    
    init(icon: String, title: String, iconColor: Color = .gray, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 100, alignment: .leading)
            
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Category Picker View
struct CategoryPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedCategory: String
    let availableCategories: [Category]
    
    var body: some View {
        NavigationView {
            List {
                // Opção "Sem Categoria"
                Button(action: {
                    selectedCategory = "Sem Categoria"
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text("Sem Categoria")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedCategory == "Sem Categoria" {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Categorias disponíveis
                ForEach(availableCategories, id: \.id) { category in
                    Button(action: {
                        selectedCategory = category.name
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(getCategoryColor(category.color))
                                .frame(width: 24)
                            Text(category.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCategory == category.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categoria")
            .navigationBarItems(trailing: Button("Cancelar") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func getCategoryColor(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        case "teal": return .teal
        default: return .gray
        }
    }
}

// DeleteCategoryConfirmationView moved into CategoriesView for better scope control
*/

// MARK: - Date Picker View
struct DatePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Data")
            .navigationBarItems(trailing: Button("Concluído") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
// MARK: - Dashboard ViewModel
class DashboardViewModel: ObservableObject {
    @Published var receitasConsolidadas: Double = 0.0
    @Published var receitasPendentes: Double = 0.0
    @Published var despesasPagas: Double = 0.0
    @Published var despesasPendentes: Double = 0.0
    @Published var saldoConsolidado: Double = 0.0
    @Published var saldoInvestido: Double = 0.0
    @Published var saldoProjetado: Double = 0.0
    @Published var progressoMetas: Double = 0.0
    @Published var ultimasTransacoes: [TransactionModel] = []
    @Published var chartEntries: [DashboardChartEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var userId: String?
    private var idToken: String?
    private let firebaseService = FirebaseRESTService.shared
    
    func setUserId(_ userId: String) {
        self.userId = userId
    }
    
    func setIdToken(_ idToken: String) {
        self.idToken = idToken
    }
    
    func loadDashboardData(startDate: String, endDate: String, consolidatedStartDate: String, consolidatedEndDate: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Debug: verificar credenciais antes do guard
        if userId == nil || (userId?.isEmpty ?? true) {
            print("⚠️ DashboardViewModel: userId ausente ao carregar dados")
        }
        if idToken == nil || (idToken?.isEmpty ?? true) {
            print("ℹ️ DashboardViewModel: idToken ausente (não é usado na REST atual)")
        }
        
        guard let userId = userId, let idToken = idToken else {
            await MainActor.run {
                self.errorMessage = "Usuário ou token não identificado"
                self.isLoading = false
            }
            return
        }
        
        do {
            print("🔄 Carregando dados do dashboard para userId: \(userId)")
            print("📅 Período atual: \(startDate) até \(endDate)")
            print("📅 Período consolidado: \(consolidatedStartDate) até \(consolidatedEndDate)")
            
            // Buscar transações do período atual (para saldo projetado e cards)
            let firebaseTransactions = try await firebaseService.getTransactions(
                userId: userId,
                startDate: startDate,
                endDate: endDate,
                idToken: idToken
            )
            
            // Buscar transações do período consolidado (para saldo consolidado)
            let consolidatedTransactions = try await firebaseService.getTransactions(
                userId: userId,
                startDate: consolidatedStartDate,
                endDate: consolidatedEndDate,
                idToken: idToken
            )
            
            print("✅ Transações do período atual: \(firebaseTransactions.count) transações")
            print("✅ Transações do período consolidado: \(consolidatedTransactions.count) transações")
            
            await MainActor.run {
                // Calcular dados do período atual (saldo projetado, cards, etc)
                self.calculateDashboardData(from: firebaseTransactions)
                // Calcular saldo consolidado separadamente
                self.calculateConsolidatedBalance(from: consolidatedTransactions)
                self.isLoading = false
            }
        } catch {
            print("❌ Erro ao carregar dados do dashboard: \(error.localizedDescription)")
            
            await MainActor.run {
                self.errorMessage = "Erro ao carregar dados: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // Armazenar todas as transações do período atual para recálculo
    private var currentTransactions: [TransactionModel] = []
    
    func updateTransactionLocally(_ updatedTransaction: TransactionModel) {
        // Atualizar na lista local de transações
        if let index = currentTransactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
            currentTransactions[index] = updatedTransaction
            // Recalcular dados do dashboard com a lista atualizada
            self.calculateDashboardData(from: currentTransactions)
            print("✅ Transação atualizada localmente no dashboard: \(updatedTransaction.id ?? "sem id")")
        } else {
            print("⚠️ Transação não encontrada na lista local do dashboard para atualizar")
        }
    }
    
    func applySnapshot(transaction: TransactionModel, for range: DateRange) {
        guard !currentTransactions.isEmpty else { return }
        guard let transactionId = transaction.id else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let transactionDate = formatter.date(from: transaction.date) else { return }
        
        if transactionDate < range.start || transactionDate > range.end {
            if let index = currentTransactions.firstIndex(where: { $0.id == transactionId }) {
                currentTransactions.remove(at: index)
                calculateDashboardData(from: currentTransactions)
            }
            return
        }
        
        if let index = currentTransactions.firstIndex(where: { $0.id == transactionId }) {
            currentTransactions[index] = transaction
        } else {
            currentTransactions.append(transaction)
        }
        
        calculateDashboardData(from: currentTransactions)
    }
    
    private func calculateDashboardData(from transactions: [TransactionModel]) {
        // Armazenar transações para uso futuro
        self.currentTransactions = transactions
        
        var receitasConsolidadas: Double = 0.0
        var receitasPendentes: Double = 0.0
        var despesasPagas: Double = 0.0
        var despesasPendentes: Double = 0.0
        var saldoInvestido: Double = 0.0
        var investimentosTransferidos: Double = 0.0
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        var incomeByDay: [Date: Double] = [:]
        var expenseByDay: [Date: Double] = [:]
        
        for transaction in transactions {
            let amount = transaction.amount
            let type = transaction.type ?? "expense"
            let status = transaction.status ?? "pending"
            let sourceTransactionId = transaction.sourceTransactionId ?? ""
            if let date = dateFormatter.date(from: transaction.date) {
                let day = calendar.startOfDay(for: date)
                if type == "income" {
                    incomeByDay[day, default: 0] += amount
                } else if type == "expense" {
                    expenseByDay[day, default: 0] += amount
                }
            }
            
            // Calcular receitas e despesas do período para os cards
            if type == "income" {
                if status == "consolidated" || status == "paid" || status == "received" {
                    receitasConsolidadas += amount
                } else {
                    receitasPendentes += amount
                }
            } else if type == "expense" {
                if status == "paid" {
                    despesasPagas += amount
                } else if status == "unpaid" {
                    despesasPendentes += amount
                }
            } else if type == "investment" {
                saldoInvestido += amount
                // Só desconta investimentos que foram transferidos de receita
                if !sourceTransactionId.isEmpty {
                    investimentosTransferidos += amount
                }
            }
        }
        
        // Atualizar os valores dos cards com os dados do período selecionado
        self.receitasConsolidadas = receitasConsolidadas
        self.receitasPendentes = receitasPendentes
        self.despesasPagas = despesasPagas
        self.despesasPendentes = despesasPendentes
        self.saldoInvestido = saldoInvestido
        
        // Calcular saldo projetado baseado no período selecionado (incluindo valores pendentes)
        let receitasProjetadas = receitasConsolidadas + receitasPendentes
        let despesasProjetadas = despesasPagas + despesasPendentes
        self.saldoProjetado = receitasProjetadas - despesasProjetadas - investimentosTransferidos
        
        // NOTA: Saldo consolidado é calculado separadamente em calculateConsolidatedBalance()
        
        // Pegar as últimas 5 transações
        let sorted = transactions.sorted { $0.createdAt > $1.createdAt }
        self.ultimasTransacoes = Array(sorted.prefix(5))
        
        // Dados para o gráfico de linhas (receitas x despesas)
        let allDates = Set(incomeByDay.keys).union(expenseByDay.keys).sorted()
        self.chartEntries = allDates.map { date in
            DashboardChartEntry(
                date: date,
                income: incomeByDay[date] ?? 0,
                expense: expenseByDay[date] ?? 0
            )
        }
        
        // Progresso de metas agora é calculado separadamente via loadDashboardGoals()
        // não precisa mais calcular aqui
        
        print("✅ Dados do dashboard calculados (período atual):")
        print("💰 Saldo projetado: R$ \(String(format: "%.2f", saldoProjetado))")
        print("📊 Valores do período - Receitas: R$ \(String(format: "%.2f", receitasConsolidadas)), Pendentes: R$ \(String(format: "%.2f", receitasPendentes))")
        print("📊 Valores do período - Despesas Pagas: R$ \(String(format: "%.2f", despesasPagas)), Pendentes: R$ \(String(format: "%.2f", despesasPendentes))")
        print("📊 Investimentos transferidos de receita: R$ \(String(format: "%.2f", investimentosTransferidos))")
        print("📊 Saldo Investido: R$ \(String(format: "%.2f", saldoInvestido))")
        print("📊 Total de transações: \(transactions.count)")
    }
    
    // Função separada para calcular saldo consolidado usando período acumulado
    private func calculateConsolidatedBalance(from transactions: [TransactionModel]) {
        var receitasConsolidadas: Double = 0.0
        var despesasPagas: Double = 0.0
        var investimentosTransferidos: Double = 0.0
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for transaction in transactions {
            let amount = transaction.amount
            let type = transaction.type ?? "expense"
            let status = transaction.status ?? "pending"
            let sourceTransactionId = transaction.sourceTransactionId ?? ""
            let dateStr = transaction.date
            
            if dateFormatter.date(from: dateStr) != nil {
                if type == "income" {
                    if status == "consolidated" || status == "paid" || status == "received" {
                        receitasConsolidadas += amount
                        print("💰 Receita consolidada: \(transaction.title ?? "Sem título") - R$ \(String(format: "%.2f", amount))")
                    }
                } else if type == "expense" {
                    if status == "paid" {
                        despesasPagas += amount
                        print("💸 Despesa paga: \(transaction.title ?? "Sem título") - R$ \(String(format: "%.2f", amount))")
                    }
                } else if type == "investment" {
                    // Só desconta investimentos que foram transferidos de receita
                    if !sourceTransactionId.isEmpty {
                        investimentosTransferidos += amount
                        print("📈 Investimento transferido de receita: \(transaction.title ?? "Sem título") - R$ \(String(format: "%.2f", amount))")
                    }
                }
            }
        }
        
        // Atualizar apenas o saldo consolidado (não os valores dos cards)
        self.saldoConsolidado = receitasConsolidadas - despesasPagas - investimentosTransferidos
        
        print("✅ Saldo consolidado atualizado: R$ \(String(format: "%.2f", self.saldoConsolidado))")
        print("📊 Saldo consolidado - Receitas: R$ \(String(format: "%.2f", receitasConsolidadas)), Despesas: R$ \(String(format: "%.2f", despesasPagas))")
        print("📊 Investimentos transferidos de receita: R$ \(String(format: "%.2f", investimentosTransferidos))")
        print("📊 Total de documentos processados para saldo consolidado: \(transactions.count)")
    }
    
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var globalDateManager = GlobalDateManager()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab = 0
    @State private var showAddTransaction = false
    @State private var scrollToTopID = UUID()
    @State private var lastTapTimeInicio: Date?
    @State private var lastTapTimeMais: Date?
    @State private var lastTapTab: Int?
    @State private var showWelcomeNotification = false
    @State private var welcomeMessage = ""
    @State private var showStatusNotification = false
    @State private var statusMessage = ""
    @State private var transactionToEdit: TransactionModel?
    @State private var transactionToDelete: TransactionModel?
    @State private var showDeleteConfirmation = false
    @State private var transactionToInvest: TransactionModel?
    @State private var showTransferIncome = false
    @State private var statusNotificationMessage = ""
    @State private var isSuccessNotification = true
    @State private var dashboardCategories: [Category] = CategoryDataProvider.defaultCategories(includeHidden: true)
    
    // Progresso de metas
    @State private var goals: [Goal] = []
    @State private var totalTargetAmount: Double = 0
    @State private var totalCurrentAmount: Double = 0
    @State private var totalProgress: Double = 0
    @State private var valoresVisiveis: Bool = true
    @State private var showPeriodFilters: Bool = false
    @State private var dashboardResetID: UUID = UUID()
    @State private var moreViewResetID: UUID = UUID()
    @State private var dashboardAppeared = false
    private let firebaseService = FirebaseRESTService.shared
    
    // Sistema de Notificações
    @StateObject private var dailyNotificationChecker = DailyNotificationChecker.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Group {
                    if selectedTab == 0 {
                        // Tab 1: Dashboard Principal
                        NavigationView {
                            ZStack {
                                Color(UIColor.systemGroupedBackground)
                                    .edgesIgnoringSafeArea(.all)
                                
                                ScrollViewReader { proxy in
                                    ScrollView(showsIndicators: false) {
                                        VStack(spacing: 8) {
                                            dashboardTopBar
                                                .padding(.horizontal, 16)
                                                .padding(.top, 10)
                                                .id(scrollToTopID)
                                            
                                            // Header com navegação de mês
                                            monthNavigationHeader
                                            
                                            // Cards principais
                                            dashboardCards
                                            
                                            // Card de saldo projetado
                                            saldoProjetadoCard
                                            
                                            // Cards de saldo
                                            saldoCards
                                            
                                            // Progresso de metas
                                            progressoMetasCard
                                            
                                            // Últimas transações
                                            ultimasTransacoesSection
                                            
                                            // Gráfico de receitas x despesas
                                            incomeExpenseChartSection
                                        }
                                        .padding(.top, 4)
                                        .padding(.bottom, 100)
                                        .opacity(dashboardAppeared ? 1 : 0)
                                        .offset(y: dashboardAppeared ? 0 : 20)
                                    }
                                    .onChange(of: scrollToTopID) { _ in
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(scrollToTopID, anchor: .top)
                                        }
                                    }
                                }
                            }
                            .navigationBarHidden(true)
                            .onAppear {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    dashboardAppeared = true
                                }
                            }
                            .onDisappear {
                                dashboardAppeared = false
                            }
                        }
                        .id(dashboardResetID)
                    } else if selectedTab == 1 {
                        // Tab 2: Transações
                        NavigationView {
                            TransactionsView()
                                .environmentObject(globalDateManager)
                                .navigationBarHidden(true)
                        }
                    } else if selectedTab == 2 {
                        // Tab 3: Metas
                        NavigationView {
                            GoalsView()
                                .environmentObject(globalDateManager)
                                .navigationTitle("Metas")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    } else if selectedTab == 3 {
                        // Tab 4: Mais
                        NavigationView {
                            MoreView()
                                .navigationBarHidden(true)
                        }
                        .id(moreViewResetID)
                    }
                }
            }
            
            // Menu inferior
            VStack {
                Spacer()
                bottomNavigationView
            }
            .zIndex(2)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .environmentObject(globalDateManager)
        .onAppear {
            // Configurar userId e token no DashboardViewModel
            if let userId = authViewModel.user?.id {
                dashboardViewModel.setUserId(userId)
                transactionsViewModel.setUserId(userId)
            }
            if let idToken = authViewModel.user?.idToken {
                dashboardViewModel.setIdToken(idToken)
                transactionsViewModel.setIdToken(idToken)
            }
            
            // Carregar dados do dashboard
            loadDashboardData()
            loadDashboardCategories()
            
            // Carregar metas para progresso
            loadDashboardGoals()
            
            // Verificar notificações se estiver habilitado
            Task {
                await checkNotificationsIfEnabled()
            }
            
            if authViewModel.isFirstLogin {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    welcomeMessage = "Seja bem-vindo ao PINEE!"
                    showWelcomeNotification = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        showWelcomeNotification = false
                    }
                }
            }
            
            Task {
                await notificationManager.refreshBadgeCount()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // Quando o app entra em foreground, verificar notificações
                Task {
                    await checkNotificationsIfEnabled()
                    await notificationManager.refreshBadgeCount()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TransactionSaved"))) { notification in
            // Atualizar dashboard quando uma transação for salva
            print("🔄 Atualizando dashboard após salvar transação...")
            loadDashboardData()
            loadDashboardGoals()
            
            if let updatedTransaction = notification.object as? TransactionModel {
                Task { @MainActor in
                    dashboardViewModel.applySnapshot(
                        transaction: updatedTransaction,
                        for: globalDateManager.getCurrentDateRange()
                    )
                }
            }
        }
        .overlay(
            Group {
                if showDeleteConfirmation, let transaction = transactionToDelete {
                    DeleteConfirmationView(
                        transaction: transaction,
                        onConfirm: {
                            confirmDeleteTransaction()
                        },
                        onCancel: {
                transactionToDelete = nil
                showDeleteConfirmation = false
            }
                    )
            }
            }
        )
        .sheet(isPresented: $showAddTransaction, onDismiss: {
            loadDashboardData()
            transactionToEdit = nil
        }) {
            AddTransactionView(transactionToEdit: transactionToEdit)
                .environmentObject(authViewModel)
                .environmentObject(globalDateManager)
        }
        .sheet(item: $transactionToEdit, onDismiss: {
            loadDashboardData()
            transactionToEdit = nil
        }) { transaction in
            AddTransactionView(transactionToEdit: transaction)
                .environmentObject(authViewModel)
                .environmentObject(globalDateManager)
        }
        .sheet(item: $transactionToInvest, onDismiss: {
            loadDashboardData()
            transactionToInvest = nil
        }) { transaction in
            TransferInvestmentView(sourceTransaction: transaction)
                .environmentObject(authViewModel)
                .environmentObject(globalDateManager)
        }
        .sheet(isPresented: $showTransferIncome, onDismiss: {
            loadDashboardData()
            transactionToInvest = nil
        }) {
            if let transaction = transactionToInvest {
                TransferIncomeView(sourceTransaction: transaction)
                    .environmentObject(authViewModel)
                    .environmentObject(globalDateManager)
            }
        }
        .overlay(
            Group {
                if showStatusNotification {
                    TransactionStatusNotificationView(
                        message: statusNotificationMessage,
                        isVisible: $showStatusNotification,
                        isSuccess: isSuccessNotification
                    )
                    .zIndex(1000)
                } else {
                    EmptyView()
                }
            }
        )
        // Recarregar quando o usuário autenticar/restaurar
        .onChange(of: authViewModel.user?.id ?? "") { newId in
            if !newId.isEmpty {
                print("🔐 Usuário disponível no dashboard: \(newId). Recarregando dados...")
                dashboardViewModel.setUserId(newId)
                transactionsViewModel.setUserId(newId)
                if let token = authViewModel.user?.idToken { 
                    dashboardViewModel.setIdToken(token)
                    transactionsViewModel.setIdToken(token)
                }
                loadDashboardData()
                loadDashboardGoals()
            }
        }
        .onChange(of: selectedTab) { newTab in
            // Quando voltar para a tela inicial, recarregar metas
            if newTab == 0 {
                loadDashboardGoals()
            }
        }
    }
    
    // MARK: - Componentes da Interface
    
    private var dashboardTopBar: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemBackground))
                profileAvatar
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(UIColor.systemBackground), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Olá, \(userGreetingName)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(greetingSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            NavigationLink(
                destination: RecentNotificationsView()
                    .environmentObject(authViewModel)
            ) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(
                                isMonochromaticMode
                                ? MonochromaticColorManager.secondaryGray.opacity(0.25)
                                : Color(UIColor.secondarySystemBackground)
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        isMonochromaticMode
                                        ? MonochromaticColorManager.primaryGray.opacity(0.25)
                                        : Color.black.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                        
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 44, height: 44)
                    
                    if notificationManager.badgeCount > 0 {
                        Text(badgeText(notificationManager.badgeCount))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                feedbackService.triggerLight()
            })
        }
    }
    
    @ViewBuilder
    private var profileAvatar: some View {
        if let url = authViewModel.user?.profileImageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    fallbackAvatar
                } else {
                    ZStack {
                        Color(UIColor.secondarySystemBackground)
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
        } else {
            fallbackAvatar
        }
    }
    
    private var fallbackAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(.secondary)
            .padding(6)
    }
    
    private var userGreetingName: String {
        let rawName = authViewModel.user?.name ?? ""
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.split(separator: " ").first, !first.isEmpty {
            return String(first)
        }
        if let email = authViewModel.user?.email,
           let username = email.split(separator: "@").first,
           !username.isEmpty {
            return String(username)
        }
        return trimmed.isEmpty ? "Usuário" : trimmed
    }
    
    private var greetingSubtitle: String {
        "Bem-vindo de volta ao PINEE!"
    }
    
    private func badgeText(_ count: Int) -> String {
        return count > 99 ? "99+" : "\(count)"
    }
    
    private var monthNavigationHeader: some View {
        VStack(spacing: 8) {
            // Navegação de período com data
            HStack(spacing: 16) {
            Button(action: previousPeriod) {
                Image(systemName: "chevron.left")
                    .foregroundColor(globalDateManager.periodType == .allTime ? .secondary : .primary)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                        .background(
                            Group {
                                if isMonochromaticMode {
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            MonochromaticColorManager.secondaryGray.opacity(0.3),
                                            MonochromaticColorManager.primaryGray.opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    // Cores adaptativas para modo claro/escuro
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(UIColor.secondarySystemBackground),
                                            Color(UIColor.tertiarySystemBackground)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                    .clipShape(Circle())
                        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .disabled(globalDateManager.periodType == .allTime)
            
            Spacer()
            
                // Data atual (clicável para mostrar filtros)
                    Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showPeriodFilters.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(globalDateManager.getCurrentDateRange().displayText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        if globalDateManager.periodType != .allTime {
                            Text(getPeriodSubtitle())
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: nextPeriod) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(globalDateManager.periodType == .allTime ? .secondary : .primary)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(
                            Group {
                                if isMonochromaticMode {
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            MonochromaticColorManager.secondaryGray.opacity(0.3),
                                            MonochromaticColorManager.primaryGray.opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    // Cores adaptativas para modo claro/escuro
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(UIColor.secondarySystemBackground),
                                            Color(UIColor.tertiarySystemBackground)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(globalDateManager.periodType == .allTime)
            }
            .padding(.horizontal, 20)
            
            // Filtros de período (chips) - ocultos até clicar na data
            if showPeriodFilters {
                HStack(spacing: 8) {
                    periodChip(
                        title: "Mensal",
                        icon: "calendar",
                        isSelected: globalDateManager.periodType == .monthly,
                        action: {
                        print("🔄 Filtro Mensal selecionado")
                        globalDateManager.updatePeriodType(.monthly)
                        print("📅 Período atual: \(globalDateManager.getCurrentDateRange().displayText)")
                        loadDashboardData()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showPeriodFilters = false
                            }
                        }
                    )
                    
                    periodChip(
                        title: "Anual",
                        icon: "calendar.badge.clock",
                        isSelected: globalDateManager.periodType == .yearly,
                        action: {
                        print("🔄 Filtro Anual selecionado")
                        globalDateManager.updatePeriodType(.yearly)
                        print("📅 Período atual: \(globalDateManager.getCurrentDateRange().displayText)")
                        loadDashboardData()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showPeriodFilters = false
                            }
                        }
                    )
                    
                    periodChip(
                        title: "Todo o período",
                        icon: "infinity",
                        isSelected: globalDateManager.periodType == .allTime,
                        action: {
                        print("🔄 Filtro Todo o Período selecionado")
                        globalDateManager.updatePeriodType(.allTime)
                        print("📅 Período atual: \(globalDateManager.getCurrentDateRange().displayText)")
                        loadDashboardData()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showPeriodFilters = false
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
    }
    
    private func getPeriodSubtitle() -> String {
        switch globalDateManager.periodType {
        case .monthly:
            return "Período mensal"
        case .yearly:
            return "Período anual"
        case .allTime:
            return "Todo o histórico"
        }
    }
    private func periodChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            // Feedback tátil
            FeedbackService.shared.triggerLight()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ?
                                [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.secondarySystemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: isSelected ? (isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color(hex: "#3B82F6").opacity(0.3)) : Color.black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                x: 0,
                y: isSelected ? 4 : 1
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dashboardCards: some View {
        VStack(spacing: 8) {
            // Cards de receitas
            HStack(spacing: 12) {
                financeCard(
                    title: "Receitas Consolidadas",
                    value: valoresVisiveis ? formatCurrencyValue(dashboardViewModel.receitasConsolidadas) : "••••••",
                    subtitle: "Valores recebidos",
                    icon: "arrow.up",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.darkGreen, MonochromaticColorManager.primaryGreen] :
                        [Color(hex: "#22C55E"), Color(hex: "#16A34A")]
                )
                
                financeCard(
                    title: "Receitas Pendentes",
                    value: valoresVisiveis ? formatCurrencyValue(dashboardViewModel.receitasPendentes) : "••••••",
                    subtitle: "A receber",
                    icon: "clock",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                        [Color(hex: "#4ADE80"), Color(hex: "#22C55E")]
                )
            }
            .padding(.horizontal, 16)
            
            // Cards de despesas
            HStack(spacing: 12) {
                financeCard(
                    title: "Despesas Pagas",
                    value: valoresVisiveis ? formatCurrencyValue(dashboardViewModel.despesasPagas) : "••••••",
                    subtitle: "Valores pagos",
                    icon: "arrow.down",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.darkGray, MonochromaticColorManager.primaryGray] :
                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
                )
                
                financeCard(
                    title: "Despesas Pendentes",
                    value: valoresVisiveis ? formatCurrencyValue(dashboardViewModel.despesasPendentes) : "••••••",
                    subtitle: "A pagar",
                    icon: "clock",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                        [Color(hex: "#F87171"), Color(hex: "#EF4444")]
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 4)
    }
    
    private var saldoCards: some View {
        HStack(spacing: 12) {
            saldoCard(
                title: "Saldo Consolidado",
                value: valoresVisiveis ? formatCurrencyValue(dashboardViewModel.saldoConsolidado) : "••••••",
                subtitle: "Apenas valores confirmados",
                gradientColors: isMonochromaticMode ? 
                    [MonochromaticColorManager.secondaryGreen, MonochromaticColorManager.primaryGreen] :
                    [Color(hex: "#8B5CF6"), Color(hex: "#7C3AED")]
            )
            
            NavigationLink(
                destination: InvestmentsView()
                    .environmentObject(authViewModel)
                    .environmentObject(globalDateManager)
            ) {
            saldoCard(
                title: "Saldo Investido",
                    value: valoresVisiveis ? formatCurrencyValue(dashboardViewModel.saldoInvestido) : "••••••",
                subtitle: "Valor total investido",
                gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.darkGreen] :
                        [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")]
            )
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                feedbackService.triggerLight()
            })
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
    private var saldoProjetadoCard: some View {
        ZStack(alignment: .topTrailing) {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo Projetado")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
                Text(valoresVisiveis ? formatCurrencyValue(dashboardViewModel.saldoProjetado) : "••••••")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Incluindo valores pendentes")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            
            Button(action: {
                valoresVisiveis.toggle()
            }) {
                Image(systemName: valoresVisiveis ? "eye" : "eye.slash")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(12)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: isMonochromaticMode ? 
                    [MonochromaticColorManager.tertiaryGreen, MonochromaticColorManager.primaryGreen] :
                    [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 16)
    }
    
    private var progressoMetasCard: some View {
        NavigationLink(
            destination: GoalsView()
                .environmentObject(authViewModel)
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .orange)
                        
                        Text("\(Int(totalProgress * 100))%")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Progresso geral de Metas")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    ProgressView(value: totalProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .orange))
                        .frame(height: 6)
                        .clipShape(Capsule())
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            feedbackService.triggerLight()
        })
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
    
    private var ultimasTransacoesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Últimas Transações")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Ver todas") {
                    selectedTab = 1
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            
            if dashboardViewModel.ultimasTransacoes.isEmpty {
                VStack(spacing: 8) {
                    Text("Nenhuma transação encontrada")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                }
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(dashboardViewModel.ultimasTransacoes) { transaction in
                        SwipeableTransactionRow(
                            transaction: transaction,
                            categoryDisplayName: dashboardDisplayName(for: transaction.category),
                            categoryIconName: dashboardIconName(for: transaction.category),
                            categoryColorName: dashboardColorName(for: transaction.category),
                             onEdit: { editTransaction(transaction) },
                             onDelete: { deleteTransaction(transaction) },
                             onToggleStatus: { toggleStatus(transaction) },
                             onTap: { editTransaction(transaction) },
                             onInvest: { investTransaction(transaction) },
                             onRedeem: { transferInvestment(transaction) }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func dashboardDisplayName(for categoryId: String) -> String {
        if categoryId.lowercased() == "general" { return "Sem Categoria" }
        if let legacy = CategoryDataProvider.legacyDisplayNames[categoryId.lowercased()] {
            return legacy
        }
        if let match = dashboardCategoryMatching(categoryId) {
            return match.name
        }
        return CategoryDataProvider.displayName(for: categoryId)
    }
    
    private func dashboardIconName(for categoryId: String) -> String? {
        if categoryId.lowercased() == "general" {
            return "questionmark.folder"
        }
        return dashboardCategoryMatching(categoryId)?.icon
    }
    
    private func dashboardColorName(for categoryId: String) -> String? {
        if categoryId.lowercased() == "general" {
            return "gray"
        }
        return dashboardCategoryMatching(categoryId)?.color
    }
    
    private func dashboardCategoryMatching(_ categoryId: String) -> Category? {
        if let match = dashboardCategories.first(where: { $0.identifiedId == categoryId || $0.name == categoryId }) {
            return match
        }
        if let userId = authViewModel.user?.id,
           let cached: [Category] = LocalCacheManager.shared.load([Category].self, for: "categories-\(userId)") {
            if let cachedMatch = cached.first(where: { $0.identifiedId == categoryId || $0.name == categoryId }) {
                return cachedMatch
            }
        }
        return CategoryDataProvider.defaultCategories(includeHidden: true)
            .first(where: { $0.identifiedId == categoryId || $0.name == categoryId })
    }
    
    private var incomeExpenseChartSection: some View {
        let entries = dashboardViewModel.chartEntries
        let incomeLineColor = isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#22C55E")
        let expenseLineColor = isMonochromaticMode ? MonochromaticColorManager.secondaryGray : Color(hex: "#EF4444")
        let axisColor = Color.white.opacity(isMonochromaticMode ? 0.2 : 0.15)
        let incomeTotal = entries.reduce(0) { $0 + $1.income }
        let expenseTotal = entries.reduce(0) { $0 + $1.expense }
        let incomeTrend = trendPercentage(for: entries.map { $0.income })
        let expenseTrend = trendPercentage(for: entries.map { $0.expense })
        let rangeDescription = globalDateManager.getCurrentDateRange().displayText
        
        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Receitas vs Despesas")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(rangeDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    legendItem(color: incomeLineColor, title: "Receitas")
                    legendItem(color: expenseLineColor, title: "Despesas")
                }
            }
            
            if entries.count >= 2 {
                IncomeExpenseLineChart(
                    entries: entries,
                    incomeColor: incomeLineColor,
                    expenseColor: expenseLineColor,
                    axisColor: axisColor,
                    periodType: globalDateManager.periodType,
                    valueFormatter: { formatCurrencyValue($0) }
                )
                .frame(height: 220)
            } else if let entry = entries.first {
                IncomeExpenseLineChart(
                    entries: [entry, entry],
                    incomeColor: incomeLineColor,
                    expenseColor: expenseLineColor,
                    axisColor: axisColor,
                    periodType: globalDateManager.periodType,
                    valueFormatter: { formatCurrencyValue($0) }
                )
                .frame(height: 220)
            } else {
                VStack(spacing: 12) {
                    Text("Ainda não há dados suficientes para o gráfico.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            }
            
            HStack(spacing: 16) {
                summaryTile(
                    title: "Receitas",
                    value: incomeTotal,
                    color: incomeLineColor,
                    change: incomeTrend,
                    isPositiveGood: true
                )
                
                summaryTile(
                    title: "Despesas",
                    value: expenseTotal,
                    color: expenseLineColor,
                    change: expenseTrend,
                    isPositiveGood: false
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if isMonochromaticMode {
                    Color(UIColor.systemGray5)
                } else {
                    Color(UIColor.secondarySystemBackground)
                }
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    isMonochromaticMode ? Color.black.opacity(0.08) : Color.black.opacity(0.05),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func summaryTile(
        title: String,
        value: Double,
        color: Color,
        change: Double?,
        isPositiveGood: Bool
    ) -> some View {
        let displayValue = valoresVisiveis ? formatCurrencyValue(value) : "••••••"
        let badge = changeBadge(change: change, isPositiveGood: isPositiveGood)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text(displayValue)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            if let badge = badge {
                badge
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.18),
                    color.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
    }
    
    private func changeBadge(change: Double?, isPositiveGood: Bool) -> AnyView? {
        guard let change = change, abs(change) > 0.0001 else {
            return nil
        }
        
        let isPositive = change >= 0
        let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        let changeText = formatter.string(from: NSNumber(value: change)) ?? "\(Int(change * 100))%"
        
        let (backgroundColor, foregroundColor): (Color, Color) = {
            if isPositive {
                return isPositiveGood
                ? (Color(hex: "#166534"), Color(hex: "#86EFAC"))
                : (Color(hex: "#7F1D1D"), Color(hex: "#FCA5A5"))
            } else {
                return isPositiveGood
                ? (Color(hex: "#7F1D1D"), Color(hex: "#FCA5A5"))
                : (Color(hex: "#166534"), Color(hex: "#86EFAC"))
            }
        }()
        
        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(changeText)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor.opacity(0.7))
            )
        )
    }
    
    private func trendPercentage(for values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let last = values.last ?? 0
        let previous = values[values.count - 2]
        guard previous != 0 else { return nil }
        return (last - previous) / previous
    }
    
    private struct IncomeExpenseLineChart: View {
        struct AxisLabel: Identifiable {
            let id = UUID()
            let position: CGFloat
            let text: String
        }
        
        let entries: [DashboardChartEntry]
        let incomeColor: Color
        let expenseColor: Color
        let axisColor: Color
        let periodType: GlobalDateManager.PeriodType
        let valueFormatter: (Double) -> String
        
        var body: some View {
            GeometryReader { geo in
                let size = geo.size
                let incomes = entries.map { $0.income }
                let expenses = entries.map { $0.expense }
                let maxValue = max(incomes.max() ?? 0, expenses.max() ?? 0, 1)
                let incomePoints = makePoints(values: incomes, size: size, maxValue: maxValue)
                let expensePoints = makePoints(values: expenses, size: size, maxValue: maxValue)
                let axisLabels = makeAxisLabels(count: entries.count)
                
                ZStack {
                    grid(in: size, axisColor: axisColor, axisLabels: axisLabels)
                    
                    if incomePoints.count > 1 {
                        fillPath(for: incomePoints, size: size)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        incomeColor.opacity(0.25),
                                        incomeColor.opacity(0.05)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    if incomePoints.count > 1 {
                        smoothPath(from: incomePoints)
                            .stroke(
                                incomeColor,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                    } else if let point = incomePoints.first {
                        Circle()
                            .fill(incomeColor)
                            .frame(width: 8, height: 8)
                            .position(point)
                    }
                    
                    if expensePoints.count > 1 {
                        smoothPath(from: expensePoints)
                            .stroke(
                                expenseColor.opacity(0.9),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 6])
                            )
                    } else if let point = expensePoints.first {
                        Circle()
                            .fill(expenseColor.opacity(0.9))
                            .frame(width: 8, height: 8)
                            .position(point)
                    }
                    
            // Sem destaques no final para manter o gráfico limpo
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
                .overlay(alignment: .bottomLeading) {
            AxisLabelsLayout(labels: axisLabels, axisColor: axisColor)
                        .frame(height: 28)
                }
            }
        }
        
        private func makePoints(values: [Double], size: CGSize, maxValue: Double) -> [CGPoint] {
            guard !values.isEmpty else { return [] }
            let denominator = CGFloat(max(values.count - 1, 1))
            return values.enumerated().map { index, value in
                let x = size.width * CGFloat(index) / denominator
                let normalized = maxValue == 0 ? 0 : value / maxValue
                let y = size.height * (1 - CGFloat(normalized))
                let clampedY = min(max(y, 0), size.height)
                return CGPoint(x: x, y: clampedY)
            }
        }
        
        private func smoothPath(from points: [CGPoint]) -> Path {
            var path = Path()
            guard points.count > 1 else {
                if let first = points.first {
                    path.move(to: first)
                }
                return path
            }
            
            path.move(to: points[0])
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let mid = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: (previous.y + current.y) / 2
                )
                path.addQuadCurve(to: mid, control: previous)
            }
            
            if let last = points.last, let penultimate = points.dropLast().last {
                path.addQuadCurve(to: last, control: penultimate)
            }
            
            return path
        }
        
        private func fillPath(for points: [CGPoint], size: CGSize) -> Path {
            var path = Path()
            guard let first = points.first, let last = points.last else { return path }
            path.move(to: CGPoint(x: first.x, y: size.height))
            for point in points {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
            return path
        }
        
        @ViewBuilder
        private func highlight(point: CGPoint, value: Double, color: Color, size: CGSize, upward: Bool) -> some View {
            let badge = Text(valueFormatter(value))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(color.opacity(0.85))
                )
            
            VStack(spacing: 4) {
                if upward {
                    badge
                }
                
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                
                if !upward {
                    badge
                }
            }
            .position(
                x: point.x,
                y: min(max(point.y + (upward ? -26 : 26), 14), size.height - 14)
            )
        }
        
        private func grid(in size: CGSize, axisColor: Color, axisLabels: [AxisLabel]) -> some View {
            let horizontalLines = 3
            return ZStack {
                ForEach(0...horizontalLines, id: \.self) { index in
                    let progress = CGFloat(index) / CGFloat(horizontalLines)
                    let y = size.height * (1 - progress)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    .stroke(axisColor.opacity(index == 0 ? 0.45 : 0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                }
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                }
                .stroke(axisColor.opacity(0.6), lineWidth: 1)
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                }
                .stroke(axisColor.opacity(0.5), lineWidth: 1)
                
                ForEach(axisLabels) { label in
                    let x = size.width * label.position
                    Path { path in
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x, y: 0))
                    }
                    .stroke(axisColor.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [2, 10]))
                }
            }
        }
        
        private func makeAxisLabels(count: Int) -> [AxisLabel] {
            guard count > 0 else { return [] }
            if count == 1 {
                return [AxisLabel(position: 0, text: formattedLabel(for: entries[0].date))]
            }
            
            let desired = min(6, count)
            let step = max(1, (count - 1) / max(desired - 1, 1))
            var indices: Set<Int> = [0, count - 1]
            var index = step
            while index < count - 1 {
                indices.insert(index)
                index += step
            }
            let sorted = indices.sorted()
            let denominator = CGFloat(max(count - 1, 1))
            
        return sorted.map { idx in
            let position = CGFloat(idx) / denominator
            let clampedPosition = min(max(position, 0.05), 0.95)
            return AxisLabel(
                position: clampedPosition,
                text: formattedLabel(for: entries[min(idx, count - 1)].date)
            )
        }
        }
        
        private func formattedLabel(for date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            switch periodType {
            case .monthly:
                formatter.dateFormat = "dd MMM"
            case .yearly:
                formatter.dateFormat = "MMM"
            case .allTime:
                formatter.dateFormat = "yyyy"
            }
            return formatter.string(from: date).uppercased()
        }
        
        private struct AxisLabelsLayout: View {
            let labels: [AxisLabel]
            let axisColor: Color
            
            var body: some View {
                GeometryReader { geo in
                    let width = geo.size.width
                    
                    ZStack(alignment: .bottomLeading) {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: width, y: 0))
                        }
                        .stroke(axisColor.opacity(0.6), lineWidth: 1)
                        
                        ForEach(labels) { label in
                            Text(label.text)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 60)
                                .position(x: width * label.position, y: 16)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Funções Auxiliares
    
    private func financeCard(title: String, value: String, subtitle: String, icon: String, gradientColors: [Color]) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 2)
                
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal)
            
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .padding(8)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    private func saldoCard(title: String, value: String, subtitle: String, gradientColors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private func transactionItem(title: String, category: String, date: String, amount: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(category)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    private func formatCurrencyValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencySymbol = "R$"
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
    
    private func formatShortDate(_ dateStr: String) -> String {
        guard !dateStr.isEmpty else { return dateStr }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: dateStr) else { return dateStr }
        
        let outFormatter = DateFormatter()
        outFormatter.locale = Locale(identifier: "pt_BR")
        outFormatter.dateFormat = "dd MMM"
        
        return outFormatter.string(from: date).capitalized
    }
    
    private func getTransactionIcon(_ transaction: TransactionModel) -> String {
        if (transaction.type ?? "expense") == "investment" {
            return "chart.line.uptrend.xyaxis"
        } else if transaction.isIncome {
            return "arrow.up.right"
        } else {
            return "arrow.down.left"
        }
    }
    
    private func getTransactionColor(_ transaction: TransactionModel) -> Color {
        if (transaction.type ?? "expense") == "investment" {
            return .blue
        } else if transaction.isIncome {
            return .green
        } else {
            return .red
        }
    }
    
    private func previousPeriod() {
        // Feedback tátil
        FeedbackService.shared.triggerLight()
        
        print("🔄 Botão anterior clicado")
        globalDateManager.previousPeriod()
        print("📅 Período atual: \(globalDateManager.getCurrentDateRange().displayText)")
        loadDashboardData()
    }
    
    private func nextPeriod() {
        // Feedback tátil
        FeedbackService.shared.triggerLight()
        
        print("🔄 Botão próximo clicado")
        globalDateManager.nextPeriod()
        print("📅 Período atual: \(globalDateManager.getCurrentDateRange().displayText)")
        loadDashboardData()
    }
    
    private func loadDashboardData() {
        print("🔄 Carregando dados do dashboard...")
        Task {
            let currentRange = globalDateManager.getCurrentDateRange()
            let consolidatedRange = globalDateManager.getConsolidatedBalanceDateRange()
            
            print("📅 Período selecionado: \(currentRange.displayText)")
            print("📅 Data início: \(currentRange.start)")
            print("📅 Data fim: \(currentRange.end)")
            print("📅 Período consolidado: \(consolidatedRange.displayText)")
            print("📅 Data início consolidada: \(consolidatedRange.start)")
            print("📅 Data fim consolidada: \(consolidatedRange.end)")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDate = dateFormatter.string(from: currentRange.start)
            let endDate = dateFormatter.string(from: currentRange.end)
            let consolidatedStartDate = dateFormatter.string(from: consolidatedRange.start)
            let consolidatedEndDate = dateFormatter.string(from: consolidatedRange.end)
            
            print("📅 Período formatado: \(startDate) até \(endDate)")
            print("📅 Período consolidado formatado: \(consolidatedStartDate) até \(consolidatedEndDate)")
            
            await dashboardViewModel.loadDashboardData(
                startDate: startDate,
                endDate: endDate,
                consolidatedStartDate: consolidatedStartDate,
                consolidatedEndDate: consolidatedEndDate
            )
        }
    }
    
    private func loadDashboardCategories() {
        let defaults = CategoryDataProvider.defaultCategories(includeHidden: true)
        dashboardCategories = defaults
        
        guard let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
            return
        }
        
        Task {
            do {
                let userCategories = try await authViewModel.firebaseService.getCategories(userId: userId, idToken: idToken)
                var seen = Set<String>()
                var ordered: [Category] = []
                
                for category in defaults {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                
                for category in userCategories {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                
                await MainActor.run {
                    self.dashboardCategories = ordered
                }
            } catch {
                print("❌ Erro ao carregar categorias para o dashboard: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notification System
    
    /// Verifica e gera notificações se estiverem habilitadas
    private func checkNotificationsIfEnabled() async {
        // Verificar se notificações diárias estão habilitadas
        let dailyNotificationEnabled = UserDefaults.standard.bool(forKey: "dailyNotificationEnabled")
        
        guard dailyNotificationEnabled,
              let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
            return
        }
        
        // Verificar status de autorização
        await dailyNotificationChecker.checkAndGenerateNotifications(
            userId: userId,
            idToken: idToken
        )
    }
    
    private func loadDashboardGoals() {
        print("🎯 Carregando metas para o dashboard...")
        guard let userId = authViewModel.user?.id else {
            print("⚠️ Usuário não autenticado para carregar metas do dashboard")
            totalProgress = 0
            return
        }
        
        Task {
            do {
                // Obter token atualizado
                var idToken = authViewModel.user?.idToken ?? ""
                if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                    try await currentUser.refreshTokensIfNeeded()
                    idToken = currentUser.idToken?.tokenString ?? ""
                }
                
                guard !idToken.isEmpty else {
                    print("⚠️ Token inválido para carregar metas do dashboard")
                    await MainActor.run {
                        totalProgress = 0
                    }
                    return
                }
                
                // Buscar metas reais do Firebase
                let loadedGoals = try await firebaseService.getGoals(userId: userId, idToken: idToken)
                
                await MainActor.run {
                    // Calcular progresso total baseado nas metas reais
                    calculateDashboardTotals(goals: loadedGoals)
                    print("✅ Progresso de metas calculado: \(Int(totalProgress * 100))% (baseado em \(loadedGoals.count) metas)")
                }
            } catch {
                print("❌ Erro ao carregar metas do dashboard: \(error.localizedDescription)")
                await MainActor.run {
                    totalProgress = 0
                }
            }
        }
    }
    
    private func calculateDashboardTotals(goals: [Goal]) {
        var targetTotal: Double = 0
        var currentTotal: Double = 0
        
        // Filtrar apenas metas ativas
        let activeGoals = goals.filter { $0.isActive }
        
        for goal in activeGoals {
            targetTotal += goal.targetAmount
            currentTotal += goal.currentAmount
        }
        
        totalProgress = targetTotal > 0 ? min(1.0, currentTotal / targetTotal) : 0
        print("📊 Dashboard - Metas ativas: \(activeGoals.count), Total meta: R$ \(targetTotal), Total atual: R$ \(currentTotal), Progresso: \(Int(totalProgress * 100))%")
    }
    
    
    // MARK: - Transaction Actions
    
    private func editTransaction(_ transaction: TransactionModel) {
        print("🔧 editTransaction chamada - transaction: \(transaction.title ?? "nil")")
        transactionToEdit = transaction
    }
    
    private func deleteTransaction(_ transaction: TransactionModel) {
        transactionToDelete = transaction
        showDeleteConfirmation = true
    }
    
    private func confirmDeleteTransaction() {
        guard let transaction = transactionToDelete,
              let id = transaction.id else { return }
        
        Task {
            let success = await transactionsViewModel.deleteTransaction(id: id)
            if success {
                await MainActor.run {
                    self.statusNotificationMessage = "Transação '\(transaction.title ?? "sem título")' excluída com sucesso"
                    self.isSuccessNotification = true
                    self.showStatusNotification = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showStatusNotification = false
                    }
                    // Enviar notificação para atualizar as telas
                    NotificationCenter.default.post(name: NSNotification.Name("TransactionSaved"), object: nil)
                    // Recarregar dados do dashboard
                    loadDashboardData()
                }
            } else {
                await MainActor.run {
                    self.statusNotificationMessage = "Erro ao excluir transação: \(transactionsViewModel.errorMessage ?? "Erro desconhecido")"
                    self.isSuccessNotification = false
                    self.showStatusNotification = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        self.showStatusNotification = false
                    }
                }
            }
        }
        
        transactionToDelete = nil
        showDeleteConfirmation = false
    }
    
    private func toggleStatus(_ transaction: TransactionModel) {
        print("🔄 Iniciando toggle de status para: \(transaction.title ?? "")")
        guard transaction.id != nil else { 
            print("❌ ID da transação não encontrado")
            return 
        }
        
        // Só permite alternar status para investimentos cadastrados diretamente
        if (transaction.type ?? "") == "investment" {
            if transaction.sourceTransactionId != nil {
                print("⛔️ Não é permitido alternar status de investimentos vindos de transferência de receita.")
                statusNotificationMessage = "Não é possível alterar o status deste investimento."
                showStatusNotification = true
                return
            }
        }
        
        // Lógica simplificada de status
        let currentStatus = transaction.status
        let newStatus: String
        if (transaction.type ?? "expense") == "expense" {
            newStatus = (currentStatus == "paid") ? "unpaid" : "paid"
        } else if (transaction.type ?? "") == "investment" {
            newStatus = (currentStatus == "invested") ? "pending" : "invested"
        } else {
            newStatus = (currentStatus == "received") ? "pending" : "received"
        }
        
        print("🔄 Status atual: \(currentStatus ?? "-") -> Novo status: \(newStatus)")
        
        Task {
            do {
                guard authViewModel.user?.id != nil,
                      authViewModel.user?.idToken != nil else {
                    await MainActor.run {
                        statusNotificationMessage = "Usuário não autenticado"
                        isSuccessNotification = false
                        showStatusNotification = true
                    }
                    return
                }
                
                // Criar transação atualizada com novo status
                let updatedTransaction = TransactionModel(
                    id: transaction.id,
                    userId: transaction.userId,
                    title: transaction.title,
                    description: transaction.description,
                    amount: transaction.amount,
                    category: transaction.category,
                    date: transaction.date,
                    isIncome: transaction.isIncome,
                    type: transaction.type,
                    status: newStatus,
                    createdAt: transaction.createdAt,
                    isRecurring: transaction.isRecurring,
                    recurringFrequency: transaction.recurringFrequency,
                    recurringEndDate: transaction.recurringEndDate,
                    sourceTransactionId: transaction.sourceTransactionId
                )
                
                let success = await transactionsViewModel.updateTransaction(updatedTransaction)
                
                await MainActor.run {
                    if success {
                        print("✅ Status atualizado com sucesso")
                        
                        // Atualizar localmente no dashboard em vez de recarregar tudo
                        dashboardViewModel.updateTransactionLocally(updatedTransaction)
                        loadDashboardData()
                        
                        // Mensagem de sucesso baseada no tipo
                        if (transaction.type ?? "") == "investment" {
                            if newStatus == "invested" {
                                statusNotificationMessage = "Investimento Aportado"
                            } else {
                                statusNotificationMessage = "Investimento não Aportado"
                            }
                        } else if (transaction.type ?? "") == "income" {
                            if newStatus == "received" {
                                statusNotificationMessage = "Receita Marcada como Recebida"
                            } else {
                                statusNotificationMessage = "Receita Marcada como Pendente"
                            }
                        } else {
                            if newStatus == "paid" {
                                statusNotificationMessage = "Despesa Marcada como Paga"
                            } else {
                                statusNotificationMessage = "Despesa Marcada como Não Paga"
                            }
                        }
                        isSuccessNotification = true
                        showStatusNotification = true
                        
                        // Auto-hide notification após 3 segundos
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showStatusNotification = false
                        }
                    } else {
                        statusNotificationMessage = "Erro ao atualizar status"
                        isSuccessNotification = false
                        showStatusNotification = true
                    }
                }
            }
        }
    }
    
    private func investTransaction(_ transaction: TransactionModel) {
        // Verificar se é uma receita
        guard transaction.isIncome else {
            print("❌ Apenas receitas podem ser transferidas para investimento")
            return
        }
        
        print("💰 Investir na transação: \(transaction.title ?? "")")
        transactionToInvest = transaction
    }
    
    private func transferInvestment(_ transaction: TransactionModel) {
        guard (transaction.type ?? "expense") == "investment" else {
            print("❌ Apenas investimentos podem ser transferidos")
            return
        }
        
        print("💰 Transferir investimento: \(transaction.title ?? "")")
        transactionToInvest = transaction
        showTransferIncome = true
    }
    
    // MARK: - Navigation Views
    private var bottomNavigationView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 0) {
                // Dashboard (Início)
                bottomNavButton(
                    icon: "house.fill", 
                    title: "Início", 
                    isSelected: selectedTab == 0,
                    tabIndex: 0
                ) {
                    handleTabTap(tabIndex: 0)
                }
                
                // Transações
                bottomNavButton(
                    icon: "list.bullet", 
                    title: "Transações", 
                    isSelected: selectedTab == 1,
                    tabIndex: 1
                ) {
                    handleTabTap(tabIndex: 1)
                }
                
                // Botão central (adicionar)
                addTransactionButton
                
                // Metas
                bottomNavButton(
                    icon: "target", 
                    title: "Metas", 
                    isSelected: selectedTab == 2,
                    tabIndex: 2
                ) {
                    handleTabTap(tabIndex: 2)
                }
                
                // Mais
                bottomNavButton(
                    icon: "ellipsis", 
                    title: "Mais", 
                    isSelected: selectedTab == 3,
                    tabIndex: 3
                ) {
                    handleTabTap(tabIndex: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color(UIColor.systemBackground))
    }
    private func handleTabTap(tabIndex: Int) {
        // Feedback tátil sem som
        feedbackService.triggerLight()
        
        // Detecção de double tap para Início (scroll to top)
        if tabIndex == 0 {
            let now = Date()
            let isCurrentlyOnDashboard = selectedTab == 0
            let isDoubleTap = isCurrentlyOnDashboard &&
                lastTapTab == 0 &&
                lastTapTimeInicio != nil &&
                now.timeIntervalSince(lastTapTimeInicio!) < 0.5
            
            if isCurrentlyOnDashboard {
                scrollToTopID = UUID()
                if isDoubleTap {
                    scrollToTopID = UUID()
                }
            } else {
                dashboardResetID = UUID()
                scrollToTopID = UUID()
            }
            
            lastTapTimeInicio = now
            lastTapTab = 0
            selectedTab = 0
            return
        }
        // Tab Mais - sempre resetar para o menu principal
        else if tabIndex == 3 {
            // Sempre resetar a navegação quando clicar no tab Mais
            // Isso garante que mesmo estando em uma tela interna, volta ao menu principal
            moreViewResetID = UUID()
            // Enviar notificação para scroll to top
                NotificationCenter.default.post(name: NSNotification.Name("ResetMoreView"), object: nil)
            lastTapTimeMais = Date()
            lastTapTab = 3
            selectedTab = 3
        }
        else {
            // Tabs normais
            selectedTab = tabIndex
        }
    }
    
    private func bottomNavButton(icon: String, title: String, isSelected: Bool = false, tabIndex: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Container para o ícone com altura fixa
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? 
                            (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#059669")) : 
                            .gray)
                }
                .frame(height: 20)
                
                // Container para o texto com altura fixa
                ZStack {
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? 
                            (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#059669")) : 
                            .gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
    }
    
    private var addTransactionButton: some View {
        VStack(spacing: 0) {
            // Espaço para manter alinhamento com outros botões
            Spacer()
                .frame(height: 44)
            
            // Botão de nova transação posicionado acima
            Button(action: { 
                feedbackService.triggerMedium()
                showAddTransaction = true 
            }) {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#059669"), 
                                Color(hex: "#10B981"), 
                                Color(hex: "#34D399")
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    )
            }
            .offset(y: -28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
    
    // MARK: - Feedback Service
    private let feedbackService = FeedbackService.shared
    
    private func setupTabBarAppearance() {
        // Esta função não é mais necessária com o menu customizado
        // Mantida para compatibilidade caso seja chamada em algum lugar
    }
    
    
    private func findTabBar() -> UITabBar? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        
        return findTabBar(in: window)
    }
    
    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar {
            return tabBar
        }
        
        for subview in view.subviews {
            if let tabBar = findTabBar(in: subview) {
                return tabBar
            }
        }
        
        return nil
    }
}
// MARK: - Categories View
struct CategoriesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var categories: [Category] = []
    @State private var showingAddCategory = false
    @State private var showingEditCategory = false
    @State private var categoryToEdit: Category?
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: Category?
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    private let feedbackService = FeedbackService.shared
    
    var body: some View {
        VStack {
            // Header com navegação
            headerView
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Carregando categorias...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Categorias Padrão
                        if !defaultCategories.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Categorias Padrão")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                
                                if !defaultIncomeCategories.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Receitas")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                ForEach(defaultIncomeCategories) { category in
                                    CategoryCard(
                                        category: category,
                                        isDefault: true
                                    )
                                    .padding(.horizontal, 16)
                                }
                                    }
                                }
                                
                                if !defaultExpenseCategories.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Despesas")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                ForEach(defaultExpenseCategories) { category in
                                    CategoryCard(
                                        category: category,
                                        isDefault: true
                                    )
                                    .padding(.horizontal, 16)
                                }
                                    }
                                }
                            }
                        }
                        
                        // Categorias Personalizadas
                        if !userCategories.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                            Text("Suas Categorias")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(userCategories.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(8)
                                }
                                .padding(.horizontal, 16)
                                
                                ForEach(userCategories) { category in
                                    SwipeableCategoryRow(
                                        category: category,
                                        onEdit: {
                                            categoryToEdit = category
                                            showingEditCategory = true
                                        },
                                        onDelete: {
                                            categoryToDelete = category
                                            showDeleteAlert = true
                                        }
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        // Estado vazio
                        if categories.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "folder")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("Nenhuma Categoria Encontrada")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Adicione suas categorias personalizadas para organizar melhor suas transações")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                
                                Button(action: {
                                    showingAddCategory = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Adicionar Categoria")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "#059669"), Color(hex: "#10B981"), Color(hex: "#34D399")]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.vertical, 40)
                        }
                        
                        // Espaçamento extra para evitar sobreposição com menu inferior
                        Spacer(minLength: 120)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView { newCategory in
                addCategory(newCategory)
            }
        }
        .sheet(isPresented: $showingEditCategory) {
            if let category = categoryToEdit {
                EditCategoryView(category: category) { updatedCategory in
                    updateCategory(updatedCategory)
                }
            }
        }
        .onAppear {
            loadCategories()
        }
        .overlay(
            Group {
                if showDeleteAlert, let category = categoryToDelete {
                    DeleteCategoryConfirmationView(
                        category: category,
                        onConfirm: {
                            Task {
                                deleteCategory(category)
                                await MainActor.run {
                                    showDeleteAlert = false
                                    categoryToDelete = nil
                                }
                            }
                        },
                        onCancel: {
                            showDeleteAlert = false
                            categoryToDelete = nil
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
        )
    }
    
    // MARK: - View Components
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Categorias")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Gerencie suas categorias personalizadas")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    feedbackService.triggerLight()
                    showingAddCategory = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Nova Categoria")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ?
                                [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                [Color(hex: "#6366F1"), Color(hex: "#4F46E5")]
                            ),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
                .opacity(0.2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Computed Properties
    private var defaultCategories: [Category] {
        return categories.filter { $0.isDefault }
    }
    
    private var defaultIncomeCategories: [Category] {
        defaultCategories.filter { $0.type.lowercased() == "income" }
    }
    
    private var defaultExpenseCategories: [Category] {
        defaultCategories.filter { $0.type.lowercased() == "expense" }
    }
    
    private var userCategories: [Category] {
        return categories.filter { !$0.isDefault }
    }
    
    // MARK: - Functions
    private func loadCategories() {
        Task {
            do {
                // Carregar categorias padrão
                let defaultCategories = getDefaultCategories()
                
                // Carregar categorias do usuário do Firebase
                if let userId = authViewModel.user?.id,
                   let idToken = authViewModel.user?.idToken {
                    let userCategories = try await authViewModel.firebaseService.getCategories(userId: userId, idToken: idToken)
                        .filter { $0.userId == userId }
                    
                    await MainActor.run {
                        self.categories = defaultCategories + userCategories
                        self.isLoading = false
                        print("✅ Categorias carregadas: \(self.categories.count) categorias (\(defaultCategories.count) padrão + \(userCategories.count) do usuário)")
                    }
                } else {
                    await MainActor.run {
                        self.categories = defaultCategories
                        self.isLoading = false
                        print("✅ Categorias padrão carregadas: \(self.categories.count) categorias")
                    }
                }
            } catch {
                await MainActor.run {
                    // Em caso de erro, carregar apenas categorias padrão
                    self.categories = getDefaultCategories()
                    self.isLoading = false
                    print("❌ Erro ao carregar categorias do Firebase: \(error)")
                }
            }
        }
    }
    
    private func getDefaultCategories() -> [Category] {
        return CategoryDataProvider.visibleDefaultCategories()
    }
    
    private func addCategory(_ category: Category) {
        Task {
            do {
                let newCategory = Category(
                    id: nil,
                    name: category.name,
                    icon: category.icon,
                    color: category.color,
                    type: category.type,
                    isSystem: false,
                    userId: authViewModel.user?.id,
                    isDefault: false
                )
                
                if let userId = authViewModel.user?.id,
                   let idToken = authViewModel.user?.idToken {
                    try await authViewModel.firebaseService.saveCategory(newCategory, userId: userId, idToken: idToken)
                    await MainActor.run {
                        print("✅ Categoria salva no Firebase: \(newCategory.name)")
                        self.loadCategories()
                    }
                } else {
                    await MainActor.run {
                        self.categories.append(newCategory)
                        print("⚠️ Categoria adicionada localmente (usuário não autenticado): \(newCategory.name)")
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Erro ao salvar categoria no Firebase: \(error)")
                    // Em caso de erro, adicionar localmente
                    let newCategory = Category(
                        id: UUID().uuidString,
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        type: category.type,
                        isSystem: false,
                        userId: authViewModel.user?.id,
                        isDefault: false
                    )
                    self.categories.append(newCategory)
                    print("✅ Categoria adicionada localmente (fallback): \(newCategory.name)")
                }
            }
        }
    }
    
    private func updateCategory(_ category: Category) {
        Task {
            do {
                // Atualizar no Firebase
                if let userId = authViewModel.user?.id,
                   let idToken = authViewModel.user?.idToken {
                    let success = try await authViewModel.firebaseService.updateCategory(category, userId: userId, idToken: idToken)
                    
                    if success {
                        await MainActor.run {
                            print("✅ Categoria atualizada no Firebase: \(category.name)")
                            self.loadCategories()
                        }
                    }
                } else {
                    await MainActor.run {
                        // Fallback: atualizar apenas localmente
                        if let index = self.categories.firstIndex(where: { $0.id == category.id }) {
                            self.categories[index] = category
                            print("⚠️ Categoria atualizada localmente (usuário não autenticado): \(category.name)")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Erro ao atualizar categoria no Firebase: \(error)")
                    // Em caso de erro, atualizar localmente
                    if let index = self.categories.firstIndex(where: { $0.id == category.id }) {
                        self.categories[index] = category
                        print("✅ Categoria atualizada localmente (fallback): \(category.name)")
                    }
                }
            }
        }
    }
    
    private func deleteCategory(_ category: Category) {
        Task {
            do {
                // Excluir do Firebase
                if let userId = authViewModel.user?.id,
                   let idToken = authViewModel.user?.idToken,
                   let categoryId = category.id {
                    try await authViewModel.firebaseService.deleteCategory(id: categoryId, userId: userId, idToken: idToken)
                    
                    await MainActor.run {
                        self.categories.removeAll { $0.id == category.id }
                        self.loadCategories()
                        print("✅ Categoria excluída do Firebase: \(category.name)")
                    }
                } else {
                    await MainActor.run {
                        // Fallback: excluir apenas localmente
                        self.categories.removeAll { $0.id == category.id }
                        print("⚠️ Categoria excluída localmente (usuário não autenticado): \(category.name)")
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Erro ao excluir categoria do Firebase: \(error)")
                    // Em caso de erro, excluir localmente
                    self.categories.removeAll { $0.id == category.id }
                    print("✅ Categoria excluída localmente (fallback): \(category.name)")
                }
            }
        }
    }
    
    private struct DeleteCategoryConfirmationView: View {
        let category: Category
        let onConfirm: () -> Void
        let onCancel: () -> Void
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        
        var body: some View {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onCancel()
                    }
                
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: isMonochromaticMode ?
                                            [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                                            [Color(hex: "#EF4444"), Color(hex: "#DC2626")]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "trash.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Excluir Categoria")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(category.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                    
                    VStack(spacing: 12) {
                        Text("Tem certeza que deseja excluir esta categoria?")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Esta ação não pode ser desfeita.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            onCancel()
                        }) {
                            Text("Cancelar")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            FeedbackService.shared.confirmFeedback()
                            onConfirm()
                        }) {
                            Text("Excluir")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: isMonochromaticMode ?
                                            [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                                            [Color(hex: "#EF4444"), Color(hex: "#DC2626")]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: 360)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Category Row (Swipeable)
private struct SwipeableCategoryRow: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isShowingActions = false
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    private let actionButtonWidth: CGFloat = 80
    private let maxOffset: CGFloat = -160
    
    var body: some View {
        ZStack {
            if offset < 0 {
                HStack(spacing: 0) {
                    Spacer()
                    actionButton(
                        title: "Editar",
                        icon: "pencil",
                        color: isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue,
                        action: onEdit
                    )
                    actionButton(
                        title: "Excluir",
                        icon: "trash",
                        color: isMonochromaticMode ? MonochromaticColorManager.primaryGray : Color.red,
                        action: onDelete
                    )
                }
                .opacity(min(abs(offset) / 80.0, 1.0))
            }
            
            CategoryCard(category: category, isDefault: false)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let horizontal = value.translation.width
                            let vertical = abs(value.translation.height)
                            guard abs(horizontal) > vertical else { return }
                            if horizontal < 0 {
                                offset = max(horizontal, maxOffset)
                            } else if isShowingActions && horizontal > 0 && offset < 0 {
                                offset = min(horizontal + maxOffset, 0)
                            }
                        }
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if horizontal < -60 || velocity < -300 {
                                    offset = maxOffset
                                    isShowingActions = true
                                } else {
                                    offset = 0
                                    isShowingActions = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if isShowingActions {
                        withAnimation(.spring(response: 0.3)) {
                            offset = 0
                            isShowingActions = false
                        }
                    }
                }
        }
        .clipped()
    }
    
    @ViewBuilder
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            offset = 0
            isShowingActions = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: actionButtonWidth)
            .frame(maxHeight: .infinity)
            .background(color)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct CategoryCard: View {
    let category: Category
    let isDefault: Bool
    
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 24))
                .foregroundColor(getCategoryColor())
                .frame(width: 48, height: 48)
                .background(getCategoryColor().opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if isDefault {
                        Text("Padrão")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                Text(isDefault ? "Categoria do sistema" : "Categoria personalizada")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func getCategoryColor() -> Color {
        switch category.color {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        case "teal": return .teal
        default: return .gray
        }
    }
}
// MARK: - Add Category View
struct AddCategoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    let onSave: (Category) -> Void
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "folder"
    @State private var selectedColor: String = "blue"
    @State private var selectedType: String = "expense"
    @State private var errorMessage: String?
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    private let icons = ["folder", "star", "heart", "bookmark", "tag", "flag", "bell", "gear"]
    private let colors = ["green", "blue", "purple", "orange", "red", "indigo", "brown", "pink", "teal"]
    private let types = [
        ("expense", "Despesa"),
        ("income", "Receita"),
        ("investment", "Investimento")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Nome da categoria
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nome da Categoria")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("Ex: Lazer", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Tipo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Picker("Tipo", selection: $selectedType) {
                            ForEach(types, id: \.0) { type in
                                Text(type.1).tag(type.0)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Ícone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ícone")
                            .font(.headline)
                            .foregroundColor(.primary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background(selectedIcon == icon ? Color.blue : Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // Cor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cor")
                            .font(.headline)
                            .foregroundColor(.primary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(colors, id: \.self) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(getColorFromString(color))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    }
                    
                    // Mensagem de erro
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Botão Salvar
                    Button(action: saveCategory) {
                        Text("Salvar Categoria")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Nova Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Salvar") {
                    saveCategory()
                }
                .disabled(name.isEmpty)
            )
        }
    }
    
    private func saveCategory() {
        guard !name.isEmpty else {
            errorMessage = "Nome da categoria é obrigatório"
            return
        }
        
        guard let userId = authViewModel.user?.id else {
            errorMessage = "Usuário não autenticado. Faça login para salvar."
            return
        }
        
        let newCategory = Category(
            id: nil,
            name: name,
            icon: selectedIcon,
            color: selectedColor,
            type: selectedType,
            isSystem: false,
            userId: userId,
            isDefault: false
        )
        
        onSave(newCategory)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func getColorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        case "teal": return .teal
        default: return .gray
        }
    }
}
// MARK: - Edit Category View
struct EditCategoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    let category: Category
    let onSave: (Category) -> Void
    
    @State private var name: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedColor: String = ""
    @State private var selectedType: String = ""
    @State private var errorMessage: String?
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    private let icons = ["folder", "star", "heart", "bookmark", "tag", "flag", "bell", "gear"]
    private let colors = ["green", "blue", "purple", "orange", "red", "indigo", "brown", "pink", "teal"]
    private let types = [
        ("expense", "Despesa"),
        ("income", "Receita"),
        ("investment", "Investimento")
    ]
    
    init(category: Category, onSave: @escaping (Category) -> Void) {
        self.category = category
        self.onSave = onSave
        
        _name = State(initialValue: category.name)
        _selectedIcon = State(initialValue: category.icon)
        _selectedColor = State(initialValue: category.color)
        _selectedType = State(initialValue: category.type)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Nome da categoria
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nome da Categoria")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("Ex: Lazer", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Tipo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Picker("Tipo", selection: $selectedType) {
                            ForEach(types, id: \.0) { type in
                                Text(type.1).tag(type.0)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Ícone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ícone")
                            .font(.headline)
                            .foregroundColor(.primary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background(selectedIcon == icon ? Color.blue : Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // Cor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cor")
                            .font(.headline)
                            .foregroundColor(.primary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(colors, id: \.self) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(getColorFromString(color))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    }
                    
                    // Mensagem de erro
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Botão Salvar
                    Button(action: saveCategory) {
                        Text("Atualizar Categoria")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Editar Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Salvar") {
                    saveCategory()
                }
                .disabled(name.isEmpty)
            )
        }
    }
    
    private func saveCategory() {
        guard !name.isEmpty else {
            errorMessage = "Nome da categoria é obrigatório"
            return
        }
        
        let updatedCategory = Category(
            id: category.id,
            name: name,
            icon: selectedIcon,
            color: selectedColor,
            type: selectedType,
            isSystem: category.isSystem,
            userId: category.userId,
            isDefault: category.isDefault
        )
        
        onSave(updatedCategory)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func getColorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        case "teal": return .teal
        default: return .gray
        }
    }
}

// MARK: - Predefined Goal View
struct PredefinedGoalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    private let feedbackService = FeedbackService.shared
    
    let onSave: (Goal) -> Void
    
    @State private var selectedType: String = ""
    @State private var targetAmount: String = "0,00"
    @State private var currentAmount: String = "0,00"
    @State private var deadline: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    let predefinedTypes = [
        ("emergency", "Reserva de Emergência", "Fundo para emergências", 10000.0, "exclamationmark.triangle.fill", Color.red),
        ("travel", "Viagem", "Meta para viagens", 5000.0, "airplane", Color.blue),
        ("house", "Casa", "Meta para comprar casa", 200000.0, "house.fill", Color.green),
        ("car", "Carro", "Meta para comprar carro", 50000.0, "car.fill", Color.orange),
        ("education", "Educação", "Meta para educação", 15000.0, "graduationcap.fill", Color.purple),
        ("investment", "Investimento", "Meta para investimentos", 25000.0, "chart.line.uptrend.xyaxis", Color.indigo),
        ("debt", "Quitar Dívidas", "Meta para quitar dívidas", 5000.0, "creditcard.fill", Color.red),
        ("retirement", "Aposentadoria", "Meta para aposentadoria", 500000.0, "person.crop.circle.fill", Color.brown)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Escolha uma Meta Predefinida")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("Selecione um tipo de meta e personalize os valores")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Grid de tipos predefinidos
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(predefinedTypes, id: \.0) { type in
                            PredefinedGoalCard(
                                type: type.0,
                                title: type.1,
                                description: type.2,
                                suggestedAmount: type.3,
                                icon: type.4,
                                color: type.5,
                                isSelected: selectedType == type.0
                            ) {
                                selectedType = type.0
                                targetAmount = formatCurrencyValue(type.3)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Campos de personalização
                    if !selectedType.isEmpty {
                        VStack(spacing: 0) {
                            // Valor Objetivo
                            VStack(spacing: 8) {
                                Text("Valor Objetivo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                TextField("R$ 0,00", text: $targetAmount)
                                    .font(.system(size: 24, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                                    .onChange(of: targetAmount) { newValue in
                                        targetAmount = formatCurrencyInput(newValue)
                                    }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            
                            // Valor Atual
                            FormFieldRow(
                                icon: "banknote",
                                title: "Valor Atual"
                            ) {
                                TextField("R$ 0,00", text: $currentAmount)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: currentAmount) { newValue in
                                        currentAmount = formatCurrencyInput(newValue)
                                    }
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Data Limite
                            FormFieldRow(
                                icon: "calendar",
                                title: "Data Limite"
                            ) {
                                DatePicker("", selection: $deadline, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .accentColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                            }
                        }
                        .padding(.top, 24)
                    }
                    
                    // Botão Salvar
                    if !selectedType.isEmpty {
                        VStack(spacing: 16) {
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            
                            Button(action: saveGoal) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Criar Meta")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "#059669"), Color(hex: "#10B981"), Color(hex: "#34D399")]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            .disabled(targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Meta Predefinida")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            )
        }
    }
    
    // MARK: - Functions
    private func saveGoal() {
        guard let userId = authViewModel.user?.id else {
            errorMessage = "Usuário não autenticado."
            return
        }
        
        // Converter valores formatados brasileiros para Double
        let cleanedTargetAmount = targetAmount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        let cleanedCurrentAmount = currentAmount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        
        guard let targetAmountValue = Double(cleanedTargetAmount) else {
            errorMessage = "Valor objetivo inválido."
            return
        }
        
        guard let currentAmountValue = Double(cleanedCurrentAmount) else {
            errorMessage = "Valor atual inválido."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let now = Date()
        let selectedTypeData = predefinedTypes.first { $0.0 == selectedType }
        
        // Criar nova meta predefinida
        let newGoal = Goal(
            id: nil,
            userId: userId,
            title: selectedTypeData?.1 ?? "Meta",
            description: selectedTypeData?.2 ?? "",
            targetAmount: targetAmountValue,
            currentAmount: currentAmountValue,
            deadline: deadline,
            category: getCategoryForType(selectedType),
            isPredefined: true,
            predefinedType: selectedType,
            createdAt: now,
            updatedAt: now,
            isActive: true
        )
        
        print("Criando meta predefinida: \(newGoal)")
        onSave(newGoal)
        isLoading = false
        feedbackService.triggerLight()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func getCategoryForType(_ type: String) -> String {
        switch type {
        case "emergency": return "Emergência"
        case "travel": return "Viagem"
        case "house": return "Casa"
        case "car": return "Carro"
        case "education": return "Educação"
        case "investment": return "Investimento"
        case "debt": return "Dívidas"
        case "retirement": return "Aposentadoria"
        default: return "Geral"
        }
    }
    
    private func formatCurrencyValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "0,00"
    }
    
    private func formatCurrencyInput(_ input: String) -> String {
        // Remover todos os caracteres não numéricos
        let cleanedInput = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Se está vazio, retornar "0,00"
        if cleanedInput.isEmpty {
            return "0,00"
        }
        
        // Converter para número inteiro (representa centavos)
        let centavos = Int(cleanedInput) ?? 0
        
        // Converter centavos para reais e centavos
        let reais = centavos / 100
        let centavosRestantes = centavos % 100
        
        // Formatar parte inteira com pontos para milhares
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        
        let formattedReais = formatter.string(from: NSNumber(value: reais)) ?? "0"
        let formattedCentavos = String(format: "%02d", centavosRestantes)
        
        return "\(formattedReais),\(formattedCentavos)"
    }
}

// MARK: - Predefined Goal Card
struct PredefinedGoalCard: View {
    let type: String
    let title: String
    let description: String
    let suggestedAmount: Double
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Ícone
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
                
                // Título
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Descrição
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Valor sugerido
                Text("R$ \(formatCurrency(suggestedAmount))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Exchange Rate Models
struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}

struct BitcoinPriceResponse: Codable {
    let bitcoin: BitcoinPrice
    
    enum CodingKeys: String, CodingKey {
        case bitcoin = "bitcoin"
    }
}

struct BitcoinPrice: Codable {
    let usd: Double
}

enum ExchangeRateError: Error {
    case invalidURL
    case noData
    case decodingError
}
// MARK: - Investments View
struct InvestmentsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var globalDateManager: GlobalDateManager
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    private let feedbackService = FeedbackService.shared
    @State private var investmentTransactions: [TransactionModel] = []
    @State private var showingAddInvestment = false
    @State private var isLoading = false
    @State private var dollarRate: Double = 5.25
    @State private var bitcoinPrice: Double = 350000.0
    @State private var bitcoinPriceUSD: Double = 65000.0
    @State private var isLoadingRates = false
    @State private var lastUpdateTime = Date()
    @State private var updateTimer: Timer?
    @State private var statusFilter: String = "all" // "all", "active", "completed"
    @State private var showPeriodFilters: Bool = false
    @State private var investmentToEdit: TransactionModel?
    @State private var investmentsAppeared = false
    @State private var investmentCategories: [Category] = CategoryDataProvider.defaultCategories(includeHidden: true)
    
    // MARK: - Computed Properties
    private var filteredInvestments: [TransactionModel] {
        var filtered = investmentTransactions
        
        // Filtro por status
        if statusFilter != "all" {
            let currentDate = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            filtered = filtered.filter { transaction in
                guard let transactionDate = dateFormatter.date(from: transaction.date) else { return false }
                
                if statusFilter == "active" {
                    // Investimentos "ativos" são os mais recentes (últimos 12 meses) ou com status "invested"
                    let twelveMonthsAgo = Calendar.current.date(byAdding: .month, value: -12, to: currentDate) ?? currentDate
                    return transactionDate >= twelveMonthsAgo || transaction.status == "invested"
                } else if statusFilter == "completed" {
                    // Investimentos "concluídos" são os mais antigos (mais de 12 meses) ou com status diferente de "invested"
                    let twelveMonthsAgo = Calendar.current.date(byAdding: .month, value: -12, to: currentDate) ?? currentDate
                    return transactionDate < twelveMonthsAgo || transaction.status != "invested"
                }
                return true
            }
        }
        
        // Ordenar por data (mais recente primeiro)
        return filtered.sorted { transaction1, transaction2 in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date1 = dateFormatter.date(from: transaction1.date) ?? Date.distantPast
            let date2 = dateFormatter.date(from: transaction2.date) ?? Date.distantPast
            return date1 > date2
        }
    }
    
    // Calcular saldo investido total
    private var totalInvestedAmount: Double {
        filteredInvestments.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filtro de período (fixo no topo)
            filterView
                .background(Color(UIColor.systemBackground))
            
            Divider()
                .opacity(0.3)
            
            // Conteúdo rolável
            Group {
                if isLoading {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Card Saldo Investido
                            saldoInvestidoCard
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            
                            // Cards de Cotações
                            exchangeRatesView
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            
                            // Filtros de status
                            filtersView
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            
                            Divider()
                                .opacity(0.3)
                                .padding(.horizontal, 16)
                            
                            if filteredInvestments.isEmpty {
                                // Estado vazio
                                emptyStateView
                                    .padding(.top, 24)
                            } else {
                                // Lista de investimentos usando o mesmo modelo de transações
                                VStack(spacing: 8) {
                                    ForEach(filteredInvestments) { transaction in
                                        SwipeableTransactionRow(
                                            transaction: transaction,
                                            categoryDisplayName: investmentDisplayName(for: transaction.category),
                                            categoryIconName: investmentIconName(for: transaction.category),
                                            categoryColorName: investmentColorName(for: transaction.category),
                                            onEdit: { editInvestment(transaction) },
                                            onDelete: { deleteInvestment(transaction) },
                                            onToggleStatus: { toggleInvestmentStatus(transaction) },
                                            onTap: { editInvestment(transaction) },
                                            onInvest: {},
                                            onRedeem: {}
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                }
                                
                                // Espaçamento extra para evitar sobreposição com menu inferior
                                Spacer(minLength: 120)
                            }
                        }
                        .background(Color(UIColor.systemGroupedBackground))
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                // Carregar investimentos
                loadInvestments()
                loadExchangeRates()
                loadInvestmentCategories()
                
                // Iniciar atualizações de cotações
                startExchangeRateUpdates()
                
                // Animar entrada
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    investmentsAppeared = true
                }
            }
            .onDisappear {
                // Resetar animação ao sair
                investmentsAppeared = false
                stopExchangeRateUpdates()
            }
            .sheet(isPresented: $showingAddInvestment) {
                AddInvestmentView { newInvestment in
                    addInvestment(newInvestment)
                }
                .environmentObject(authViewModel)
                .environmentObject(globalDateManager)
            }
            .sheet(item: $investmentToEdit, onDismiss: {
                loadInvestments()
                investmentToEdit = nil
            }) { transaction in
                AddTransactionView(transactionToEdit: transaction)
                    .environmentObject(authViewModel)
                    .environmentObject(globalDateManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TransactionSaved"))) { _ in
                // Atualizar investimentos quando uma nova transação for salva
                print("🔄 Atualizando investimentos após salvar...")
                loadInvestments()
            }
        }
    }
    
    private func loadInvestmentCategories() {
        let defaults = CategoryDataProvider.defaultCategories(includeHidden: true)
        investmentCategories = defaults
        
        guard let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
            return
        }
        
        Task {
            do {
                let userCategories = try await authViewModel.firebaseService.getCategories(userId: userId, idToken: idToken)
                var seen = Set<String>()
                var ordered: [Category] = []
                
                for category in defaults {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                
                for category in userCategories {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                
                await MainActor.run {
                    self.investmentCategories = ordered
                }
            } catch {
                print("❌ Erro ao carregar categorias para investimentos: \(error.localizedDescription)")
            }
        }
    }
    
    private func investmentDisplayName(for categoryId: String) -> String {
        if categoryId.lowercased() == "general" { return "Sem Categoria" }
        if let legacy = CategoryDataProvider.legacyDisplayNames[categoryId.lowercased()] {
            return legacy
        }
        if let match = investmentCategoryMatching(categoryId) {
            return match.name
        }
        return CategoryDataProvider.displayName(for: categoryId)
    }
    
    private func investmentIconName(for categoryId: String) -> String? {
        if categoryId.lowercased() == "general" {
            return "questionmark.folder"
        }
        return investmentCategoryMatching(categoryId)?.icon
    }
    
    private func investmentColorName(for categoryId: String) -> String? {
        if categoryId.lowercased() == "general" {
            return "gray"
        }
        return investmentCategoryMatching(categoryId)?.color
    }
    
    private func investmentCategoryMatching(_ categoryId: String) -> Category? {
        if let match = investmentCategories.first(where: { $0.identifiedId == categoryId || $0.name == categoryId }) {
            return match
        }
        if let userId = authViewModel.user?.id,
           let cached: [Category] = LocalCacheManager.shared.load([Category].self, for: "categories-\(userId)") {
            if let cachedMatch = cached.first(where: { $0.identifiedId == categoryId || $0.name == categoryId }) {
                return cachedMatch
            }
        }
        return CategoryDataProvider.defaultCategories(includeHidden: true)
            .first(where: { $0.identifiedId == categoryId || $0.name == categoryId })
    }

    // MARK: - View Components
    private var filterView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button(action: previousPeriod) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(globalDateManager.periodType == .allTime ? .secondary : .primary)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(filterButtonBackground)
                        .clipShape(Circle())
                        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(globalDateManager.periodType == .allTime)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showPeriodFilters.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(globalDateManager.getCurrentDateRange().displayText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if globalDateManager.periodType != .allTime {
                            Text(getPeriodSubtitle())
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: nextPeriod) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(globalDateManager.periodType == .allTime ? .secondary : .primary)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(filterButtonBackground)
                        .clipShape(Circle())
                        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(globalDateManager.periodType == .allTime)
            }
            .padding(.horizontal, 20)

            if showPeriodFilters {
                HStack(spacing: 8) {
                    periodChip(
                        title: "Mensal",
                        icon: "calendar",
                        isSelected: globalDateManager.periodType == .monthly
                    ) {
                        globalDateManager.updatePeriodType(.monthly)
                        loadInvestments()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPeriodFilters = false
                        }
                    }

                    periodChip(
                        title: "Anual",
                        icon: "calendar.badge.clock",
                        isSelected: globalDateManager.periodType == .yearly
                    ) {
                        globalDateManager.updatePeriodType(.yearly)
                        loadInvestments()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPeriodFilters = false
                        }
                    }

                    periodChip(
                        title: "Todo o período",
                        icon: "infinity",
                        isSelected: globalDateManager.periodType == .allTime
                    ) {
                        globalDateManager.updatePeriodType(.allTime)
                        loadInvestments()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPeriodFilters = false
                        }
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
    }

    private var filterButtonBackground: some View {
        Group {
            if isMonochromaticMode {
                LinearGradient(
                    gradient: Gradient(colors: [
                        MonochromaticColorManager.secondaryGray.opacity(0.3),
                        MonochromaticColorManager.primaryGray.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.secondarySystemBackground),
                        Color(UIColor.tertiarySystemBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .foregroundColor(isMonochromaticMode ? Color(hex: "#059669") : .blue)
            Text("Carregando investimentos...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 80, height: 80)

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Text("Nenhum investimento encontrado")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)

                Text("Neste período não há investimentos registrados")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                feedbackService.triggerLight()
                showingAddInvestment = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Adicionar Investimento")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#3B82F6"),
                            Color(hex: "#2563EB"),
                            Color(hex: "#1D4ED8")
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var filtersView: some View {
        HStack(spacing: 12) {
            Button(action: cycleStatusFilter) {
                HStack(spacing: 6) {
                    Image(systemName: getStatusIcon())
                        .font(.system(size: 14))
                        .foregroundColor(getStatusColor())

                    Text(getStatusText())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(getStatusColor())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(getStatusColor().opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(getStatusColor().opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
    }

    private var saldoInvestidoCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saldo Investido")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))

            Text(formatCurrency(totalInvestedAmount))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("Valor total investido")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: isMonochromaticMode ?
                    [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.darkGreen] :
                    [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private var exchangeRatesView: some View {
        HStack(spacing: 12) {
            exchangeRateCard(
                title: "Dólar Comercial",
                mainValue: isLoadingRates ? nil : formatCurrency(dollarRate),
                secondaryValue: nil,
                isLoading: isLoadingRates
            )
            
            exchangeRateCard(
                title: "Bitcoin",
                mainValue: isLoadingRates ? nil : formatCurrency(bitcoinPrice),
                secondaryValue: isLoadingRates ? nil : formatCurrencyUSD(bitcoinPriceUSD),
                isLoading: isLoadingRates
            )
        }
    }
    
    private func exchangeRateCard(title: String, mainValue: String?, secondaryValue: String?, isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                if let mainValue {
                    Text(mainValue)
                        .font(.system(size: 18, weight: .bold))
                }
                if let secondaryValue {
                    Text(secondaryValue)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 96)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Helper Views & Actions
    private func periodChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            feedbackService.triggerLight()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ?
                                [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.secondarySystemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: isSelected ? (isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color(hex: "#3B82F6").opacity(0.3)) : Color.black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                x: 0,
                y: isSelected ? 4 : 1
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func getPeriodSubtitle() -> String {
        switch globalDateManager.periodType {
        case .monthly:
            return "Período mensal"
        case .yearly:
            return "Período anual"
        case .allTime:
            return "Todo o histórico"
        }
    }

    private func cycleStatusFilter() {
        switch statusFilter {
        case "all":
            statusFilter = "active"
        case "active":
            statusFilter = "completed"
        default:
            statusFilter = "all"
        }
        feedbackService.triggerLight()
    }

    private func getStatusIcon() -> String {
        switch statusFilter {
        case "active": return "play.circle.fill"
        case "completed": return "checkmark.circle.fill"
        default: return "list.bullet.circle.fill"
        }
    }

    private func getStatusText() -> String {
        switch statusFilter {
        case "active": return "Ativos"
        case "completed": return "Concluídos"
        default: return "Todos"
        }
    }

    private func getStatusColor() -> Color {
        switch statusFilter {
        case "active": return .green
        case "completed": return .blue
        default: return isMonochromaticMode ? Color(hex: "#059669") : .blue
        }
    }

    private func previousPeriod() {
        feedbackService.triggerLight()
        globalDateManager.previousPeriod()
        loadInvestments()
    }

    private func nextPeriod() {
        feedbackService.triggerLight()
        globalDateManager.nextPeriod()
        loadInvestments()
    }

    private func addInvestment(_ investment: Investment) {
        loadInvestments()
    }

    private func editInvestment(_ transaction: TransactionModel) {
        investmentToEdit = transaction
    }

    private func deleteInvestment(_ transaction: TransactionModel) {
        Task {
            guard let userId = authViewModel.user?.id,
                  let transactionId = transaction.id else { return }

            do {
                try await authViewModel.firebaseService.deleteTransaction(id: transactionId, userId: userId)
                loadInvestments()
                NotificationCenter.default.post(name: NSNotification.Name("TransactionSaved"), object: nil)
            } catch {
                print("❌ Erro ao deletar investimento: \(error.localizedDescription)")
            }
        }
    }

    private func loadInvestments() {
        Task {
            guard let userId = authViewModel.user?.id else {
                await MainActor.run {
                    self.isLoading = false
                    self.investmentTransactions = []
                }
                return
            }

            var idToken = authViewModel.user?.idToken ?? ""
            if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                do {
                    try await currentUser.refreshTokensIfNeeded()
                    idToken = currentUser.idToken?.tokenString ?? ""
                } catch {
                    print("❌ Erro ao atualizar token: \(error.localizedDescription)")
                }
            }

            guard !idToken.isEmpty else {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }

            let range = globalDateManager.getCurrentDateRange()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let startDate = formatter.string(from: range.start)
            let endDate = formatter.string(from: range.end)

            await MainActor.run {
                self.isLoading = true
            }

            do {
                let transactions = try await authViewModel.firebaseService.getTransactions(
                    userId: userId,
                    startDate: startDate,
                    endDate: endDate,
                    idToken: idToken
                )

                let investments = transactions.filter { ($0.type ?? "expense") == "investment" }

                await MainActor.run {
                    self.investmentTransactions = investments
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.investmentTransactions = []
                    self.isLoading = false
                }
                print("❌ Erro ao carregar investimentos: \(error.localizedDescription)")
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func formatCurrencyUSD(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private func formatLastUpdate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Atualizado às \(formatter.string(from: lastUpdateTime))"
    }

    private func toggleInvestmentStatus(_ transaction: TransactionModel) {
        Task {
            guard let userId = authViewModel.user?.id else { return }
            
            var idToken = authViewModel.user?.idToken ?? ""
            if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                do {
                    try await currentUser.refreshTokensIfNeeded()
                    idToken = currentUser.idToken?.tokenString ?? ""
                } catch {
                    print("⚠️ Erro ao atualizar token: \(error.localizedDescription)")
                }
            }
            
            guard !idToken.isEmpty else { return }
            
            // Alternar status entre "invested" e "pending"
            let newStatus = transaction.status == "invested" ? "pending" : "invested"
            
            // Criar nova instância com status atualizado
            let updatedTransaction = TransactionModel(
                id: transaction.id,
                userId: transaction.userId,
                title: transaction.title,
                description: transaction.description,
                amount: transaction.amount,
                category: transaction.category,
                date: transaction.date,
                isIncome: transaction.isIncome,
                type: transaction.type,
                status: newStatus,
                createdAt: transaction.createdAt,
                isRecurring: transaction.isRecurring,
                recurringFrequency: transaction.recurringFrequency,
                recurringEndDate: transaction.recurringEndDate,
                sourceTransactionId: transaction.sourceTransactionId
            )
            
            do {
                _ = try await authViewModel.firebaseService.updateTransaction(
                    updatedTransaction,
                    userId: userId,
                    idToken: idToken
                )
                
                // Recarregar investimentos após atualizar
                await MainActor.run {
                    loadInvestments()
                    NotificationCenter.default.post(name: NSNotification.Name("TransactionSaved"), object: nil)
                }
            } catch {
                print("❌ Erro ao atualizar status do investimento: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadExchangeRates() {
        isLoadingRates = true
        
        // Buscar cotações reais de forma segura
        Task {
            await fetchRealExchangeRates()
        }
    }
    
    private func fetchRealExchangeRates() async {
        do {
            // Buscar cotação do dólar (USD/BRL)
            let dollarRate = try await fetchDollarRate()
            
            // Buscar cotação do Bitcoin (USD)
            let bitcoinPriceUSD = try await fetchBitcoinPrice()
            
            // Converter Bitcoin para BRL
            let bitcoinPriceBRL = bitcoinPriceUSD * dollarRate
            
            await MainActor.run {
                self.dollarRate = dollarRate
                self.bitcoinPrice = bitcoinPriceBRL
                self.bitcoinPriceUSD = bitcoinPriceUSD
                self.lastUpdateTime = Date()
                self.isLoadingRates = false
            }
        } catch {
            await MainActor.run {
                // Em caso de erro, manter valores anteriores
                self.isLoadingRates = false
                print("Erro ao carregar cotações: \(error)")
            }
        }
    }
    
    private func fetchDollarRate() async throws -> Double {
        // API gratuita para cotação USD/BRL
        guard let url = URL(string: "https://api.exchangerate-api.com/v4/latest/USD") else {
            throw ExchangeRateError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            return response.rates["BRL"] ?? 5.25 // Fallback para valor padrão
        } catch {
            print("❌ Erro ao buscar cotação do dólar: \(error)")
            return 5.25 // Fallback para valor padrão
        }
    }
    private func fetchBitcoinPrice() async throws -> Double {
        // API gratuita para cotação do Bitcoin
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd") else {
            throw ExchangeRateError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(BitcoinPriceResponse.self, from: data)
            return response.bitcoin.usd
        } catch {
            print("❌ Erro ao buscar cotação do Bitcoin: \(error)")
            return 65000.0 // Fallback para valor padrão
        }
    }
    
    private func startExchangeRateUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.loadExchangeRates()
        }
    }
    
    private func stopExchangeRateUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
}
    
    // MARK: - Investment Card
    struct InvestmentCard: View {
        let investment: Investment
        let onUpdate: (Investment) -> Void
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        @Environment(\.colorScheme) private var colorScheme
        
        @State private var showingEdit = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(investment.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(investment.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(getTypeColor())
                            )
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(investment.amount))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(formatDate(investment.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !investment.notes.isEmpty {
                    Text(investment.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isMonochromaticMode ? Color(hex: "#059669").opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
            .onTapGesture {
                showingEdit = true
            }
            .sheet(isPresented: $showingEdit) {
                EditInvestmentView(investment: investment) { updatedInvestment in
                    onUpdate(updatedInvestment)
                }
            }
        }
        
        private func getTypeColor() -> Color {
            switch investment.type {
            case .stocks: return .blue
            case .bonds: return .green
            case .realEstate: return .orange
            case .crypto: return .purple
            case .mutualFunds: return .red
            case .other: return .gray
            }
        }
        
        private func formatCurrency(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "BRL"
            formatter.locale = Locale(identifier: "pt_BR")
            return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
        }
        
        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Add Investment View
    struct AddInvestmentView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var authViewModel: AuthViewModel
        @EnvironmentObject var globalDateManager: GlobalDateManager
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        
        let onSave: (Investment) -> Void
        
        @State private var type: String = "investment"
        @State private var amount: String = "0,00"
        @State private var description: String = ""
        @State private var category: String = CategoryDataProvider.investmentCategoryID
        @State private var date: Date = Date()
        @State private var isPaid: Bool = true
        @State private var isRecurring: Bool = false
        @State private var recurringFrequency: String = "monthly"
        @State private var recurringEndDate: Date = Date()
        @State private var errorMessage: String?
        @State private var isLoading: Bool = false
        
        let frequencies = ["monthly", "weekly", "yearly"]
        let categories = ["Investimento", "Ações", "Títulos", "Imóveis", "Criptomoedas", "Fundos", "Outros"]
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 0) {
                        // Tipo de Transação - Header (apenas Investimento)
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                // Investimento (única opção)
                                HStack(spacing: 8) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Investimento")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue)
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                        
                        // Valor - Destaque
                        VStack(spacing: 8) {
                            Text("Valor")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("R$ 0,00", text: $amount)
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .padding(.vertical, 16)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(16)
                                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                .onChange(of: amount) { newValue in
                                    amount = formatCurrencyInput(newValue)
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        
                        // Campos principais
                        VStack(spacing: 0) {
                            // Descrição
                            FormFieldRow(
                                icon: "text.alignleft",
                                title: "Descrição"
                            ) {
                                TextField("Adicionar descrição", text: $description)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Data
                            FormFieldRow(
                                icon: "calendar",
                                title: "Data"
                            ) {
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .tint(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Status
                            FormFieldRow(
                                icon: "checkmark.circle",
                                title: "Aportado"
                            ) {
                                Toggle("", isOn: $isPaid)
                                    .tint(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Recorrência
                            FormFieldRow(
                                icon: "repeat",
                                title: "Recorrente"
                            ) {
                                Toggle("", isOn: $isRecurring)
                                    .tint(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                            }
                            
                            // Campos de recorrência (condicionais)
                            if isRecurring {
                                VStack(spacing: 0) {
                                    Divider()
                                        .padding(.leading, 56)
                                    
                                    FormFieldRow(
                                        icon: "clock",
                                        title: "Frequência"
                                    ) {
                                        Picker("Frequência", selection: $recurringFrequency) {
                                            ForEach(frequencies, id: \.self) { freq in
                                                Text(getFrequencyDisplayName(freq)).tag(freq)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 56)
                                    
                                    FormFieldRow(
                                        icon: "calendar.badge.clock",
                                        title: "Até"
                                    ) {
                                        DatePicker("", selection: $recurringEndDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .tint(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                    }
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        
                        // Mensagem de erro
                        if let errorMessage = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                        
                        // Loading
                        if isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Salvando...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 24)
                        }
                        
                        // Espaçamento extra no final
                        Spacer(minLength: 40)
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                .navigationBarTitle("Novo Investimento", displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancelar") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Salvar") {
                            saveInvestment()
                        }
                        .disabled(amount.isEmpty || amount == "0,00" || isLoading)
                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                    }
                }
            }
            .onAppear {
                // Sincronizar data com o GlobalDateManager
                let calendar = Calendar.current
                let currentDate = Date()
                let selectedDate = globalDateManager.selectedDate
                
                // Verificar se o mês/ano selecionado é o mês vigente
                let isCurrentMonth = calendar.isDate(selectedDate, equalTo: currentDate, toGranularity: .month)
                
                if isCurrentMonth {
                    // Se for o mês vigente, usar a data atual
                    date = currentDate
                } else {
                    // Se não for o mês vigente, usar o dia 1 do mês/ano selecionado
                    let components = calendar.dateComponents([.year, .month], from: selectedDate)
                    if let firstDayOfMonth = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) {
                        date = firstDayOfMonth
                    }
                }
            }
        }
        
        // MARK: - Functions
        private func saveInvestment() {
            guard let userId = authViewModel.user?.id else {
                errorMessage = "Usuário não autenticado."
                return
            }
            
            // Converter valor formatado brasileiro para Double
            let cleanedAmount = amount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            guard let amountValue = Double(cleanedAmount) else {
                errorMessage = "Valor inválido."
                return
            }
            
            let amountInReais = amountValue
            isLoading = true
            errorMessage = nil
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let now = Date()
            
            let status: String = isPaid ? "invested" : "pending"
            
            Task {
                do {
                    // Obter token atualizado
                    var idToken = authViewModel.user?.idToken ?? ""
                    if idToken.isEmpty, let currentUser = GIDSignIn.sharedInstance.currentUser {
                        try await currentUser.refreshTokensIfNeeded()
                        idToken = currentUser.idToken?.tokenString ?? ""
                    }
                    
                    guard !idToken.isEmpty else {
                        await MainActor.run {
                            errorMessage = "Token de autenticação não encontrado."
                            isLoading = false
                        }
                        return
                    }
                    
                    if isRecurring {
                        // Criar múltiplas transações recorrentes
                        try await createRecurringInvestmentTransactions(
                            userId: userId,
                            idToken: idToken,
                            amountInReais: amountInReais,
                            status: status,
                            dateFormatter: dateFormatter,
                            now: now
                        )
                    } else {
                        // Criar transação única
                        let transaction = TransactionModel(
                            id: nil,
                            userId: userId,
                            title: description.isEmpty ? "-" : description,
                            description: description.isEmpty ? "-" : description,
                            amount: amountInReais,
                            category: CategoryDataProvider.investmentCategoryID,
                            date: dateFormatter.string(from: date),
                            isIncome: false,
                            type: "investment",
                            status: status,
                            createdAt: now,
                            isRecurring: false,
                            recurringFrequency: "",
                            recurringEndDate: "",
                            sourceTransactionId: nil
                        )
                        
                        try await authViewModel.firebaseService.saveTransaction(transaction, userId: userId, idToken: idToken)
                        
                        await MainActor.run {
                            // Criar objeto Investment para callback
                            let investment = Investment(
                                id: nil,
                                name: description.isEmpty ? "Investimento" : description,
                                type: InvestmentType.other,
                                amount: amountInReais,
                                startDate: date,
                                notes: ""
                            )
                            
                            onSave(investment)
                            isLoading = false
                            
                            // Feedback háptico
                            FeedbackService.shared.successFeedback()
                            
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Erro ao salvar: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        }
        
        private func createRecurringInvestmentTransactions(
            userId: String,
            idToken: String,
            amountInReais: Double,
            status: String,
            dateFormatter: DateFormatter,
            now: Date
        ) async throws {
            let calendar = Calendar.current
            var currentDate = date
            let endDate = recurringEndDate
            var transactionCount = 0
            let maxTransactions = 50 // Limite para evitar muitas transações
            
            print("🔄 Criando investimentos recorrentes:")
            print("   Data inicial: \(dateFormatter.string(from: currentDate))")
            print("   Data final: \(dateFormatter.string(from: endDate))")
            print("   Frequência: \(recurringFrequency)")
            
            let parentRecurringId = "recurring_investment_\(now.timeIntervalSince1970)"
            
            // Criar as transações recorrentes
            while currentDate <= endDate && transactionCount < maxTransactions {
                let transaction = TransactionModel(
                    id: nil,
                    userId: userId,
                    title: description.isEmpty ? "-" : description,
                    description: description.isEmpty ? "-" : description,
                    amount: amountInReais,
                    category: CategoryDataProvider.investmentCategoryID,
                    date: dateFormatter.string(from: currentDate),
                    isIncome: false,
                    type: "investment",
                    status: status,
                    createdAt: now,
                    isRecurring: false,
                    recurringFrequency: "",
                    recurringEndDate: "",
                    sourceTransactionId: parentRecurringId
                )
                
                try await authViewModel.firebaseService.saveTransaction(transaction, userId: userId, idToken: idToken)
                
                print("   ✅ Investimento criado para: \(dateFormatter.string(from: currentDate))")
                transactionCount += 1
                
                // Calcular próxima data baseada na frequência
                switch recurringFrequency {
                case "weekly":
                    currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
                case "monthly":
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                case "yearly":
                    currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
                default:
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                }
            }
            
            await MainActor.run {
                print("✅ \(transactionCount) investimentos recorrentes criados com sucesso")
                
                // Criar objeto Investment para callback
                let investment = Investment(
                    id: nil,
                    name: description.isEmpty ? "Investimento" : description,
                    type: InvestmentType.other,
                    amount: amountInReais,
                    startDate: date,
                    notes: ""
                )
                
                onSave(investment)
                isLoading = false
                
                // Feedback háptico
                FeedbackService.shared.successFeedback()
                
                presentationMode.wrappedValue.dismiss()
            }
        }
        
        // Mapeamento de frequências para português
        private func getFrequencyDisplayName(_ frequency: String) -> String {
            switch frequency {
            case "monthly": return "Mensal"
            case "weekly": return "Semanal"
            case "yearly": return "Anual"
            default: return frequency.capitalized
            }
        }
        
        private func formatCurrencyInput(_ input: String) -> String {
            // Remover todos os caracteres não numéricos
            let cleanedInput = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            
            // Se está vazio, retornar "0,00"
            if cleanedInput.isEmpty {
                return "0,00"
            }
            
            // Converter para número inteiro (representa centavos)
            let centavos = Int(cleanedInput) ?? 0
            
            // Converter centavos para reais e centavos
            let reais = centavos / 100
            let centavosRestantes = centavos % 100
            
            // Formatar parte inteira com pontos para milhares
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            formatter.groupingSize = 3
            
            let formattedReais = formatter.string(from: NSNumber(value: reais)) ?? "0"
            let formattedCentavos = String(format: "%02d", centavosRestantes)
            
            return "\(formattedReais),\(formattedCentavos)"
        }
    }
    // MARK: - Edit Investment View
    struct EditInvestmentView: View {
        @Environment(\.presentationMode) var presentationMode
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        
        let investment: Investment
        let onSave: (Investment) -> Void
        
        @State private var name: String
        @State private var selectedType: InvestmentType
        @State private var amount: String
        @State private var startDate: Date
        @State private var notes: String
        @State private var isLoading = false
        @State private var errorMessage: String?
        
        init(investment: Investment, onSave: @escaping (Investment) -> Void) {
            self.investment = investment
            self.onSave = onSave
            self._name = State(initialValue: investment.name)
            self._selectedType = State(initialValue: investment.type)
            self._amount = State(initialValue: String(format: "%.2f", investment.amount).replacingOccurrences(of: ".", with: ","))
            self._startDate = State(initialValue: investment.startDate)
            self._notes = State(initialValue: investment.notes)
        }
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Editar Investimento")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Modifique as informações do investimento")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Form Fields (same as AddInvestmentView)
                        VStack(spacing: 16) {
                            // Nome
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nome do Investimento")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                TextField("Ex: Tesla Inc.", text: $name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            // Tipo
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tipo")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Picker("Tipo", selection: $selectedType) {
                                    ForEach(InvestmentType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            // Valor
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Valor Investido")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                TextField("R$ 0,00", text: $amount)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                                    .onChange(of: amount) { newValue in
                                        formatCurrencyInput(newValue)
                                    }
                            }
                            
                            // Data
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Data de Início")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .accentColor(isMonochromaticMode ? Color(hex: "#059669") : .blue)
                            }
                            
                            // Notas
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notas (Opcional)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                TextField("Adicione observações...", text: $notes)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(minHeight: 80)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                        
                        // Save Button
                        Button(action: saveInvestment) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Salvar Alterações")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "#059669"), Color(hex: "#10B981"), Color(hex: "#34D399")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .disabled(isLoading || name.isEmpty || amount.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancelar") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
        
        private func formatCurrencyInput(_ input: String) {
            let cleanInput = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            
            if let value = Double(cleanInput) {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = "BRL"
                formatter.locale = Locale(identifier: "pt_BR")
                
                if let formattedString = formatter.string(from: NSNumber(value: value / 100)) {
                    amount = formattedString
                }
            }
        }
        
        private func saveInvestment() {
            guard !name.isEmpty else {
                errorMessage = "Nome é obrigatório"
                return
            }
            
            guard !amount.isEmpty else {
                errorMessage = "Valor é obrigatório"
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            // Converter valor formatado para Double
            let cleanAmount = amount.replacingOccurrences(of: "[^0-9,]", with: "", options: .regularExpression)
            let amountValue = Double(cleanAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            
            let updatedInvestment = Investment(
                id: investment.id,
                name: name,
                type: selectedType,
                amount: amountValue,
                startDate: startDate,
                notes: notes
            )
            
            onSave(updatedInvestment)
            
            // Feedback háptico
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            presentationMode.wrappedValue.dismiss()
        }
    }
    // MARK: - Achievements View
    struct AchievementsView: View {
        @Environment(\.presentationMode) private var presentationMode
        @EnvironmentObject var authViewModel: AuthViewModel
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        
        @State private var achievements: [Achievement] = []
        @State private var selectedCategory: AchievementCategory = .transactions
        @State private var totalPoints: Int = 0
        @State private var unlockedCount: Int = 0
        @State private var showCelebration = false
        @State private var isLoading = true
        
        var filteredAchievements: [Achievement] {
            return achievements.filter { $0.category == selectedCategory }
        }
        
        var userLevel: Int {
            return (totalPoints / 100) + 1
        }
        
        var progressToNextLevel: Double {
            let currentLevelPoints = (userLevel - 1) * 100
            let currentProgress = totalPoints - currentLevelPoints
            return Double(currentProgress) / 100.0
        }
        
        var body: some View {
            VStack(spacing: 0) {
                // Header com botão voltar
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Estatísticas do usuário
                        userStatsView
                        
                        // Filtros por categoria
                        categoryFiltersView
                        
                        // Lista de conquistas
                        achievementsListView
                        
                        // Espaçamento extra
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                loadAchievements()
            }
            .overlay(
                // Animação de celebração
                celebrationOverlay
            )
        }
        
        // MARK: - Header View
        private var headerView: some View {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Conquistas")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Ícone de troféu
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .yellow)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
        }
        
        // MARK: - User Stats View
        private var userStatsView: some View {
            VStack(spacing: 16) {
                // Nível do usuário
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nível \(userLevel)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .primary)
                        
                        Text("\(totalPoints) pontos")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Avatar circular com nível
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: isMonochromaticMode ?
                                                   [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                                    [Color(hex: "#059669"), Color(hex: "#16A34A")]
                                                  ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 60, height: 60)
                        
                        Text("\(userLevel)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Progresso para próximo nível
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progresso para Nível \(userLevel + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int(progressToNextLevel * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.systemGray5))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: isMonochromaticMode ?
                                                       [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                                        [Color(hex: "#059669"), Color(hex: "#16A34A")]
                                                      ),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geometry.size.width * progressToNextLevel, height: 8)
                                .animation(.easeInOut(duration: 0.8), value: progressToNextLevel)
                        }
                    }
                    .frame(height: 8)
                }
                
                // Estatísticas gerais
                HStack(spacing: 20) {
                    StatCard(
                        number: "\(unlockedCount)",
                        label: "Desbloqueadas"
                    )
                    
                    StatCard(
                        number: "\(achievements.count)",
                        label: "Total"
                    )
                    
                    StatCard(
                        number: "\(totalPoints)",
                        label: "Pontos"
                    )
                }
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
        
        // MARK: - Category Filters View
        private var categoryFiltersView: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AchievementCategory.allCases, id: \.self) { category in
                        CategoryFilterButton(
                            category: category,
                            isSelected: selectedCategory == category,
                            isMonochromaticMode: isMonochromaticMode
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        
        // MARK: - Achievements List View
        private var achievementsListView: some View {
            LazyVStack(spacing: 12) {
                ForEach(filteredAchievements) { achievement in
                    AchievementCard(
                        achievement: achievement,
                        isMonochromaticMode: isMonochromaticMode
                    )
                }
            }
        }
        
        // MARK: - Celebration Overlay
        private var celebrationOverlay: some View {
            Group {
                if showCelebration {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.yellow)
                                .scaleEffect(showCelebration ? 1.2 : 0.8)
                                .animation(.easeInOut(duration: 0.6).repeatCount(3, autoreverses: true), value: showCelebration)
                            
                            Text("Parabéns!")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Você desbloqueou uma nova conquista!")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            Button("Continuar") {
                                showCelebration = false
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#059669"))
                            )
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                        .padding(.horizontal, 40)
                    }
                }
            }
        }
        
        // MARK: - Functions
        private func loadAchievements() {
            // Carregar conquistas mock
            achievements = getMockAchievements()
            calculateStats()
            isLoading = false
            
            // Simular desbloqueio de conquista
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // showCelebration = true
            }
        }
        
        private func calculateStats() {
            unlockedCount = achievements.filter { $0.isUnlocked }.count
            totalPoints = achievements.filter { $0.isUnlocked }.reduce(0) { $0 + $1.points }
        }
        
        private func getMockAchievements() -> [Achievement] {
            return [
                // Transações
                Achievement(
                    id: "first_transaction",
                    title: "Primeiro Passo",
                    description: "Registre sua primeira transação",
                    icon: "1.circle.fill",
                    category: .transactions,
                    difficulty: .bronze,
                    points: 10,
                    requirement: 1,
                    currentProgress: 1,
                    isUnlocked: true,
                    unlockedDate: Date(),
                    color: "#CD7F32"
                ),
                Achievement(
                    id: "transaction_master",
                    title: "Mestre das Transações",
                    description: "Registre 100 transações",
                    icon: "100.circle.fill",
                    category: .transactions,
                    difficulty: .gold,
                    points: 50,
                    requirement: 100,
                    currentProgress: 75,
                    isUnlocked: false,
                    unlockedDate: nil,
                    color: "#FFD700"
                ),
                Achievement(
                    id: "weekly_tracker",
                    title: "Rastreador Semanal",
                    description: "Registre transações por 7 dias consecutivos",
                    icon: "calendar.badge.checkmark",
                    category: .streaks,
                    difficulty: .silver,
                    points: 25,
                    requirement: 7,
                    currentProgress: 5,
                    isUnlocked: false,
                    unlockedDate: nil,
                    color: "#C0C0C0"
                ),
                // Metas
                Achievement(
                    id: "first_goal",
                    title: "Objetivo Definido",
                    description: "Crie sua primeira meta",
                    icon: "target",
                    category: .goals,
                    difficulty: .bronze,
                    points: 10,
                    requirement: 1,
                    currentProgress: 1,
                    isUnlocked: true,
                    unlockedDate: Date().addingTimeInterval(-86400 * 3),
                    color: "#CD7F32"
                ),
                Achievement(
                    id: "goal_achiever",
                    title: "Realizador de Sonhos",
                    description: "Complete 5 metas",
                    icon: "checkmark.seal.fill",
                    category: .goals,
                    difficulty: .gold,
                    points: 50,
                    requirement: 5,
                    currentProgress: 2,
                    isUnlocked: false,
                    unlockedDate: nil,
                    color: "#FFD700"
                ),
                // Marcos
                Achievement(
                    id: "first_month",
                    title: "Primeiro Mês",
                    description: "Use o app por 30 dias",
                    icon: "calendar.circle.fill",
                    category: .milestones,
                    difficulty: .silver,
                    points: 25,
                    requirement: 30,
                    currentProgress: 18,
                    isUnlocked: false,
                    unlockedDate: nil,
                    color: "#C0C0C0"
                ),
                Achievement(
                    id: "year_veteran",
                    title: "Veterano de Um Ano",
                    description: "Use o app por 365 dias",
                    icon: "crown.fill",
                    category: .milestones,
                    difficulty: .diamond,
                    points: 100,
                    requirement: 365,
                    currentProgress: 18,
                    isUnlocked: false,
                    unlockedDate: nil,
                    color: "#B9F2FF"
                )
            ]
        }
    }
    
    // MARK: - AI Assistant View (Temporary)
    struct AIAssistantView: View {
        @Environment(\.presentationMode) var presentationMode
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        
        var body: some View {
            VStack {
                // Header com botão voltar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("AI Assistant")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Espaçador para centralizar o título
                    Color.clear
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                Text("Funcionalidade em desenvolvimento")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Export View (Temporary)
    struct ExportView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var authViewModel: AuthViewModel
        @EnvironmentObject var globalDateManager: GlobalDateManager
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        
        var body: some View {
            VStack {
                // Header com botão voltar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Exportar Dados")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Espaçador para centralizar o título
                    Color.clear
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                Text("Funcionalidade em desenvolvimento")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
    // MARK: - Privacy Policy View
    struct PrivacyPolicyView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var authViewModel: AuthViewModel
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        @State private var selectedSection: PrivacySection = .overview
        
        enum PrivacySection: String, CaseIterable {
            case overview = "Visão Geral"
            case dataCollection = "Coleta de Dados"
            case dataUsage = "Uso dos Dados"
            case security = "Segurança"
            case rights = "Seus Direitos"
            
            var icon: String {
                switch self {
                case .overview: return "eye.fill"
                case .dataCollection: return "folder.fill"
                case .dataUsage: return "gear.fill"
                case .security: return "lock.shield.fill"
                case .rights: return "person.crop.circle.fill"
                }
            }
        }
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    // Header com botão voltar
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Text("Política de Privacidade")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Espaçador para centralizar o título
                        Color.clear
                            .frame(width: 20, height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Seções
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PrivacySection.allCases, id: \.self) { section in
                                Button(action: { selectedSection = section }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: section.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(selectedSection == section ? Color(hex: "#059669") : .secondary)
                                        Text(section.rawValue)
                                            .font(.system(size: 13, weight: selectedSection == section ? .semibold : .medium))
                                            .foregroundColor(selectedSection == section ? .primary : .secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(selectedSection == section ? Color(UIColor.systemBackground) : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    }
                    
                    Divider()
                    
                    // Conteúdo
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: selectedSection.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#059669"))
                                Text(selectedSection.rawValue)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            Text("Última atualização: Janeiro 2024")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            // Conteúdo da seção
                            Group {
                                switch selectedSection {
                                case .overview: overviewContent
                                case .dataCollection: dataCollectionContent
                                case .dataUsage: dataUsageContent
                                case .security: securityContent
                                case .rights: rightsContent
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        
        // MARK: - Content Sections
        private var overviewContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bem-vindo à Política de Privacidade do PINEE!")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("No PINEE, sua privacidade é fundamental para nós. Esta política explica como coletamos, usamos e protegemos suas informações pessoais quando você utiliza nosso aplicativo de gestão financeira.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔒 Compromisso com a Privacidade")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("• Suas informações financeiras são suas e apenas suas")
                    Text("• Utilizamos criptografia de ponta para proteger seus dados")
                    Text("• Nunca vendemos ou compartilhamos seus dados pessoais")
                    Text("• Você tem controle total sobre suas informações")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        
        private var dataCollectionContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Quais Dados Coletamos")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text("Informações de Conta")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text("Nome, email e informações básicas de perfil para criar e gerenciar sua conta.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.green)
                            Text("Dados Financeiros")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text("Transações, categorias, metas e investimentos que você registra no app.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
        
        private var dataUsageContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Como Usamos Seus Dados")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fornecer Serviços")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Processar transações, gerar relatórios e personalizar sua experiência.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Melhorar o App")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Analisar padrões de uso para desenvolver novas funcionalidades.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Segurança")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Detectar e prevenir atividades fraudulentas e proteger sua conta.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        
        private var securityContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Segurança dos Dados")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔐 Medidas de Segurança")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("• Criptografia de ponta a ponta para todos os dados")
                    Text("• Servidores seguros com certificados SSL")
                    Text("• Acesso restrito apenas a pessoal autorizado")
                    Text("• Backup regular e seguro dos dados")
                    Text("• Monitoramento contínuo de segurança")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        
        private var rightsContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Seus Direitos")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("👤 Controle Total")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("• Acessar seus dados a qualquer momento")
                    Text("• Corrigir informações incorretas")
                    Text("• Solicitar exclusão de dados")
                    Text("• Exportar seus dados")
                    Text("• Revogar consentimentos")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    // MARK: - About App View
    struct AboutAppView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var authViewModel: AuthViewModel
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        @State private var animateLogo = false
        @State private var showFeatures = false
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header com botão voltar
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Text("Sobre o App")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Espaçador para centralizar o título
                            Color.clear
                                .frame(width: 20, height: 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Header com Logo e Nome
                        VStack(spacing: 20) {
                            // Logo animado
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "#059669"), Color(hex: "#10B981"), Color(hex: "#34D399")]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(animateLogo ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateLogo)
                                
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(animateLogo ? 360 : 0))
                                    .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: animateLogo)
                            }
                            
                            VStack(spacing: 8) {
                                Text("PINEE")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("Seu companheiro financeiro")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("Versão 1.0.0")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        
                        // Informações do App
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sobre o PINEE")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("O PINEE é um aplicativo de gestão financeira pessoal desenvolvido para ajudar você a controlar suas finanças de forma simples e eficiente. Com interface intuitiva e funcionalidades poderosas, você pode acompanhar suas receitas, despesas, investimentos e metas financeiras.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                            }
                            
                            // Features
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Principais Funcionalidades")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 12) {
                                    FeatureCard(
                                        icon: "creditcard.fill",
                                        title: "Gestão de Transações",
                                        description: "Registre e categorize suas receitas e despesas"
                                    )
                                    
                                    FeatureCard(
                                        icon: "target",
                                        title: "Metas Financeiras",
                                        description: "Defina e acompanhe suas metas de economia"
                                    )
                                    
                                    FeatureCard(
                                        icon: "chart.line.uptrend.xyaxis",
                                        title: "Investimentos",
                                        description: "Acompanhe seus investimentos e cotações"
                                    )
                                    
                                    FeatureCard(
                                        icon: "chart.bar.fill",
                                        title: "Relatórios",
                                        description: "Visualize relatórios detalhados de suas finanças"
                                    )
                                }
                            }
                            
                            // Estatísticas
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Estatísticas")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 20) {
                                    StatCard(
                                        number: "1.0.0",
                                        label: "Versão Atual"
                                    )
                                    
                                    StatCard(
                                        number: "2024",
                                        label: "Ano de Lançamento"
                                    )
                                    
                                    StatCard(
                                        number: "iOS",
                                        label: "Plataforma"
                                    )
                                }
                            }
                            
                            // Informações de Contato
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Desenvolvido com ❤️")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("PINEE foi desenvolvido para simplificar sua vida financeira. Se você tem sugestões ou encontrou algum problema, entre em contato conosco.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                animateLogo = true
            }
        }
    }
    
    // MARK: - Feature Card
    struct FeatureCard: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#059669"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "#059669").opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Stat Card
    struct StatCard: View {
        let number: String
        let label: String
        
        var body: some View {
            VStack(spacing: 8) {
                Text(number)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "#059669"))
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Feedback View
    struct LegacyFeedbackView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var authViewModel: AuthViewModel
        @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
        
        @State private var feedbackText = ""
        @State private var isSubmittingFeedback = false
        @State private var feedbackSubmitted = false
        @State private var selectedCategory: FeedbackCategory = .suggestion
        @State private var showSuccessMessage = false
        
        enum FeedbackCategory: String, CaseIterable {
            case suggestion = "Sugestão"
            case bug = "Bug"
            case feature = "Nova Funcionalidade"
            case general = "Geral"
            
            var icon: String {
                switch self {
                case .suggestion: return "lightbulb.fill"
                case .bug: return "ant.fill"
                case .feature: return "star.fill"
                case .general: return "message.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .suggestion: return .yellow
                case .bug: return .red
                case .feature: return .blue
                case .general: return .gray
                }
            }
        }
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header com botão voltar
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Text("Feedback")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Espaçador para centralizar o título
                            Color.clear
                                .frame(width: 20, height: 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Header
                        VStack(spacing: 12) {
                            Text("Envie seu Feedback")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Sua opinião é muito importante para nós! Ajude-nos a melhorar o PINEE compartilhando suas sugestões, reportando bugs ou solicitando novas funcionalidades.")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 20)
                        
                        // Categoria
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Categoria")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 16))
                                                .foregroundColor(selectedCategory == category ? .white : category.color)
                                            
                                            Text(category.rawValue)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedCategory == category ? category.color : Color(UIColor.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedCategory == category ? Color.clear : category.color.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Texto do Feedback
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Seu Feedback")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            TextField("Descreva sua sugestão, bug ou solicitação...", text: $feedbackText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(minHeight: 120)
                                .padding(.horizontal, 20)
                        }
                        
                        // Botão de Envio
                        Button(action: submitFeedback) {
                            HStack {
                                if isSubmittingFeedback {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(isSubmittingFeedback ? "Enviando..." : "Enviar Feedback")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "#059669"), Color(hex: "#10B981"), Color(hex: "#34D399")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .disabled(isSubmittingFeedback || feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, 20)
                        
                        // Mensagem de Sucesso
                        if showSuccessMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                
                                Text("Feedback Enviado!")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Obrigado pelo seu feedback! Vamos analisar sua mensagem e trabalhar para melhorar o PINEE.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                        
                        // Informações de Contato
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Outras Formas de Contato")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "#059669"))
                                        .frame(width: 40, height: 40)
                                        .background(Color(hex: "#059669").opacity(0.1))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Email")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("contato@pinee.app")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.orange)
                                        .frame(width: 40, height: 40)
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Avalie na App Store")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Sua avaliação nos ajuda muito!")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        
        private func submitFeedback() {
            guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            isSubmittingFeedback = true
            
            // Simular envio do feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isSubmittingFeedback = false
                self.showSuccessMessage = true
                self.feedbackText = ""
                
                // Feedback háptico
                FeedbackService.shared.successFeedback()
                
                // Esconder mensagem de sucesso após 5 segundos
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.showSuccessMessage = false
                }
            }
        }
    }
    
    
    // MARK: - Investment Model
    struct Investment: Identifiable, Codable {
        var id: String?
        let name: String
        let type: InvestmentType
        let amount: Double
        let startDate: Date
        let notes: String
        
        init(id: String? = nil, name: String, type: InvestmentType, amount: Double, startDate: Date, notes: String) {
            self.id = id
            self.name = name
            self.type = type
            self.amount = amount
            self.startDate = startDate
            self.notes = notes
        }
    }
    
    // MARK: - Investment Type
    enum InvestmentType: String, CaseIterable, Codable {
        case stocks = "Ações"
        case bonds = "Títulos"
        case realEstate = "Imóveis"
        case crypto = "Criptomoedas"
        case mutualFunds = "Fundos"
        case other = "Outros"
    }
    // MARK: - Achievements System Models
    struct Achievement: Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let icon: String
        let category: AchievementCategory
        let difficulty: AchievementDifficulty
        let points: Int
        let requirement: Int
        let currentProgress: Int
        let isUnlocked: Bool
        let unlockedDate: Date?
        let color: String
        
        var progress: Double {
            return min(Double(currentProgress) / Double(requirement), 1.0)
        }
        
        var progressText: String {
            return "\(currentProgress)/\(requirement)"
        }
    }
    
    enum AchievementCategory: String, CaseIterable, Codable {
        case transactions = "Transações"
        case goals = "Metas"
        case streaks = "Sequências"
        case milestones = "Marcos"
        case social = "Social"
        
        var icon: String {
            switch self {
            case .transactions: return "arrow.left.arrow.right"
            case .goals: return "target"
            case .streaks: return "flame.fill"
            case .milestones: return "mountain.2.fill"
            case .social: return "person.3.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .transactions: return .blue
            case .goals: return .orange
            case .streaks: return .red
            case .milestones: return .purple
            case .social: return .pink
            }
        }
    }
    
    enum AchievementDifficulty: String, CaseIterable, Codable {
        case bronze = "Bronze"
        case silver = "Prata"
        case gold = "Ouro"
        case diamond = "Diamante"
        
        var color: Color {
            switch self {
            case .bronze: return Color(hex: "#CD7F32")
            case .silver: return Color(hex: "#C0C0C0")
            case .gold: return Color(hex: "#FFD700")
            case .diamond: return Color(hex: "#B9F2FF")
            }
        }
        
        var points: Int {
            switch self {
            case .bronze: return 10
            case .silver: return 25
            case .gold: return 50
            case .diamond: return 100
            }
        }
    }
    
    // MARK: - Achievement Card
    struct AchievementCard: View {
        let achievement: Achievement
        let isMonochromaticMode: Bool
        
        var body: some View {
            HStack(spacing: 16) {
                // Ícone da conquista
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ?
                              Color(hex: achievement.color) :
                                Color(UIColor.systemGray4)
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(achievement.isUnlocked ? .white : .gray)
                }
                .opacity(achievement.isUnlocked ? 1.0 : 0.6)
                
                // Informações da conquista
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(achievement.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                        
                        Spacer()
                        
                        // Badge de dificuldade
                        Text(achievement.difficulty.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(achievement.difficulty.color)
                            .cornerRadius(10)
                    }
                    
                    Text(achievement.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Progresso ou data de desbloqueio
                    if !achievement.isUnlocked {
                        progressView
                    } else {
                        unlockedView
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(achievement.isUnlocked ?
                            Color(hex: achievement.color).opacity(0.3) :
                                Color.clear, lineWidth: 2)
            )
        }
        
        private var progressView: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progresso")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(achievement.progressText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: achievement.color))
                            .frame(width: geometry.size.width * achievement.progress, height: 6)
                            .animation(.easeInOut(duration: 0.8), value: achievement.progress)
                    }
                }
                .frame(height: 6)
            }
        }
        
        private var unlockedView: some View {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                
                if let unlockedDate = achievement.unlockedDate {
                    Text("Desbloqueado em \(formatDate(unlockedDate))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("+\(achievement.points) pts")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
            }
        }
        
        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Category Filter Button
    struct CategoryFilterButton: View {
        let category: AchievementCategory
        let isSelected: Bool
        let isMonochromaticMode: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(isSelected ? .white : (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : category.color))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ?
                              (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : category.color) :
                                Color(UIColor.secondarySystemBackground)
                             )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : category.color, lineWidth: isSelected ? 0 : 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Preview
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }