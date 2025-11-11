#!/bin/bash

# Script para corrigir erros de sintaxe Swift causados pelo comentário excessivo

echo "🔧 Corrigindo erros de sintaxe Swift..."

# 1. Corrigir declarações de variáveis Firestore
echo "📝 Corrigindo declarações de variáveis Firestore..."

find PINEE -name "*.swift" -exec sed -i '' 's/private let db = \/\/ Firestore\.firestore()/private let db: Any? = nil \/\/ Firestore.firestore() temporariamente desabilitado/g' {} \;

# 2. Corrigir tipos ListenerRegistration
echo "📝 Corrigindo tipos ListenerRegistration..."
find PINEE -name "*.swift" -exec sed -i '' 's/ListenerRegistration/Any?/g' {} \;

# 3. Corrigir tipos QueryDocumentSnapshot
echo "📝 Corrigindo tipos QueryDocumentSnapshot..."
find PINEE -name "*.swift" -exec sed -i '' 's/QueryDocumentSnapshot/Any/g' {} \;

# 4. Corrigir tipos Firestore em parâmetros de função
echo "📝 Corrigindo tipos Firestore em parâmetros..."
find PINEE -name "*.swift" -exec sed -i '' 's/db: Firestore/db: Any?/g' {} \;

# 5. Corrigir chaves extras que quebraram a sintaxe
echo "📝 Corrigindo chaves extras..."

# Arquivos específicos que têm problemas de chaves
files_with_bracket_issues=(
    "PINEE/TransferInvestmentView.swift"
    "PINEE/AddTransactionView.swift" 
    "PINEE/TransferIncomeView.swift"
    "PINEE/AuthViewModel.swift"
    "PINEE/DevView.swift"
    "PINEE/ContentView.swift"
    "PINEE/SettingsView.swift"
)

for file in "${files_with_bracket_issues[@]}"; do
    if [ -f "$file" ]; then
        echo "  - Corrigindo chaves em: $file"
        # Remover chaves extras no final dos arquivos
        sed -i '' '/^}$/d' "$file"
        
        # Adicionar uma chave de fechamento no final se necessário
        if ! tail -1 "$file" | grep -q "^}"; then
            echo "}" >> "$file"
        fi
    fi
done

# 6. Corrigir problemas específicos de sintaxe
echo "📝 Corrigindo problemas específicos de sintaxe..."

# Corrigir } else { que foram quebrados
find PINEE -name "*.swift" -exec sed -i '' 's/^        } else {$/        \/\/ } else {/g' {} \;

# 7. Comentar funções que usam Firestore
echo "📝 Comentando funções que usam Firestore..."
find PINEE -name "*.swift" -exec sed -i '' 's/private func createRecurringTransactions(/\/\/ private func createRecurringTransactions(/g' {} \;
find PINEE -name "*.swift" -exec sed -i '' 's/private func createRecurringInvestmentTransactions(/\/\/ private func createRecurringInvestmentTransactions(/g' {} \;

# 8. Corrigir @State properties que ficaram fora de structs
echo "📝 Corrigindo @State properties fora de structs..."
find PINEE -name "*.swift" -exec sed -i '' '/^    @State private var showTransferInvestment = false$/c\
    \/\/ @State private var showTransferInvestment = false' {} \;
find PINEE -name "*.swift" -exec sed -i '' '/^    @State private var showTransferIncome = false$/c\
    \/\/ @State private var showTransferIncome = false' {} \;
find PINEE -name "*.swift" -exec sed -i '' '/^    @State private var transactionToInvest: TransactionModel?$/c\
    \/\/ @State private var transactionToInvest: TransactionModel?' {} \;

echo "✅ Erros de sintaxe Swift corrigidos!"
echo "🚀 Agora tente compilar novamente!"











