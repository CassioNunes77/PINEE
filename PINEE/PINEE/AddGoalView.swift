//
//  AddGoalView.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//

import SwiftUI
import UIKit
import GoogleSignIn

// TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
/*
struct AddGoalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    // @EnvironmentObject var globalDateManager: GlobalDateManager  // TEMPORARIAMENTE COMENTADO
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var goalToEdit: Any?  // TEMPORARIAMENTE ALTERADO - Goal não disponível
    let onSave: (Any) -> Void  // TEMPORARIAMENTE ALTERADO - Goal não disponível
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetAmount: String = ""
    @State private var currentAmount: String = "0,00"
    @State private var deadline: Date = Date()
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    init(goalToEdit: Any? = nil, onSave: @escaping (Any) -> Void) {  // TEMPORARIAMENTE ALTERADO
        self.goalToEdit = goalToEdit
        self.onSave = onSave
        
        // TEMPORARIAMENTE COMENTADO - Goal não disponível
        /*
        print("🔧 AddGoalView init - goalToEdit: \(goalToEdit?.title ?? "nil")")
        print("🔧 AddGoalView init - targetAmount: \(goalToEdit?.targetAmount ?? 0)")
        */
        
        // TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
        /*
        // Inicializar os estados com valores padrão
        let initialTitle = goalToEdit?.title ?? ""
        let initialDescription = goalToEdit?.description ?? ""
        
        // Formatar o valor objetivo corretamente para o padrão brasileiro
        let initialTargetAmount: String
        if let goal = goalToEdit {
            // Para edição, converter o valor existente para formato brasileiro
            let amountValue = goal.targetAmount
            
            // Formatar o valor em reais com separadores brasileiros
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            formatter.groupingSize = 3
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            
            initialTargetAmount = formatter.string(from: NSNumber(value: amountValue)) ?? "0,00"
            
            print("🔧 AddGoalView init - formatted targetAmount: \(initialTargetAmount)")
        // } else {
            // Para novas metas, começar com "0,00"
            initialTargetAmount = "0,00"
            print("🔧 AddGoalView init - new goal, starting with 0,00")
        }
        
        // Formatar o valor atual corretamente para o padrão brasileiro
        let initialCurrentAmount: String
        if let goal = goalToEdit {
            // Para edição, converter o valor existente para formato brasileiro
            let amountValue = goal.currentAmount
            
            // Formatar o valor em reais com separadores brasileiros
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            formatter.groupingSize = 3
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            
            initialCurrentAmount = formatter.string(from: NSNumber(value: amountValue)) ?? "0,00"
        // } else {
            // Para novas metas, começar com "0,00"
            initialCurrentAmount = "0,00"
        }
        
        let initialDeadline = goalToEdit?.deadline ?? Calendar.current.date(byAdding: .month, value: 12, to: Date()) ?? Date()
        
        // Inicializar os estados
        _title = State(initialValue: initialTitle)
        _description = State(initialValue: initialDescription)
        _targetAmount = State(initialValue: initialTargetAmount)
        _currentAmount = State(initialValue: initialCurrentAmount)
        _deadline = State(initialValue: initialDeadline)
        
        print("🔧 AddGoalView init - Estados inicializados:")
        print("   title: \(initialTitle)")
        print("   description: \(initialDescription)")
        print("   targetAmount: \(initialTargetAmount)")
        print("   currentAmount: \(initialCurrentAmount)")
        print("   deadline: \(initialDeadline)")
    }
    */
    
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
                            // TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
                            // saveGoal()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(goalToEdit != nil ? "Atualizar" : "Salvar")
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
            .navigationTitle(getNavigationTitle())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A")),
                trailing: Button(goalToEdit != nil ? "Atualizar" : "Salvar") {
                    // TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
                    // saveGoal()
                }
                .disabled(targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.isEmpty || isLoading)
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            )
            .onAppear {
                // TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
                /*
                if let userId = authViewModel.user?.id {
                    // categoryPickerVM.loadCategories(for: "goal", userId: userId)
                }
                */
            }
        }
    }
    
    // Função para determinar o título da navegação
    private func getNavigationTitle() -> String {
        if let goal = goalToEdit {
            return "Editar Meta"
        // } else {
            return "Nova Meta"
        }
    }
    
    // MARK: - Feedback Service
    private let feedbackService = FeedbackService.shared
    
    // TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
    /*
    private func saveGoal() {
        // TEMPORARIAMENTE COMENTADO - AuthViewModel e Goal não disponíveis
        /*
        guard let userId = authViewModel.user?.id else {
            errorMessage = "Usuário não autenticado."
            return
        }
        */
        
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
        
        if let editingGoal = goalToEdit, let id = editingGoal.id {
            // Atualizar meta existente
            let updatedGoal = Goal(
                id: id,
                userId: userId,
                title: title.isEmpty ? "-" : title,
                description: description.isEmpty ? "-" : description,
                targetAmount: targetAmountValue,
                currentAmount: currentAmountValue,
                deadline: deadline,
                category: editingGoal.category,
                isPredefined: editingGoal.isPredefined,
                predefinedType: editingGoal.predefinedType,
                createdAt: editingGoal.createdAt,
                updatedAt: now,
                isActive: true
            )
            
            print("Atualizando meta: \(updatedGoal)")
            onSave(updatedGoal)
            isLoading = false
            feedbackService.successFeedback()
            presentationMode.wrappedValue.dismiss()
        // } else {
            // Criar nova meta
            let newGoal = Goal(
                userId: userId,
                title: title.isEmpty ? "-" : title,
                description: description.isEmpty ? "-" : description,
                targetAmount: targetAmountValue,
                currentAmount: currentAmountValue,
                deadline: deadline,
                category: "Geral",
                isPredefined: false,
                predefinedType: nil,
                createdAt: now,
                updatedAt: now,
                isActive: true
            )
            
            print("Criando meta: \(newGoal)")
            onSave(newGoal)
            isLoading = false
            feedbackService.successFeedback()
            presentationMode.wrappedValue.dismiss()
        }
        */
        
        // TEMPORÁRIO: Simular sucesso - TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
        /*
        isLoading = false
        feedbackService.successFeedback()
        presentationMode.wrappedValue.dismiss()
        */
    }
    */
    
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

