//
//  ContentView.swift
//  PINEE
//
//  Created by Cássio Nunes on 18/06/25.
//

import SwiftUI
import FirebaseAuth
import UserNotifications
import StoreKit

// Definição local de DateRange para compatibilidade
struct DateRange {
    var start: Date
    var end: Date
    var displayText: String
    init(start: Date, end: Date, displayText: String) {
        self.start = start
        self.end = end
        self.displayText = displayText
    }
}

// Classe para gerenciar o estado global do período selecionado
class GlobalDateManager: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var periodType: PeriodType = .monthly
    
    enum PeriodType: String, CaseIterable, Hashable {
        case monthly = "monthly"
        case yearly = "yearly"
        case allTime = "allTime"
        
        var displayName: String {
            switch self {
            case .monthly: return "Mensal"
            case .yearly: return "Anual"
            case .allTime: return "Todo o período"
            }
        }
    }
    
    func updateSelectedDate(_ date: Date) {
        selectedDate = date
    }
}

// MARK: - Welcome Notification View
struct WelcomeNotificationView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Bem-vindo ao PINEE!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

// MARK: - Status Notification View
struct StatusNotificationView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(message)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Goals View (Simplificada para compilação)
struct GoalsView: View {
    var body: some View {
        Text("Goals View - Temporariamente desabilitada")
            .foregroundColor(.secondary)
    }
}

// MARK: - More View
struct MoreView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("More View - Temporariamente simplificada")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                Button("Abrir Menu") {
                    showSheet = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationTitle("Mais")
            .sheet(isPresented: $showSheet) {
                Text("Menu Temporário")
                    .padding()
            }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var globalDateManager = GlobalDateManager()
    @State private var showWelcomeNotification = false
    @State private var welcomeMessage = ""
    @State private var showStatusNotification = false
    @State private var statusMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 16) {
                    Text("PINEE")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Controle Financeiro Pessoal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Welcome Notification
                if showWelcomeNotification {
                    WelcomeNotificationView(
                        message: welcomeMessage,
                        isShowing: $showWelcomeNotification
                    )
                    .padding(.horizontal)
                }
                
                // Status Notification
                if showStatusNotification {
                    StatusNotificationView(
                        message: statusMessage,
                        isShowing: $showStatusNotification
                    )
                    .padding(.horizontal)
                }
                
                // Main Content
                VStack(spacing: 16) {
                    Text("App temporariamente em modo simplificado")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    // Quick Actions
                    VStack(spacing: 12) {
                        NavigationLink(destination: GoalsView()) {
                            HStack {
                                Image(systemName: "target")
                                Text("Metas")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        NavigationLink(destination: MoreView()) {
                            HStack {
                                Image(systemName: "ellipsis.circle")
                                Text("Mais")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Footer
                Text("Versão simplificada para compilação")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
        .environmentObject(globalDateManager)
        .onAppear {
            // Simular welcome message se for primeiro login
            if authViewModel.isFirstLogin {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    welcomeMessage = "Seja bem-vindo ao PINEE!"
                    showWelcomeNotification = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        showWelcomeNotification = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}

