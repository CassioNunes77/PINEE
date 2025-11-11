import Foundation
import SwiftUI
import AudioToolbox
// import FirebaseFirestore

// MARK: - Transactions ViewModel
class TransactionsViewModel: ObservableObject {
    @Published var transactions: [TransactionModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var receitaProjetada: Double = 0
    @Published var despesaProjetada: Double = 0
    @Published var saldoProjetado: Double = 0
    
    private var userId: String?
    private var idToken: String?
    private let firebaseService = FirebaseRESTService.shared
    
    // MARK: - Initialization
    init() {
        // Inicialização vazia - userId será definido quando necessário
    }
    
    // MARK: - Public Methods
    func setUserId(_ userId: String) {
        self.userId = userId
    }
    
    func setIdToken(_ idToken: String) {
        self.idToken = idToken
    }
    
    func loadTransactions(startDate: String, endDate: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let userId = userId, let idToken = idToken else {
            await MainActor.run {
                self.errorMessage = "Usuário ou token não identificado"
                self.isLoading = false
            }
            return
        }
        
        let cacheKey = "transactions-\(userId)-\(startDate)-\(endDate)"
        
        if let cached: [TransactionModel] = LocalCacheManager.shared.load([TransactionModel].self, for: cacheKey, maxAge: 60 * 5) {
            await MainActor.run {
                self.transactions = cached
                self.calculateProjections()
                self.isLoading = false
            }
            print("📦 Transações carregadas do cache para período \(startDate) - \(endDate)")
        }
        
        do {
            print("🔄 Carregando transações do Firebase para userId: \(userId)")
            print("📅 Período: \(startDate) até \(endDate)")
            
            // Buscar transações reais do Firebase
            let firebaseTransactions = try await firebaseService.getTransactions(
                userId: userId,
                startDate: startDate,
                endDate: endDate,
                idToken: idToken
            )
            
            print("✅ Transações carregadas do Firebase: \(firebaseTransactions.count) transações")
            LocalCacheManager.shared.save(firebaseTransactions, for: cacheKey)
            
            await MainActor.run {
                self.transactions = firebaseTransactions
                self.calculateProjections()
                self.isLoading = false
            }
        } catch {
            print("❌ Erro ao carregar transações do Firebase: \(error.localizedDescription)")
            
            await MainActor.run {
                self.errorMessage = "Erro ao carregar transações: \(error.localizedDescription)"
                self.isLoading = false
                
                // Em caso de erro, limpar transações e mostrar estado vazio
                print("🔄 Limpando transações devido ao erro")
                self.transactions = []
                self.calculateProjections()
            }
        }
    }
    
    func saveTransaction(_ transaction: TransactionModel) async -> Bool {
        guard let userId = userId, let idToken = idToken else {
            await MainActor.run {
                self.errorMessage = "Usuário ou token não identificado"
            }
            return false
        }
        
        do {
            try await firebaseService.saveTransaction(transaction, userId: userId, idToken: idToken)
            
            // Recarregar transações após salvar
            let currentRange = DateRange(start: Date(), end: Date(), displayText: "Período atual")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDate = dateFormatter.string(from: currentRange.start)
            let endDate = dateFormatter.string(from: currentRange.end)
            
            await loadTransactions(startDate: startDate, endDate: endDate)
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Erro ao salvar transação: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func updateTransaction(_ transaction: TransactionModel) async -> Bool {
        guard let userId = userId, let idToken = idToken else {
            await MainActor.run {
                self.errorMessage = "Usuário ou token não identificado"
            }
            return false
        }
        
        do {
            _ = try await firebaseService.updateTransaction(transaction, userId: userId, idToken: idToken)
            
            // Atualizar localmente a transação na lista em vez de recarregar tudo
            await MainActor.run {
                if let index = self.transactions.firstIndex(where: { $0.id == transaction.id }) {
                    self.transactions[index] = transaction
                    self.calculateProjections()
                    print("✅ Transação atualizada localmente: \(transaction.id ?? "sem id")")
                } else {
                    print("⚠️ Transação não encontrada na lista local para atualizar")
                }
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Erro ao atualizar transação: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func deleteTransaction(id: String) async -> Bool {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let userId = userId else {
            await MainActor.run {
                self.errorMessage = "Usuário não identificado"
                self.isLoading = false
            }
            return false
        }
        
        do {
            // Excluir do Firebase
            try await firebaseService.deleteTransaction(id: id, userId: userId)
            
            // Remover transação da lista local após sucesso
            await MainActor.run {
                self.transactions.removeAll { $0.id == id }
                self.calculateProjections()
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Private Methods
    private func calculateProjections() {
        var receitaTotal: Double = 0
        var despesaTotal: Double = 0
        
        for transaction in transactions {
            if (transaction.type ?? "expense") == "income" {
                receitaTotal += transaction.amount
            } else if (transaction.type ?? "expense") == "expense" {
                despesaTotal += transaction.amount
            }
        }
        
        receitaProjetada = receitaTotal
        despesaProjetada = despesaTotal
        saldoProjetado = receitaTotal - despesaTotal
    }
    
    // MARK: - Computed Properties
    var filteredTransactions: [TransactionModel] {
        return transactions.sorted { $0.createdAt > $1.createdAt }
    }
    
    var hasTransactions: Bool {
        return !transactions.isEmpty
    }
}

// MARK: - Transactions View
struct TransactionsView: View {
    // MARK: - ViewModels
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var transactionToEdit: TransactionModel?
    @State private var statusFilter: String = "all" // "all", "confirmed", "pending"
    @State private var typeFilter: String = "all" // "all", "income", "expense"
    @State private var showStatusNotification = false
    @State private var statusNotificationMessage = ""
    @State private var isSuccessNotification = true
    @State private var categoryFilter: String = "all" // Adicionado para filtro de categoria
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: TransactionModel?
    @State private var availableCategories: [Category] = []
    @State private var showCategoryPicker = false
    @State private var showPeriodFilters: Bool = false
    
    @State private var offset: CGFloat = 0
    @State private var isShowingActions = false
    @State private var transactionsAppeared = false
    
    private static func formatMonthYear(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date).capitalized
    }
    
    // MARK: - Properties
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var globalDateManager: GlobalDateManager
    // @StateObject private var categoryPickerVM = CategoryPickerViewModel()
    
    // MARK: - Computed Properties
    private var filteredTransactions: [TransactionModel] {
        var filtered = transactionsViewModel.filteredTransactions
        
        // Filtro por tipo
        if typeFilter != "all" {
            filtered = filtered.filter { $0.type == typeFilter }
        }
        
        // Filtro por status
        if statusFilter != "all" {
            filtered = filtered.filter { transaction in
                if statusFilter == "confirmed" {
                    return transaction.status == "paid" || transaction.status == "received"
                } else if statusFilter == "pending" {
                    return transaction.status == "unpaid" || transaction.status == "pending"
                }
                return true
            }
        }
        
        // Filtro por categoria
        if categoryFilter != "all" {
            filtered = filtered.filter { $0.category == categoryFilter }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filtro de período (fixo no topo)
            filterView
                .background(Color(UIColor.systemBackground))
                .padding(.top, 8)
            
            Divider()
                .opacity(0.3)
            
            // Conteúdo rolável
            Group {
                if transactionsViewModel.isLoading {
                    loadingView
                } else if !transactionsViewModel.hasTransactions {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Cards de projeção
                            projectionCardsView
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            
                            // Filtros de status e tipo
                            filtersView
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            
                            Divider()
                                .opacity(0.3)
                                .padding(.horizontal, 16)
                            
                            // Lista de transações
                            VStack(spacing: 8) {
                                ForEach(filteredTransactions) { transaction in
                                    SwipeableTransactionRow(
                                        transaction: transaction,
                                        categoryDisplayName: displayName(for: transaction.category),
                                        categoryIconName: iconName(for: transaction.category),
                                        categoryColorName: colorName(for: transaction.category),
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
                            .padding(.vertical, 12)
                            
                            // Espaçamento extra para evitar sobreposição com menu inferior
                            Spacer(minLength: 120)
                        }
                        .opacity(transactionsAppeared ? 1 : 0)
                        .offset(y: transactionsAppeared ? 0 : 20)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(
            // Notificação de status
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
        .onAppear {
            // Configurar userId e token no ViewModel
            if let userId = authViewModel.user?.id {
                transactionsViewModel.setUserId(userId)
            }
            if let idToken = authViewModel.user?.idToken {
                transactionsViewModel.setIdToken(idToken)
            }
            
            // Carregar categorias
            loadCategories()
            
            // Carregar transações do Firebase
            Task {
                let currentRange = globalDateManager.getCurrentDateRange()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let startDate = dateFormatter.string(from: currentRange.start)
                let endDate = dateFormatter.string(from: currentRange.end)
                
                await transactionsViewModel.loadTransactions(startDate: startDate, endDate: endDate)
            }
            
            // Animar entrada
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                transactionsAppeared = true
            }
        }
        .onDisappear {
            // Resetar animação ao sair
            transactionsAppeared = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TransactionSaved"))) { _ in
            // Atualizar transações quando uma nova for salva
            print("🔄 Atualizando transações após salvar...")
            loadTransactions()
        }
        .sheet(item: $transactionToEdit, onDismiss: {
            // Atualizar dados após edição e limpar transactionToEdit
            loadTransactions()
            transactionToEdit = nil
        }) { transaction in
            AddTransactionView(transactionToEdit: transaction)
                .environmentObject(authViewModel)
                .environmentObject(globalDateManager)
        }
        .sheet(item: $transactionToInvest, onDismiss: {
            // Atualizar dados após transferência e limpar transactionToInvest
            loadTransactions()
            transactionToInvest = nil
        }) { transaction in
                TransferInvestmentView(sourceTransaction: transaction)
                    .environmentObject(authViewModel)
                    .environmentObject(globalDateManager)
        }
        .sheet(isPresented: $showTransferIncome, onDismiss: {
            // Atualizar dados após transferência e limpar transactionToInvest
            loadTransactions()
            transactionToInvest = nil
        }) {
            if let transaction = transactionToInvest {
                TransferIncomeView(sourceTransaction: transaction)
                    .environmentObject(authViewModel)
                    .environmentObject(globalDateManager)
            }
        }
    }

    private var filterView: some View {
        VStack(spacing: 12) {
            // Navegação de período com data
            HStack(spacing: 16) {
                Button(action: previousMonth) {
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
                
                Button(action: nextMonth) {
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
                            loadTransactions()
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
                            loadTransactions()
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
                            loadTransactions()
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
        .padding(.vertical, 12)
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
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
            
            Text("Carregando transações...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Nenhuma transação encontrada")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Neste período não há transações registradas")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func previousMonth() {
        // Feedback tátil
        FeedbackService.shared.triggerLight()
        
        print("🔄 Botão anterior clicado")
        globalDateManager.previousPeriod()
        print("📅 Período atual: \(globalDateManager.getCurrentDateRange().displayText)")
        loadTransactions()
    }
    
    private func nextMonth() {
        // Feedback tátil
        FeedbackService.shared.triggerLight()
        
        print("🔄 Botão próximo clicado")
        globalDateManager.nextPeriod()
        print("📅 Período atual: \(globalDateManager.getCurrentDateRange().displayText)")
        loadTransactions()
    }
    
    private func loadTransactions() {
        print("🔄 Carregando transações...")
        Task {
            let currentRange = globalDateManager.getCurrentDateRange()
            print("📅 Período selecionado: \(currentRange.displayText)")
            print("📅 Data início: \(currentRange.start)")
            print("📅 Data fim: \(currentRange.end)")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDate = dateFormatter.string(from: currentRange.start)
            let endDate = dateFormatter.string(from: currentRange.end)
            
            print("📅 Período formatado: \(startDate) até \(endDate)")
            
            await transactionsViewModel.loadTransactions(startDate: startDate, endDate: endDate)
        }
    }
    
    private func loadCategories() {
        let defaults = CategoryDataProvider.visibleDefaultCategories()
        availableCategories = defaults
        print("✅ Categorias padrão carregadas: \(defaults.count)")

        guard let userId = authViewModel.user?.id, let idToken = authViewModel.user?.idToken else { return }

        Task {
            do {
                let userCategories = try await authViewModel.firebaseService.getCategories(userId: userId, idToken: idToken)
                let visibleUserCategories = userCategories.filter { !CategoryDataProvider.hiddenCategoryIDs.contains($0.identifiedId) }
                var seen = Set<String>()
                var ordered: [Category] = []
                for category in defaults {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                for category in visibleUserCategories {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                let finalCategories = ordered
                await MainActor.run {
                    self.availableCategories = finalCategories
                    print("✅ Categorias totais carregadas: \(self.availableCategories.count)")
                }
            } catch {
                print("❌ Erro ao carregar categorias do usuário: \(error.localizedDescription)")
            }
        }
    }

    private func displayName(for categoryId: String) -> String {
        if categoryId.lowercased() == "general" { return "Sem Categoria" }
        if let legacy = CategoryDataProvider.legacyDisplayNames[categoryId.lowercased()] {
            return legacy
        }
        if let match = categoryMatching(categoryId) {
            return match.name
        }
        return categoryId
    }
    
    private func iconName(for categoryId: String) -> String? {
        if categoryId.lowercased() == "general" {
            return "questionmark.folder"
        }
        if let match = categoryMatching(categoryId) {
            return match.icon
        }
        return nil
    }
    
    private func colorName(for categoryId: String) -> String? {
        if categoryId.lowercased() == "general" {
            return "gray"
        }
        return categoryMatching(categoryId)?.color
    }
    
    private func categoryMatching(_ categoryId: String) -> Category? {
        if let match = availableCategories.first(where: { $0.identifiedId == categoryId || $0.name == categoryId }) {
            return match
        }
        if let userId = authViewModel.user?.id,
           let cached: [Category] = LocalCacheManager.shared.load([Category].self, for: "categories-\(userId)") {
            if let cachedMatch = cached.first(where: { $0.identifiedId == categoryId || $0.name == categoryId }) {
                return cachedMatch
            }
        }
        if let systemMatch = CategoryDataProvider.defaultCategories(includeHidden: true).first(where: { $0.identifiedId == categoryId || $0.name == categoryId }) {
            return systemMatch
        }
        return nil
    }

    private func editTransaction(_ transaction: TransactionModel) {
        print("🔧 editTransaction chamada - transaction: \(transaction.title ?? "nil")")
        print("🔧 editTransaction chamada - amount: \(transaction.amount)")
        print("🔧 editTransaction chamada - id: \(transaction.id ?? "nil")")
        print("🔧 editTransaction chamada - type: \(transaction.type ?? "nil")")
        
        // Definir transactionToEdit diretamente - o sheet será apresentado automaticamente
        transactionToEdit = transaction
        print("🔧 editTransaction - transactionToEdit definido: \(transactionToEdit?.title ?? "nil")")
        print("🔧 editTransaction - transactionToEdit type: \(transactionToEdit?.type ?? "nil")")
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
                    // Recarregar transações
                    loadTransactions()
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
        
        // Limpar variáveis
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
        // db.collection("transactions").document(id).updateData([
        //     "status": newStatus
        // ]) { error in
        //     if let error = error {
        //         print("❌ Erro: \(error.localizedDescription)")
        //         DispatchQueue.main.async {
        //             self.statusNotificationMessage = "Erro ao atualizar"
        //             self.showStatusNotification = true
        //         }
        //     } else {
        //         print("✅ Status atualizado com sucesso")
        //         DispatchQueue.main.async {
        //             if (transaction.type ?? "") == "investment" {
        //                 if newStatus == "invested" {
        //                     self.statusNotificationMessage = "Investimento Aportado"
        //                 } else {
        //                     self.statusNotificationMessage = "Investimento não Aportado"
        //                 }
        //             } else if (transaction.type ?? "") == "income" {
        //                 if newStatus == "received" {
        //                     self.statusNotificationMessage = "Receita Marcada como Recebida"
        //                 } else {
        //                     self.statusNotificationMessage = "Receita Marcada como Pendente"
        //                 }
        //             } else {
        //                 self.statusNotificationMessage = "Status atualizado"
        //             }
        //             self.showStatusNotification = true
        //             DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        //                 self.showStatusNotification = false
        //             }
        //         }
        //     }
        // }
        
        // Atualizar status usando FirebaseRESTService
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
                        
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TransactionSaved"),
                            object: updatedTransaction
                        )
                    } else {
                        statusNotificationMessage = "Erro ao atualizar status"
                        isSuccessNotification = false
                        showStatusNotification = true
                    }
                }
            }
        }
    }
    
    @State private var transactionToInvest: TransactionModel? = nil
    @State private var showTransferIncome = false
    
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

    // MARK: - Views
    private var projectionCardsView: some View {
        VStack(spacing: 12) {
            // Cards de receita e despesa projetada
            HStack(spacing: 12) {
                projectionCard(
                    title: "Receita Projetada",
                    value: formatCurrency(transactionsViewModel.receitaProjetada),
                    subtitle: "Total de receitas",
                    icon: "arrow.up",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.darkGreen, MonochromaticColorManager.primaryGreen] :
                        [Color(hex: "#22C55E"), Color(hex: "#16A34A")]
                )

                projectionCard(
                    title: "Despesa Projetada",
                    value: formatCurrency(transactionsViewModel.despesaProjetada),
                    subtitle: "Total de despesas",
                    icon: "arrow.down",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.darkGray, MonochromaticColorManager.primaryGray] :
                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
                )
            }

            // Saldo projetado
            saldoProjetadoCard
        }
    }
    
    private func projectionCard(title: String, value: String, subtitle: String, icon: String, gradientColors: [Color]) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))

                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)

            Image(systemName: icon)
                .font(.system(size: 18))
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

    private var saldoProjetadoCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo Projetado")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                Text(formatCurrency(transactionsViewModel.saldoProjetado))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: isMonochromaticMode ? 
                    [MonochromaticColorManager.lightGreen, MonochromaticColorManager.primaryGreen] :
                    [Color(hex: "#7C3AED"), Color(hex: "#6D28D9")]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    private var filtersView: some View {
        HStack(spacing: 12) {
            // Botão de Status - Alterna entre: Status → Confirmados → Pendentes → Status
            Button(action: {
                switch statusFilter {
                case "all":
                    statusFilter = "confirmed"
                case "confirmed":
                    statusFilter = "pending"
                case "pending":
                    statusFilter = "all"
                default:
                    statusFilter = "all"
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: getStatusIcon())
                        .font(.system(size: 12, weight: .medium))
                    Text(getStatusText())
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(getStatusColor())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(getStatusBackground())
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(getStatusBorderColor(), lineWidth: 1)
                )
            }
            
            // Botão de Tipo - Alterna entre: Tipo → Receitas → Despesas → Investimentos → Tipo
            Button(action: {
                switch typeFilter {
                case "all":
                    typeFilter = "income"
                case "income":
                    typeFilter = "expense"
                case "expense":
                    typeFilter = "investment"
                case "investment":
                    typeFilter = "all"
                default:
                    typeFilter = "all"
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: getTypeIcon())
                        .font(.system(size: 12, weight: .medium))
                    Text(getTypeText())
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(getTypeColor())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(getTypeBackground())
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(getTypeBorderColor(), lineWidth: 1)
                )
            }
            // Botão de Categoria - agora é um Menu com todas as categorias
            Menu {
                Button("Todas") {
                    categoryFilter = "all"
                }
                
                // Categorias disponíveis
                ForEach(availableCategories, id: \.id) { category in
                    Button(action: {
                        categoryFilter = category.name
                    }) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(getCategoryColorFromString(category.color))
                            Text(category.name)
                            if categoryFilter == category.name {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                // Opção "Sem Categoria"
                Button(action: {
                    categoryFilter = "Sem Categoria"
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.gray)
                        Text("Sem Categoria")
                        if categoryFilter == "Sem Categoria" {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: getCategoryIcon())
                        .font(.system(size: 12, weight: .medium))
                    Text(getCategoryText())
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(getCategoryColor())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(getCategoryBackground())
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(getCategoryBorderColor(), lineWidth: 1)
                )
            }
            Spacer()
        }
    }
    
    // MARK: - Helper Functions for Status Filter
    private func getStatusText() -> String {
        switch statusFilter {
        case "all":
            return "Status"
        case "confirmed":
            return "Confirmados"
        case "pending":
            return "Pendentes"
        default:
            return "Status"
        }
    }
    
    private func getStatusIcon() -> String {
        switch statusFilter {
        case "all":
            return "line.3.horizontal.decrease.circle"
        case "confirmed":
            return "checkmark.circle.fill"
        case "pending":
            return "clock.circle.fill"
        default:
            return "line.3.horizontal.decrease.circle"
        }
    }
    
    private func getStatusColor() -> Color {
        switch statusFilter {
        case "all":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .primary
        case "confirmed":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green
        case "pending":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .orange
        default:
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .primary
        }
    }
    
    private func getStatusBackground() -> Color {
        switch statusFilter {
        case "all":
            return Color(UIColor.secondarySystemBackground)
        case "confirmed":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.green.opacity(0.1)
        case "pending":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.orange.opacity(0.1)
        default:
            return Color(UIColor.secondarySystemBackground)
        }
    }
    
    private func getStatusBorderColor() -> Color {
        switch statusFilter {
        case "all":
            return Color(UIColor.separator)
        case "confirmed":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.green.opacity(0.3)
        case "pending":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.orange.opacity(0.3)
        default:
            return Color(UIColor.separator)
        }
    }
    
    // MARK: - Helper Functions for Type Filter
    private func getTypeText() -> String {
        switch typeFilter {
        case "all":
            return "Tipo"
        case "income":
            return "Receitas"
        case "expense":
            return "Despesas"
        case "investment":
            return "Investimentos"
        default:
            return "Tipo"
        }
    }
    
    private func getTypeIcon() -> String {
        switch typeFilter {
        case "all":
            return "list.bullet.circle"
        case "income":
            return "arrow.up.circle.fill"
        case "expense":
            return "arrow.down.circle.fill"
        case "investment":
            return "chart.line.uptrend.xyaxis"
        default:
            return "list.bullet.circle"
        }
    }
    
    private func getTypeColor() -> Color {
        switch typeFilter {
        case "all":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .primary
        case "income":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green
        case "expense":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .red
        case "investment":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue
        default:
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .primary
        }
    }
    
    private func getTypeBackground() -> Color {
        switch typeFilter {
        case "all":
            return Color(UIColor.secondarySystemBackground)
        case "income":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.green.opacity(0.1)
        case "expense":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.red.opacity(0.1)
        case "investment":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.blue.opacity(0.1)
        default:
            return Color(UIColor.secondarySystemBackground)
        }
    }
    
    private func getTypeBorderColor() -> Color {
        switch typeFilter {
        case "all":
            return Color(UIColor.separator)
        case "income":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.green.opacity(0.3)
        case "expense":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.red.opacity(0.3)
        case "investment":
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.blue.opacity(0.3)
        default:
            return Color(UIColor.separator)
        }
    }

    // Adicione helpers para o filtro de categoria, seguindo o padrão da tela de metas:
    private func getCategoryText() -> String {
        if categoryFilter == "all" {
            return "Categoria"
        } else if categoryFilter == "Sem Categoria" {
            return "Sem Categoria"
        } else {
            // Buscar a categoria nas categorias disponíveis
            if let category = availableCategories.first(where: { $0.name == categoryFilter }) {
                return category.name
            }
            return categoryFilter
        }
    }
    
    private func getCategoryIcon() -> String {
        if categoryFilter == "all" {
            return "folder.circle"
        } else if categoryFilter == "Sem Categoria" {
            return "folder"
        } else {
            // Buscar a categoria nas categorias disponíveis
            if let category = availableCategories.first(where: { $0.name == categoryFilter }) {
                return category.icon
            }
            return "folder.circle"
        }
    }
    private func getCategoryColor() -> Color {
        if categoryFilter == "all" {
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .primary
        } else if categoryFilter == "Sem Categoria" {
            return .gray
        } else {
            // Buscar a categoria nas categorias disponíveis
            if let category = availableCategories.first(where: { $0.name == categoryFilter }) {
                return getCategoryColorFromString(category.color)
            }
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue
        }
    }
    
    private func getCategoryColorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        default: return .gray
        }
    }
    private func getCategoryBackground() -> Color {
        if categoryFilter == "all" {
            return Color(UIColor.secondarySystemBackground)
        } else {
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.blue.opacity(0.1)
        }
    }
    private func getCategoryBorderColor() -> Color {
        if categoryFilter == "all" {
            return Color(UIColor.separator)
        } else {
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.blue.opacity(0.3)
        }
    }
    private func getNextCategory() -> String {
        let categories = ["all", "Geral", "Educação", "Viagem", "Carro", "Casa", "Investimento", "Emergência"]
        guard let currentIndex = categories.firstIndex(of: categoryFilter) else { return "all" }
        let nextIndex = (currentIndex + 1) % categories.count
        return categories[nextIndex]
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
    
}

// Função global para formatar valores de transação
func formatCurrency(_ value: Double, isIncome: Bool, isInvestment: Bool) -> String {
    // Verificar se o valor é válido
    guard value.isFinite else {
        return "R$ 0,00"
    }
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "BRL"
    formatter.locale = Locale(identifier: "pt_BR")
    
    let number = NSNumber(value: value)
    let formattedValue = formatter.string(from: number) ?? "R$ 0,00"
    
    // Para transações de investimento, não mostrar + ou -
    if isInvestment {
        return formattedValue
    }
    
    return isIncome ? "+\(formattedValue)" : "-\(formattedValue)"
}

// MARK: - Swipeable Transaction Row
public struct SwipeableTransactionRow: View {
    let transaction: TransactionModel
    let displayCategoryName: String
    let categoryIconName: String?
    let categoryColorName: String?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleStatus: () -> Void
    let onTap: () -> Void
    let onInvest: () -> Void
    let onRedeem: () -> Void
    
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var offset: CGFloat = 0
    @State private var isShowingActions = false
    
    private let actionButtonWidth: CGFloat = 80
    private let maxOffset: CGFloat = -240 // Para três botões (esquerda)
    private let maxRightOffset: CGFloat = 80 // Para um botão (direita)
    
    init(transaction: TransactionModel,
         categoryDisplayName: String? = nil,
         categoryIconName: String? = nil,
         categoryColorName: String? = nil,
         onEdit: @escaping () -> Void,
         onDelete: @escaping () -> Void,
         onToggleStatus: @escaping () -> Void,
         onTap: @escaping () -> Void = {},
         onInvest: @escaping () -> Void = {},
         onRedeem: @escaping () -> Void = {}) {
        self.transaction = transaction
        self.displayCategoryName = categoryDisplayName ?? transaction.category
        self.categoryIconName = categoryIconName
        self.categoryColorName = categoryColorName
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleStatus = onToggleStatus
        self.onTap = onTap
        self.onInvest = onInvest
        self.onRedeem = onRedeem
    }
    
    public var body: some View {
        ZStack {
            // Background com botões de ação da esquerda (apenas quando offset < 0)
            if offset < 0 {
                HStack(spacing: 0) {
                    Spacer()
                    
                    // Botão Editar
                    Button(action: {
                        // Fechar as ações primeiro
                        offset = 0
                        isShowingActions = false
                        
                        // Pequeno delay para garantir que a animação termine
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onEdit()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .medium))
                            Text("Editar")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: actionButtonWidth)
                        .frame(maxHeight: .infinity)
                        .background(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Botão Alternar Status
                    Button(action: {
                        // Fechar as ações primeiro
                        offset = 0
                        isShowingActions = false
                        
                        // Pequeno delay para garantir que a animação termine
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onToggleStatus()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 18, weight: .medium))
                            Text("Status")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: actionButtonWidth)
                        .frame(maxHeight: .infinity)
                        .background(isMonochromaticMode ? MonochromaticColorManager.secondaryGreen : Color.orange)
                        .cornerRadius(12)
                    }
                    
                    // Botão Excluir
                    Button(action: {
                        // Fechar as ações primeiro
                        offset = 0
                        isShowingActions = false
                        
                        // Pequeno delay para garantir que a animação termine
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onDelete()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                            Text("Excluir")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: actionButtonWidth)
                        .frame(maxHeight: .infinity)
                        .background(isMonochromaticMode ? MonochromaticColorManager.primaryGray : Color.red)
                        .cornerRadius(12)
                    }
                }
                .opacity(min(abs(offset) / 80.0, 1.0)) // Fade in baseado no offset
            }
            
            // Background com botão Investir da direita (apenas quando offset > 0 e é receita)
            if offset > 0 && transaction.isIncome {
                HStack(spacing: 0) {
                    // Botão Investir
                    Button(action: {
                        offset = 0
                        isShowingActions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onInvest()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 18, weight: .medium))
                            Text("Investir")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: maxRightOffset)
                        .frame(maxHeight: .infinity)
                        .background(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue)
                        .cornerRadius(12)
                    }
                    Spacer()
                }
                .opacity(min(offset / 80.0, 1.0))
            }
            // Background com botão Transferir da direita (apenas quando offset > 0 e é investimento)
            if offset > 0 && (transaction.type ?? "expense") == "investment" {
                HStack(spacing: 0) {
                    // Botão Transferir
                    Button(action: {
                        offset = 0
                        isShowingActions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onRedeem()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 18, weight: .medium))
                            Text("Transferir")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: maxRightOffset)
                        .frame(maxHeight: .infinity)
                        .background(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.orange)
                        .cornerRadius(12)
                    }
                    Spacer()
                }
                .opacity(min(offset / 80.0, 1.0))
            }
            
            // Conteúdo principal da transação
            TransactionRow(
                transaction: transaction,
                displayCategoryName: displayCategoryName,
                categoryIconName: categoryIconName,
                categoryColorName: categoryColorName
            )
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let horizontalTranslation = value.translation.width
                            let verticalTranslation = abs(value.translation.height)
                            
                            // Só processa swipe horizontal se o movimento horizontal for maior que o vertical
                            // Isso permite que o ScrollView funcione quando o usuário arrasta verticalmente
                            if abs(horizontalTranslation) > verticalTranslation {
                                // Permite arrastar para a esquerda (sempre)
                                if horizontalTranslation < 0 {
                                    offset = max(horizontalTranslation, maxOffset)
                                }
                                // Permite arrastar para a direita se for receita ou investimento
                                else if horizontalTranslation > 0 && (transaction.isIncome || (transaction.type ?? "expense") == "investment") {
                                    offset = min(horizontalTranslation, maxRightOffset)
                                }
                                // Se as ações estão visíveis, permite arrastar de volta
                                else if isShowingActions && horizontalTranslation > 0 && offset < 0 {
                                    offset = min(horizontalTranslation + maxOffset, 0)
                                }
                                else if isShowingActions && horizontalTranslation < 0 && offset > 0 {
                                    offset = max(horizontalTranslation + maxRightOffset, 0)
                                }
                            }
                        }
                        .onEnded { value in
                            let horizontalTranslation = value.translation.width
                            let verticalTranslation = abs(value.translation.height)
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            
                            // Só processa o fim do swipe se foi principalmente horizontal
                            if abs(horizontalTranslation) > verticalTranslation {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    // Swipe para a esquerda
                                    if horizontalTranslation < -60 || velocity < -300 {
                                        offset = maxOffset
                                        isShowingActions = true
                                    }
                                    // Swipe para a direita (receitas e investimentos)
                                    else if horizontalTranslation > 60 && (transaction.isIncome || (transaction.type ?? "expense") == "investment") || velocity > 300 && (transaction.isIncome || (transaction.type ?? "expense") == "investment") {
                                        offset = maxRightOffset
                                        isShowingActions = true
                                    }
                                    // Retorna à posição original
                                    else {
                                        offset = 0
                                        isShowingActions = false
                                    }
                                }
                            }
                        }
                )
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            // Se as ações de swipe estão visíveis, fecha elas
            if isShowingActions {
                withAnimation(.spring(response: 0.3)) {
                    offset = 0
                    isShowingActions = false
                }
            } else {
                // Se não há ações visíveis, abre a tela de edição
                onTap()
            }
        }
    }
}

// MARK: - Enhanced Transaction Row
public struct TransactionRow: View {
    let transaction: TransactionModel
    let displayCategoryName: String
    let categoryIconName: String?
    let categoryColorName: String?
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    // Computed properties para quebrar a complexidade
    private var gradientColors: [Color] {
        if let categoryColor = resolvedCategoryColor {
            return [
                categoryColor.opacity(0.85),
                categoryColor
            ]
        }
        if (transaction.type ?? "expense") == "investment" {
            return isMonochromaticMode ? 
                [MonochromaticColorManager.primaryGreen.opacity(0.8), MonochromaticColorManager.primaryGreen] :
                [Color.blue.opacity(0.8), Color.blue]
        } else if transaction.isIncome {
            return isMonochromaticMode ? 
                [MonochromaticColorManager.primaryGreen.opacity(0.8), MonochromaticColorManager.primaryGreen] :
                [Color.green.opacity(0.8), Color.green]
        } else {
            return isMonochromaticMode ? 
                [MonochromaticColorManager.primaryGray.opacity(0.8), MonochromaticColorManager.primaryGray] :
                [Color.red.opacity(0.8), Color.red]
        }
    }
    
