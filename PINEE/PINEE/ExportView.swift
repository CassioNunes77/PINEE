//
//  ExportView.swift
//  PINEE
//
//  Created by Cássio Nunes on 19/06/25.
//

import SwiftUI

struct ExportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var globalDateManager: GlobalDateManager
    @StateObject private var exportService = ExportService()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDateRange: DateRange
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var exportedFileURL: URL?
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "pt_BR")
        let displayText = formatter.string(from: now).capitalized
        
        _selectedDateRange = State(initialValue: DateRange(
            start: startOfMonth,
            end: endOfMonth,
            displayText: displayText
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Exportar Dados")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Exporte suas transações em formato CSV")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Date Range Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Período de Exportação")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("De:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(selectedDateRange.start))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Até:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(selectedDateRange.end))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Período:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(selectedDateRange.displayText)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Export Options
                VStack(spacing: 12) {
                    Text("Opções de Exportação")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ExportOptionRow(
                            icon: "doc.text",
                            title: "Formato CSV",
                            subtitle: "Compatível com Excel e Google Sheets",
                            isSelected: true
                        )
                        
                        ExportOptionRow(
                            icon: "calendar",
                            title: "Incluir período selecionado",
                            subtitle: "Apenas transações do período escolhido",
                            isSelected: true
                        )
                        
                        ExportOptionRow(
                            icon: "chart.bar",
                            title: "Dados completos",
                            subtitle: "Todas as informações das transações",
                            isSelected: true
                        )
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Export Button
                VStack(spacing: 16) {
                    if exportService.isExporting {
                        VStack(spacing: 12) {
                            ProgressView(value: exportService.exportProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                            
                            Text(exportService.exportMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: startExport) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Exportar para CSV")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    if let fileURL = exportedFileURL {
                        Button(action: { shareFile(fileURL) }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Compartilhar Arquivo")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Exportar")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            print("🔍 ExportView apareceu")
            selectedDateRange = globalDateManager.getCurrentDateRange()
            print("📅 Período selecionado: \(selectedDateRange.displayText)")
        }
        .alert("Exportação Concluída", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Seus dados foram exportados com sucesso!")
        }
        .alert("Erro na Exportação", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func startExport() {
        guard let userId = authViewModel.user?.id else {
            errorMessage = "Usuário não autenticado"
            showErrorAlert = true
            return
        }
        
        exportService.exportTransactionsToCSV(
            userId: userId,
            dateRange: selectedDateRange
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileURL):
                    self.exportedFileURL = fileURL
                    self.showSuccessAlert = true
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    private func shareFile(_ fileURL: URL) {
        exportService.shareCSVFile(fileURL: fileURL)
    }
}

struct ExportOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}
