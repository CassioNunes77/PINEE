# Solução para Erro de Provisioning Profile (0xe800801a)

## Erro
```
Failed to install embedded profile for focus.PINEE : 0xe800801a 
(This provisioning profile does not have a valid signature)
```

## Soluções (tente nesta ordem)

### 1. Limpar DerivedData (JÁ EXECUTADO)
✅ O DerivedData foi limpo automaticamente.

### 2. No Xcode - Reconfigurar Signing

1. Abra o projeto PINEE.xcodeproj no Xcode
2. Selecione o projeto "PINEE" no Project Navigator (ícone azul no topo)
3. Selecione o target "PINEE" na lista de targets
4. Vá para a aba **"Signing & Capabilities"**
5. **Desmarque** "Automatically manage signing"
6. **Marque novamente** "Automatically manage signing"
7. Verifique se:
   - ✅ Team: `4Y6MWV9B36` está selecionado
   - ✅ Bundle Identifier: `focus.PINEE`
   - ✅ Signing Certificate: "Apple Development" aparece

### 3. No Dispositivo iOS

1. Conecte seu iPhone ao Mac
2. No iPhone, vá em: **Configurações > Geral > Gerenciamento de VPN e Dispositivo** (ou **Configurações > Geral > Perfis e Gerenciamento de Dispositivo**)
3. Procure pelo perfil do desenvolvedor (geralmente aparece com o nome do seu time/Apple ID)
4. Toque no perfil e selecione **"Confiar"**
5. Confirme que você confia no desenvolvedor

### 4. Limpar e Recompilar

No Xcode:
1. **Product > Clean Build Folder** (Shift + Cmd + K)
2. Feche e reabra o Xcode
3. Tente compilar novamente (Cmd + R)

### 5. Se o problema persistir

#### Opção A: Verificar Certificados
1. No Xcode: **Xcode > Settings > Accounts**
2. Selecione sua conta Apple
3. Clique em **"Manage Certificates..."**
4. Verifique se há um certificado "Apple Development" válido
5. Se não houver, clique em **"+"** e adicione "Apple Development"

#### Opção B: Recriar Provisioning Profile Manualmente
1. Acesse [Apple Developer Portal](https://developer.apple.com/account)
2. Vá em **Certificates, Identifiers & Profiles**
3. Em **Profiles**, exclua o perfil existente para `focus.PINEE`
4. Crie um novo perfil de desenvolvimento
5. No Xcode, force a atualização: **Product > Clean Build Folder** e recompile

#### Opção C: Verificar Bundle Identifier
Certifique-se de que o Bundle ID `focus.PINEE` está registrado no Apple Developer Portal:
1. Acesse [Apple Developer Portal](https://developer.apple.com/account)
2. Vá em **Identifiers**
3. Verifique se `focus.PINEE` existe e está configurado corretamente

### 6. Verificar UDID do Dispositivo

Certifique-se de que seu dispositivo está registrado:
1. No Xcode: **Window > Devices and Simulators**
2. Selecione seu dispositivo
3. Copie o **UDID**
4. Verifique se este UDID está registrado no Apple Developer Portal

## Configuração Atual do Projeto

- ✅ Team: `4Y6MWV9B36`
- ✅ Bundle Identifier: `focus.PINEE`
- ✅ Code Sign Style: Automatic
- ✅ Code Sign Identity: Apple Development

## Informações do Dispositivo

- Modelo: iPhone 14,5 (iPhone 13 Pro Max)
- iOS: 18.6 (22G5073b)
- UDID: 00008110-0011449E1E3A401E

## Nota Importante

Se você estiver usando uma conta Apple Developer gratuita (Apple ID pessoal):
- O certificado expira após 7 dias
- Você precisa recriar o perfil periodicamente
- O dispositivo precisa estar conectado ao Mac para instalar

Se você tiver uma conta Apple Developer paga ($99/ano):
- Os certificados são mais estáveis
- Menos problemas com provisioning profiles

