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
        // } else {
            return Color.red
        }
    }
    
    private var iconName: String {
        if transactionType == "investment" {
            return "chart.line.uptrend.xyaxis"
        } else if isIncome {
            return "chevron.up"
        // } else {
            return "chevron.down"
        }
    }
    
    private var amountColor: Color {
        if transactionType == "investment" {
            return Color.blue
        } else if isIncome {
            return Color.green
        // } else {
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
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 80)
                        .background(Color.red)
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