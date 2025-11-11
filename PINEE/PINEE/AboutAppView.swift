import SwiftUI
import UIKit

// MARK: - About App View
struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    @State private var animateLogo = false
    @State private var showFeatures = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header com Logo e Nome
                    VStack(spacing: 20) {
                        // Logo animado
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: isMonochromaticMode ? 
                                            [MonochromaticColorManager.primaryGreen, MonochromaticColorManager.secondaryGreen] :
                                            [Color(hex: "#16A34A"), Color(hex: "#22C55E")]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .scaleEffect(animateLogo ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateLogo)
                            
                            PineTreeIcon()
                            .rotationEffect(.degrees(animateLogo ? 360 : 0))
                            .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: animateLogo)
                        }
                        
                        VStack(spacing: 8) {
                            Text("PINEE")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Seu companheiro financeiro")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("Versão 1.0.0")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            Text("Lançado em 2025")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.9))
                        }
                    }
                    .padding(.top, 20)
                    
                    // Missão
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "target")
                                .font(.system(size: 24))
                                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                            
                            Text("Nossa Missão")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        Text("Transformar a gestão financeira pessoal em uma experiência simples, intuitiva e inspiradora. Queremos que cada usuário sinta que tem controle total sobre suas finanças e possa construir um futuro financeiro sólido.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Recursos Principais
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.system(size: 24))
                                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                            
                            Text("Recursos Principais")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            FeatureCard(
                                icon: "chart.pie.fill",
                                title: "Análises Detalhadas",
                                description: "Visualize seus gastos com gráficos intuitivos"
                            )
                            
                            FeatureCard(
                                icon: "target",
                                title: "Metas Financeiras",
                                description: "Defina e acompanhe suas metas de economia"
                            )
                            
                            FeatureCard(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Investimentos",
                                description: "Acompanhe seus investimentos e rendimentos"
                            )
                            
                            FeatureCard(
                                icon: "bell.fill",
                                title: "Lembretes Inteligentes",
                                description: "Receba notificações personalizadas"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(showFeatures ? 1.0 : 0.0)
                    .offset(y: showFeatures ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.3), value: showFeatures)
                    
                    // Estatísticas do App
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 24))
                                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                            
                            Text("PINEE em Números")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 20) {
                            StatCard(
                                number: "100%",
                                label: "Gratuito",
                                icon: "heart.fill"
                            )
                            
                            StatCard(
                                number: "24/7",
                                label: "Disponível",
                                icon: "clock.fill"
                            )
                            
                            StatCard(
                                number: "∞",
                                label: "Possibilidades",
                                icon: "infinity"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(showFeatures ? 1.0 : 0.0)
                    .offset(y: showFeatures ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.5), value: showFeatures)
                    
                    // Agradecimento
                    VStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                            .scaleEffect(animateLogo ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateLogo)
                        
                        Text("Obrigado por escolher o PINEE!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Esperamos que o PINEE ajude você a alcançar seus objetivos financeiros e construir um futuro mais próspero.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .opacity(showFeatures ? 1.0 : 0.0)
                    .offset(y: showFeatures ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.7), value: showFeatures)
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("Desenvolvido com ❤️ por Corevo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("© 2025 PINEE. Todos os direitos reservados.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Sobre o PINEE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
                }
            }
        }
        .onAppear {
            animateLogo = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showFeatures = true
            }
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

private struct PineTreeIcon: View {
    var size: CGFloat = 140
    
    var body: some View {
        Group {
            if let _ = UIImage(named: "LoginTree") {
                Image("LoginTree")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: size * 0.07, height: size * 0.22)
                        .offset(y: size * 0.18)
                    
                    ForEach(0..<3, id: \.self) { index in
                        Triangle()
                            .fill(Color.white)
                            .frame(
                                width: size * (0.8 - CGFloat(index) * 0.12),
                                height: size * (0.45 - CGFloat(index) * 0.12)
                            )
                            .offset(y: CGFloat(index) * size * -0.08)
                    }
                }
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let number: String
    let label: String
    let icon: String
    @AppStorage("isMonochromaticMode") private var isMonochromaticMode: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isMonochromaticMode ? MonochromaticColorManager.primaryGreen : Color(hex: "#16A34A"))
            
            Text(number)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Preview
struct AboutAppView_Previews: PreviewProvider {
    static var previews: some View {
        AboutAppView()
    }
}
