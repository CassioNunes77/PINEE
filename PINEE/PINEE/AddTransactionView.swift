//
//  AddTransactionView.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//

import SwiftUI
import UIKit

// MARK: - Category Model
struct Category: Identifiable, Codable {
    let id: String?
    let name: String
    let icon: String
    let color: String
    let type: String
    let isSystem: Bool
    let userId: String?
    let isDefault: Bool
    
    var identifiedId: String {
        return id ?? name
    }
}

// MARK: - CategoryPickerViewModel
class CategoryPickerViewModel: ObservableObject {
    @Published var categories: [Category] = []
    private let firebaseService = FirebaseRESTService.shared
    
    func loadCategories(for type: String, userId: String?, idToken: String?) {
        let includeHidden = type == "investment"
        let defaults = CategoryDataProvider.categories(for: type, includeHidden: includeHidden)
        DispatchQueue.main.async {
            self.categories = defaults
        }

        guard let userId = userId, let idToken = idToken else {
            print("🔍 CategoryPickerViewModel: sem credenciais, usando apenas categorias padrão")
            return
        }

        Task {
            do {
                let remoteCategories = try await firebaseService.getCategories(userId: userId, idToken: idToken)
                let filteredRemote: [Category] = remoteCategories.filter { category in
                    let normalizedType = category.type.lowercased()
                    if CategoryDataProvider.hiddenCategoryIDs.contains(category.identifiedId) {
                        return includeHidden && normalizedType == "investment"
                    }
                    if type == "investment" {
                        return normalizedType == "investment"
                    }
                    return normalizedType == type.lowercased()
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
                for category in filteredRemote {
                    let key = category.identifiedId.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        ordered.append(category)
                    }
                }
                let finalCategories = ordered
                await MainActor.run {
                    self.categories = finalCategories
                }
            } catch {
                print("❌ CategoryPickerViewModel: erro ao carregar categorias remotas - \(error.localizedDescription)")
            }
        }
    }
}

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss // Adaptado para iOS 18
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var globalDateManager: GlobalDateManager
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var transactionToEdit: TransactionModel?
    
    @State private var type: String = "expense"
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var category: String = CategoryDataProvider.fallbackCategoryID(for: "expense")
    @State private var date: Date = Date()
    @State private var isPaid: Bool = false
    @State private var isReceived: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: String = "monthly"
    @State private var recurringEndDate: Date = Date()
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var showCategoryModal = false
    
    @StateObject private var categoryPickerVM = CategoryPickerViewModel()
    private let firebaseService = FirebaseRESTService.shared
    
    let frequencies = ["monthly", "weekly", "yearly"]
    
    init(transactionToEdit: TransactionModel? = nil) {
        self.transactionToEdit = transactionToEdit
        
        print("🔧 AddTransactionView init - transactionToEdit: \(transactionToEdit?.title ?? "nil")")
        print("🔧 AddTransactionView init - amount: \(transactionToEdit?.amount ?? 0)")
        
        // Inicializar os estados com valores padrão
        let initialType = transactionToEdit?.type ?? "expense"
        
        // Garantir que o tipo seja válido
        let validType = (initialType == "income" || initialType == "expense" || initialType == "investment") ? initialType : "expense"
        
        // Formatar o valor corretamente para o padrão brasileiro
        let initialAmount: String
        if let transaction = transactionToEdit {
            // Para edição, converter o valor existente para formato brasileiro
            let amountValue = transaction.amount
            
            // Formatar o valor em reais com separadores brasileiros
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            formatter.groupingSize = 3
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            
            initialAmount = formatter.string(from: NSNumber(value: amountValue)) ?? "0,00"
            
            print("🔧 AddTransactionView init - formatted amount: \(initialAmount)")
        } else {
            // Para novas transações, começar com "0,00"
            initialAmount = "0,00"
            print("🔧 AddTransactionView init - new transaction, starting with 0,00")
        }
        
        let initialDescription = transactionToEdit?.description ?? ""
        let initialCategory: String
        if let existingCategory = transactionToEdit?.category, !existingCategory.isEmpty {
            initialCategory = existingCategory
        } else if validType == "investment" {
            initialCategory = CategoryDataProvider.investmentCategoryID
        } else {
            initialCategory = CategoryDataProvider.fallbackCategoryID(for: validType)
        }
        let initialIsPaid = transactionToEdit?.status == "paid"
        let initialIsReceived = transactionToEdit?.status == "received"
        let initialIsRecurring = transactionToEdit?.isRecurring ?? false
        let initialRecurringFrequency = transactionToEdit?.recurringFrequency ?? "monthly"
        
        // Processar data da transação
        var initialDate = Date()
        if let transaction = transactionToEdit {
            // Se for edição, usar a data da transação
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let transactionDate = dateFormatter.date(from: transaction.date) {
                initialDate = transactionDate
            }
        } else {
            // Se for nova transação, usar a data do GlobalDateManager
            // A lógica será aplicada no onAppear para ter acesso ao GlobalDateManager
            initialDate = Date()
        }
        
        // Processar data final de recorrência
        var initialRecurringEndDate = Date()
        if let transaction = transactionToEdit, let endDate = transaction.recurringEndDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let endDateObj = dateFormatter.date(from: endDate) {
                initialRecurringEndDate = endDateObj
            }
        }
        
        // Inicializar os estados
        _type = State(initialValue: validType)
        _amount = State(initialValue: initialAmount)
        _description = State(initialValue: initialDescription)
        _category = State(initialValue: initialCategory)
        _isPaid = State(initialValue: initialIsPaid)
        _isReceived = State(initialValue: initialIsReceived)
        _isRecurring = State(initialValue: initialIsRecurring)
        _date = State(initialValue: initialDate)
        _recurringFrequency = State(initialValue: initialRecurringFrequency)
        _recurringEndDate = State(initialValue: initialRecurringEndDate)
        
        print("🔧 AddTransactionView init - Estados inicializados:")
        print("   type: \(validType)")
        print("   amount: \(initialAmount)")
        print("   description: \(initialDescription)")
        print("   category: \(initialCategory)")
        print("   isPaid: \(initialIsPaid)")
        print("   isReceived: \(initialIsReceived)")
        print("   isRecurring: \(initialIsRecurring)")
        print("   date: \(initialDate)")
        print("   recurringFrequency: \(initialRecurringFrequency)")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Tipo de Transação - Header (oculto para edição de investimento)
                    if transactionToEdit == nil || transactionToEdit?.type != "investment" {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                // Despesa
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        type = "expense"
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(type == "expense" ? 
                                                (isMonochromaticMode ? .white : .white) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGray : .red))
                                        
                                        Text("Despesa")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(type == "expense" ? 
                                                (isMonochromaticMode ? .white : .white) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGray : .red))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(type == "expense" ? 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGray : Color.red) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGray.opacity(0.1) : Color.red.opacity(0.1)))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isMonochromaticMode ? MonochromaticColorManager.primaryGray.opacity(0.3) : Color.red.opacity(0.3), 
                                                   lineWidth: type == "expense" ? 0 : 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Receita
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        type = "income"
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(type == "income" ? 
                                                (isMonochromaticMode ? .white : .white) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green))
                                        
                                        Text("Receita")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(type == "income" ? 
                                                (isMonochromaticMode ? .white : .white) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(type == "income" ? 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.green) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.green.opacity(0.1)))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.green.opacity(0.3), 
                                                   lineWidth: type == "income" ? 0 : 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Investimento
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        type = "investment"
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(type == "investment" ? 
                                                (isMonochromaticMode ? .white : .white) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue))
                                        
                                        Text("Investir")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(type == "investment" ? 
                                                (isMonochromaticMode ? .white : .white) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(type == "investment" ? 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue) : 
                                                (isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.1) : Color.blue.opacity(0.1)))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color.blue.opacity(0.3), 
                                                   lineWidth: type == "investment" ? 0 : 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .onChange(of: type) { newType in
                                if newType == "investment" {
                                    category = CategoryDataProvider.investmentCategoryID
                                }
                                // Atualizar status baseado no tipo
                                if newType == "expense" {
                                    isReceived = false
                                    if category.isEmpty || CategoryDataProvider.hiddenCategoryIDs.contains(category) {
                                        category = CategoryDataProvider.fallbackCategoryID(for: newType)
                                    }
                                } else if newType == "income" {
                                    isPaid = false
                                    if category.isEmpty || CategoryDataProvider.hiddenCategoryIDs.contains(category) {
                                        category = CategoryDataProvider.fallbackCategoryID(for: newType)
                                    }
                                } else if newType == "investment" {
                                    isPaid = true
                                    isReceived = false
                                }
                                categoryPickerVM.loadCategories(for: newType, userId: authViewModel.user?.id, idToken: authViewModel.user?.idToken)
                            }
                        }
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
                            .foregroundColor(type == "expense" ? 
                                (isMonochromaticMode ? .primary : .red) : 
                                (type == "income" ? 
                                    (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green) :
                                    (isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)))
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
                                .datePickerStyle(CompactDatePickerStyle())
                                .accentColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Categoria
                        FormFieldRow(
                            icon: "folder",
                            title: "Categoria"
                        ) {
                            let pickerCategories: [Category] = categoryPickerVM.categories
                            let isInvestment = type == "investment"
                            if isInvestment {
                                // Categoria travada em 'Investir'
                                if let investmentCat = pickerCategories.first(where: { $0.id == "investment" }) {
                                    Text(investmentCat.name)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Investir")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Button(action: { showCategoryModal = true }) {
                                    HStack {
                                        Text(pickerCategories.first(where: { $0.id == category || $0.name == category })?.name ?? "Selecionar categoria")
                                            .foregroundColor(category.isEmpty ? .secondary : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .sheet(isPresented: $showCategoryModal) {
                                    CategorySelectionModal(
                                        categories: pickerCategories,
                                        selectedCategory: $category,
                                        isPresented: $showCategoryModal
                                    )
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Status (Aportado)
                        if type == "investment" {
                            if transactionToEdit?.sourceTransactionId == nil {
                                // Investimento cadastrado diretamente: toggle habilitar/desabilitar
                            FormFieldRow(
                                icon: "checkmark.circle",
                                    title: "Aportado"
                            ) {
                                    Toggle("", isOn: $isPaid)
                                    .toggleStyle(SwitchToggleStyle(tint: isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green))
                            }
                        } else {
                                // Investimento de receita: status sempre ativo
                            FormFieldRow(
                                icon: "checkmark.circle",
                                title: "Aportado"
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
                        } else if type == "expense" {
                            FormFieldRow(
                                icon: "checkmark.circle",
                                title: "Pago"
                            ) {
                                Toggle("", isOn: $isPaid)
                                    .toggleStyle(SwitchToggleStyle(tint: isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green))
                            }
                        } else if type == "income" {
                            FormFieldRow(
                                icon: "checkmark.circle",
                                title: "Recebido"
                            ) {
                                Toggle("", isOn: $isReceived)
                                    .toggleStyle(SwitchToggleStyle(tint: isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green))
                            }
                        }
                        
                        // Recorrente (oculto para investimentos transferidos de receita)
                        if type != "investment" {
                            Divider()
                                .padding(.leading, 56)
                            
                            FormFieldRow(
                                icon: "repeat",
                                title: "Recorrente"
                            ) {
                                Toggle("", isOn: $isRecurring)
                                    .toggleStyle(SwitchToggleStyle(tint: isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue))
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
                                    .accentColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                }
                                
                                Divider()
                                    .padding(.leading, 56)
                                
                                FormFieldRow(
                                    icon: "calendar.badge.clock",
                                    title: "Até"
                                ) {
                                    DatePicker("", selection: $recurringEndDate, displayedComponents: .date)
                                        .datePickerStyle(CompactDatePickerStyle())
                                        .accentColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                }
                            }
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
                        
                        Button(action: saveTransaction) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(transactionToEdit != nil ? "Atualizar" : "Salvar")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.blue)
                            )
                        }
                        .disabled(amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.isEmpty || isLoading)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                }
            }
            .navigationTitle(getNavigationTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(transactionToEdit != nil ? "Atualizar" : "Salvar") {
                        saveTransaction()
                    }
                    .disabled(amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.isEmpty || isLoading)
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                }
            }
        }
        .onAppear {
            // Carregar categorias baseado no tipo
            categoryPickerVM.loadCategories(for: type, userId: authViewModel.user?.id, idToken: authViewModel.user?.idToken)
            
            // Se for edição, usar a data do GlobalDateManager apenas se não for investimento
            if transactionToEdit == nil && type != "investment" {
                date = globalDateManager.selectedDate
            }
        }
        .onChange(of: type) { newType in
            categoryPickerVM.loadCategories(for: newType, userId: authViewModel.user?.id, idToken: authViewModel.user?.idToken)
        }
    }
    
    // Função para determinar o título da navegação
    private func getNavigationTitle() -> String {
        if let transaction = transactionToEdit {
            if transaction.type == "investment" {
                return "Editar investimento"
            } else if transaction.type == "income" {
                return "Editar Receita"
            } else {
                return "Editar Despesa"
            }
        } else {
            return "Nova Transação"
        }
    }
    
    // MARK: - Feedback Service
    private let feedbackService = FeedbackService.shared
    
    private func saveTransaction() {
        guard let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
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
        
        let status: String = {
            // Para investimentos transferidos de receita, sempre "invested"
            if transactionToEdit?.type == "investment" && transactionToEdit?.sourceTransactionId != nil {
                return "invested"
            }
            
            if type == "expense" {
                return isPaid ? "paid" : "unpaid"
            } else if type == "income" {
                return isReceived ? "received" : "pending"
            } else if type == "investment" {
                return isPaid ? "invested" : "pending"
            } else {
                return "pending"
            }
        }()
        
        // Determinar categoria
        let categoryId: String = {
            if type == "investment" { return CategoryDataProvider.investmentCategoryID }
            if category.isEmpty || category == "Outros" {
                return CategoryDataProvider.fallbackCategoryID(for: type)
            }
            return category
        }()
        
        if let editingTransaction = transactionToEdit, let id = editingTransaction.id {
            // Atualizar transação existente - criar nova instância com valores atualizados
            let updatedTransaction = TransactionModel(
                id: id,
                userId: userId,
                title: description.isEmpty ? "-" : description,
                description: description.isEmpty ? "-" : description,
                amount: amountInReais,
                category: categoryId,
                date: dateFormatter.string(from: date),
                isIncome: type == "income",
                type: type,
                status: status,
                createdAt: editingTransaction.createdAt,
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : "",
                recurringEndDate: isRecurring ? dateFormatter.string(from: recurringEndDate) : "",
                sourceTransactionId: editingTransaction.sourceTransactionId
            )
            
            Task {
                do {
                    _ = try await firebaseService.updateTransaction(updatedTransaction, userId: userId, idToken: idToken)
                    
                    await MainActor.run {
                        isLoading = false
                        feedbackService.successFeedback()
                        
                        // Enviar notificação para atualizar as telas
                    NotificationCenter.default.post(name: NSNotification.Name("TransactionSaved"), object: transaction)
                        
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Erro ao atualizar: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // Criar nova transação
            let newTransaction = TransactionModel(
                id: nil,
                userId: userId,
                title: description.isEmpty ? "-" : description,
                description: description.isEmpty ? "-" : description,
                amount: amountInReais,
                category: categoryId,
                date: dateFormatter.string(from: date),
                isIncome: type == "income",
                type: type,
                status: status,
                createdAt: now,
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : "",
                recurringEndDate: isRecurring ? dateFormatter.string(from: recurringEndDate) : "",
                sourceTransactionId: nil
            )
            
            Task {
                do {
                    try await firebaseService.saveTransaction(newTransaction, userId: userId, idToken: idToken)
                    
                    await MainActor.run {
                        isLoading = false
                        feedbackService.successFeedback()
                        
                        // Enviar notificação para atualizar as telas
                    NotificationCenter.default.post(name: NSNotification.Name("TransactionSaved"), object: transaction)
                        
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Erro ao salvar: \(error.localizedDescription)"
                    }
                }
            }
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

// MARK: - Form Field Row Component
struct FormFieldRow<Content: View>: View {
    let icon: String
    let title: String
    let content: Content
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Ícone
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(getIconColor())
                .frame(width: 24, height: 24)
            
            // Título
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(minWidth: 80, alignment: .leading)
            
            // Conteúdo
            content
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func getIconColor() -> Color {
        if isMonochromaticMode {
            return MonochromaticColorManager.primaryGreen
        }
        
        switch icon {
        case "text.alignleft": return .orange
        case "folder": return .purple
        case "calendar": return .red
        case "checkmark.circle": return .green
        case "repeat": return .blue
        case "clock": return .blue
        case "calendar.badge.clock": return .blue
        default: return .gray
        }
    }
}

struct AddTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        AddTransactionView()
    }
}

struct CategorySelectionModal: View {
    let categories: [Category]
    @Binding var selectedCategory: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List(categories) { cat in
                Button(action: {
                    selectedCategory = cat.id ?? cat.name
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: cat.icon)
                            .foregroundColor(.accentColor)
                        Text(cat.name)
                        if selectedCategory == (cat.id ?? cat.name) {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Categorias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { isPresented = false }
                }
            }
        }
    }
}
