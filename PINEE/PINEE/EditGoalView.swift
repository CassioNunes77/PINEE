import SwiftUI
import FirebaseAuth
// import FirebaseFirestore
import UIKit

struct EditGoalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    var goalToEdit: Goal

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetAmount: String = "0,00"
    @State private var currentAmount: String = "0,00"
    @State private var deadline: Date = Date()
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false

    init(goalToEdit: Goal) {
        self.goalToEdit = goalToEdit
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        _title = State(initialValue: goalToEdit.title)
        _description = State(initialValue: goalToEdit.description)
        _targetAmount = State(initialValue: formatter.string(from: NSNumber(value: goalToEdit.targetAmount)) ?? "0,00")
        _currentAmount = State(initialValue: formatter.string(from: NSNumber(value: goalToEdit.currentAmount)) ?? "0,00")
        _deadline = State(initialValue: goalToEdit.deadline)
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
                        Divider().padding(.leading, 56)
                        // Descrição
                        FormFieldRow(
                            icon: "text.quote",
                            title: "Descrição"
                        ) {
                            TextField("Descreva sua meta", text: $description)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        Divider().padding(.leading, 56)
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
                        Divider().padding(.leading, 56)
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
                                    Text("Salvar Alterações")
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
                trailing: Button("Salvar") {
                    saveGoal()
                }
                .disabled(targetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.isEmpty || isLoading)
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            )
        }
    }

    private func saveGoal() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Usuário não autenticado."
            return
        }
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
        let db = // Firestore.firestore()
        if let id = goalToEdit.id {
            let goal: [String: Any] = [
                "userId": user.uid,
                "title": title.isEmpty ? "-" : title,
                "description": description.isEmpty ? "-" : description,
                "targetAmount": targetAmountValue,
                "currentAmount": currentAmountValue,
                "deadline": deadline,
                "isActive": true
            ]
            db// .collection("users")// .document(user.uid)// .collection("goals")// .document(id).updateData(goal) { err in
                isLoading = false
                if let err = err {
                    errorMessage = "Erro ao atualizar: \(err.localizedDescription)"
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    private func formatCurrencyInput(_ input: String) -> String {
        let cleanedInput = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleanedInput.isEmpty { return "0,00" }
        let centavos = Int(cleanedInput) ?? 0
        let reais = centavos / 100
        let centavosRestantes = centavos % 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        let formattedReais = formatter.string(from: NSNumber(value: reais)) ?? "0"
        let formattedCentavos = String(format: "%02d", centavosRestantes)
        return "\(formattedReais),\(formattedCentavos)"
    }
} 