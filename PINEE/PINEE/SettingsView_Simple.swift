//
//  SettingsView.swift
//  PINEE
//
//  Created by Cássio Nunes on 23/06/25.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showHelp = false
    @State private var showContact = false
    @State private var showFeedback = false
    @State private var showPremium = false
    @State private var feedbackText = ""
    @State private var isSubmittingFeedback = false
    @State private var feedbackSubmitted = false
    @State private var showNotificationMessage = false
    @State private var notificationMessage = ""
    @State private var updateTimer: Timer?
    @State private var forceUpdate: Bool = false
    @State private var showExpirationNotification = false
    @State private var expirationMessage = "Sua assinatura premium expirou. Você voltou para o plano gratuito."
    private let db: Any? = nil
    
    var appVersion: String {
        "Ver 0.5 Beta"
    }
    
    var lastUpdate: String {
        "23/06/2025"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Configurações")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Ajuste as configurações do app")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Account Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Informações da Conta")
                            .font(.headline)
                        
                        HStack {
                            Text("Usuário:")
                                .foregroundColor(.secondary)
                            Text(authViewModel.user?.name ?? "Não autenticado")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Email:")
                                .foregroundColor(.secondary)
                            Text(authViewModel.user?.email ?? "Não disponível")
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // App Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Informações do App")
                            .font(.headline)
                        
                        HStack {
                            Text("Versão:")
                                .foregroundColor(.secondary)
                            Text(appVersion)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Última atualização:")
                                .foregroundColor(.secondary)
                            Text(lastUpdate)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configurações")
                            .font(.headline)
                        
                        Toggle("Notificações", isOn: $notificationsEnabled)
                        
                        Toggle("Modo Monocromático", isOn: $isMonochromaticMode)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            print("⚙️ SettingsView apareceu")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(AuthViewModel())
        }
    }
}










