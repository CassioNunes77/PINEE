//
//  SwipeTransactionItem.swift
//  PINEE
//
//  Created by Cássio Nunes on 24/06/25.
//

import Foundation
import SwiftUI

struct TransactionItemView: View {
    let title: String
    let category: String
    let amount: String
    let date: String
    let isIncome: Bool
    let transactionType: String
    
    // Computed properties para quebrar a complexidade
    private var circleColor: Color {
        if transactionType == "investment" {
            return Color.blue
        } else if isIncome {
            return Color.green
        } else {
            return Color.red
        }
    }
    
    private var iconName: String {
        if transactionType == "investment" {
            return "chart.line.uptrend.xyaxis"
        } else if isIncome {
            return "chevron.up"
        } else {
            return "chevron.down"
        }
    }
    
    private var amountColor: Color {
        if transactionType == "investment" {
            return Color.blue
        } else if isIncome {
            return Color.green
        } else {
            return Color.red
        }
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(circleColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Text(category)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(amountColor)
                Text(date)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct SwipeTransactionItem: View {
    let transaction: TransactionModel
    let onEdit: () -> Void
    let onDelete: () -> Void
    let formatCurrency: (Double) -> String
    let formatShortDate: (String) -> String

    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    private let swipeThreshold: CGFloat = 50

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 80)
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 80)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }

            TransactionItemView(
                title: transaction.title ?? transaction.description ?? "-",
                category: transaction.category,
                amount: formatCurrency(transaction.amount),
                date: formatShortDate(transaction.date),
                isIncome: transaction.isIncome,
                transactionType: transaction.type ?? "expense"
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation {
                            if value.translation.width < -swipeThreshold {
                                offset = -120
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
            .onTapGesture {
                if isSwiped {
                    withAnimation {
                        offset = 0
                        isSwiped = false
                    }
                }
            }
        }
    }
}

struct SwipeTransactionItem_Previews: PreviewProvider {
    static var previews: some View {
        SwipeTransactionItem(
            transaction: TransactionModel(
                id: "1",
                userId: "user1",
                title: "Compra no mercado",
                description: "Compras do mês",
                amount: 150.0,
                category: "Alimentação",
                date: "2025-06-24",
                isIncome: false,
                type: "expense",
                status: "paid",
                createdAt: Date(),
                isRecurring: false,
                recurringFrequency: "",
                recurringEndDate: "",
                sourceTransactionId: nil
            ),
            onEdit: {},
            onDelete: {},
            formatCurrency: { value in
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = "BRL"
                formatter.locale = Locale(identifier: "pt_BR")
                return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
            },
            formatShortDate: { dateStr in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: dateStr) {
                    let outFormatter = DateFormatter()
                    outFormatter.locale = Locale(identifier: "pt_BR")
                    outFormatter.dateFormat = "dd MMM"
                    return outFormatter.string(from: date)
                }
                return dateStr
            }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
