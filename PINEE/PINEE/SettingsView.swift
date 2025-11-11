//
//  SettingsView.swift
//  PINEE
//
//  Created by Cássio Nunes on 23/06/25.
//

import SwiftUI
// import FirebaseFirestore
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @StateObject private var feedbackService = FeedbackService.shared
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showHelp = false
    @State private var showContact = false
    @State private var showPremium = false
    @State private var showNotificationMessage = false
    @State private var notificationMessage = ""
    @State private var updateTimer: Timer?
    @State private var forceUpdate: Bool = false // Para forçar atualização da UI
    @StateObject private var iapManager = IAPManager.shared
    @State private var showExpirationNotification = false
    @State private var expirationMessage = "Sua assinatura premium expirou. Você voltou para o plano gratuito."
    // private let db = Firestore.firestore()
    
    var appVersion: String {
        "Ver 0.5 Beta"
    }
    
    var lastUpdate: String {
        "23/06/2025"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Informações da Conta
                VStack(alignment: .leading, spacing: 8) {
                    Text("Informações da Conta")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Nome")
                        Spacer()
                        Text(authViewModel.user?.name ?? "Usuário")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authViewModel.user?.email ?? "email@exemplo.com")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Preferências
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferências")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Modo Escuro")
                        Spacer()
                        Picker("Modo Escuro", selection: $colorScheme) {
                            Text("Sistema").tag("system")
                            Text("Claro").tag("light")
                            Text("Escuro").tag("dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 180)
                        .id("colorScheme-\(colorScheme)-\(forceUpdate)")
                        .onChange(of: colorScheme) { newValue in
                            print("🎨 Modo escuro alterado para: \(newValue)")
                            // Forçar atualização da UI
                            forceUpdate.toggle()
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modo Pinee")
                            Text("Tema verde e cinza")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $isMonochromaticMode)
                            .id("isMonochromaticMode-\(isMonochromaticMode)-\(forceUpdate)")
                            .onChange(of: isMonochromaticMode) { newValue in
                                print("🎨 Modo monocromático alterado para: \(newValue)")
                                feedbackService.triggerLight()
                                // Forçar atualização da UI
                                forceUpdate.toggle()
                            }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Respostas Táteis")
                            Text("Feedback de vibração ao toque")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $feedbackService.hapticFeedbackEnabled)
                            .onChange(of: feedbackService.hapticFeedbackEnabled) { newValue in
                                // Não tocar feedback aqui para evitar loop infinito
                            }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sons")
                            Text("Feedback sonoro ao toque")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $feedbackService.soundFeedbackEnabled)
                            .onChange(of: feedbackService.soundFeedbackEnabled) { newValue in
                                feedbackService.playTapSound()
                            }
                    }
                    
                    HStack {
                        Text("Moeda")
                        Spacer()
                        Text("BRL (R$)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Formato de Data")
                        Spacer()
                        Text("DD/MM/AAAA")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Seja Premium - Exibir apenas se não for premium, exclusive ou lifetime
                if let accountType = authViewModel.user?.accountType, !accountType.isPremium {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Seja Premium")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .yellow)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upgrade para Premium")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Desbloqueie recursos exclusivos")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                                    Text("Relatórios avançados")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                                    Text("Exportação de dados")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                                    Text("Backup na nuvem")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .green)
                                    Text("Suporte prioritário")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Button(action: {
                                showPremium = true
                            }) {
                                Text("Fazer Upgrade")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }

                // Informações do App
                VStack(alignment: .leading, spacing: 8) {
                    Text("Informações do App")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Versão")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Última Atualização")
                        Spacer()
                        Text(lastUpdate)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        rateApp()
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .yellow)
                            Text("Avalie na App Store")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink(destination: FeedbackView().environmentObject(authViewModel)) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 16))
                                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : .blue)
                            Text("Enviar Feedback")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        feedbackService.triggerLight()
                    })
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Botão DEV (apenas para conta do desenvolvedor)
                if authViewModel.user?.email == "cassionunes.si@gmail.com" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Desenvolvimento")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        NavigationLink(destination: DevView().environmentObject(authViewModel)) {
                            HStack(spacing: 12) {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DEV")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text("Painel do desenvolvedor")
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
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }


            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 120)
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .overlay(
            // Notificação de status das notificações
            Group {
                if showNotificationMessage {
                    VStack {
                        HStack(spacing: 12) {
                            // Ícone com animação
                            Image(systemName: notificationMessage.contains("ativadas com sucesso") ? "checkmark.circle.fill" : 
                                       notificationMessage.contains("negada") ? "xmark.circle.fill" : "bell.slash.fill")
                                .foregroundColor(notificationMessage.contains("ativadas com sucesso") ? .green : 
                                               notificationMessage.contains("negada") ? .red : .orange)
                                .font(.system(size: 20))
                                .scaleEffect(showNotificationMessage ? 1.0 : 0.5)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showNotificationMessage)
                            
                            // Mensagem
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
        .sheet(isPresented: $showHelp) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                Text("Central de Ajuda")
                    .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                        Text("Encontre respostas para as perguntas mais frequentes sobre o PINEE.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        VStack(alignment: .leading, spacing: 20) {
                            FAQItem(question: "Como faço meu cadastro no PINEE?", answer: "Basta acessar a tela inicial e escolher uma das opções de login (Google, email, etc). Seu cadastro é feito automaticamente ao autenticar.")
                            FAQItem(question: "Como criar uma categoria personalizada?", answer: "Vá até a tela de categorias, toque em 'Nova Categoria', escolha nome, ícone, cor e tipo (despesa ou receita) e salve.")
                            FAQItem(question: "O que é o PINEE Premium?", answer: "O Premium libera recursos exclusivos, como exportação de dados, relatórios avançados e suporte prioritário. Você pode assinar na tela de upgrade.")
                            FAQItem(question: "Como funciona a segurança dos meus dados?", answer: "Todos os dados são criptografados e armazenados com segurança no Firebase. Só você tem acesso às suas informações.")
                            FAQItem(question: "Posso exportar meus dados?", answer: "Sim! Usuários premium podem exportar dados financeiros em CSV pela tela de configurações.")
                            FAQItem(question: "Como defino uma meta financeira?", answer: "Acesse a tela de Metas, toque em 'Nova Meta', preencha os campos e salve. Você pode acompanhar o progresso em tempo real.")
                            FAQItem(question: "Como registrar um investimento?", answer: "Na tela de transações, escolha o tipo 'Investir', preencha os dados e salve. Você pode resgatar investimentos ou transferir valores entre receitas e investimentos.")
                            FAQItem(question: "Como altero ou excluo uma transação?", answer: "Deslize a transação para o lado na lista e escolha editar ou excluir.")
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
                .navigationTitle("Central de Ajuda")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                Button("Fechar") { showHelp = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showContact) {
            VStack {
                Text("Contato")
                    .font(.title2)
                    .padding()
                Text("Entre em contato conosco para suporte técnico.")
                    .padding()
                Spacer()
                Button("Fechar") { showContact = false }
                    .padding()
            }
        }
        .sheet(isPresented: $showPremium) {
            PremiumView()
        }
        .onAppear {
            print("⚙️ SettingsView apareceu - Iniciando atualização automática")
            startAutoUpdate()
            setupUserDefaultsObserver()
            // Checar expiração da assinatura ao abrir
            // TEMPORARIAMENTE COMENTADO - Verificar disponibilidade do IAPManager
            /*
            Task {
                await iapManager.checkSubscriptionStatus(authViewModel: authViewModel) {
                    // Callback de expiração
                    showExpirationNotification = true
                }
            }
            */
        }
        .onDisappear {
            print("⚙️ SettingsView desapareceu - Parando atualização automática")
            stopAutoUpdate()
            removeUserDefaultsObserver()
        }
        .alert(isPresented: $showExpirationNotification) {
            Alert(title: Text("Assinatura Expirada"), message: Text(expirationMessage), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Auto Update Methods
    private func startAutoUpdate() {
        // Parar timer anterior se existir
        stopAutoUpdate()
        
        // Sincronizar valores iniciais
        syncSettingsValues()
        
        // Criar timer para atualização automática a cada 0.5 segundos
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Forçar atualização da view para sincronizar os switches
            self.forceUpdate.toggle()
        }
    }
    
    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func syncSettingsValues() {
        // Ler valores diretamente do UserDefaults para garantir sincronização
        let userDefaults = UserDefaults.standard
        
        // Sincronizar modo escuro
        let savedColorScheme = userDefaults.string(forKey: "colorScheme") ?? "system"
        if colorScheme != savedColorScheme {
            colorScheme = savedColorScheme
            print("🔄 Sincronizando modo escuro: \(savedColorScheme)")
        }
        
        // Sincronizar modo monocromático
        let savedMonochromaticMode = userDefaults.bool(forKey: "isMonochromaticMode")
        if isMonochromaticMode != savedMonochromaticMode {
            isMonochromaticMode = savedMonochromaticMode
            print("🔄 Sincronizando modo monocromático: \(savedMonochromaticMode)")
        }
        
        // Forçar atualização da UI
        forceUpdate.toggle()
    }
    
    private func setupUserDefaultsObserver() {
        // Observar mudanças nos UserDefaults
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 UserDefaults mudou - Sincronizando configurações")
            self.syncSettingsValues()
        }
    }
    
    private func removeUserDefaultsObserver() {
        // Remover observer
        NotificationCenter.default.removeObserver(
            self,
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    private func shareApp() {
        let appName = "PINEE"
        let appDescription = "Controle suas finanças de forma simples e eficiente"
        let appStoreURL = "https://apps.apple.com/app/pinee" // URL fictícia
        
        let shareText = """
        Olá! Quero compartilhar com você o app \(appName) - \(appDescription)
        
        Baixe agora: \(appStoreURL)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func rateApp() {
        // URL da App Store para o app PINEE (substitua pelo ID correto do seu app)
        let appStoreURL = "https://apps.apple.com/app/id1234567890?action=write-review"
        
        if let url = URL(string: appStoreURL) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback para URL genérica da App Store
                let fallbackURL = "https://apps.apple.com/app/pinee"
                if let fallbackURL = URL(string: fallbackURL) {
                    UIApplication.shared.open(fallbackURL)
                }
            }
        }
    }
}

// FAQItem view
struct FAQItem: View {
    let question: String
    let answer: String
    @State private var expanded: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { withAnimation { expanded.toggle() } }) {
                HStack {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(question)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            if expanded {
                Text(answer)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
