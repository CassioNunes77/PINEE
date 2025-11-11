//
//  TransferIncomeView.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//

import SwiftUI
// import FirebaseFirestore
// import FirebaseAuth // Temporariamente desabilitado
import UIKit

struct TransferIncomeView: View {
    @Environment(\.presentationMode) var presentationMode
    // @EnvironmentObject var authViewModel: AuthViewModel  // COMENTADO - temporariamente desabilitado
    // @EnvironmentObject var globalDateManager: GlobalDateManager  // COMENTADO - temporariamente desabilitado
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    let sourceTransaction: TransactionModel
    
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var category: String = "Resgate"
    @State private var date: Date = Date()
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    let categories = ["Resgate"]
    
    init(sourceTransaction: TransactionModel) {
        self.sourceTransaction = sourceTransaction
        
        print("🔧 TransferIncomeView init - sourceTransaction: \(sourceTransaction.title ?? "nil")")
        print("🔧 TransferIncomeView init - amount: \(sourceTransaction.amount)")
        
        // Inicializar o valor com o valor total do investimento
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let initialAmount = formatter.string(from: NSNumber(value: sourceTransaction.amount)) ?? "0,00"
        
        // Inicializar a descrição com base na transação de origem
        let initialDescription = "Transferência de \(sourceTransaction.title ?? sourceTransaction.description ?? "investimento")"
        
        _amount = State(initialValue: initialAmount)
        _description = State(initialValue: initialDescription)
        _date = State(initialValue: Date())
        
        print("🔧 TransferIncomeView init - Estados inicializados:")
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
                            // Receita (transferência de investimento)
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
                                    Text(formatCurrency(sourceTransaction.amount))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                    
                                    Text(formatShortDate(sourceTransaction.date))
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
                        Text("Valor a transferir")
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
                            .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                            .onChange(of: amount) { newValue in
                                amount = formatCurrencyInput(newValue)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Campos principais
                    VStack(spacing: 0) {
                        // Descrição
                        HStack(spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            TextField("Adicionar descrição", text: $description)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Data
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .accentColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Categoria (fixa como Resgate)
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Resgate")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
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
            .navigationBarTitle("Transferir para Receita", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A")),
                trailing: Button("Transferir") {
                    transferToIncome()
                }
                .disabled(amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.isEmpty || isLoading)
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            )
        }
        .onAppear {
            print("🔧 TransferIncomeView onAppear - sourceTransaction: \(sourceTransaction.title ?? "nil")")
            print("🔧 TransferIncomeView onAppear - amount: \(sourceTransaction.amount)")
        }
    }
    
    // MARK: - Functions
    private func transferToIncome() {
        // TEMPORARIAMENTE COMENTADO - AuthViewModel não disponível
        /*
        guard let userId = authViewModel.user?.id else {
            errorMessage = "Usuário não autenticado"
            return
        }
        */
        
        // Validar valor
        guard let amountValue = parseCurrencyInput(amount), amountValue > 0 else {
            errorMessage = "Valor inválido"
            return
        }
        
        // Validar se o valor não excede o valor do investimento
        if amountValue > sourceTransaction.amount {
            errorMessage = "Valor não pode exceder o valor do investimento"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Criar a transação de receita
        let _ = [
            // "userId": userId,  // COMENTADO - temporariamente desabilitado
            "title": description,
            "description": description,
            "amount": amountValue,
            "category": category,
            "date": dateString,
            "type": "income",
            "isIncome": true,
            "status": "received",
            // "createdAt": Timestamp(date: Date()),  // COMENTADO - Timestamp não disponível
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
            // Transferência total: deletar a transação de investimento original
            print("🔄 Transferência total detectada - deletando investimento original")
            
            // TEMPORARIAMENTE COMENTADO - Firestore não disponível
            /*
            // Primeiro criar a receita
            db.collection("transactions").addDocument(data: incomeTransaction) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Erro ao criar transação de receita: \(error.localizedDescription)")
                        self.errorMessage = "Erro ao transferir para receita"
                        self.isLoading = false
                    } else {
                        print("✅ Transação de receita criada com sucesso")
                        print("💰 Valor transferido: R$ \(String(format: "%.2f", amountValue))")
                        
                        // Depois deletar o investimento original
                        if let investmentId = self.sourceTransaction.id {
                            db.collection("transactions").document(investmentId).delete { deleteError in
                                DispatchQueue.main.async {
                                    self.isLoading = false
                                    
                                    if let deleteError = deleteError {
                                        print("❌ Erro ao deletar investimento original: \(deleteError.localizedDescription)")
                                        self.errorMessage = "Receita criada, mas erro ao remover investimento"
                                    } else {
                                        print("✅ Investimento original deletado com sucesso")
                                        print("📊 Investimento de origem removido: \(self.sourceTransaction.title ?? "")")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isLoading = false
                print("✅ Transferência simulada com sucesso")
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // MARK: - Helper Functions
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
    
    private func parseCurrencyInput(_ input: String) -> Double? {
        // Se o input estiver vazio, retornar nil
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        
        // Remover todos os caracteres não numéricos
        let cleaned = trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Se após limpeza estiver vazio, retornar nil
        if cleaned.isEmpty {
            return nil
        }
        
        // Converter para número inteiro (representa centavos)
        let centavos = Int(cleaned) ?? 0
        
        // Converter centavos para reais
        return Double(centavos) / 100.0
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}

struct TransferIncomeView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTransaction = TransactionModel(
            id: "sample",
            userId: "user123",
            title: "Investimento em Ações",
            description: "Investimento em ações da empresa",
            amount: 1000.0,
            category: "Investimento",
            date: "2024-01-15",
            isIncome: false,
            type: "investment",
            status: "invested",
            createdAt: Date(),
            isRecurring: false,
            recurringFrequency: "",
            recurringEndDate: "",
            sourceTransactionId: nil
        )
        
        TransferIncomeView(sourceTransaction: sampleTransaction)
    }
}