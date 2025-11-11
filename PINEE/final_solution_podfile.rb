# Solução final para compatibilidade com Xcode 16
# Este script remove completamente o BoringSSL-GRPC e substitui por uma versão compatível

require 'xcodeproj'

puts "🔧 Aplicando solução final para Xcode 16..."

# 1. Fazer backup do Podfile atual
system("cp Podfile Podfile.backup.$(date +%Y%m%d_%H%M%S)")

# 2. Criar novo Podfile sem BoringSSL-GRPC
new_podfile = <<~PODFILE
# Podfile para Xcode 16 - SEM BoringSSL-GRPC
# Solução temporária para permitir compilação

platform :ios, '15.0'
use_frameworks!

target 'PINEE' do
  
  # Firebase sem dependências problemáticas
  pod 'FirebaseCore', '10.18.0'
  pod 'FirebaseAuth', '10.18.0'
  pod 'FirebaseFirestore', '10.18.0'
  pod 'FirebaseFirestoreSwift', '10.18.0'
  
  # Google Sign-In
  pod 'GoogleSignIn', '7.0.0'
  
  # Configurações agressivas para Xcode 16
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # Suprimir todos os warnings
        config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
        config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
        config.build_settings['CLANG_WARN_STRICT_PROTOTYPES'] = 'NO'
        config.build_settings['CLANG_WARN_UNGUARDED_AVAILABILITY'] = 'NO'
        
        # Configurações para bibliotecas problemáticas
        if target.name.start_with?('gRPC') || target.name.start_with?('abseil')
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
          config.build_settings['OTHER_CFLAGS'] = '$(inherited) -Wno-error -Wno-everything'
          config.build_settings['OTHER_CPLUSPLUSFLAGS'] = '$(inherited) -Wno-error -Wno-everything'
        end
        
        # Configurações para Firebase
        if target.name.start_with?('Firebase')
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
          config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        end
      end
    end
  end
  
end
PODFILE

File.write('Podfile', new_podfile)
puts "✅ Novo Podfile criado!"

# 3. Limpar e reinstalar
puts "🧹 Limpando instalação anterior..."
system("rm -rf Pods/ Podfile.lock")

puts "⬇️ Instalando dependências..."
system("pod install")

puts "🎉 Solução aplicada! Tente compilar agora."
puts "💡 Se ainda houver problemas, podemos usar uma versão mais antiga do Firebase."


