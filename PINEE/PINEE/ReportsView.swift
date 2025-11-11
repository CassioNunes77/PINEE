//
//  ReportsView.swift
//  PINEE
//
//  Created by Cássio Nunes on 25/06/25.
//

import SwiftUI
import AudioToolbox
// import FirebaseFirestore
import StoreKit

struct ReportsView: View {
    // MARK: - Properties
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var globalDateManager: GlobalDateManager
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var transactions: [TransactionModel] = []
    @State private var isLoading = true
    @State private var selectedTypeSliceIndex: Int? = nil
    @State private var selectedIncomeCategorySliceIndex: Int? = nil
    @State private var selectedExpenseCategorySliceIndex: Int? = nil
    @State private var showPeriodFilters: Bool = false
    private let firebaseService = FirebaseRESTService.shared
    
    // MARK: - Computed Properties
    // Dados agrupados por período para o gráfico de linha
    private var timeSeriesData: [(date: Date, income: Double, expense: Double, label: String)] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var groupedData: [Date: (income: Double, expense: Double, label: String)] = [:]
        let calendar = Calendar.current
        
        for transaction in transactions {
            guard let transactionDate = dateFormatter.date(from: transaction.date) else { continue }
            
            // Agrupar por período baseado no tipo selecionado
            let keyDate: Date
            let labelFormatter = DateFormatter()
            labelFormatter.locale = Locale(identifier: "pt_BR")
            
            switch globalDateManager.periodType {
            case .monthly:
                // Agrupar por dia
                let components = calendar.dateComponents([.year, .month, .day], from: transactionDate)
                keyDate = calendar.date(from: components) ?? transactionDate
                labelFormatter.dateFormat = "dd/MM"
            case .yearly:
                // Agrupar por mês
                let components = calendar.dateComponents([.year, .month], from: transactionDate)
                keyDate = calendar.date(from: components) ?? transactionDate
                labelFormatter.dateFormat = "MMM"
            case .allTime:
                // Agrupar por mês
                let components = calendar.dateComponents([.year, .month], from: transactionDate)
                keyDate = calendar.date(from: components) ?? transactionDate
                labelFormatter.dateFormat = "MMM yyyy"
            }
            
            if groupedData[keyDate] == nil {
                groupedData[keyDate] = (income: 0, expense: 0, label: labelFormatter.string(from: keyDate))
            }
            
            if (transaction.type ?? "expense") == "income" {
                groupedData[keyDate]?.income += transaction.amount
            } else if (transaction.type ?? "expense") == "expense" {
                groupedData[keyDate]?.expense += transaction.amount
            }
        }
        
