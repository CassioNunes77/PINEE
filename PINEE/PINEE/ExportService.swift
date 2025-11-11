//
//  ExportService.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//

import Foundation
import UIKit
// import FirebaseFirestore

class ExportService: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportMessage = ""
    
    private let db: Any? = nil // Firestore.firestore() temporariamente desabilitado
    
    func exportTransactionsToCSV(
        userId: String,
        dateRange: DateRange,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            self.isExporting = true
            self.exportProgress = 0.0
            self.exportMessage = "Preparando exportação..."
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startStr = dateFormatter.string(from: dateRange.start)
        let endStr = dateFormatter.string(from: dateRange.end)
        
        DispatchQueue.main.async {
            self.exportMessage = "Buscando transações..."
            self.exportProgress = 0.2
        }
        
        // Buscar transações do período
        db// .collection("transactions")
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: startStr)
            .whereField("date", isLessThanOrEqualTo: endStr)
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.isExporting = false
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.isExporting = false
                        completion(.failure(ExportError.noDataFound))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.exportMessage = "Processando \(documents.count) transações..."
                    self.exportProgress = 0.4
                }
                
                // Processar transações
                let transactions = documents.compactMap { doc -> TransactionModel? in
                    let data = doc.data()
                    
                    return TransactionModel(
                        id: doc.documentID,
                        userId: userId,
                        title: data["title"] as? String ?? data["description"] as? String ?? "-",
                        description: data["description"] as? String ?? "",
                        amount: (data["amount"] as? NSNumber)?.doubleValue ?? 0,
                        category: data["category"] as? String ?? "",
                        date: data["date"] as? String ?? "",
                        isIncome: (data["type"] as? String ?? "") == "income",
                        type: data["type"] as? String ?? "",
                        status: data["status"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        isRecurring: data["isRecurring"] as? Bool ?? false,
                        recurringFrequency: data["recurringFrequency"] as? String ?? "",
                        recurringEndDate: data["recurringEndDate"] as? String ?? "",
                        sourceTransactionId: data["sourceTransactionId"] as? String ?? nil
                    )
                }
                
                DispatchQueue.main.async {
                    self.exportMessage = "Gerando arquivo CSV..."
                    self.exportProgress = 0.6
                }
                
                // Gerar CSV
                let csvContent = self.generateCSVContent(transactions: transactions, dateRange: dateRange)
                
                DispatchQueue.main.async {
                    self.exportMessage = "Salvando arquivo..."
                    self.exportProgress = 0.8
                }
                
                // Salvar arquivo
                do {
                    let fileURL = try self.saveCSVToFile(csvContent: csvContent, dateRange: dateRange)
                    
                    DispatchQueue.main.async {
                        self.exportMessage = "Exportação concluída!"
                        self.exportProgress = 1.0
                        self.isExporting = false
                        completion(.success(fileURL))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isExporting = false
                        completion(.failure(error))
                    }
                }
            }
    }
    
    private func generateCSVContent(transactions: [TransactionModel], dateRange: DateRange) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        let displayDateFormatter = DateFormatter()
        displayDateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        
        // Cabeçalho CSV
        var csvContent = "Data,Descrição,Categoria,Tipo,Valor,Status,Recorrente,Frequência,Data de Criação\n"
        
        // Dados das transações
        for transaction in transactions {
            let date = dateFormatter.date(from: transaction.date) ?? Date()
            let formattedDate = dateFormatter.string(from: date)
            
            let description = (transaction.title ?? transaction.description ?? "-")
                .replacingOccurrences(of: ",", with: ";")
                .replacingOccurrences(of: "\"", with: "'")
            
            let category = transaction.category.replacingOccurrences(of: ",", with: ";")
            let type = transaction.isIncome ? "Receita" : "Despesa"
            let amount = String(format: "%.2f", transaction.amount)
            let status = self.translateStatus(transaction.status)
            let isRecurring = transaction.isRecurring ?? false ? "Sim" : "Não"
            let frequency = self.translateFrequency(transaction.recurringFrequency ?? "")
            let createdAt = displayDateFormatter.string(from: transaction.createdAt)
            
            let row = "\(formattedDate),\"\(description)\",\(category),\(type),\(amount),\(status),\(isRecurring),\(frequency),\(createdAt)\n"
            csvContent += row
        }
        
        return csvContent
    }
    
    private func translateStatus(_ status: String) -> String {
        switch status {
        case "paid": return "Pago"
        case "unpaid": return "Não Pago"
        case "received": return "Recebido"
        case "pending": return "Pendente"
        case "consolidated": return "Consolidado"
        default: return status.capitalized
        }
    }
    
    private func translateFrequency(_ frequency: String) -> String {
        switch frequency {
        case "monthly": return "Mensal"
        case "weekly": return "Semanal"
        case "yearly": return "Anual"
        default: return frequency.capitalized
        }
    }
    
    private func saveCSVToFile(csvContent: String, dateRange: DateRange) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDate = dateFormatter.string(from: dateRange.start)
        let endDate = dateFormatter.string(from: dateRange.end)
        
        let fileName = "PINEE_Transacoes_\(startDate)_\(endDate).csv"
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExportError.fileSystemError
        }
        
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    func shareCSVFile(fileURL: URL) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

enum ExportError: Error, LocalizedError {
    case noDataFound
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .noDataFound:
            return "Nenhuma transação encontrada para o período selecionado"
        case .fileSystemError:
            return "Erro ao salvar arquivo no sistema"
        }
    }
} 