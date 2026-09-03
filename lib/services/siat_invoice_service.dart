import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../config/gemini_config.dart';
import '../models/siat_invoice.dart';

class SiatInvoiceService {
  final http.Client _client;

  SiatInvoiceService({http.Client? client}) : _client = client ?? http.Client();

  /// Diccionario nativo de principales empresas y comercios de Bolivia por NIT
  static final Map<String, Map<String, String>> _knownBolivianNits = {
    '1009445021': {'name': 'IC Norte S.A.', 'cat': 'cat_food', 'desc': 'Supermercado IC Norte'},
    '1020415021': {'name': 'Hipermaxi S.A.', 'cat': 'cat_food', 'desc': 'Supermercado Hipermaxi'},
    '1020269020': {'name': 'Farmacias Chavez S.A.', 'cat': 'cat_health', 'desc': 'Farmacia Chavez'},
    '1016766023': {'name': 'Farmacorp S.A.', 'cat': 'cat_health', 'desc': 'Farmacia Farmacorp'},
    '1028775027': {'name': 'YPFB Refinación S.A.', 'cat': 'cat_transport', 'desc': 'Combustible / Gasolina'},
    '1028779029': {'name': 'YPFB Aviación S.A.', 'cat': 'cat_transport', 'desc': 'Combustible Aviación'},
    '1020583025': {'name': 'Fidalga S.A.', 'cat': 'cat_food', 'desc': 'Supermercado Fidalga'},
    '1020427027': {'name': 'Supermercados Ketal S.A.', 'cat': 'cat_food', 'desc': 'Supermercado Ketal'},
    '1020387029': {'name': 'PIL Andina S.A.', 'cat': 'cat_food', 'desc': 'Lácteos y Alimentos PIL'},
    '1020525027': {'name': 'Avícola Sofía Ltda.', 'cat': 'cat_food', 'desc': 'Carnes y Alimentos Sofía'},
    '1020229023': {'name': 'CRE R.L.', 'cat': 'cat_services', 'desc': 'Servicio de Electricidad CRE'},
    '1020227027': {'name': 'SAGUAPAC R.L.', 'cat': 'cat_services', 'desc': 'Servicio de Agua Saguapac'},
    '1020359021': {'name': 'DELAPAZ S.A.', 'cat': 'cat_services', 'desc': 'Electricidad La Paz'},
    '1020355029': {'name': 'ELFEC S.A.', 'cat': 'cat_services', 'desc': 'Electricidad Cochabamba'},
    '1020239021': {'name': 'Telecel S.A. (Tigo)', 'cat': 'cat_services', 'desc': 'Telefonía e Internet Tigo'},
    '1020295020': {'name': 'Entel S.A.', 'cat': 'cat_services', 'desc': 'Telefonía e Internet Entel'},
    '1020317028': {'name': 'Nuevatel PCS (Viva)', 'cat': 'cat_services', 'desc': 'Telefonía e Internet Viva'},
    '1020465022': {'name': 'Cine Center S.A.', 'cat': 'cat_entertainment', 'desc': 'Cine y Entretenimiento'},
    '1020343026': {'name': 'Boliviana de Aviación (BoA)', 'cat': 'cat_transport', 'desc': 'Pasajes Aéreos BoA'},
    '1028781021': {'name': 'Farmacias Bolivia', 'cat': 'cat_health', 'desc': 'Farmacia Bolivia'},
    '1020615024': {'name': 'Pollos Chuy', 'cat': 'cat_food', 'desc': 'Restaurante Pollos Chuy'},
    '1020601026': {'name': 'Pollos Copacabana', 'cat': 'cat_food', 'desc': 'Restaurante Pollos Copacabana'},
    '1003456029': {'name': 'Univalle S.A.', 'cat': 'cat_education', 'desc': 'Universidad del Valle'},
  };

  /// 1. Parsear datos iniciales del código QR
  SiatInvoice? parseQrData(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('http://') || text.startsWith('https://')) {
      return _parseSiatUrl(text);
    }

    if (text.contains('|')) {
      return _parsePipeSeparated(text);
    }

