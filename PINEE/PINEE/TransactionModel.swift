//
//  TransactionModel.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//

import Foundation

struct TransactionModel: Codable, Identifiable {
    var id: String?
    let userId: String
    let title: String?
    let description: String?
    let amount: Double
    let category: String
    let date: String
    let isIncome: Bool
    let type: String?
    let status: String?
    let createdAt: Date
    let isRecurring: Bool?
    let recurringFrequency: String?
    let recurringEndDate: String?
    let sourceTransactionId: String?
}
