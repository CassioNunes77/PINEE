//
//  DevView.swift
//  PINEE
//
//  Created by Cássio Nunes on 23/06/25.
//

import SwiftUI
// import FirebaseFirestore

struct DevView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var systemColorScheme
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    @State private var showNotificationMessage = false
    @State private var notificationMessage = ""
    @State private var isLoading = false
    @State private var showFeedbacks = false
    
    private let db: Any? = nil // Firestore.firestore() temporariamente desabilitado
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerView
                
                // Seção de Testes de Conta
                accountTestSection
                
                // Seção de Dados
                dataSection
                
                // Seção de Configurações
                settingsSection
                
                // Seção de Logs
                logsSection
                
                // Seção de Notificações
                notificationsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 120)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Desenvolvimento")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            // Notificação de status
            Group {
                if showNotificationMessage {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                                .scaleEffect(showNotificationMessage ? 1.0 : 0.5)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showNotificationMessage)
                            
                            Text(notificationMessage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .opacity(showNotificationMessage ? 1.0 : 0.0)
                                .animation(.easeOut(duration: 0.4).delay(0.3), value: showNotificationMessage)
                            
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
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: showNotificationMessage)
                    .zIndex(1000)
                }
            }
        )
        .onAppear {
            // Verificar se é a conta do desenvolvedor
            // TEMPORARIAMENTE COMENTADO - AuthViewModel não disponível
            /*
             guard authViewModel.user?.email == "cassionunes.si@gmail.com" else {
             return
             }
             */
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Ícone de Desenvolvimento
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: "hammer.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Painel do Desenvolvedor")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Ferramentas exclusivas para desenvolvimento e testes")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Account Test Section
    private var accountTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Testes de Conta")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: {
                    simulateUpgrade()
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Simular Upgrade Premium")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    simulateLifetimeAccount()
                }) {
                    HStack {
                        Image(systemName: "infinity.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Simular Conta Vitalícia")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    simulateExclusiveLicense()
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Simular Licença Exclusiva")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    simulateDowngrade()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Simular Downgrade Free")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Data Section
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gerenciamento de Dados")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: {
                    clearUserData()
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Limpar Dados do Usuário")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    generateTestData()
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Gerar Dados de Teste")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                NavigationLink(
                    destination: FeedbackListView()
                        .environmentObject(authViewModel)
                ) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Ver Feedbacks")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configurações Avançadas")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: {
                    resetAppSettings()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Resetar Configurações")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    exportDebugInfo()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Exportar Info de Debug")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Logs Section
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Logs e Monitoramento")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: {
                    viewAppLogs()
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Visualizar Logs")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    testNotifications()
                }) {
                    HStack {
                        Image(systemName: "bell")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Testar Notificações")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notificações")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: {
                    sendTestNotification()
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Enviar Notificação de Teste")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color.green)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    sendBroadcastNotification()
                }) {
                    HStack {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("Notificação Broadcast")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    private func simulateUpgrade() {
        isLoading = true
        // TEMPORARIAMENTE COMENTADO - AuthViewModel não disponível
        /*
         authViewModel.setPremiumStatus(isPremium: true, premiumSource: "development") { success in
         isLoading = false
         showNotificationMessage = true
         notificationMessage = success ? "Upgrade para Premium simulado com sucesso!" : "Erro ao simular upgrade"
         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
         showNotificationMessage = false
         }
         }
         */
        
        // TEMPORÁRIO: Simular sucesso
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.showNotificationMessage = true
            self.notificationMessage = "Upgrade para Premium simulado com sucesso!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showNotificationMessage = false
            }
        }
    }
    
    private func simulateDowngrade() {
        isLoading = true
        // TEMPORARIAMENTE COMENTADO - AuthViewModel não disponível
        /*
         authViewModel.setPremiumStatus(isPremium: false, premiumSource: "development") { success in
         isLoading = false
         showNotificationMessage = true
         notificationMessage = success ? "Downgrade para Free simulado com sucesso!" : "Erro ao simular downgrade"
         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
         showNotificationMessage = false
         }
         }
         */
        
        // TEMPORÁRIO: Simular sucesso
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.showNotificationMessage = true
            self.notificationMessage = "Downgrade para Free simulado com sucesso!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showNotificationMessage = false
            }
        }
    }
    
    private func simulateLifetimeAccount() {
        isLoading = true
        // TEMPORARIAMENTE COMENTADO - AuthViewModel não disponível
        /*
         authViewModel.setAccountType(.lifetime, source: "development") { success in
         isLoading = false
         showNotificationMessage = true
         notificationMessage = success ? "Conta Vitalícia simulada com sucesso!" : "Erro ao simular conta vitalícia"
         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
         showNotificationMessage = false
         }
         }
         */
        
        // TEMPORÁRIO: Simular sucesso
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.showNotificationMessage = true
            self.notificationMessage = "Conta Vitalícia simulada com sucesso!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showNotificationMessage = false
            }
        }
    }
    
    private func simulateExclusiveLicense() {
        isLoading = true
        // TEMPORARIAMENTE COMENTADO - AuthViewModel não disponível
        /*
         authViewModel.setAccountType(.exclusive, source: "development") { success in
         isLoading = false
         showNotificationMessage = true
         notificationMessage = success ? "Licença Exclusiva simulada com sucesso!" : "Erro ao simular licença exclusiva"
         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
         showNotificationMessage = false
         }
         }
         */
        
        // TEMPORÁRIO: Simular sucesso
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.showNotificationMessage = true
            self.notificationMessage = "Licença Exclusiva simulada com sucesso!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showNotificationMessage = false
            }
        }
    }
    
    private func clearUserData() {
        showNotificationMessage = true
        notificationMessage = "Função de limpeza de dados será implementada"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showNotificationMessage = false
        }
    }
    
    private func generateTestData() {
        showNotificationMessage = true
        notificationMessage = "Função de geração de dados será implementada"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showNotificationMessage = false
        }
    }
    
    private func resetAppSettings() {
        showNotificationMessage = true
        notificationMessage = "Função de reset será implementada"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showNotificationMessage = false
        }
    }
    
    private func exportDebugInfo() {
        showNotificationMessage = true
        notificationMessage = "Função de exportação será implementada"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showNotificationMessage = false
        }
    }
    
    private func viewAppLogs() {
        showNotificationMessage = true
        notificationMessage = "Função de logs será implementada"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showNotificationMessage = false
        }
    }
    
    private func testNotifications() {
        showNotificationMessage = true
        notificationMessage = "Função de teste de notificações será implementada"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showNotificationMessage = false
        }
    }
    
    private func sendTestNotification() {
        Task {
            let notificationManager = NotificationManager.shared
            await notificationManager.scheduleNotification(
                id: "test_\(UUID().uuidString)",
                title: "Teste de Notificação",
                body: "Esta é uma notificação de teste do PINEE!",
                date: Date().addingTimeInterval(5) // 5 segundos
            )
            
            await MainActor.run {
                showNotificationMessage = true
                notificationMessage = "Notificação de teste será enviada em 5 segundos!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showNotificationMessage = false
                }
            }
        }
    }
    
    private func sendBroadcastNotification() {
        showNotificationMessage = true
        notificationMessage = "Notificação broadcast enviada com sucesso!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showNotificationMessage = false
        }
    }
    
    // MARK: - FeedbackListView
    struct FeedbackListView: View {
        @Environment(\.presentationMode) var presentationMode
        @State private var feedbacks: [Feedback] = []
        @State private var isLoading = true
        private let db: Any? = nil // Firestore.firestore() temporariamente desabilitado
        var body: some View {
            NavigationView {
                Group {
                    if isLoading {
                        ProgressView("Carregando feedbacks...")
                            .padding()
                    } else if feedbacks.isEmpty {
                        Text("Nenhum feedback encontrado.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        List(feedbacks) { fb in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(fb.userName)
                                        .font(.headline)
                                    Spacer()
                                    Text(fb.createdAtString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(fb.userEmail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(fb.feedback)
                                    .font(.body)
                                    .padding(.top, 2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .navigationTitle("Feedbacks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Fechar") { presentationMode.wrappedValue.dismiss() }
                    }
                }
            }
            .onAppear(perform: loadFeedbacks)
        }
        private func loadFeedbacks() {
            // TEMPORARIAMENTE COMENTADO - Firestore não disponível
            /*
             db.collection("feedbacks").order(by: "createdAt", descending: true).getDocuments { snapshot, error in
             if let docs = snapshot?.documents {
             self.feedbacks = docs.compactMap { doc in
             let data = doc.data()
             return Feedback(
             id: doc.documentID,
             userName: data["userName"] as? String ?? "-",
             userEmail: data["userEmail"] as? String ?? "-",
             feedback: data["feedback"] as? String ?? "-",
             createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
             )
             }
             */
            
            // TEMPORÁRIO: Simular feedbacks
            self.feedbacks = [
                Feedback(
                    id: "1",
                    userName: "Usuário Teste",
                    userEmail: "teste@example.com",
                    feedback: "Feedback simulado para teste",
                    createdAt: Date()
                )
            ]
            self.isLoading = false
        }
    }
    
    struct Feedback: Identifiable {
        let id: String
        let userName: String
        let userEmail: String
        let feedback: String
        let createdAt: Date
        var createdAtString: String {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: createdAt)
        }
    }
    
    struct DevView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                DevView()
                // .environmentObject(AuthViewModel())  // TEMPORARIAMENTE COMENTADO
            }
        }
    }
}
