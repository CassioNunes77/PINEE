import SwiftUI

struct HelpCenterView: View {
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var expandedFAQs: Set<UUID> = []
    
    private let helpTopics: [HelpTopic] = [
        HelpTopic(
            icon: "book.fill",
            title: "Guia Rápido",
            description: "Aprenda os conceitos básicos para começar a usar o PINEE em minutos."
        ),
        HelpTopic(
            icon: "target",
            title: "Metas Financeiras",
            description: "Veja como criar, editar e acompanhar metas para seus objetivos."
        ),
        HelpTopic(
            icon: "chart.line.uptrend.xyaxis",
            title: "Investimentos",
            description: "Entenda como registrar aportes, resgates e acompanhar seus resultados."
        )
    ]
    
    private let faqItems: [HelpCenterFAQ] = [
        HelpCenterFAQ(
            question: "Como registrar uma nova transação?",
            answer: "Toque no botão central “+” na barra inferior e escolha o tipo de transação que deseja cadastrar. Informe os dados solicitados e toque em Salvar."
        ),
        HelpCenterFAQ(
            question: "Consigo importar meus dados antigos?",
            answer: "Sim. Acesse a seção \"Ferramentas\" no menu Mais e utilize as opções de Importar ou Exportar para trabalhar com backups em formato JSON."
        ),
        HelpCenterFAQ(
            question: "Onde altero notificações e lembretes?",
            answer: "Dentro do menu Mais, toque em Notificações para ajustar lembretes diários, lembretes de metas e mensagens de boas-vindas."
        ),
        HelpCenterFAQ(
            question: "Como falar com o suporte?",
            answer: "Use a opção Feedback na seção Suporte para enviar sua mensagem diretamente para nossa equipe. Você receberá uma resposta por e-mail assim que possível."
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                quickHelpTopics
                faqSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Central de Ajuda")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conte com a gente")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Encontre respostas rápidas, dicas de produtividade e links úteis para aproveitar o PINEE ao máximo.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var quickHelpTopics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Materiais de Apoio")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            ForEach(helpTopics) { topic in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: topic.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#059669"))
                        .frame(width: 36, height: 36)
                        .background(
                            (isMonochromaticMode ? MonochromaticColorManager.secondaryGray.opacity(0.25) : Color(UIColor.secondarySystemBackground))
                        )
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(topic.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(topic.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
            }
        }
    }
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Perguntas Frequentes")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(faqItems) { item in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedFAQs.contains(item.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedFAQs.insert(item.id)
                                } else {
                                    expandedFAQs.remove(item.id)
                                }
                            }
                        ),
                        content: {
                            Text(item.answer)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.top, 6)
                        },
                        label: {
                            HStack(spacing: 10) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#059669"))
                                Text(item.question)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                        }
                    )
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
}

private struct HelpTopic: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

private struct HelpCenterFAQ: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

