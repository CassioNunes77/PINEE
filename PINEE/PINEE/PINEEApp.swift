//
//  PINEEApp.swift
//  PINEE
//
//  Created by Cássio Nunes on 18/06/25.
//

import SwiftUI
import GoogleSignIn
// import FirebaseCore // Temporariamente desabilitado

// O atributo @main deve estar aqui, no seu App.
@main
struct PINEEApp: App {
    // 1. A inicialização do Firebase Delegate está correta.
    // @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) var delegate // Temporariamente desabilitado
    
    // 2. Esta é a ÚNICA fonte da verdade para o estado de autenticação.
    //    Criamos o viewModel aqui e o distribuímos para todas as views que precisarem.
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) var systemColorScheme
    
    init() {
        // Configurar Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            fatalError("GoogleService-Info.plist não encontrado ou CLIENT_ID inválido")
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        
        // Configurar o tema inicial baseado na preferência salva
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            switch colorScheme {
            case "light":
                window.overrideUserInterfaceStyle = .light
            case "dark":
                window.overrideUserInterfaceStyle = .dark
            default:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                NavigationView {
                    ContentView()
                        .environmentObject(authViewModel)
                        .preferredColorScheme(getPreferredColorScheme())
                }
            } else {
                LoginView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(getPreferredColorScheme())
            }
        }
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}


// MARK: - Firebase App Delegate está definido em FirebaseAppDelegate.swift
