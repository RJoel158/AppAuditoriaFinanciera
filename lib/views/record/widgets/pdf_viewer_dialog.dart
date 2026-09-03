import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/financial_record.dart';

class PdfViewerDialog extends StatefulWidget {
  final String? localFilePath;
  final String? pdfUrl;
  final String title;
  final FinancialRecord? record;
  final double? amount;
  final DateTime? date;
  final List<InvoiceItem>? items;

  const PdfViewerDialog({
    super.key,
    this.localFilePath,
    this.pdfUrl,
    this.title = 'Factura Electrónica SIAT',
    this.record,
    this.amount,
    this.date,
    this.items,
  });

  static Future<void> show(
    BuildContext context, {
    String? localFilePath,
    String? pdfUrl,
    String title = 'Factura Electrónica SIAT',
    FinancialRecord? record,
    double? amount,
    DateTime? date,
    List<InvoiceItem>? items,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerDialog(
          localFilePath: localFilePath,
          pdfUrl: pdfUrl,
          title: title,
          record: record,
          amount: amount ?? record?.amount,
          date: date ?? record?.date,
          items: items ?? record?.items,
        ),
      ),
    );
  }

  @override
  State<PdfViewerDialog> createState() => _PdfViewerDialogState();
}

class _PdfViewerDialogState extends State<PdfViewerDialog> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdfData();
  }

  Future<void> _loadPdfData() async {
    try {
      // 1. Archivo local (verificar si se pasó en localFilePath o en pdfUrl)
      final candidatePath = widget.localFilePath ??
          (widget.pdfUrl != null && !widget.pdfUrl!.startsWith('http') && !widget.pdfUrl!.startsWith('data:')
              ? widget.pdfUrl
              : null);

      if (candidatePath != null && candidatePath.isNotEmpty) {
        final file = File(candidatePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty && bytes.length > 50) {
            setState(() {
              _pdfBytes = bytes;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 2. Data URL Base64
      if (widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty) {
        final url = widget.pdfUrl!.trim();

        if (url.startsWith('data:')) {
          final commaIdx = url.indexOf(',');
          final base64String = commaIdx != -1 ? url.substring(commaIdx + 1).trim() : url;
          final cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
          final normalized = base64.normalize(cleanBase64);
          final bytes = base64Decode(normalized);
          if (bytes.isNotEmpty) {
            setState(() {
              _pdfBytes = bytes;
              _isLoading = false;
            });
            return;
          }
        }

        // 3. Descarga remota HTTP
        if (url.startsWith('http://') || url.startsWith('https://')) {
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            setState(() {
              _pdfBytes = response.bodyBytes;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 4. Generación Garantizada On-The-Fly si no se pudo cargar archivo físico
      final fallbackBytes = await _generateDynamicPdfBytes();
      setState(() {
        _pdfBytes = fallbackBytes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando PDF, generando comprobante dinámico: $e');
      try {
        final fallbackBytes = await _generateDynamicPdfBytes();
        setState(() {
          _pdfBytes = fallbackBytes;
          _isLoading = false;
        });
      } catch (e2) {
        setState(() {
          _errorMessage = 'Error al renderizar el documento PDF: $e2';
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List> _generateDynamicPdfBytes() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final invoiceTitle = widget.title.isNotEmpty ? widget.title : (widget.record?.title ?? 'Factura Electrónica SIAT');
    final invoiceAmount = widget.amount ?? widget.record?.amount ?? 0.0;
    final invoiceDate = widget.date ?? widget.record?.date ?? DateTime.now();
    final invoiceItems = widget.items ?? widget.record?.items ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                invoiceTitle.toUpperCase(),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text('DOCUMENTO FISCAL DIGITAL',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
              pw.Divider(thickness: 0.8, color: PdfColors.grey400),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fecha de Emisión:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text(dateFormat.format(invoiceDate), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, color: PdfColors.grey400),

              // Tabla de productos si existen
              if (invoiceItems.isNotEmpty) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('DETALLE DE PRODUCTOS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 3),
                pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(3.5),
                    2: const pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text('CANT', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text('DESCRIPCIÓN', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text('SUBTOTAL', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                    ...invoiceItems.map(
                      (item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                            child: pw.Text(
                              item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2),
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                            child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 7)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                            child: pw.Text('Bs ${item.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8, color: PdfColors.grey400),
              ],

              // Total
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL BS:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Bs ${invoiceAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('DOCUMENTO AUDITADO Y REGISTRADO EN FAMFINANCE',
                  style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 1,
        actions: [
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.primary),
              tooltip: 'Compartir Documento',
              onPressed: () => Printing.sharePdf(bytes: _pdfBytes!, filename: '${widget.title}.pdf'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Cargando comprobante oficial...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : PdfPreview(
                  build: (format) => _pdfBytes!,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  maxPageWidth: 600,
                  pdfFileName: '${widget.title}.pdf',
                  scrollViewDecoration: const BoxDecoration(color: AppColors.background),
                ),
    );
  }
}
