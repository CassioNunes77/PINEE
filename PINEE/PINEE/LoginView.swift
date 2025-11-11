import SwiftUI

// Forma Triangle customizada para o ícone de pinheiro
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            // Background gradiente moderno
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#059669"), // Verde esmeralda mais escuro
                    Color(hex: "#10B981"), // Verde esmeralda médio
                    Color(hex: "#34D399")  // Verde esmeralda mais claro
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            // Elementos de design do fundo
            ZStack {
                // Círculos decorativos com blur
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: UIScreen.main.bounds.width * 0.8)
                    .position(x: UIScreen.main.bounds.width * 0.9,
                             y: UIScreen.main.bounds.height * 0.2)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: UIScreen.main.bounds.width * 0.6)
                    .position(x: UIScreen.main.bounds.width * 0.1,
                             y: UIScreen.main.bounds.height * 0.8)
                    .blur(radius: 60)
                
                // Conteúdo principal
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Logo e ícone
                    VStack(spacing: 16) {
                        // Imagem enviada para login (Assets: LoginTree). Fallback para pinheiro vetorial
                        Group {
                            if UIImage(named: "LoginTree") != nil {
                                Image("LoginTree")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 180, maxHeight: 180)
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 20)
                                        .offset(y: 25)
                                    
                                    // Folhas do pinheiro (triângulos maiores)
                                    ForEach(0..<3, id: \.self) { index in
                                        Triangle()
                                            .fill(Color.white)
                                            .frame(width: 70 - CGFloat(index * 12), height: 40 - CGFloat(index * 10))
                                            .offset(y: CGFloat(index * -8))
                                    }
                                }
                                .frame(width: 140, height: 140)
                                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 6)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text("PINEE")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            Text("Controle Financeiro Inteligente")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // Botão de login com Google atualizado
                    VStack(spacing: 16) {
                        Button(action: {
                            authViewModel.signInWithGoogle()
                        }) {
                            HStack(spacing: 16) {
                                // Ícone do Google usando SF Symbols
                                Image(systemName: "globe")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.blue)
                                
                                Text("Continuar com Google")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        }
                        .padding(.horizontal, 32)
                        
                        // Mensagem de segurança
                        Text("Seus dados estão 100% seguros conosco")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Loading e mensagens de erro
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                            .padding()
                    }
                    
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Versão do app atualizada
                    Text("Ver 0.5 Beta")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 20)
                }
                .padding()
            }
        }
    }
}


