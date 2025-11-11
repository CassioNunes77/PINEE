#!/bin/bash

# Script para restaurar Firebase Firestore

echo "🔄 Restaurando Firebase Firestore..."

# Restaurar arquivos .backup
find PINEE -name "*.backup" | while read backup_file; do
    original_file="${backup_file%.backup}"
    echo "  - Restaurando: $original_file"
    cp "$backup_file" "$original_file"
    rm "$backup_file"
done

echo "✅ Firebase Firestore restaurado!"