    return null;
  }

  SiatInvoice? _parseSiatUrl(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      final params = uri.queryParameters;

      final nit = params['nit'] ?? params['p_nit'] ?? params['Nit'] ?? '';
      final cuf = params['cuf'] ?? params['p_cuf'] ?? params['Cuf'] ?? '';
      final numero = params['numero'] ?? params['nro'] ?? params['nroFactura'] ?? params['p_numero'] ?? '';
      final importeStr = params['importe'] ?? params['monto'] ?? params['total'] ?? params['p_importe'] ?? '0';
      final fechaStr = params['fecha'] ?? params['p_fecha'] ?? '';

      final amount = double.tryParse(importeStr.replaceAll(',', '.')) ?? 0.0;

      DateTime date = DateTime.now();
      if (fechaStr.isNotEmpty) {
        date = _parseFlexibleDate(fechaStr) ?? DateTime.now();
      }

      // Buscar si el NIT ya es conocido en Bolivia
      final known = _knownBolivianNits[nit];
      final vendor = known?['name'] ?? (nit.isNotEmpty ? 'Factura SIAT (NIT: $nit)' : 'Factura Electrónica SIAT');
      final cat = known?['cat'] ?? inferCategory(vendor);
      final notes = 'Factura N° $numero • ${known?['desc'] ?? vendor}';

      return SiatInvoice(
        nit: nit,
        cuf: cuf,
        invoiceNumber: numero,
        amount: amount,
        date: date,
        vendorName: vendor,
        rawQrUrl: urlString,
        suggestedCategory: cat,
        readableNotes: notes,
      );
    } catch (e) {
      debugPrint('Error parseando URL SIAT: $e');
      return null;
    }
  }

  SiatInvoice? _parsePipeSeparated(String text) {
    try {
      final parts = text.split('|');
      if (parts.length < 5) return null;

      final nit = parts[0].trim();
      final numero = parts[1].trim();
      final autorizacion = parts[2].trim();
      final fechaStr = parts[3].trim();
      final importeStr = parts[4].trim();
      final controlCode = parts.length > 6 ? parts[6].trim() : null;
      final buyerNit = parts.length > 7 ? parts[7].trim() : null;

      final amount = double.tryParse(importeStr.replaceAll(',', '.')) ?? 0.0;
      final date = _parseFlexibleDate(fechaStr) ?? DateTime.now();

      final known = _knownBolivianNits[nit];
      final vendor = known?['name'] ?? 'Factura N° $numero (NIT: $nit)';
      final cat = known?['cat'] ?? inferCategory(vendor);
      final notes = 'Factura N° $numero • ${known?['desc'] ?? vendor}';

      return SiatInvoice(
        nit: nit,
        cuf: autorizacion,
        invoiceNumber: numero,
        amount: amount,
        date: date,
        vendorName: vendor,
        authorizationNumber: autorizacion,
        controlCode: controlCode,
        buyerNit: buyerNit,
        rawQrUrl: text,
        suggestedCategory: cat,
        readableNotes: notes,
      );
    } catch (e) {
      debugPrint('Error parseando formato pipe: $e');
      return null;
    }
  }

  /// 2. Consultar web SIAT y enriquecer con IA Gemini 1.5 Flash
  Future<SiatInvoice> fetchInvoiceDetails(SiatInvoice invoice) async {
    String htmlContent = '';
    String? pdfUrl;

    // A. Intentar consulta HTTP al portal SIAT
    if (invoice.rawQrUrl.startsWith('http')) {
      try {
        final response = await _client.get(
          Uri.parse(invoice.rawQrUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          htmlContent = response.body;

          // Buscar enlace de descarga de PDF en el HTML
          final document = html_parser.parse(htmlContent);
          final links = document.querySelectorAll('a, button');
          for (final link in links) {
            final href = link.attributes['href'] ?? '';
            if (href.toLowerCase().contains('.pdf') ||
                href.toLowerCase().contains('descargar') ||
                href.toLowerCase().contains('representaciongrafica')) {
              if (href.startsWith('http')) {
                pdfUrl = href;
              } else if (href.startsWith('/')) {
                final uri = Uri.parse(invoice.rawQrUrl);
                pdfUrl = '${uri.scheme}://${uri.host}$href';
              }
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Consulta HTTP SIAT directa: $e');
      }
    }

    // B. Procesamiento Inteligente con Gemini 1.5 Flash
    try {
      final aiInvoice = await _analyzeInvoiceWithGemini(
        invoice: invoice,
        htmlContent: htmlContent,
      );

      if (aiInvoice != null) {
        return aiInvoice.copyWith(pdfUrl: pdfUrl ?? aiInvoice.pdfUrl);
      }
    } catch (e) {
      debugPrint('Error en Gemini AI Invoice Parser: $e');
    }

    // C. Fallback con Diccionario Local de NITs
    final known = _knownBolivianNits[invoice.nit];
    if (known != null) {
      final updatedVendor = known['name']!;
      final updatedCat = known['cat']!;
      final notes = 'Compra en $updatedVendor • Factura N° ${invoice.invoiceNumber}';
      return invoice.copyWith(
        vendorName: updatedVendor,
        suggestedCategory: updatedCat,
        readableNotes: notes,
        pdfUrl: pdfUrl,
      );
    }

    return invoice.copyWith(pdfUrl: pdfUrl);
  }

  /// Análisis con Google Gemini AI
  Future<SiatInvoice?> _analyzeInvoiceWithGemini({
    required SiatInvoice invoice,
    required String htmlContent,
  }) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GeminiConfig.apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
        ),
      );

      final prompt = '''
Eres un auditor financiero experto en facturación electrónica de Bolivia (SIAT - Impuestos Nacionales).
Analiza los datos de esta factura emitida en Bolivia:
- URL / QR: ${invoice.rawQrUrl}
- NIT Emisor: ${invoice.nit}
- Factura N°: ${invoice.invoiceNumber}
- CUF: ${invoice.cuf}
- Monto inicial detectado: ${invoice.amount}
- Fecha inicial: ${invoice.date.toIso8601String()}
- Contenido Web / HTML: ${htmlContent.isNotEmpty ? htmlContent.substring(0, htmlContent.length.clamp(0, 3000)) : "Sin contenido HTML"}

Instrucciones estrictas:
1. "vendorName": Nombre comercial real, limpio y exacto de la empresa (Ejemplo: "IC Norte S.A.", "Hipermaxi", "Farmacias Chavez", "YPFB", etc.). Si el NIT es 1009445021 es "IC Norte S.A.".
2. "amount": Monto total a pagar en Bolivianos (número decimal, ej: 45.50). Si no está explícito pero puedes deducirlo del QR/HTML, colócalo.
3. "date": Fecha en formato "YYYY-MM-DD" o la fecha de la factura.
4. "suggestedCategory": Una de las siguientes categorías exactas: "cat_food", "cat_health", "cat_transport", "cat_services", "cat_education", "cat_entertainment", "cat_shopping".
5. "readableNotes": Una nota breve y limpia para control de gastos familiar (Ejemplo: "Compra en IC Norte • Factura N° ${invoice.invoiceNumber}"). No pongas hashes largos de CUF ni códigos incomprensibles.

Devuelve ÚNICAMENTE un JSON con esta estructura:
{
  "vendorName": "IC Norte S.A.",
  "amount": 0.0,
  "date": "2026-09-03",
  "suggestedCategory": "cat_food",
  "readableNotes": "Compra en IC Norte S.A. • Factura N° 327519"
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final jsonText = response.text?.trim() ?? '';
      if (jsonText.isNotEmpty) {
        final data = jsonDecode(jsonText) as Map<String, dynamic>;

        final vendor = data['vendorName'] as String? ?? invoice.vendorName;
        final amountVal = (data['amount'] as num?)?.toDouble() ?? invoice.amount;
        final cat = data['suggestedCategory'] as String? ?? invoice.suggestedCategory;
        final notes = data['readableNotes'] as String? ?? 'Factura N° ${invoice.invoiceNumber} • $vendor';

        DateTime parsedDate = invoice.date;
        if (data['date'] != null) {
          final d = DateTime.tryParse(data['date'].toString());
          if (d != null) parsedDate = d;
        }

        return invoice.copyWith(
          vendorName: vendor,
          amount: amountVal > 0 ? amountVal : invoice.amount,
          suggestedCategory: cat,
          date: parsedDate,
          readableNotes: notes,
        );
      }
    } catch (e) {
      debugPrint('Gemini parse exception: $e');
    }
    return null;
  }

  /// 3. Descargar PDF oficial o generar Comprobante PDF si no hay link directo
  Future<File?> downloadOrGenerateInvoicePdf({
    required SiatInvoice invoice,
  }) async {
    // Si hay URL de descarga del SIAT, intentar descargarla
    if (invoice.pdfUrl != null && invoice.pdfUrl!.isNotEmpty) {
      try {
        final response = await _client.get(
          Uri.parse(invoice.pdfUrl!),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'factura_siat_${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          return file;
        }
      } catch (e) {
        debugPrint('Descarga PDF remota falló, generando comprobante local: $e');
      }
    }

    // Si no hay PDF remoto o falló la descarga, generar Comprobante Oficial Digital SIAT en PDF
    return await _generateLocalVoucherPdf(invoice);
  }

  /// Generar comprobante en PDF elegante para auditoría familiar
  Future<File> _generateLocalVoucherPdf(SiatInvoice invoice) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                invoice.vendorName.toUpperCase(),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text('NIT: ${invoice.nit}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text('FACTURA ELECTRÓNICA SIAT N° ${invoice.invoiceNumber}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fecha de Emisión:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(dateFormat.format(invoice.date), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (invoice.buyerNit != null && invoice.buyerNit!.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NIT/CI Comprador:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text(invoice.buyerNit!, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL PAGADO:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Bs ${invoice.amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              if (invoice.cuf.isNotEmpty) ...[
                pw.Text('CÓDIGO ÚNICO DE FACTURA (CUF):', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Text(
                  invoice.cuf,
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                ),
              ],
              pw.Spacer(),
              pw.Text(
                'Documento registrado y auditado con FamFinance',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
              ),
            ],
          );
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final fileName = 'comprobante_siat_${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// 4. Deducir categoría por palabras clave
  static String inferCategory(String vendorName) {
    final v = vendorName.toLowerCase();
    if (v.contains('farma') || v.contains('salud') || v.contains('clinica') || v.contains('hospital') || v.contains('chavez')) {
      return 'cat_health';
    }
    if (v.contains('hipermaxi') || v.contains('fidalga') || v.contains('norte') || v.contains('ic norte') || v.contains('supermercado') || v.contains('mercado') || v.contains('alimentos') || v.contains('sofia') || v.contains('pil') || v.contains('lacteos')) {
      return 'cat_food';
    }
    if (v.contains('restaurante') || v.contains('snack') || v.contains('cafe') || v.contains('pollos') || v.contains('pizza') || v.contains('burger') || v.contains('comida')) {
      return 'cat_food';
    }
    if (v.contains('ypfb') || v.contains('surtidor') || v.contains('gasolina') || v.contains('combustible') || v.contains('transporte') || v.contains('boa')) {
      return 'cat_transport';
    }
    if (v.contains('cre') || v.contains('saguapac') || v.contains('delapaz') || v.contains('elfec') || v.contains('tigo') || v.contains('entel') || v.contains('viva') || v.contains('servicio')) {
      return 'cat_services';
    }
    if (v.contains('colegio') || v.contains('universidad') || v.contains('univalle') || v.contains('instituto') || v.contains('libreria')) {
      return 'cat_education';
    }
    if (v.contains('cine') || v.contains('parque') || v.contains('juegos') || v.contains('evento')) {
      return 'cat_entertainment';
    }
    if (v.contains('moda') || v.contains('ropa') || v.contains('calzados') || v.contains('manaco') || v.contains('fair play')) {
      return 'cat_shopping';
    }
    return 'cat_food';
  }

  DateTime? _parseFlexibleDate(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;
    final formats = [
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
    ];
    for (final f in formats) {
      try {
        final df = DateFormat(f);
        return df.parseLoose(clean);
      } catch (_) {}
    }
    try {
      return DateTime.parse(clean);
    } catch (_) {}
    return null;
  }
}
