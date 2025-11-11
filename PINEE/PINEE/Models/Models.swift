import Foundation

public enum PeriodFilter {
    case daily
    case weekly
    case monthly
    case yearly
    case custom
}

private func processConsolidatedBalance(documents: [Any], userId: String) {
    var receitasConsolidadas: Double = 0
    var despesasPagas: Double = 0
    var saldoInvestido: Double = 0
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    let consolidatedRange = globalDateManager.getConsolidatedBalanceDateRange()
    
    for doc in documents {
        let data = doc.data()
        let amount = (data["amount"] as? NSNumber)?.doubleValue ?? (data["amount"] as? Double) ?? 0
        let type = data["type"] as? String ?? ""
        let status = data["status"] as? String ?? ""
        let dateStr = data["date"] as? String ?? ""
        let title = data["title"] as? String ?? data["description"] as? String ?? "Sem título"
        
        if let date = dateFormatter.date(from: dateStr) {
            if type == "income" {
                if status == "consolidated" || status == "paid" || status == "received" {
                    receitasConsolidadas += amount
                }
            } else if type == "expense" {
                if status == "paid" {
                    despesasPagas += amount
                }
            } else if type == "investment" {
                saldoInvestido += amount
            }
        }
    }
    
    self.saldoConsolidado = receitasConsolidadas - despesasPagas
    self.saldoInvestido = saldoInvestido
}