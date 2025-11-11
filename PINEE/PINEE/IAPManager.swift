import Foundation
import StoreKit
import Combine

@MainActor
class IAPManager: ObservableObject {
    static let shared = IAPManager()
    
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()
    
    // Substitua pelo Product ID cadastrado no App Store Connect
    let premiumProductID = "premium_upgrade"
    
    @Published var premiumProduct: Product?
    
    init() {
        fetchProducts()
        listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func fetchProducts() {
        Task {
            do {
                let products = try await Product.products(for: [premiumProductID])
                self.premiumProduct = products.first
            } catch {
                self.errorMessage = "Erro ao buscar produtos: \(error.localizedDescription)"
            }
        }
    }
    
    func purchasePremium() async {
        guard let product = premiumProduct else { return }
        isLoading = true
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await handlePurchase(transaction: transaction)
                case .unverified(_, let error):
                    self.errorMessage = "Compra não verificada: \(error.localizedDescription)"
                }
            case .userCancelled:
                break
            case .pending:
                self.errorMessage = "Compra pendente."
            default:
                break
            }
        } catch {
            self.errorMessage = "Erro na compra: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
        } catch {
            self.errorMessage = "Erro ao restaurar compras: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func listenForTransactions() {
        updateListenerTask = Task.detached(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.handlePurchase(transaction: transaction)
                }
            }
        }
    }
    
    private func handlePurchase(transaction: Transaction) async {
        // Aqui você pode validar o recibo com a Apple (quando tiver conta paga)
        // await validateReceipt()
        
        // Atualize o status premium no Firestore
        await updatePremiumStatusInFirestore(isPremium: true)
        
        // Marque como premium localmente
        await MainActor.run {
            self.isPremium = true
        }
        // Finalize a transação
        await transaction.finish()
    }
    
    // Placeholder para validação de recibo
    func validateReceipt() async {
        // Implemente a validação de recibo aqui quando tiver conta developer
    }
    
    // Placeholder para integração com Firestore
    func updatePremiumStatusInFirestore(isPremium: Bool) async {
        // A atualização do status premium será feita na tela após a compra/restauração.
    }
    
    // NOVO: Checagem de expiração automática da assinatura
    // TEMPORARIAMENTE COMENTADO - AuthViewModel não disponível
    /*
    func checkSubscriptionStatus(authViewModel: AuthViewModel? = nil, onExpire: (() -> Void)? = nil) async {
        guard let product = premiumProduct else {
            await MainActor.run { self.isPremium = false }
            return
        }
        do {
            let statuses = try await product.subscription?.status
            if let status = statuses?.first {
                let state = status.state
                if state == .subscribed {
                    await MainActor.run { self.isPremium = true }
                } else if state == .expired || state == .inGracePeriod || state == .inBillingRetryPeriod || state == .revoked {
                    await MainActor.run { self.isPremium = false }
                    if let authVM = authViewModel {
                        authVM.setPremiumStatus(isPremium: false) { _ in }
                    }
                    onExpire?()
                } else {
                    await MainActor.run { self.isPremium = false }
                }
            } else {
                await MainActor.run { self.isPremium = false }
            }
        } catch {
            await MainActor.run { self.isPremium = false }
        }
    }
    */
} 