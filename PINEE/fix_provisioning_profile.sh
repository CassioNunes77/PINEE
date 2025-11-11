#!/bin/bash

# Script para corrigir problemas de provisioning profile no Xcode

echo "🔧 Limpando DerivedData do projeto PINEE..."

# Limpar DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/PINEE-*

echo "✅ DerivedData limpo"

echo ""
echo "📋 Próximos passos para corrigir o problema de provisioning profile:"
echo ""
echo "1. Abra o Xcode"
echo "2. Vá para o projeto PINEE"
echo "3. Selecione o target 'PINEE' no Project Navigator"
echo "4. Vá para a aba 'Signing & Capabilities'"
echo "5. Certifique-se de que:"
echo "   - 'Automatically manage signing' está marcado"
echo "   - O 'Team' está selecionado (4Y6MWV9B36)"
echo "   - O Bundle Identifier está como 'focus.PINEE'"
echo ""
echo "6. Se o problema persistir:"
echo "   - Desmarque e marque novamente 'Automatically manage signing'"
echo "   - Ou tente selecionar um perfil manualmente e depois voltar para automático"
echo ""
echo "7. No dispositivo iOS:"
echo "   - Vá em Configurações > Geral > Gerenciamento de VPN e Dispositivo"
echo "   - Procure pelo seu perfil de desenvolvedor e toque em 'Confiar'"
echo ""
echo "8. Limpe o build: Product > Clean Build Folder (Shift+Cmd+K)"
echo "9. Tente compilar novamente"
echo ""

