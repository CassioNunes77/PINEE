import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var feedbackText: String = ""
    @State private var isLoading: Bool = false
    @State private var dailyFeedbackCount: Int = 0
    @State private var isCheckingDailyLimit: Bool = true
    @State private var statusMessage: String = ""
    @State private var statusIsError: Bool = false
    @State private var showStatusBanner: Bool = false
    @FocusState private var isEditorFocused: Bool

    private let maxCharacters: Int = 500
    private let feedbackService = FeedbackService.shared
    private let firebaseService = FirebaseRESTService.shared

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 12)

                    feedbackEditorSection
                    accountInfoSection

                    if dailyFeedbackCount >= 3 {
                        dailyLimitReachedSection
                    }

                    submitButton

                    VStack(spacing: 4) {
                        Text("Feedbacks enviados hoje: \(dailyFeedbackCount)/3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Limite diário para manter a qualidade da análise.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .task {
            await checkDailyFeedbackLimit()
        }
        .overlay(alignment: .top) {
            if showStatusBanner {
                statusBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showStatusBanner)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: isMonochromaticMode ?
                                [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                [Color(hex: "#22C55E"), Color(hex: "#16A34A")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Envie seu Feedback")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("Sua opinião nos ajuda a deixar o PINEE ainda melhor. Conte tudo o que estiver sentindo!")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                Text("Informações do Usuário")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: 12) {
                infoRow(title: "Nome", value: authViewModel.user?.name ?? "Usuário")
                Divider().opacity(0.15)
                infoRow(title: "Email", value: authViewModel.user?.email ?? "-")
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
    }

    private var feedbackEditorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.line")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                Text("Seu Feedback")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("\(feedbackText.count)/\(maxCharacters)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(feedbackText.count >= maxCharacters ? .red : .secondary)
            }

            VStack(spacing: 12) {
                TextEditor(text: $feedbackText)
                    .focused($isEditorFocused)
                    .frame(minHeight: 200)
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(feedbackText.count >= maxCharacters ? Color.red.opacity(0.7) : Color.clear, lineWidth: 2)
                    )
                    .onChange(of: feedbackText) { newValue in
                        if newValue.count > maxCharacters {
                            feedbackText = String(newValue.prefix(maxCharacters))
                        }
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Como podemos ajudar?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Conte o que você mais gosta e o que podemos melhorar")
                        Text("• Descreva bugs ou travamentos que tenha encontrado")
                        Text("• Sugira ideias de novos recursos e melhorias de usabilidade")
                        Text("• Compartilhe experiências que tenham feito diferença")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
    }

    private var dailyLimitReachedSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundColor(.orange)
            Text("Limite diário atingido")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Text("Você já enviou 3 feedbacks hoje. Tente novamente amanhã para continuar contribuindo com melhorias.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var submitButton: some View {
        Button(action: submitFeedback) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(isLoading ? "Enviando..." : "Enviar feedback")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isMonochromaticMode ?
                        [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                        [Color(hex: "#16A34A"), Color(hex: "#22C55E")]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(submitDisabled)
        .opacity(submitDisabled ? 0.5 : 1.0)
    }

    private var submitDisabled: Bool {
        feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || dailyFeedbackCount >= 3 || isCheckingDailyLimit
    }

    private var statusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIsError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(statusIsError ? .red : .green)

            Text(statusMessage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    // MARK: - Actions

    private func submitFeedback() {
        guard let user = authViewModel.user else {
            presentStatus(message: "Não foi possível identificar o usuário autenticado.", isError: true)
            return
        }

        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            presentStatus(message: "Por favor, escreva seu feedback antes de enviar.", isError: true)
            feedbackService.selection()
            return
        }

        guard dailyFeedbackCount < 3 else {
            presentStatus(message: "Você já enviou 3 feedbacks hoje. Tente novamente amanhã.", isError: true)
            return
        }

        isLoading = true
        Task {
            do {
                try await firebaseService.submitFeedback(
                    userId: user.id,
                    userName: user.name,
                    userEmail: user.email,
                    message: trimmed
                )

                await MainActor.run {
                    isLoading = false
                    dailyFeedbackCount += 1
                    feedbackText = ""
                    isEditorFocused = false
                    presentStatus(message: "Feedback enviado com sucesso! Obrigado por nos ajudar a evoluir. 🌱", isError: false)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    presentStatus(message: "Não foi possível enviar seu feedback. Tente novamente em instantes.", isError: true)
                }
            }
        }
    }

    private func checkDailyFeedbackLimit() async {
        guard let userId = authViewModel.user?.id else {
            await MainActor.run {
                isCheckingDailyLimit = false
            }
            return
        }

        do {
            let count = try await firebaseService.getDailyFeedbackCount(userId: userId)
            await MainActor.run {
                dailyFeedbackCount = count
                isCheckingDailyLimit = false
            }
        } catch {
            await MainActor.run {
                isCheckingDailyLimit = false
                presentStatus(message: "Não foi possível verificar seu limite diário de feedback hoje.", isError: true)
            }
        }
    }

    private func presentStatus(message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
        showStatusBanner = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showStatusBanner = false
            }
        }
    }
}

