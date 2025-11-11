#!/bin/bash

# Script para atualizar Firebase e resolver problemas de compatibilidade com Xcode 16
# Execute este script no diretório raiz do projeto

echo "🔥 Atualizando Firebase para compatibilidade com Xcode 16..."

# 1. Limpar cache do CocoaPods
echo "📦 Limpando cache do CocoaPods..."
pod cache clean --all

# 2. Remover Pods e Podfile.lock
echo "🗑️ Removendo instalação anterior..."
rm -rf Pods/
rm -rf Podfile.lock

# 3. Limpar build do Xcode
echo "🧹 Limpando build do Xcode..."
xcodebuild clean -workspace PINEE.xcworkspace -scheme PINEE

# 4. Instalar pods atualizados
echo "⬇️ Instalando dependências atualizadas..."
pod install --repo-update

# 5. Verificar instalação
echo "✅ Verificando instalação..."
if [ -d "Pods" ]; then
    echo "✅ Pods instalados com sucesso!"
    echo "📋 Versões instaladas:"
    pod outdated
else
    echo "❌ Erro na instalação dos Pods"
    exit 1
fi

echo "🎉 Atualização concluída! Agora você pode compilar com Xcode 16."
echo "💡 Se ainda houver erros, execute 'pod update' e limpe o projeto no Xcode."


