//
//  PremiumView.swift
//  PINEE
//
//  Created by Cássio Nunes on 23/06/25.
//

import SwiftUI

struct PremiumView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @Environment(\.colorScheme) var systemColorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedPlan: PremiumPlan = .monthly
    @StateObject private var iapManager = IAPManager.shared
    @State private var showSuccessMessage = false
    @State private var showErrorMessage = false
    var showNavigationTitle: Bool = true
    
    // Cores adaptativas para todos os modos
    private var backgroundColor: Color {
        if isMonochromaticMode {
            return systemColorScheme == .dark ? Color.black : Color.white
        } else {
            return systemColorScheme == .dark ? Color(UIColor.systemBackground) : Color(hex: "#F0FDF4")
        }
    }
    
    private var cardBackgroundColor: Color {
        if isMonochromaticMode {
            return systemColorScheme == .dark ? Color.black.opacity(0.8) : Color.white
        } else {
            return systemColorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.secondarySystemBackground)
        }
    }
    
    private var primaryColor: Color {
        if isMonochromaticMode {
            return MonochromaticColorManager.primaryGreen
        } else {
            return systemColorScheme == .dark ? .blue : Color(hex: "#F59E0B")
        }
    }
    
    private var secondaryColor: Color {
        if isMonochromaticMode {
            return MonochromaticColorManager.secondaryGreen
        } else {
            return systemColorScheme == .dark ? .blue : Color(hex: "#F97316")
        }
    }
    
    private var textColor: Color {
        if isMonochromaticMode {
            return systemColorScheme == .dark ? .white : .black
        } else {
            return systemColorScheme == .dark ? .white : .primary
        }
    }
    
    private var secondaryTextColor: Color {
        if isMonochromaticMode {
            return systemColorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7)
        } else {
            return systemColorScheme == .dark ? .white.opacity(0.7) : .secondary
        }
    }
    
    enum PremiumPlan: String, CaseIterable {
        case monthly = "monthly"
        case yearly = "yearly"
        
        var title: String {
            switch self {
            case .monthly: return "Mensal"
            case .yearly: return "Anual"
            }
        }
        
        var price: String {
            switch self {
            case .monthly: return "R$ 9,90"
            case .yearly: return "R$ 99,90"
            }
        }
        
        var savings: String? {
            switch self {
            case .monthly: return nil
            case .yearly: return "Economize 16%"
            }
        }
        
        var period: String {
            switch self {
            case .monthly: return "mês"
            case .yearly: return "ano"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerView
                    
                    // Planos
                    plansView
                    
                    // Benefícios
                    benefitsView
                    
                    // Botão de upgrade
                    upgradeButton
                    
                    // Termos e condições
                    termsView
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [backgroundColor, cardBackgroundColor]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(showNavigationTitle ? "Seja Premium" : "")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Ícone Premium
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [primaryColor, secondaryColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(systemColorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Desbloqueie o PINEE Premium")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                
                Text("Acesse recursos exclusivos e maximize seu controle financeiro")
                    .font(.system(size: 16))
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Plans View
    private var plansView: some View {
        VStack(spacing: 16) {
            Text("Escolha seu plano")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textColor)
            
            VStack(spacing: 12) {
                ForEach(PremiumPlan.allCases, id: \.self) { plan in
                    planCard(plan: plan)
                }
            }
        }
    }
    
    private func planCard(plan: PremiumPlan) -> some View {
        Button(action: {
            selectedPlan = plan
        }) {
            HStack(spacing: 16) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(selectedPlan == plan ? primaryColor : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if selectedPlan == plan {
                        Circle()
                            .fill(selectedPlan == plan ? primaryColor : Color.clear)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(textColor)
                        
                        if let savings = plan.savings {
                            Text(savings)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text("\(plan.price) por \(plan.period)")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedPlan == plan ? primaryColor.opacity(0.1) : cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedPlan == plan ? primaryColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Benefits View
    private var benefitsView: some View {
        VStack(spacing: 20) {
            Text("Benefícios Premium")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textColor)
            
            VStack(spacing: 16) {
                benefitRow(
                    icon: "chart.bar.fill",
                    title: "Relatórios Avançados",
                    description: "Análises detalhadas e gráficos interativos"
                )
                
                benefitRow(
                    icon: "square.and.arrow.up",
                    title: "Exportação de Dados",
                    description: "Exporte seus dados em PDF e Excel"
                )
                
                benefitRow(
                    icon: "icloud.fill",
                    title: "Backup na Nuvem",
                    description: "Sincronização automática e backup seguro"
                )
                
                benefitRow(
                    icon: "headphones",
                    title: "Suporte Prioritário",
                    description: "Atendimento exclusivo e resposta rápida"
                )
                
                benefitRow(
                    icon: "paintbrush.fill",
                    title: "Temas Personalizados",
                    description: "Personalize cores e aparência do app"
                )
                
                benefitRow(
                    icon: "infinity",
                    title: "Transações Ilimitadas",
                    description: "Sem limite de transações por mês"
                )
            }
        }
    }
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(primaryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)
            }
            
            Spacer()
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Upgrade Button
    private var upgradeButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                // TEMPORARIAMENTE COMENTADO - Adaptação para iOS 18
                /*
                Task {
                    await iapManager.purchasePremium()
                    if iapManager.isPremium {
                        authViewModel.setPremiumStatus(isPremium: true)
                        showSuccessMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSuccessMessage = false
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else if iapManager.errorMessage != nil {
                        showErrorMessage = true
                    }
                }
                */
                
                // Simular upgrade para manter funcionalidade visual
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessMessage = false
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                HStack {
                    if iapManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                    }
                    Text(iapManager.isLoading ? "Processando..." : "Fazer Upgrade para Premium")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [primaryColor, secondaryColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(systemColorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
            }
            .disabled(iapManager.isLoading)
            
            Button(action: {
                // TEMPORARIAMENTE COMENTADO - Adaptação para iOS 18
                /*
                Task {
                    await iapManager.restorePurchases()
                    if iapManager.isPremium {
                        authViewModel.setPremiumStatus(isPremium: true)
                        showSuccessMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSuccessMessage = false
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else if iapManager.errorMessage != nil {
                        showErrorMessage = true
                    }
                }
                */
                
                // Simular restauração
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessMessage = false
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Text("Restaurar Compras")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .disabled(iapManager.isLoading)
            
            Text("Cancelamento a qualquer momento")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .alert(isPresented: $showErrorMessage) {
            Alert(title: Text("Erro"), message: Text(iapManager.errorMessage ?? "Erro desconhecido"), dismissButton: .default(Text("OK")))
        }
        .overlay(
            Group {
                if showSuccessMessage {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                            Text("Upgrade realizado com sucesso!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        Spacer()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: showSuccessMessage)
                    .zIndex(1000)
                }
            }
        )
    }
    
    // MARK: - Terms View
    private var termsView: some View {
        VStack(spacing: 8) {
            Text("Ao fazer upgrade, você concorda com nossos")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Button("Termos de Uso") {
                    // Abrir termos de uso
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                
                Text("e")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Button("Política de Privacidade") {
                    // Abrir política de privacidade
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
            }
        }
    }
}

struct PremiumView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumView()
            .environmentObject(AuthViewModel())
    }
}