    private var fallbackIconName: String {
        if (transaction.type ?? "expense") == "investment" {
            return "chart.line.uptrend.xyaxis"
        } else if transaction.isIncome {
            return "arrow.up.right"
        } else {
            return "arrow.down.left"
        }
    }
    
    private var resolvedIconName: String {
        if let customIcon = categoryIconName, !customIcon.isEmpty {
            return customIcon
        }
        return fallbackIconName
    }
    
    private var resolvedCategoryColor: Color? {
        guard let name = categoryColorName, !name.isEmpty else {
            return nil
        }
        return colorForCategoryColorName(name)
    }
    
    private var amountColor: Color {
        if (transaction.type ?? "expense") == "investment" {
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue
        } else if transaction.isIncome {
            return isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.green
        } else {
            return isMonochromaticMode ? MonochromaticColorManager.primaryGray : Color.red
        }
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Indicador de pendente
            if transaction.status == "pending" || transaction.status == "unpaid" || transaction.status == "aguardando" {
                Circle()
                    .fill(isMonochromaticMode ? Color.gray : Color.orange)
                    .frame(width: 8, height: 8)
            }
            // Ícone da transação
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
                Image(systemName: resolvedIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Informações da transação
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title ?? transaction.description ?? "-")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    Text(self.displayCategoryName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatShortDate(transaction.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Valor da transação
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(transaction.amount, isIncome: transaction.isIncome, isInvestment: (transaction.type ?? "expense") == "investment"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(amountColor)
                
                if (transaction.isRecurring ?? false) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Recorrente")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Indicador de que é clicável
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle()) // Garante que toda a área seja clicável
        .allowsHitTesting(true) // Garante que o toque seja detectado
    }
    
    private func colorForCategoryColorName(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        case "teal": return .teal
        case "gray": return .gray
        default: return .gray
        }
    }
    
    private func formatShortDate(_ dateStr: String) -> String {
        // Verificar se a string está vazia
        guard !dateStr.isEmpty else {
            return dateStr
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = dateFormatter.date(from: dateStr) else {
            // Se não conseguir fazer o parse, retorna a string original
            return dateStr
        }
        
        let outFormatter = DateFormatter()
        outFormatter.locale = Locale(identifier: "pt_BR")
        outFormatter.dateFormat = "dd MMM"
        
        let result = outFormatter.string(from: date)
        return result.capitalized
    }
}

// MARK: - Status Notification View
public struct TransactionStatusNotificationView: View {
    let message: String
    @Binding var isVisible: Bool
    let isSuccess: Bool
    
    public var body: some View {
        VStack {
            // Notificação principal
            HStack(spacing: 12) {
                // Ícone
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isSuccess ? .green : .red)
                    .font(.system(size: 20))
                
                // Mensagem
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
                
                // Ícone de fechar
                Button(action: dismissNotification) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
            )
            .padding(.horizontal, 16)
            .padding(.top, 50) // Posicionado no topo absoluto
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: isVisible)
        .zIndex(1000)
    }
    
    private func dismissNotification() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = false
        }
    }
}
