import SwiftUI

struct MoreView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var globalDateManager: GlobalDateManager
    @State private var showExportData = false
    @State private var showImportData = false
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var scrollToTopID = UUID()
    @State private var isAppeared = false
    @State private var showLogoutConfirmation = false
    private let feedbackService = FeedbackService.shared
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                    // Anchor para scroll to top
                    Color.clear
                        .frame(height: 0)
                        .id("top")
                    
                        quickAccessSection
                        toolsSection
                        settingsSection
                        supportSection
                        informationSection
                        logoutSection
                    Spacer(minLength: 100)
                }
                .padding(.vertical, 16)
                .padding(.bottom, 120)
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 20)
            }
            .onChange(of: scrollToTopID) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarHidden(true) // Esconde a barra de navegação
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAppeared = true
            }
        }
        .onDisappear {
            isAppeared = false
        }
        .sheet(isPresented: $showExportData) {
            ExportView()
                .environmentObject(authViewModel)
                .environmentObject(globalDateManager)
        }
        .sheet(isPresented: $showImportData) {
            // View para importar dados - precisa ser implementada
            Text("Importar Dados")
                .navigationTitle("Importar Dados")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetMoreView"))) { _ in
            // Quando receber a notificação, fazer scroll para o topo
            scrollToTopID = UUID()
        }
        .overlay(
            Group {
                if showLogoutConfirmation {
                    LogoutConfirmationView(
                        title: "Sair da conta?",
                        message: "Você precisará entrar novamente para acessar seus dados.",
                        confirmTitle: "Sair",
                        cancelTitle: "Cancelar",
                        confirmAction: {
                            showLogoutConfirmation = false
                            authViewModel.signOut()
                        },
                        cancelAction: {
                            showLogoutConfirmation = false
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(5)
                }
            }
        )
        }

    // MARK: - Section Helpers
    @ViewBuilder
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Acesso Rápido")
                .font(.headline)
                .foregroundColor(.secondary)
            
            NavigationLink(destination: ProfileView().environmentObject(authViewModel)) {
                toolRow(
                    icon: "person.circle.fill",
                    iconColor: primaryIconColor,
                    title: "Perfil",
                    subtitle: "Gerencie sua conta e informações"
                )
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                feedbackService.triggerLight()
            })
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ferramentas")
                .font(.headline)
                .foregroundColor(.secondary)
            
            toolNavigationCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: primaryIconColor,
                title: "Investimentos",
                subtitle: "Acompanhe seus investimentos"
            ) {
                InvestmentsView()
                    .environmentObject(authViewModel)
                    .environmentObject(globalDateManager)
            }
            
            toolNavigationCard(
                icon: "target",
                iconColor: secondaryIconColor,
                title: "Metas",
                subtitle: "Defina e acompanhe suas metas"
            ) {
                NavigationView {
                    GoalsView()
                        .environmentObject(authViewModel)
                        .environmentObject(globalDateManager)
                }
            }
            
            toolNavigationCard(
                icon: "chart.pie.fill",
                iconColor: primaryIconColor,
                title: "Estatísticas",
                subtitle: "Visualize gráficos e análises"
            ) {
                ReportsView()
                    .environmentObject(authViewModel)
                    .environmentObject(globalDateManager)
            }
            
            toolNavigationCard(
                icon: "trophy.fill",
                iconColor: tertiaryIconColor,
                title: "Conquistas",
                subtitle: "Veja suas conquistas e badges"
            ) {
                AchievementsView()
                    .environmentObject(authViewModel)
            }
            
            toolNavigationCard(
                icon: "brain.head.profile",
                iconColor: tertiaryIconColor,
                title: "AI Assistant",
                subtitle: "Assistente inteligente para finanças"
            ) {
                AIAssistantView()
                    .environmentObject(authViewModel)
            }
            
            toolNavigationCard(
                icon: "folder.fill",
                iconColor: tertiaryIconColor,
                title: "Categorias",
                subtitle: "Gerencie suas categorias"
            ) {
                CategoriesView()
                    .environmentObject(authViewModel)
            }
            
            Button(action: {
                feedbackService.triggerLight()
                showImportData = true
            }) {
                toolRow(
                    icon: "square.and.arrow.down",
                    iconColor: primaryIconColor,
                    title: "Importar Dados",
                    subtitle: "Restaurar dados de backup"
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                feedbackService.triggerLight()
                showExportData = true
            }) {
                toolRow(
                    icon: "square.and.arrow.up",
                    iconColor: secondaryIconColor,
                    title: "Exportar Dados",
                    subtitle: "Backup e compartilhamento"
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configurações")
                .font(.headline)
                .foregroundColor(.secondary)
            
            toolNavigationCard(
                icon: "bell.fill",
                iconColor: primaryIconColor,
                title: "Notificações",
                subtitle: "Gerencie alertas e lembretes"
            ) {
                NotificationsView()
                    .environmentObject(authViewModel)
            }
            
            toolNavigationCard(
                icon: "gearshape.fill",
                iconColor: neutralIconColor,
                title: "Ajustes",
                subtitle: "Configurações do aplicativo"
            ) {
                SettingsView()
                    .environmentObject(authViewModel)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suporte")
                .font(.headline)
                .foregroundColor(.secondary)
            
            toolNavigationCard(
                icon: "questionmark.circle.fill",
                iconColor: tertiaryIconColor,
                title: "Central de Ajuda",
                subtitle: "Tutoriais e perguntas frequentes"
            ) {
                HelpCenterView()
                    .environmentObject(authViewModel)
            }
            
            toolNavigationCard(
                icon: "bubble.left.fill",
                iconColor: primaryIconColor,
                title: "Feedback",
                subtitle: "Envie sua opinião"
            ) {
                FeedbackView()
                    .environmentObject(authViewModel)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Informações")
                .font(.headline)
                .foregroundColor(.secondary)
            
            toolNavigationCard(
                icon: "info.circle.fill",
                iconColor: neutralIconColor,
                title: "Sobre o App",
                subtitle: "Versão e informações técnicas"
            ) {
                AboutAppView()
            }
            
            toolNavigationCard(
                icon: "hand.raised.fill",
                iconColor: neutralIconColor,
                title: "Política de Privacidade",
                subtitle: "Como protegemos seus dados"
            ) {
                PrivacyPolicyView()
                    .environmentObject(authViewModel)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var logoutSection: some View {
        Button(action: {
            feedbackService.triggerHeavy()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showLogoutConfirmation = true
            }
        }) {
            toolRow(
                icon: "rectangle.portrait.and.arrow.right",
                iconColor: destructiveIconColor,
                title: "Sair da Conta",
                subtitle: "Fazer logout do aplicativo"
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    
    // MARK: - Shared Helpers
    @ViewBuilder
    private func toolNavigationCard<Destination: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            toolRow(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            feedbackService.triggerLight()
        })
    }
    
    private func toolRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Color Helpers
    private var primaryIconColor: Color {
        isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#3B82F6")
    }
    
    private var secondaryIconColor: Color {
        isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#F97316")
    }
    
    private var tertiaryIconColor: Color {
        isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#8B5CF6")
    }
    
    private var neutralIconColor: Color {
        isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .gray
    }
    
    private var destructiveIconColor: Color {
        isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .red
    }

}

// MARK: - Preview
struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
            .environmentObject(AuthViewModel())
    }
}

struct LogoutConfirmationView: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var appear = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cancelAction()
                    }
                }
                .opacity(appear ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: appear)
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: isMonochromaticMode ?
                                        [MonochromaticColorManager.primaryGray, MonochromaticColorManager.secondaryGray] :
                                        [Color(hex: "#F97316"), Color(hex: "#EA580C")]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(message)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                HStack(spacing: 12) {
                    Button(action: {
                        FeedbackService.shared.cancelFeedback()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cancelAction()
                        }
                    }) {
                        Text(cancelTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        FeedbackService.shared.confirmFeedback()
                        confirmAction()
                    }) {
                        Text(confirmTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: isMonochromaticMode ?
                                        [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                        [Color(hex: "#EF4444"), Color(hex: "#DC2626")]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
            .scaleEffect(appear ? 1 : 0.9)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appear)
        }
        .onAppear {
            appear = true
        }
    }
}
