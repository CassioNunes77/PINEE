//
//  TransferInvestmentView.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//

import SwiftUI
// import FirebaseFirestore
// import FirebaseAuth // Temporariamente desabilitado
import UIKit

struct TransferInvestmentView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    // @EnvironmentObject var globalDateManager: GlobalDateManager  // TEMPORARIAMENTE COMENTADO
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    let sourceTransaction: TransactionModel
    
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var category: String = "Investimento"
    @State private var date: Date = Date()
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    let categories = ["Investimento"]
    
    var isRedeem: Bool {
        (sourceTransaction.type ?? "") == "investment"
    }
    
    init(sourceTransaction: TransactionModel) {
        self.sourceTransaction = sourceTransaction
        
        print("🔧 TransferInvestmentView init - sourceTransaction: \(sourceTransaction.title ?? "nil")")
        print("🔧 TransferInvestmentView init - amount: \(sourceTransaction.amount)")
        
        // Inicializar o valor com o valor total da receita
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let initialAmount = formatter.string(from: NSNumber(value: sourceTransaction.amount)) ?? "0,00"
        
        // Inicializar a descrição com base na transação de origem
        let initialDescription = "Transferência de \(sourceTransaction.title ?? sourceTransaction.description ?? "receita")"
        
        _amount = State(initialValue: initialAmount)
        _description = State(initialValue: initialDescription)
        _date = State(initialValue: Date())
        
        print("🔧 TransferInvestmentView init - Estados inicializados:")
        print("   amount: \(initialAmount)")
        print("   description: \(initialDescription)")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header - Tipo de Transação
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            if isRedeem {
                                // Receita (resgate)
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Receita")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.green)
                                )
                            } else {
                                // Investimento (aplicação)
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
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Informações da transação de origem
                    VStack(spacing: 8) {
                        Text("Transferindo de")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sourceTransaction.title ?? sourceTransaction.description ?? "-")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(sourceTransaction.category)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(formatCurrency(sourceTransaction.amount, isIncome: sourceTransaction.isIncome, isInvestment: false))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                                    
                                    Text(formatDateString(sourceTransaction.date))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Campo de valor
                    VStack(spacing: 8) {
                        Text("Valor a investir")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("Digite o valor", text: $amount)
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                            .onChange(of: amount) { newValue in
                                // TEMPORARIAMENTE COMENTADO - formatCurrencyInput não disponível
                                // amount = formatCurrencyInput(newValue)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Campos principais
                    VStack(spacing: 0) {
                        // Descrição
                        HStack(spacing: 16) {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Descrição")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Adicionar descrição", text: $description)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Data
                        HStack(spacing: 16) {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Data")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Categoria (fixa como Investimento)
                        HStack(spacing: 16) {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Categoria")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("Investimento")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .padding(.top, 24)
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
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
                            Text("Transferindo...")
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
            .navigationBarTitle("Transferir para Investimento", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A")),
                trailing: Button(isRedeem ? "Resgatar" : "Transferir") {
                    if isRedeem {
                        redeemToIncome()
                    } else {
                        transferToInvestment()
                    }
                }
                    .disabled(amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.isEmpty || isLoading)
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            )
        }
        .onAppear {
            print("🔧 TransferInvestmentView onAppear - sourceTransaction: \(sourceTransaction.title ?? "nil")")
            print("🔧 TransferInvestmentView onAppear - amount: \(sourceTransaction.amount)")
        }
    }
    
    // MARK: - Functions
    
    // Função para formatar string de data
    private func formatDateString(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    // Função para resgatar investimento para receita
    private func redeemToIncome() {
        // TEMPORÁRIO: Simular sucesso
        isLoading = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            print("✅ Resgate simulado com sucesso")
            self.presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func transferToInvestment() {
        guard let userId = authViewModel.user?.id else {
            errorMessage = "Usuário não autenticado"
            return
        }
        
        // Validar valor
        let cleanedAmount = amount.replacingOccurrences(of: "[^0-9,]", with: "", options: .regularExpression)
        guard let amountValue = Double(cleanedAmount.replacingOccurrences(of: ",", with: ".")), amountValue > 0 else {
            errorMessage = "Valor inválido"
            return
        }
        
        // Validar se o valor não excede o valor da receita
        if amountValue > sourceTransaction.amount {
            errorMessage = "Valor não pode exceder o valor da receita"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Criar a transação de investimento
        let _ = [
            "userId": userId,
            "title": description,
            "description": description,
            "amount": amountValue,
            "category": category,
            "date": dateString,
            "type": "investment",
            "isIncome": false,
            "status": "invested",
            "createdAt": Date(),
            "isRecurring": false,
            "recurringFrequency": "",
            "recurringEndDate": "",
            "sourceTransactionId": sourceTransaction.id ?? "",
            "sourceTransactionTitle": sourceTransaction.title ?? sourceTransaction.description ?? "",
            "sourceTransactionAmount": sourceTransaction.amount
        ] as [String : Any]
        
        // Verificar se é transferência total (100%) ou parcial
        let isFullTransfer = abs(amountValue - sourceTransaction.amount) < 0.01 // Tolerância para comparação de Double
        
        if isFullTransfer {
            // Transferência total: deletar a transação de receita original
            print("🔄 Transferência total detectada - deletando receita original")
            
            // TEMPORARIAMENTE COMENTADO - Firestore não disponível
            /*
             db.collection("transactions").addDocument(data: investmentTransaction) { error in
             DispatchQueue.main.async {
             if let error = error {
             print("❌ Erro ao criar transação de investimento: \(error.localizedDescription)")
             self.errorMessage = "Erro ao transferir para investimento"
             self.isLoading = false
             } else {
             print("✅ Transação de investimento criada com sucesso")
             print("💰 Valor transferido: R$ \(String(format: "%.2f", amountValue))")
             
             // Depois deletar a receita original
             if let incomeId = self.sourceTransaction.id {
             db.collection("transactions").document(incomeId).delete { deleteError in
             DispatchQueue.main.async {
             self.isLoading = false
             
             if let deleteError = deleteError {
             print("❌ Erro ao deletar receita original: \(deleteError.localizedDescription)")
             self.errorMessage = "Investimento criado, mas erro ao remover receita"
             } else {
             print("✅ Receita original deletada com sucesso")
             print("📊 Receita de origem removida: \(self.sourceTransaction.title ?? "")")
             }
             */
            
            // TEMPORÁRIO: Simular sucesso
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isLoading = false
                print("✅ Transferência para investimento simulada com sucesso")
                self.presentationMode.wrappedValue.dismiss()
            }
            // } else {
            // TEMPORARIAMENTE COMENTADO - código problemático
            /*
             // Transferência parcial: atualizar o valor da receita original
             print("🔄 Transferência parcial detectada - atualizando receita original")
             
             let newIncomeAmount = sourceTransaction.amount - amountValue
             let updatedIncomeData = [
             "amount": newIncomeAmount,
             "updatedAt": Timestamp(date: Date())
             ] as [String : Any]
             */
            
            // TEMPORARIAMENTE COMENTADO - código problemático
            /*
             // Primeiro criar o investimento
             db.collection("transactions").addDocument(data: investmentTransaction) { error in
             DispatchQueue.main.async {
             if let error = error {
             print("❌ Erro ao criar transação de investimento: \(error.localizedDescription)")
             self.errorMessage = "Erro ao transferir para investimento"
             self.isLoading = false
             } else {
             print("✅ Transação de investimento criada com sucesso")
             print("💰 Valor transferido: R$ \(String(format: "%.2f", amountValue))")
             
             // Depois atualizar a receita original
             if let incomeId = self.sourceTransaction.id {
             db.collection("transactions").document(incomeId).updateData(updatedIncomeData) { updateError in
             DispatchQueue.main.async {
             self.isLoading = false
             
             if let updateError = updateError {
             print("❌ Erro ao atualizar receita original: \(updateError.localizedDescription)")
             self.errorMessage = "Investimento criado, mas erro ao atualizar receita"
             } else {
             print("✅ Receita original atualizada com sucesso")
             print("📊 Novo valor da receita: R$ \(String(format: "%.2f", newIncomeAmount))")
             print("📊 Receita de origem: \(self.sourceTransaction.title ?? "")")
             }
             
             // Fechar a tela
             self.presentationMode.wrappedValue.dismiss()
             }
             }
             } else {
             self.isLoading = false
             self.presentationMode.wrappedValue.dismiss()
             }
             }
             }
             }
             */
            
            // TEMPORÁRIO: Simular sucesso
            /*
             DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             self.isLoading = false
             print("✅ Transferência simulada com sucesso")
             self.presentationMode.wrappedValue.dismiss()
             }
             */
        }
    }
    
    struct TransferInvestmentView_Previews: PreviewProvider {
        static var previews: some View {
            let sampleTransaction = TransactionModel(
                id: "sample",
                userId: "user123",
                title: "Salário",
                description: "Salário do mês",
                amount: 5000.0,
                category: "Salário",
                date: "2024-01-15",
                isIncome: true,
                type: "income",
                status: "received",
                createdAt: Date(),
                isRecurring: false,
                recurringFrequency: "",
                recurringEndDate: "",
                sourceTransactionId: nil
            )
            
            TransferInvestmentView(sourceTransaction: sampleTransaction)
        }
    }
}
