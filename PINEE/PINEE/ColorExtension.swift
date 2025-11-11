//
//  ColorExtension.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//


import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Sistema de Cores Monocromáticas
class MonochromaticColorManager: ObservableObject {
    @Published var isMonochromaticMode: Bool = false
    
    // Cores base para o modo monocromático
    static let primaryGreen = Color(hex: "#16A34A") // Verde principal
    static let secondaryGreen = Color(hex: "#22C55E") // Verde secundário
    static let lightGreen = Color(hex: "#4ADE80") // Verde claro
    static let darkGreen = Color(hex: "#15803D") // Verde escuro
    
    // Tons de cinza para despesas
    static let primaryGray = Color(hex: "#6B7280") // Cinza principal
    static let secondaryGray = Color(hex: "#9CA3AF") // Cinza secundário
    static let lightGray = Color(hex: "#D1D5DB") // Cinza claro
    static let darkGray = Color(hex: "#374151") // Cinza escuro
    static let tertiaryGray = Color(hex: "#4B5563") // Cinza terciário
    static let quaternaryGray = Color(hex: "#7C3AED") // Roxo para variedade
    static let quinaryGray = Color(hex: "#DC2626") // Vermelho para variedade
    
    // Tons adicionais de verde para receitas
    static let tertiaryGreen = Color(hex: "#10B981") // Verde terciário
    static let quaternaryGreen = Color(hex: "#06B6D4") // Ciano para variedade
    static let quinaryGreen = Color(hex: "#84CC16") // Verde lima para variedade
    
    // Cores de fundo monocromáticas
    static let backgroundGreen = Color(hex: "#F0FDF4") // Fundo verde claro
    static let backgroundGray = Color(hex: "#F9FAFB") // Fundo cinza claro
    static let cardBackgroundGreen = Color(hex: "#FFFFFF") // Fundo dos cards
    static let cardBackgroundGray = Color(hex: "#F3F4F6") // Fundo dos cards (modo escuro)
    
    // Função para obter cor de receita baseada no modo
    static func incomeColor(isMonochromatic: Bool) -> Color {
        return isMonochromatic ? primaryGreen : Color(hex: "#16A34A")
    }
    
    // Função para obter cor de despesa baseada no modo
    static func expenseColor(isMonochromatic: Bool) -> Color {
        return isMonochromatic ? primaryGray : .red
    }
    
    // Função para obter cor de fundo baseada no modo
    static func backgroundColor(isMonochromatic: Bool, isDarkMode: Bool) -> Color {
        if isMonochromatic {
            return isDarkMode ? Color(hex: "#1F2937") : backgroundGreen
        } else {
            return isDarkMode ? Color.black : Color(UIColor.systemBackground)
        }
    }
    
    // Função para obter cor de fundo dos cards baseada no modo
    static func cardBackgroundColor(isMonochromatic: Bool, isDarkMode: Bool) -> Color {
        if isMonochromatic {
            return isDarkMode ? Color(hex: "#374151") : cardBackgroundGreen
        } else {
            return isDarkMode ? Color(UIColor.secondarySystemBackground) : Color(UIColor.secondarySystemBackground)
        }
    }
    
    // Função para obter cor de texto baseada no modo
    static func textColor(isMonochromatic: Bool, isDarkMode: Bool) -> Color {
        if isMonochromatic {
            return isDarkMode ? Color(hex: "#F9FAFB") : Color(hex: "#1F2937")
        } else {
            return isDarkMode ? Color.white : Color.black
        }
    }
    
    // Função para obter cor de texto secundário baseada no modo
    static func secondaryTextColor(isMonochromatic: Bool, isDarkMode: Bool) -> Color {
        if isMonochromatic {
            return isDarkMode ? Color(hex: "#9CA3AF") : Color(hex: "#6B7280")
        } else {
            return isDarkMode ? Color.gray : Color.gray
        }
    }
    
    // Função para obter cor de destaque baseada no modo
    static func accentColor(isMonochromatic: Bool) -> Color {
        return isMonochromatic ? primaryGreen : Color(hex: "#059669")
    }
    
    // Função para obter cor de gradiente baseada no modo
    static func gradientColors(isMonochromatic: Bool) -> [Color] {
        if isMonochromatic {
            return [primaryGreen, secondaryGreen]
        } else {
            return [Color(hex: "#059669"), Color(hex: "#16A34A")]
        }
    }
}
