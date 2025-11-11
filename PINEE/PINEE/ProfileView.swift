// ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPremium = false
    @StateObject private var iapManager = IAPManager.shared
    @State private var showExpirationNotification = false
    @State private var expirationMessage = "Sua assinatura premium expirou. Você voltou para o plano gratuito."
    @State private var showLogoutConfirmation = false
    private let feedbackService = FeedbackService.shared
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                AsyncImage(url: authViewModel.user?.profileImageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 120, height: 120)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 4))
                            .shadow(radius: 10)
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.top, 16)
                
                Text(authViewModel.user?.name ?? "Usuário")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(authViewModel.user?.email ?? "email@exemplo.com")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Status da Conta
                if let user = authViewModel.user {
                    HStack(spacing: 8) {
                        Image(systemName: user.accountType.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(user.accountType.color)
                        
                        Text(user.accountType.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(user.accountType.color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(user.accountType.color.opacity(0.1))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(user.accountType.color.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Seção Premium
                VStack(spacing: 12) {
                    if let user = authViewModel.user, user.accountType.isPremium {
                        // Mensagem para usuários premium
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.yellow)
                            
                            Text("Você é Premium!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Obrigado por escolher o PINEE Premium. Aproveite todos os recursos exclusivos disponíveis para você.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 20)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    } else {
                        // Bloco para usuários não premium
                        Text("PINEE Premium")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Desbloqueie recursos avançados e tenha uma experiência completa de controle financeiro.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showPremium = true
                        }) {
                            Text("Atualizar Premium")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#16A34A"))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // Botão Indicar Amigo
                Button(action: {
                    shareApp()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                        Text("Indicar para um Amigo")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
                
                // Botão Avalie na App Store
                Button(action: {
                    rateApp()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yellow)
                        Text("Avalie na App Store")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
                
                Spacer(minLength: 20)
                
                // Botão Sair - Mais discreto
                Button(action: {
                    feedbackService.triggerHeavy()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showLogoutConfirmation = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .medium))
                        Text("Sair da Conta")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 40)
                
                // Espaçamento extra para evitar sobreposição com menu inferior
                Spacer(minLength: 100)
                }
                .padding(.bottom, 120) // Padding extra para garantir que não corte
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .overlay(
            Group {
                if showLogoutConfirmation {
                    LogoutConfirmationView(
                        title: "Deseja sair do PINEE?",
                        message: "Ao sair, você precisará informar suas credenciais novamente para acessar seus dados.",
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
        .sheet(isPresented: $showPremium) {
            NavigationView {
                PremiumView(showNavigationTitle: false)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Fechar") {
                                showPremium = false
                            }
                        }
                    }
            }
        }
        .onAppear {
            // TEMPORARIAMENTE COMENTADO - Verificar disponibilidade do IAPManager
            /*
            Task {
                await iapManager.checkSubscriptionStatus(authViewModel: authViewModel) {
                    showExpirationNotification = true
                }
            }
            */
        }
        .alert(isPresented: $showExpirationNotification) {
            Alert(title: Text("Assinatura Expirada"), message: Text(expirationMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func shareApp() {
        let shareText = """
        Experimente o PINEE! 📱💰
        
        O melhor app para controlar suas finanças pessoais de forma simples e eficiente.
        
        Baixe agora na App Store!
        """
        
        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // Para iPad
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            window.rootViewController?.present(activityController, animated: true)
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

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
                .environmentObject(AuthViewModel())
        }
    }
}