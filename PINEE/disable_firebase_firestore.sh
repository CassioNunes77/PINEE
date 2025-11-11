#!/bin/bash

# Script para desabilitar temporariamente Firebase Firestore
# que é a principal dependência do BoringSSL-GRPC

echo "🔧 Desabilitando Firebase Firestore temporariamente..."

# 1. Fazer backup dos arquivos originais
cp PINEE/FirebaseAppDelegate.swift PINEE/FirebaseAppDelegate.swift.backup
cp PINEE/PINEEApp.swift PINEE/PINEEApp.swift.backup

# 2. Comentar imports do Firestore
sed -i '' 's/import FirebaseFirestore/\/\/ import FirebaseFirestore/g' PINEE/*.swift
sed -i '' 's/import FirebaseFirestoreSwift/\/\/ import FirebaseFirestoreSwift/g' PINEE/*.swift

# 3. Comentar uso do Firestore no código
find PINEE -name "*.swift" -exec sed -i '' 's/Firestore.firestore()/\/\/ Firestore.firestore()/g' {} \;
find PINEE -name "*.swift" -exec sed -i '' 's/\.collection(/\/\/ .collection(/g' {} \;
find PINEE -name "*.swift" -exec sed -i '' 's/\.document(/\/\/ .document(/g' {} \;

echo "✅ Firebase Firestore temporariamente desabilitado!"
echo "📋 Arquivos originais salvos com extensão .backup"
echo "🔄 Para restaurar: ./restore_firebase_firestore.sh"
echo ""
echo "🚀 Agora tente compilar o projeto!"


