import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/app_categories.dart';
import '../models/financial_record.dart';

class PdfReportService {
  /// Genera y abre el visor de impresión/descarga de PDF directamente en el móvil
  static Future<void> generateAndExportPdf({
    required List<FinancialRecord> records,
    required double totalIncome,
    required double totalExpense,
    required String periodLabel,
    String? aiDiagnosis,
  }) async {
    final pdf = pw.Document();
    final balance = totalIncome - totalExpense;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat('#,##0.00', 'es_BO');

    // Desglose por categoría
    final Map<String, double> categoryTotals = {};
    for (final r in records.where((r) => r.type == RecordType.expense)) {
      categoryTotals[r.category] = (categoryTotals[r.category] ?? 0.0) + r.amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) => _buildHeader(periodLabel),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          // 1. Tarjetas de Resumen Financiero
          _buildSummaryCards(totalIncome, totalExpense, balance, currencyFormat),
          pw.SizedBox(height: 16),

          // 2. Diagnóstico IA / Recomendaciones si existen
          if (aiDiagnosis != null && aiDiagnosis.trim().isNotEmpty) ...[
            _buildAiDiagnosisBox(aiDiagnosis),
            pw.SizedBox(height: 16),
          ],

          // 3. Desglose de Gastos por Categoría
          if (categoryTotals.isNotEmpty) ...[
            pw.Text(
              'Desglose de Gastos por Categoría',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
            ),
            pw.SizedBox(height: 6),
            _buildCategoryTable(categoryTotals, totalExpense, currencyFormat),
            pw.SizedBox(height: 16),
          ],

          // 4. Detalle de Movimientos Registrados
          pw.Text(
            'Detalle de Transacciones (${records.length} movimientos)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 6),
          _buildTransactionsTable(records, dateFormat, currencyFormat),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final filename = 'FamFinance_Reporte_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    // Despliega automáticamente la ventana nativa de compartir de Android (WhatsApp, Drive, Gmail, etc.)
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }


  static pw.Widget _buildHeader(String periodLabel) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FamFinance - Auditoría Familiar',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
              ),

              pw.SizedBox(height: 2),
              pw.Text(
                'Periodo: $periodLabel',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.Text(
                'Costo de emisión: Bs 0.00 (Local)',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Reporte Oficial de Control Familiar', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCards(
    double totalIncome,
    double totalExpense,
    double balance,
    NumberFormat currencyFormat,
  ) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _buildCard('Ingresos Totales', 'Bs ${currencyFormat.format(totalIncome)}', PdfColors.teal700, PdfColors.teal50),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildCard('Gastos Totales', 'Bs ${currencyFormat.format(totalExpense)}', PdfColors.red700, PdfColors.red50),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildCard(
            balance >= 0 ? 'Ahorro / Superávit' : 'Déficit Neto',
            'Bs ${currencyFormat.format(balance)}',
            balance >= 0 ? PdfColors.blue700 : PdfColors.orange800,
            balance >= 0 ? PdfColors.blue50 : PdfColors.orange50,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCard(String title, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: textColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 9, color: textColor, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildAiDiagnosisBox(String aiDiagnosis) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.amber600, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('💡 Diagnóstico Financiero & Recomendaciones IA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
          pw.SizedBox(height: 4),
          pw.Text(aiDiagnosis, style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey900, lineSpacing: 1.3)),
        ],
      ),
    );
  }

  static pw.Widget _buildCategoryTable(
    Map<String, double> categoryTotals,
    double totalExpense,
    NumberFormat currencyFormat,
  ) {
    final sorted = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Categoría', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Monto (Bs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('% del Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...sorted.map((entry) {
          final cat = AppCategories.getCategoryById(entry.key);
          final percent = totalExpense > 0 ? (entry.value / totalExpense * 100).toStringAsFixed(1) : '0.0';
          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(cat.name, style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(currencyFormat.format(entry.value), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$percent%', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTransactionsTable(
    List<FinancialRecord> records,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Fecha', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Concepto', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Categoría', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Miembro', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Monto (Bs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...records.map((r) {
          final isIncome = r.type == RecordType.income;
          final cat = AppCategories.getCategoryById(r.category);
          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(dateFormat.format(r.date), style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.title, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cat.name, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.registeredBy, style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '${isIncome ? "+" : "-"}${currencyFormat.format(r.amount)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: isIncome ? PdfColors.teal800 : PdfColors.red800,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
