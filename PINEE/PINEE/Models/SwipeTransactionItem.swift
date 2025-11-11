import SwiftUI

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
                isIncome: transaction.isIncome
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