        // Ordenar por data
        return groupedData.sorted { $0.key < $1.key }.map { date, data in
            (date: date, income: data.income, expense: data.expense, label: data.label)
        }
    }
    
    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func summaryTile(
        title: String,
        value: Double,
        color: Color,
        change: Double?,
        isPositiveGood: Bool
    ) -> some View {
        let displayValue = formatCurrencyValue(value)
        let badge = changeBadge(change: change, isPositiveGood: isPositiveGood)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text(displayValue)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            if let badge = badge {
                badge
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.18),
                    color.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
    }
    
    private func changeBadge(change: Double?, isPositiveGood: Bool) -> AnyView? {
        guard let change = change, abs(change) > 0.0001 else {
            return nil
        }
        
        let isPositive = change >= 0
        let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        let changeText = formatter.string(from: NSNumber(value: change)) ?? "\(Int(change * 100))%"
        
        let (backgroundColor, foregroundColor): (Color, Color) = {
            if isPositive {
                return isPositiveGood
                ? (Color(hex: "#166534"), Color(hex: "#86EFAC"))
                : (Color(hex: "#7F1D1D"), Color(hex: "#FCA5A5"))
            } else {
                return isPositiveGood
                ? (Color(hex: "#7F1D1D"), Color(hex: "#FCA5A5"))
                : (Color(hex: "#166534"), Color(hex: "#86EFAC"))
            }
        }()
        
        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(changeText)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor.opacity(0.7))
            )
        )
    }
    
    private func trendPercentage(for values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let last = values.last ?? 0
        let previous = values[values.count - 2]
        guard previous != 0 else { return nil }
        return (last - previous) / previous
    }
    
    private func formatCurrencyValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0,00"
    }
    
    private struct ReportsIncomeExpenseLineChart: View {
        struct AxisLabel: Identifiable {
            let id = UUID()
            let position: CGFloat
            let text: String
        }
        
        let entries: [DashboardChartEntry]
        let incomeColor: Color
        let expenseColor: Color
        let axisColor: Color
        let periodType: GlobalDateManager.PeriodType
        let valueFormatter: (Double) -> String
        
        var body: some View {
            GeometryReader { geo in
                let size = geo.size
                let incomes = entries.map { $0.income }
                let expenses = entries.map { $0.expense }
                let maxValue = max(incomes.max() ?? 0, expenses.max() ?? 0, 1)
                let incomePoints = makePoints(values: incomes, size: size, maxValue: maxValue)
                let expensePoints = makePoints(values: expenses, size: size, maxValue: maxValue)
                let axisLabels = makeAxisLabels(count: entries.count)
                
                ZStack {
                    grid(in: size, axisColor: axisColor, axisLabels: axisLabels)
                    
                    if incomePoints.count > 1 {
                        fillPath(for: incomePoints, size: size)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        incomeColor.opacity(0.25),
                                        incomeColor.opacity(0.05)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    if incomePoints.count > 1 {
                        smoothPath(from: incomePoints)
                            .stroke(
                                incomeColor,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                    } else if let point = incomePoints.first {
                        Circle()
                            .fill(incomeColor)
                            .frame(width: 8, height: 8)
                            .position(point)
                    }
                    
                    if expensePoints.count > 1 {
                        smoothPath(from: expensePoints)
                            .stroke(
                                expenseColor.opacity(0.9),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 6])
                            )
                    } else if let point = expensePoints.first {
                        Circle()
                            .fill(expenseColor.opacity(0.9))
                            .frame(width: 8, height: 8)
                            .position(point)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
                .padding(.horizontal, 12)
            }
        }
        
        private func makePoints(values: [Double], size: CGSize, maxValue: Double) -> [CGPoint] {
            guard values.count > 0 else { return [] }
            let stepX = size.width / CGFloat(max(values.count - 1, 1))
            return values.enumerated().map { index, value in
                let x = stepX * CGFloat(index)
                let y = size.height - ((CGFloat(value) / CGFloat(maxValue)) * size.height)
                return CGPoint(x: x, y: y)
            }
        }
        
        private func smoothPath(from points: [CGPoint]) -> Path {
            var path = Path()
            guard points.count > 1 else {
                if let first = points.first {
                    path.addEllipse(in: CGRect(x: first.x - 2, y: first.y - 2, width: 4, height: 4))
                }
                return path
            }
            
            path.move(to: points[0])
            for index in 1..<points.count {
                let current = points[index]
                let previous = points[index - 1]
                let midPoint = CGPoint(x: (current.x + previous.x) / 2, y: (current.y + previous.y) / 2)
                path.addQuadCurve(to: midPoint, control: controlPoint(from: previous, to: midPoint))
                path.addQuadCurve(to: current, control: controlPoint(from: midPoint, to: current))
            }
            return path
        }
        
        private func fillPath(for points: [CGPoint], size: CGSize) -> Path {
            var path = Path()
            guard let first = points.first, let last = points.last else { return path }
            path.move(to: CGPoint(x: first.x, y: size.height))
            points.forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
            return path
        }
        
        private func controlPoint(from point1: CGPoint, to point2: CGPoint) -> CGPoint {
            var controlPoint = CGPoint(
                x: (point1.x + point2.x) / 2,
                y: (point1.y + point2.y) / 2
            )
            let deltaY = abs(point2.y - controlPoint.y)
            if point1.y < point2.y {
                controlPoint.y += deltaY
            } else if point1.y > point2.y {
                controlPoint.y -= deltaY
            }
            return controlPoint
        }
        
        private func grid(in size: CGSize, axisColor: Color, axisLabels: [AxisLabel]) -> some View {
            ZStack {
                Path { path in
                    for index in 0...4 {
                        let y = size.height * CGFloat(index) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(axisColor, lineWidth: 1)
                
                ForEach(axisLabels) { label in
                    Text(label.text)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .position(x: label.position * size.width, y: size.height + 14)
                }
            }
        }
        
        private func makeAxisLabels(count: Int) -> [AxisLabel] {
            guard count > 0 else { return [] }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            
            switch periodType {
            case .monthly:
                formatter.dateFormat = "dd/MM"
            case .yearly:
                formatter.dateFormat = "MMM"
            case .allTime:
                formatter.dateFormat = "MMM yy"
            }
            
            let strideValue = max(1, count / 6)
            return entries.enumerated().compactMap { index, entry in
                guard index % strideValue == 0 || index == count - 1 else { return nil }
                let position = CGFloat(index) / CGFloat(max(count - 1, 1))
                return AxisLabel(position: position, text: formatter.string(from: entry.date))
            }
        }
    }
    
    private var incomeExpenseEntries: [DashboardChartEntry] {
        timeSeriesData.map { DashboardChartEntry(date: $0.date, income: $0.income, expense: $0.expense) }
    }
    
    private var expenseCategoryDistribution: [(String, Double, Color)] {
        var categoryTotals: [String: Double] = [:]
        
        for transaction in transactions where (transaction.type ?? "expense") == "expense" {
            let category = transaction.category.isEmpty ? "Outros" : transaction.category
            categoryTotals[category, default: 0] += transaction.amount
        }
        
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        let colors: [Color] = isMonochromaticMode ? [
            MonochromaticColorManager.primaryGreen,
            MonochromaticColorManager.primaryGray,
            MonochromaticColorManager.secondaryGreen,
            MonochromaticColorManager.secondaryGray,
            MonochromaticColorManager.tertiaryGreen
        ] : [
            .red, .orange, .purple, .pink, .brown
        ]
        
        return sortedCategories.enumerated().map { index, item in
            (item.key, item.value, colors[index % colors.count])
        }
    }
    
    private var incomeCategoryDistribution: [(String, Double, Color)] {
        var categoryTotals: [String: Double] = [:]
        
        for transaction in transactions where (transaction.type ?? "expense") == "income" {
            let category = transaction.category.isEmpty ? "Outros" : transaction.category
            categoryTotals[category, default: 0] += transaction.amount
        }
        
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        let colors: [Color] = [
            isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green,
            isMonochromaticMode ? MonochromaticColorManager.secondaryGreen : .blue,
            isMonochromaticMode ? MonochromaticColorManager.tertiaryGreen : .teal,
            isMonochromaticMode ? MonochromaticColorManager.quaternaryGreen : .cyan,
            isMonochromaticMode ? MonochromaticColorManager.quinaryGreen : .mint
        ]
        
        return sortedCategories.enumerated().map { index, item in
            (item.key, item.value, colors[index % colors.count])
        }
    }
    
    private var statusDistribution: [(String, Double, Color)] {
        var paidTotal: Double = 0
        var unpaidTotal: Double = 0
        var receivedTotal: Double = 0
        var pendingTotal: Double = 0
        
        for transaction in transactions {
            if (transaction.type ?? "expense") == "expense" {
                if transaction.status == "paid" {
                    paidTotal += transaction.amount
                } else {
                    unpaidTotal += transaction.amount
                }
            } else if (transaction.type ?? "expense") == "income" {
                if transaction.status == "received" {
                    receivedTotal += transaction.amount
                } else {
                    pendingTotal += transaction.amount
                }
            }
        }
        
        let total = paidTotal + unpaidTotal + receivedTotal + pendingTotal
        guard total > 0 else { return [] }
        
        return [
            ("Pago", paidTotal, isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green),
            ("Não Pago", unpaidTotal, isMonochromaticMode ? MonochromaticColorManager.primaryGray : .red),
            ("Recebido", receivedTotal, isMonochromaticMode ? MonochromaticColorManager.secondaryGreen : .blue),
            ("Pendente", pendingTotal, isMonochromaticMode ? MonochromaticColorManager.secondaryGray : .orange)
        ]
    }
    
    private var summaryStats: (totalIncome: Double, totalExpense: Double, balance: Double) {
        var income: Double = 0
        var expense: Double = 0
        
        for transaction in transactions {
            if (transaction.type ?? "expense") == "income" {
                income += transaction.amount
            } else if (transaction.type ?? "expense") == "expense" {
                expense += transaction.amount
            }
        }
        
        return (income, expense, income - expense)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header com filtro de período
            filterView
                .background(Color(UIColor.systemBackground))
            
            Divider()
                .opacity(0.3)
            
            if isLoading {
                loadingView
            } else if transactions.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        // Resumo geral
                        summaryCardsView
                            .padding(.horizontal, 16)
                        // Gráfico de linha - Receitas e Despesas
                        typeDistributionView
                            .padding(.vertical, 8)
                        Divider().opacity(0).frame(height: 24)
                        incomeCategoryChartView
                            .frame(height: 440)
                            .padding(.vertical, 8)
                        Divider().opacity(0).frame(height: 24)
                        expenseCategoryChartView
                            .frame(height: 440)
                            .padding(.vertical, 8)
                        Spacer(minLength: 32) // Borda final após o último gráfico
                    }
                    .padding(.vertical, 16)
                    Spacer(minLength: 120) // Espaço extra para não colar no menu inferior
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadTransactions()
        }
        .onChange(of: globalDateManager.selectedDate) { _ in
            loadTransactions()
        }
        .onChange(of: globalDateManager.periodType) { _ in
            loadTransactions()
        }
    }
    
    // MARK: - Views
    private var filterView: some View {
        VStack(spacing: 12) {
            // Navegação de período com data
            HStack(spacing: 16) {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(globalDateManager.periodType == .allTime ? .secondary : .primary)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(
                            Group {
                                if isMonochromaticMode {
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            MonochromaticColorManager.secondaryGray.opacity(0.3),
                                            MonochromaticColorManager.primaryGray.opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    // Cores adaptativas para modo claro/escuro
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(UIColor.secondarySystemBackground),
                                            Color(UIColor.tertiarySystemBackground)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(globalDateManager.periodType == .allTime)
                
                Spacer()
                
                // Data atual (clicável para mostrar filtros)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showPeriodFilters.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(globalDateManager.getCurrentDateRange().displayText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        if globalDateManager.periodType != .allTime {
                            Text(getPeriodSubtitle())
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(globalDateManager.periodType == .allTime ? .secondary : .primary)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(
                            Group {
                                if isMonochromaticMode {
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            MonochromaticColorManager.secondaryGray.opacity(0.3),
                                            MonochromaticColorManager.primaryGray.opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    // Cores adaptativas para modo claro/escuro
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(UIColor.secondarySystemBackground),
                                            Color(UIColor.tertiarySystemBackground)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(globalDateManager.periodType == .allTime)
            }
            .padding(.horizontal, 20)
            
            // Filtros de período (chips) - ocultos até clicar na data
            if showPeriodFilters {
                HStack(spacing: 8) {
                    periodChip(
                        title: "Mensal",
                        icon: "calendar",
                        isSelected: globalDateManager.periodType == .monthly,
                        action: {
                            globalDateManager.updatePeriodType(.monthly)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showPeriodFilters = false
                            }
                        }
                    )
                    
                    periodChip(
                        title: "Anual",
                        icon: "calendar.badge.clock",
                        isSelected: globalDateManager.periodType == .yearly,
                        action: {
                            globalDateManager.updatePeriodType(.yearly)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showPeriodFilters = false
                            }
                        }
                    )
                    
                    periodChip(
                        title: "Todo o período",
                        icon: "infinity",
                        isSelected: globalDateManager.periodType == .allTime,
                        action: {
                            globalDateManager.updatePeriodType(.allTime)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showPeriodFilters = false
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 12)
    }
    
    private func getPeriodSubtitle() -> String {
        switch globalDateManager.periodType {
        case .monthly:
            return "Período mensal"
        case .yearly:
            return "Período anual"
        case .allTime:
            return "Todo o histórico"
        }
    }
    
    private func periodChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            // Feedback tátil
            FeedbackService.shared.triggerLight()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ?
                                [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.secondarySystemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(
                color: isSelected ? (isMonochromaticMode ? MonochromaticColorManager.primaryGreen.opacity(0.3) : Color(hex: "#3B82F6").opacity(0.3)) : Color.black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                x: 0,
                y: isSelected ? 4 : 1
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Carregando estatísticas...")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "chart.pie")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("Nenhum dado encontrado")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Neste período não há transações para gerar estatísticas")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private var summaryCardsView: some View {
        VStack(spacing: 12) {
            // Cards de receita e despesa
            HStack(spacing: 12) {
                summaryCard(
                    title: "Receitas",
                    value: formatCurrency(summaryStats.totalIncome),
                    icon: "arrow.up",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.darkGreen, MonochromaticColorManager.primaryGreen] :
                        [Color(hex: "#22C55E"), Color(hex: "#16A34A")]
                )
                
                summaryCard(
                    title: "Despesas",
                    value: formatCurrency(summaryStats.totalExpense),
                    icon: "arrow.down",
                    gradientColors: isMonochromaticMode ? 
                        [MonochromaticColorManager.darkGray, MonochromaticColorManager.primaryGray] :
                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
                )
            }
            
            // Saldo
            saldoCard
        }
    }
    
    private func summaryCard(title: String, value: String, icon: String, gradientColors: [Color]) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))

                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)

            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .padding(8)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    private var saldoCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                Text(formatCurrency(summaryStats.balance))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: isMonochromaticMode ? 
                    [MonochromaticColorManager.lightGreen, MonochromaticColorManager.primaryGreen] :
                    [Color(hex: "#7C3AED"), Color(hex: "#6D28D9")]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    private var typeDistributionView: some View {
        let entries = incomeExpenseEntries
        let rangeDescription = globalDateManager.getCurrentDateRange().displayText
        let incomeLineColor = isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#22C55E")
        let expenseLineColor = isMonochromaticMode ? MonochromaticColorManager.primaryGray : Color(hex: "#EF4444")
        let axisColor = Color.white.opacity(isMonochromaticMode ? 0.2 : 0.15)
        let incomeTotal = entries.reduce(0) { $0 + $1.income }
        let expenseTotal = entries.reduce(0) { $0 + $1.expense }
        let incomeTrend = trendPercentage(for: entries.map { $0.income })
        let expenseTrend = trendPercentage(for: entries.map { $0.expense })
        
        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Receitas vs Despesas")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(rangeDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    legendItem(color: incomeLineColor, title: "Receitas")
                    legendItem(color: expenseLineColor, title: "Despesas")
                }
            }
            
            if entries.count >= 2 {
                ReportsIncomeExpenseLineChart(
                    entries: entries,
                    incomeColor: incomeLineColor,
                    expenseColor: expenseLineColor,
                    axisColor: axisColor,
                    periodType: globalDateManager.periodType,
                    valueFormatter: { formatCurrencyValue($0) }
                )
                .frame(height: 220)
            } else if let entry = entries.first {
                ReportsIncomeExpenseLineChart(
                    entries: [entry, entry],
                    incomeColor: incomeLineColor,
                    expenseColor: expenseLineColor,
                    axisColor: axisColor,
                    periodType: globalDateManager.periodType,
                    valueFormatter: { formatCurrencyValue($0) }
                )
                .frame(height: 220)
            } else {
                VStack(spacing: 12) {
                    Text("Ainda não há dados suficientes para o gráfico.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            }
            
            HStack(spacing: 16) {
                summaryTile(
                    title: "Receitas",
                    value: incomeTotal,
                    color: incomeLineColor,
                    change: incomeTrend,
                    isPositiveGood: true
                )
                
                summaryTile(
                    title: "Despesas",
                    value: expenseTotal,
                    color: expenseLineColor,
                    change: expenseTrend,
                    isPositiveGood: false
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if isMonochromaticMode {
                    Color(UIColor.systemGray5)
                } else {
                    Color(UIColor.secondarySystemBackground)
                }
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    isMonochromaticMode ? Color.black.opacity(0.08) : Color.black.opacity(0.05),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var incomeCategoryChartView: some View {
        let chartSize = UIScreen.main.bounds.width * 0.8
        return VStack(alignment: .center, spacing: 16) {
            Text("Receitas por categoria")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            ZStack {
                Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: 18)
                    .frame(width: chartSize, height: chartSize)
                ForEach(Array(incomeCategoryDistribution.enumerated()), id: \.offset) { index, item in
                    PieSliceView(
                        startAngle: startAngle(for: index, data: incomeCategoryDistribution),
                        endAngle: endAngle(for: index, data: incomeCategoryDistribution),
                        color: item.2,
                        strokeWidth: 18
                    )
                    .frame(width: chartSize, height: chartSize)
                    .scaleEffect(selectedIncomeCategorySliceIndex == index ? 1.07 : 1.0)
                    .shadow(color: selectedIncomeCategorySliceIndex == index ? item.2.opacity(0.3) : .clear, radius: 12)
                    .animation(.easeInOut(duration: 0.3), value: selectedIncomeCategorySliceIndex)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedIncomeCategorySliceIndex = selectedIncomeCategorySliceIndex == index ? nil : index
                        }
                    }
                }
                if let selected = selectedIncomeCategorySliceIndex {
                    let item = incomeCategoryDistribution[selected]
                    VStack {
                        Text("\(item.0): \(formatCurrency(item.1))")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(10)
                            .background(Color(.systemBackground).opacity(0.97))
                            .cornerRadius(10)
                            .shadow(radius: 6)
                        Spacer()
                    }
                    .frame(width: chartSize, height: chartSize)
                    .offset(y: -chartSize * 0.32)
                    .animation(.easeInOut, value: selectedIncomeCategorySliceIndex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            VStack(spacing: 8) {
                ForEach(incomeCategoryDistribution, id: \.0) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.2)
                            .frame(width: 12, height: 12)
                        Text(item.0)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(formatPercentage(calculatePercentage(item.1, total: incomeCategoryDistribution.reduce(0) { $0 + $1.1 })))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            if !incomeCategoryDistribution.isEmpty {
                let total = incomeCategoryDistribution.reduce(0) { $0 + $1.1 }
                let maxItem = incomeCategoryDistribution.max(by: { $0.1 < $1.1 })
                let minItem = incomeCategoryDistribution.min(by: { $0.1 < $1.1 })
                HStack(spacing: 20) {
                    if let maxItem = maxItem {
                        VStack(spacing: 2) {
                            Text("Pico:")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(maxItem.1))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let minItem = minItem {
                        VStack(spacing: 2) {
                            Text("Mínimo:")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(minItem.1))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 2) {
                        Text("Total:")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(formatCurrency(total))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .frame(maxWidth: .infinity)
        .clipped()
    }
    
    private var expenseCategoryChartView: some View {
        let chartSize = UIScreen.main.bounds.width * 0.8
        return VStack(alignment: .center, spacing: 16) {
            Text("Despesas por categoria")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            ZStack {
                Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: 18)
                    .frame(width: chartSize, height: chartSize)
                ForEach(Array(expenseCategoryDistribution.enumerated()), id: \.offset) { index, item in
                    PieSliceView(
                        startAngle: startAngle(for: index, data: expenseCategoryDistribution),
                        endAngle: endAngle(for: index, data: expenseCategoryDistribution),
                        color: item.2,
                        strokeWidth: 18
                    )
                    .frame(width: chartSize, height: chartSize)
                    .scaleEffect(selectedExpenseCategorySliceIndex == index ? 1.07 : 1.0)
                    .shadow(color: selectedExpenseCategorySliceIndex == index ? item.2.opacity(0.3) : .clear, radius: 12)
                    .animation(.easeInOut(duration: 0.3), value: selectedExpenseCategorySliceIndex)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedExpenseCategorySliceIndex = selectedExpenseCategorySliceIndex == index ? nil : index
                        }
                    }
                }
                if let selected = selectedExpenseCategorySliceIndex {
                    let item = expenseCategoryDistribution[selected]
                    VStack {
                        Text("\(item.0): \(formatCurrency(item.1))")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(10)
                            .background(Color(.systemBackground).opacity(0.97))
                            .cornerRadius(10)
                            .shadow(radius: 6)
                        Spacer()
                    }
                    .frame(width: chartSize, height: chartSize)
                    .offset(y: -chartSize * 0.32)
                    .animation(.easeInOut, value: selectedExpenseCategorySliceIndex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            VStack(spacing: 8) {
                ForEach(expenseCategoryDistribution, id: \.0) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.2)
                            .frame(width: 12, height: 12)
                        Text(item.0)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(formatPercentage(calculatePercentage(item.1, total: expenseCategoryDistribution.reduce(0) { $0 + $1.1 })))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            if !expenseCategoryDistribution.isEmpty {
                let total = expenseCategoryDistribution.reduce(0) { $0 + $1.1 }
                let maxItem = expenseCategoryDistribution.max(by: { $0.1 < $1.1 })
                let minItem = expenseCategoryDistribution.min(by: { $0.1 < $1.1 })
                HStack(spacing: 20) {
                    if let maxItem = maxItem {
                        VStack(spacing: 2) {
                            Text("Pico:")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(maxItem.1))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let minItem = minItem {
                        VStack(spacing: 2) {
                            Text("Mínimo:")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(minItem.1))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 2) {
                        Text("Total:")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(formatCurrency(total))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .frame(maxWidth: .infinity)
        .clipped()
    }
    
    // MARK: - Functions
    private func calculatePercentage(_ value: Double, total: Double) -> Double {
        guard total > 0 else { return 0 }
        return (value / total) * 100
    }
    
    private func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
    
    private func startAngle(for index: Int, data: [(String, Double, Color)]) -> Double {
        let total = data.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        
        var angle: Double = -90 // Começar do topo
        for i in 0..<index {
            angle += (data[i].1 / total) * 360
        }
        return angle
    }
    
    private func endAngle(for index: Int, data: [(String, Double, Color)]) -> Double {
        let total = data.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        
        var angle: Double = -90 // Começar do topo
        for i in 0...index {
            angle += (data[i].1 / total) * 360
        }
        return angle
    }
    
    private func previousMonth() {
        // Feedback tátil
        FeedbackService.shared.triggerLight()
        
        globalDateManager.previousPeriod()
    }
    
    private func nextMonth() {
        // Feedback tátil
        FeedbackService.shared.triggerLight()
        
        globalDateManager.nextPeriod()
    }
    
    private func loadTransactions() {
        guard let userId = authViewModel.user?.id,
              let idToken = authViewModel.user?.idToken else {
            print("⚠️ UserId ou idToken não encontrado")
            isLoading = false
            return
        }
        
        isLoading = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let currentRange = globalDateManager.getCurrentDateRange()
        let startDate = dateFormatter.string(from: currentRange.start)
        let endDate = dateFormatter.string(from: currentRange.end)
        
        print("🔍 Carregando estatísticas")
        print("👤 UserId: \(userId)")
        print("📅 Período: \(startDate) até \(endDate)")
        
        Task {
            do {
                print("🔄 Carregando transações do Firebase para userId: \(userId)")
                print("📅 Período: \(startDate) até \(endDate)")
                
                let firebaseTransactions = try await firebaseService.getTransactions(
                    userId: userId,
                    startDate: startDate,
                    endDate: endDate,
                    idToken: idToken
                )
                
                print("✅ Transações carregadas do Firebase: \(firebaseTransactions.count) transações")
                
                await MainActor.run {
                    self.transactions = firebaseTransactions.sorted { $0.createdAt > $1.createdAt }
                    print("✅ Estatísticas atualizadas: \(self.transactions.count) transações")
                    self.isLoading = false
                }
            } catch {
                print("❌ Erro ao carregar transações: \(error.localizedDescription)")
                await MainActor.run {
                    self.transactions = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}

struct PieSliceView: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    let strokeWidth: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = (size - strokeWidth) / 2

            Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(degrees: startAngle),
                endAngle: Angle(degrees: endAngle),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(color)
        }
    }
}

struct ReportsView_Previews: PreviewProvider {
    static var previews: some View {
        ReportsView()
            .environmentObject(AuthViewModel())
            .environmentObject(GlobalDateManager())
    }
}
