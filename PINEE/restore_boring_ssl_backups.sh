#!/bin/bash

# Script para restaurar backups dos arquivos BoringSSL-GRPC
echo "🔄 Restaurando backups dos arquivos BoringSSL-GRPC..."

# Restaurar arquivos .backup
find Pods/BoringSSL-GRPC -name "*.backup" | while read backup_file; do
    original_file="${backup_file%.backup}"
    echo "  - Restaurando: $original_file"
    cp "$backup_file" "$original_file"
    rm "$backup_file"
done

# Restaurar arquivos xcconfig
find Pods/Target\ Support\ Files/BoringSSL-GRPC -name "*.backup" | while read backup_file; do
    original_file="${backup_file%.backup}"
    echo "  - Restaurando: $original_file"
    cp "$backup_file" "$original_file"
    rm "$backup_file"
done

echo "✅ Backups restaurados!"


