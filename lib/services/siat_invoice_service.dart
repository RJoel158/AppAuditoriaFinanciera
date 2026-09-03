import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/siat_invoice.dart';

class SiatInvoiceService {
  final http.Client _client;

  SiatInvoiceService({http.Client? client}) : _client = client ?? http.Client();

  static const String _siatRestBase = 'https://siatrest.impuestos.gob.bo/sre-sfe-shared-v2-rest';
  static const String _consultaFacturaEndpoint = '$_siatRestBase/consulta/factura';
  static const String _representacionGraficaEndpoint = '$_siatRestBase/consulta/representacionGrafica';

  /// 1. Parsear el texto / URL del código QR escaneado
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

      return SiatInvoice(
        nit: nit,
        cuf: cuf,
        invoiceNumber: numero,
        amount: amount,
        date: date,
        vendorName: 'Consultando SIAT...',
        rawQrUrl: urlString,
        suggestedCategory: 'cat_food',
        readableNotes: 'Factura SIAT N° $numero',
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

      return SiatInvoice(
        nit: nit,
        cuf: autorizacion,
        invoiceNumber: numero,
        amount: amount,
        date: date,
        vendorName: 'Factura N° $numero',
        authorizationNumber: autorizacion,
        controlCode: controlCode,
        buyerNit: buyerNit,
        rawQrUrl: text,
        suggestedCategory: 'cat_food',
        readableNotes: 'Factura N° $numero • NIT: $nit',
      );
    } catch (e) {
      debugPrint('Error parseando formato pipe: $e');
      return null;
    }
  }

  /// 2. Consultar directamente el API REST Oficial de SIAT de Impuestos Nacionales de Bolivia
  Future<SiatInvoice> fetchInvoiceDetails(SiatInvoice invoice) async {
    final nitNum = int.tryParse(invoice.nit);
    final nroNum = int.tryParse(invoice.invoiceNumber);

    if (nitNum == null || nroNum == null || invoice.cuf.isEmpty) {
      return invoice;
    }

    try {
      // Petición HTTP PUT a la API de consulta de factura oficial del SIN
      final response = await _client.put(
        Uri.parse(_consultaFacturaEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*',
          'Origin': 'https://siat.impuestos.gob.bo',
          'Referer': 'https://siat.impuestos.gob.bo/',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        },
        body: jsonEncode({
          'nitEmisor': nitNum,
          'cuf': invoice.cuf,
          'numeroFactura': nroNum,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['transaccion'] == true && data['objeto'] != null) {
          final obj = data['objeto'] as Map<String, dynamic>;

          // Razón Social real del comercio
          final razonSocial = obj['razonSocialEmisor'] as String? ?? invoice.vendorName;

          // Monto total real en Bolivianos
          final montoTotal = (obj['montoTotal'] as num?)?.toDouble() ??
              (obj['montoTotalMoneda'] as num?)?.toDouble() ??
              invoice.amount;

          // Fecha y hora exacta de emisión
          DateTime invoiceDate = invoice.date;
          if (obj['fechaEmision'] != null) {
            final parsed = DateTime.tryParse(obj['fechaEmision'].toString());
            if (parsed != null) invoiceDate = parsed;
          }

          // Desglose de productos comprados para notas amigables
          final productos = obj['listaDetalle'] as List<dynamic>? ?? [];
          final productosSummary = productos.map((p) {
            final cant = p['cantidad'];
            final desc = p['descripcion'] ?? 'Ítem';
            final sub = p['subTotal'];
            return '$cant x $desc (Bs $sub)';
          }).join(', ');

          final cleanNotes = productosSummary.isNotEmpty
              ? productosSummary
              : 'Compra en $razonSocial • Factura N° ${invoice.invoiceNumber}';

          return invoice.copyWith(
            vendorName: razonSocial.trim(),
            amount: montoTotal,
            date: invoiceDate,
            suggestedCategory: inferCategory(razonSocial),
            readableNotes: cleanNotes,
            buyerNit: obj['numeroDocumento']?.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error consultando API SIAT oficial: $e');
    }

    return invoice;
  }

  /// 3. Descargar el archivo PDF oficial del SIAT (Rollo térmico oficial o Documento)
  Future<File?> downloadOrGenerateInvoicePdf({
    required SiatInvoice invoice,
  }) async {
    final nitNum = int.tryParse(invoice.nit);
    final nroNum = int.tryParse(invoice.invoiceNumber);

    if (nitNum != null && nroNum != null && invoice.cuf.isNotEmpty) {
      try {
        // Petición HTTP PUT al endpoint de representación gráfica oficial de SIAT
        final response = await _client.put(
          Uri.parse(_representacionGraficaEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json, text/plain, */*',
            'Origin': 'https://siat.impuestos.gob.bo',
            'Referer': 'https://siat.impuestos.gob.bo/',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
          },
          body: jsonEncode({
            'nit': nitNum,
            'cuf': invoice.cuf,
            'numeroFactura': nroNum,
            'tamanio': 1, // 1 = Formato Rollo Oficial del SIAT
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['transaccion'] == true && data['representacionGrafica'] != null) {
            final base64Pdf = data['representacionGrafica'] as String;
            if (base64Pdf.isNotEmpty) {
              final pdfBytes = base64Decode(base64Pdf);
              final tempDir = await getTemporaryDirectory();
              final fileName = 'Factura_SIAT_${invoice.invoiceNumber}_${invoice.nit}.pdf';
              final file = File('${tempDir.path}/$fileName');
              await file.writeAsBytes(pdfBytes);
              debugPrint('PDF Oficial del SIAT descargado y guardado: ${file.path} (${pdfBytes.length} bytes)');
              return file;
            }
          }
        }
      } catch (e) {
        debugPrint('Error descargando representación gráfica de SIAT: $e');
      }
    }

    return null;
  }

  /// 4. Deducir categoría por palabras clave de comercios en Bolivia
  static String inferCategory(String vendorName) {
    final v = vendorName.toLowerCase();

    // Salud y Farmacia
    if (v.contains('farma') ||
        v.contains('farmacia') ||
        v.contains('salud') ||
        v.contains('clinica') ||
        v.contains('hospital') ||
        v.contains('chavez') ||
        v.contains('farmacorp') ||
        v.contains('medico') ||
        v.contains('dental')) {
      return 'cat_health';
    }

    // Supermercado y Alimentación / Restaurantes
    if (v.contains('foods') ||
        v.contains('bolivian foods') ||
        v.contains('hipermaxi') ||
        v.contains('fidalga') ||
        v.contains('norte') ||
        v.contains('ic norte') ||
        v.contains('supermercado') ||
        v.contains('mercado') ||
        v.contains('alimentos') ||
        v.contains('sofia') ||
        v.contains('pil') ||
        v.contains('kantal') ||
        v.contains('restaurante') ||
        v.contains('snack') ||
        v.contains('cafe') ||
        v.contains('pollos') ||
        v.contains('pizza') ||
        v.contains('burger') ||
        v.contains('comida') ||
        v.contains('dumbo') ||
        v.contains('starbucks')) {
      return 'cat_food';
    }

    // Transporte y Combustible
    if (v.contains('ypfb') ||
        v.contains('surtidor') ||
        v.contains('gasolina') ||
        v.contains('combustible') ||
        v.contains('transporte') ||
        v.contains('boa') ||
        v.contains('aviacion')) {
      return 'cat_transport';
    }

    // Servicios Básicos
    if (v.contains('cre') ||
        v.contains('saguapac') ||
        v.contains('delapaz') ||
        v.contains('elfec') ||
        v.contains('tigo') ||
        v.contains('telecel') ||
        v.contains('entel') ||
        v.contains('viva') ||
        v.contains('cotas') ||
        v.contains('servicio')) {
      return 'cat_services';
    }

    // Educación
    if (v.contains('colegio') ||
        v.contains('universidad') ||
        v.contains('univalle') ||
        v.contains('upb') ||
        v.contains('instituto') ||
        v.contains('libreria')) {
      return 'cat_education';
    }

    // Entretenimiento
    if (v.contains('cine') ||
        v.contains('center') ||
        v.contains('multicine') ||
        v.contains('parque') ||
        v.contains('juegos') ||
        v.contains('evento')) {
      return 'cat_entertainment';
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