//*/

// MARK: - Add Goal View
struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    private let feedbackService = FeedbackService.shared
    
    var goalToEdit: Goal?
    let onSave: (Goal) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetAmount: String = "0,00"
    @State private var currentAmount: String = "0,00"
    @State private var deadline: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var category: String = "Geral"
    @State private var isPredefined: Bool = false
    @State private var predefinedType: String? = nil
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    let categories = ["Geral", "Emergência", "Viagem", "Casa", "Carro", "Educação", "Investimento"]
    
    init(goalToEdit: Goal? = nil, onSave: @escaping (Goal) -> Void) {
        self.goalToEdit = goalToEdit
        self.onSave = onSave
        
        // Inicializar campos se estiver editando
        if let goal = goalToEdit {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            formatter.groupingSize = 3
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            
            _title = State(initialValue: goal.title)
            _description = State(initialValue: goal.description)
            _targetAmount = State(initialValue: formatter.string(from: NSNumber(value: goal.targetAmount)) ?? "0,00")
            _currentAmount = State(initialValue: formatter.string(from: NSNumber(value: goal.currentAmount)) ?? "0,00")
            _deadline = State(initialValue: goal.deadline)
            _category = State(initialValue: goal.category)
            _isPredefined = State(initialValue: goal.isPredefined)
            _predefinedType = State(initialValue: goal.predefinedType)
        }
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
                        
                        // Categoria
                        FormFieldRow(
                            icon: "folder.fill",
                            title: "Categoria"
                        ) {
                            Picker("Categoria", selection: $category) {
                                ForEach(categories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .accentColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
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
                        
                        Button(action: saveGoal) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(goalToEdit != nil ? "Atualizar" : "Salvar")
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
                        .disabled(targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.isEmpty || isLoading)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                }
            }
            .navigationTitle(goalToEdit != nil ? "Editar Meta" : "Nova Meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(goalToEdit != nil ? "Atualizar" : "Salvar") {
                        saveGoal()
                    }
                    .disabled(targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.isEmpty || isLoading)
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                }
            }
        }
    }
    
    // MARK: - Functions
    private func saveGoal() {
        guard !isLoading else { return }
        guard let userId = authViewModel.user?.id else {
            errorMessage = "Usuário não autenticado."
            return
        }
        
        let cleanedTargetAmount = targetAmount
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        let cleanedCurrentAmount = currentAmount
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        guard let targetAmountValue = Double(cleanedTargetAmount), targetAmountValue > 0 else {
            errorMessage = "Valor objetivo inválido. Deve ser maior que zero."
            return
        }
        
        guard let currentAmountValue = Double(cleanedCurrentAmount), currentAmountValue >= 0 else {
            errorMessage = "Valor atual inválido."
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "O título da meta é obrigatório."
            return
        }
        
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isLoading = true
        errorMessage = nil
        
        let now = Date()
        let goal: Goal
        
        if let editingGoal = goalToEdit, let goalId = editingGoal.id {
            goal = Goal(
                id: goalId,
                userId: userId,
                title: trimmedTitle,
                description: trimmedDescription,
                targetAmount: targetAmountValue,
                currentAmount: currentAmountValue,
                deadline: deadline,
                category: category,
                isPredefined: isPredefined,
                predefinedType: predefinedType,
                createdAt: editingGoal.createdAt,
                updatedAt: now,
                isActive: editingGoal.isActive
            )
        } else {
            goal = Goal(
                id: nil,
                userId: userId,
                title: trimmedTitle,
                description: trimmedDescription,
                targetAmount: targetAmountValue,
                currentAmount: currentAmountValue,
                deadline: deadline,
                category: category,
                isPredefined: isPredefined,
                predefinedType: predefinedType,
                createdAt: now,
                updatedAt: now,
                isActive: true
            )
        }
        
        feedbackService.successFeedback()
        onSave(goal)
        isLoading = false
        dismiss()
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

struct AddGoalView_Previews: PreviewProvider {
    static var previews: some View {
        AddGoalView { _ in }
            // .environmentObject(AuthViewModel())  // TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
            // .environmentObject(GlobalDateManager())  // TEMPORARIAMENTE COMENTADO PARA COMPILAÇÃO
    }
} 
