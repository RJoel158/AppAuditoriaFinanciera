import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';

class PdfViewerDialog extends StatefulWidget {
  final String? localFilePath;
  final String? pdfUrl;
  final String title;

  const PdfViewerDialog({
    super.key,
    this.localFilePath,
    this.pdfUrl,
    this.title = 'Factura Electrónica SIAT',
  });

  static Future<void> show(
    BuildContext context, {
    String? localFilePath,
    String? pdfUrl,
    String title = 'Factura Electrónica SIAT',
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerDialog(
          localFilePath: localFilePath,
          pdfUrl: pdfUrl,
          title: title,
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
      // 1. Archivo local
      if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
        final file = File(widget.localFilePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
          });
          return;
        }
      }

      // 2. URL o Base64
      if (widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty) {
        final url = widget.pdfUrl!;

        if (url.startsWith('data:')) {
          // Data URL Base64
          final base64String = url.split(',').last;
          final bytes = base64Decode(base64String);
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
          });
          return;
        }

        if (url.startsWith('http://') || url.startsWith('https://')) {
          // Descarga remota
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

      setState(() {
        _errorMessage = 'No se pudo cargar el archivo PDF del comprobante.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al abrir el documento PDF: $e';
        _isLoading = false;
      });
    }
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
