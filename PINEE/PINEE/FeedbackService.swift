//
//  FeedbackService.swift
//  PINEE
//
//  Created on 23/06/25.
//

import UIKit
import AudioToolbox
import SwiftUI

/// Serviço centralizado para gerenciar feedbacks táteis e sonoros
class FeedbackService: ObservableObject {
    static let shared = FeedbackService()
    
    @AppStorage("hapticFeedbackEnabled") var hapticFeedbackEnabled: Bool = true
    @AppStorage("soundFeedbackEnabled") var soundFeedbackEnabled: Bool = true
    
    private var impactLight: UIImpactFeedbackGenerator?
    private var impactMedium: UIImpactFeedbackGenerator?
    private var impactHeavy: UIImpactFeedbackGenerator?
    private var selectionFeedback: UISelectionFeedbackGenerator?
    private var notificationFeedback: UINotificationFeedbackGenerator?
    
    private init() {
        prepareHapticGenerators()
    }
    
    // MARK: - Preparação
    private func prepareHapticGenerators() {
        impactLight = UIImpactFeedbackGenerator(style: .light)
        impactMedium = UIImpactFeedbackGenerator(style: .medium)
        impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        selectionFeedback = UISelectionFeedbackGenerator()
        notificationFeedback = UINotificationFeedbackGenerator()
    }
    
    // MARK: - Haptic Feedback
    
    /// Feedback de impacto leve (para toques, navegação, etc.)
    func triggerLight() {
        guard hapticFeedbackEnabled else { return }
        impactLight?.prepare()
        impactLight?.impactOccurred()
    }
    
    /// Feedback de impacto médio (para ações importantes)
    func triggerMedium() {
        guard hapticFeedbackEnabled else { return }
        impactMedium?.prepare()
        impactMedium?.impactOccurred()
    }
    
    /// Feedback de impacto forte (para ações críticas)
    func triggerHeavy() {
        guard hapticFeedbackEnabled else { return }
        impactHeavy?.prepare()
        impactHeavy?.impactOccurred()
    }
    
    /// Feedback de seleção (para mudanças de valor, seleções)
    func selection() {
        guard hapticFeedbackEnabled else { return }
        selectionFeedback?.prepare()
        selectionFeedback?.selectionChanged()
    }
    
    /// Feedback de sucesso
    func success() {
        guard hapticFeedbackEnabled else { return }
        notificationFeedback?.prepare()
        notificationFeedback?.notificationOccurred(.success)
        playSuccessSound()
    }
    
    /// Feedback de erro
    func error() {
        guard hapticFeedbackEnabled else { return }
        notificationFeedback?.prepare()
        notificationFeedback?.notificationOccurred(.error)
        playErrorSound()
    }
    
    /// Feedback de aviso
    func warning() {
        guard hapticFeedbackEnabled else { return }
        notificationFeedback?.prepare()
        notificationFeedback?.notificationOccurred(.warning)
    }
    
    // MARK: - Sound Feedback
    
    /// Som discreto para ações comuns
    func playTapSound() {
        guard soundFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(1104) // Tock sound - discreto
    }
    
    /// Som para ações importantes
    func playActionSound() {
        guard soundFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(1057) // Peek sound
    }
    
    /// Som de sucesso
    func playSuccessSound() {
        guard soundFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(1054) // Success sound
    }
    
    /// Som de erro
    func playErrorSound() {
        guard soundFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(1053) // Error sound
    }
    
    /// Som de confirmação
    func playConfirmSound() {
        guard soundFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(1105) // Confirm sound
    }
    
    /// Som de cancelamento
    func playCancelSound() {
        guard soundFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(1102) // Cancel sound
    }
    
    /// Som minimalista para ações leves
    func playMinimalSound() {
        guard soundFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(1104) // Tock sound
    }
    
    // MARK: - Combined Feedback
    
    /// Feedback combinado (haptic + sound) para ações importantes
    func actionFeedback() {
        triggerMedium()
        playActionSound()
    }
    
    /// Feedback combinado leve (haptic + sound) para ações simples
    func lightFeedback() {
        triggerLight()
        playTapSound()
    }
    
    /// Feedback combinado para sucesso
    func successFeedback() {
        success()
    }
    
    /// Feedback combinado para erro
    func errorFeedback() {
        error()
    }
    
    /// Feedback combinado para confirmação
    func confirmFeedback() {
        triggerMedium()
        playConfirmSound()
    }
    
    /// Feedback combinado para cancelamento
    func cancelFeedback() {
        triggerLight()
        playCancelSound()
    }
}

// MARK: - View Extension
extension View {
    /// Adiciona feedback tátil leve ao toque
    func hapticLight() -> some View {
        self.onTapGesture {
            FeedbackService.shared.triggerLight()
        }
    }
    
    /// Adiciona feedback tátil médio ao toque
    func hapticMedium() -> some View {
        self.onTapGesture {
            FeedbackService.shared.triggerMedium()
        }
    }
    
    /// Adiciona feedback combinado ao toque
    func hapticAction() -> some View {
        self.onTapGesture {
            FeedbackService.shared.actionFeedback()
        }
    }
}

