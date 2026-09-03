import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/siat_invoice.dart';

class SiatInvoiceService {
  final http.Client _client;

  SiatInvoiceService({http.Client? client}) : _client = client ?? http.Client();

  /// 1. Parsear el texto crudo del código QR (URL o formato pipe "|" de Impuestos de Bolivia)
  SiatInvoice? parseQrData(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    // Caso A: Es una URL de consulta SIAT (ej. https://siat.impuestos.gob.bo/consulta/QR?nit=... o https://pilotosiat.impuestos.gob.bo/...)
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return _parseSiatUrl(text);
    }

    // Caso B: Formato de Facturación Computarizada tradicional / SIAT separado por barra vertical (|)
    // Formato común: NIT|NroFactura|NroAutorizacion|FechaEmision|Total|MontoBaseCF|CodigoControl|NITComprador|...
    if (text.contains('|')) {
      return _parsePipeSeparated(text);
    }

    return null;
  }

  /// Parsear URL de consulta SIAT
  SiatInvoice? _parseSiatUrl(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      final params = uri.queryParameters;

      // Buscar parámetros con diferentes nomenclaturas habituales del SIN
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

      final defaultVendor = nit.isNotEmpty ? 'Factura SIAT (NIT: $nit)' : 'Factura Electrónica SIAT';

      return SiatInvoice(
        nit: nit,
        cuf: cuf,
        invoiceNumber: numero,
        amount: amount,
        date: date,
        vendorName: defaultVendor,
        rawQrUrl: urlString,
        suggestedCategory: inferCategory(defaultVendor),
      );
    } catch (e) {
      debugPrint('Error parseando URL SIAT: $e');
      return null;
    }
  }

  /// Parsear formato clásico con barras (|)
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

      final defaultVendor = 'Factura N° $numero (NIT: $nit)';

      return SiatInvoice(
        nit: nit,
        cuf: autorizacion, // En facturación anterior se usaba autorización
        invoiceNumber: numero,
        amount: amount,
        date: date,
        vendorName: defaultVendor,
        authorizationNumber: autorizacion,
        controlCode: controlCode,
        buyerNit: buyerNit,
        rawQrUrl: text,
        suggestedCategory: inferCategory(defaultVendor),
      );
    } catch (e) {
      debugPrint('Error parseando formato pipe: $e');
      return null;
    }
  }

  /// 2. Consultar el portal web de SIAT para extraer Razón Social, Fecha exacta y enlace al PDF
  Future<SiatInvoice> fetchInvoiceDetails(SiatInvoice invoice) async {
    if (!invoice.rawQrUrl.startsWith('http')) {
      return invoice;
    }

    try {
      final response = await _client.get(
        Uri.parse(invoice.rawQrUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'es-BO,es;q=0.9,en;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final bodyText = document.body?.text ?? '';

        String vendor = invoice.vendorName;
        DateTime invoiceDate = invoice.date;
        String? pdfUrl;
        double parsedAmount = invoice.amount;

        // A. Buscar Razón Social / Nombre Emisor
        // 1. Buscar en elementos con clases o IDs conocidos
        final possibleVendorSelectors = [
          'span#razonSocial',
          'div.razon-social',
          'span.nombreEmisor',
          'h2',
          'h3',
          'td.razonSocial',
        ];

        for (final selector in possibleVendorSelectors) {
          final el = document.querySelector(selector);
          if (el != null && el.text.trim().isNotEmpty && el.text.trim().length > 3) {
            vendor = el.text.trim();
            break;
          }
        }

        // 2. Si no se encontró por selector, buscar en tablas y etiquetas de texto
        if (vendor == invoice.vendorName || vendor.startsWith('Factura SIAT')) {
          final tableCells = document.querySelectorAll('td, th, p, span, div');
          for (var i = 0; i < tableCells.length; i++) {
            final cellText = tableCells[i].text.trim().toLowerCase();
            if (cellText.contains('razón social') ||
                cellText.contains('razon social') ||
                cellText.contains('nombre o razón') ||
                cellText.contains('emisor:')) {
              // El valor suele estar en la celda contigua o en el texto siguiente
              if (i + 1 < tableCells.length) {
                final nextText = tableCells[i + 1].text.trim();
                if (nextText.isNotEmpty && nextText.length > 2) {
                  vendor = nextText;
                  break;
                }
              }
            }
          }
        }

        // B. Buscar Fecha de Emisión
        final dateRegex = RegExp(r'(\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4}(?:\s+\d{2}:\d{2}(?::\d{2})?)?)');
        final dateMatches = dateRegex.allMatches(bodyText);
        for (final match in dateMatches) {
          final extracted = match.group(1);
          if (extracted != null) {
            final d = _parseFlexibleDate(extracted);
            if (d != null) {
              invoiceDate = d;
              break;
            }
          }
        }

        // C. Buscar Monto Total si no venía en la URL
        if (parsedAmount <= 0) {
          final amountRegex = RegExp(r'(?:total|importe|monto)(?:.*?)(?:Bs\.?|BOB)?\s*([\d\.\,]+)', caseSensitive: false);
          final amountMatch = amountRegex.firstMatch(bodyText);
          if (amountMatch != null) {
            final valStr = amountMatch.group(1)?.replaceAll(',', '.') ?? '0';
            parsedAmount = double.tryParse(valStr) ?? 0.0;
          }
        }

        // D. Buscar Enlace a Representación Gráfica / PDF de Factura
        final links = document.querySelectorAll('a, button');
        for (final link in links) {
          final href = link.attributes['href'] ?? '';
          final onClick = link.attributes['onclick'] ?? '';
          if (href.toLowerCase().contains('.pdf') ||
              href.toLowerCase().contains('descargar') ||
              href.toLowerCase().contains('factura') ||
              onClick.toLowerCase().contains('.pdf')) {
            if (href.startsWith('http')) {
              pdfUrl = href;
            } else if (href.startsWith('/')) {
              final uri = Uri.parse(invoice.rawQrUrl);
              pdfUrl = '${uri.scheme}://${uri.host}$href';
            }
            break;
          }
        }

        // Limpiar el nombre del comercio si contiene prefijos
        vendor = vendor.replaceAll(RegExp(r'^(Razón Social|Nombre|Emisor)\s*:\s*', caseSensitive: false), '').trim();

        return invoice.copyWith(
          vendorName: vendor,
          date: invoiceDate,
          amount: parsedAmount > 0 ? parsedAmount : invoice.amount,
          pdfUrl: pdfUrl,
          suggestedCategory: inferCategory(vendor),
        );
      }
    } catch (e) {
      debugPrint('Nota al consultar web SIAT (usando datos extraídos del QR): $e');
    }

    return invoice;
  }

  /// 3. Descargar el archivo PDF o comprobante de la factura y guardarlo temporalmente
  Future<File?> downloadInvoicePdf({
    required String pdfUrl,
    required String invoiceNumber,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse(pdfUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'factura_siat_${invoiceNumber.isNotEmpty ? invoiceNumber : DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('No se pudo descargar el PDF remoto de la factura: $e');
    }
    return null;
  }

  /// 4. Deducir la categoría del gasto según el nombre de la empresa / razón social en Bolivia
  static String inferCategory(String vendorName) {
    final v = vendorName.toLowerCase();

    // Salud y Farmacia
    if (v.contains('farma') ||
        v.contains('farmacia') ||
        v.contains('salud') ||
        v.contains('clinica') ||
        v.contains('hospital') ||
        v.contains('medico') ||
        v.contains('dental') ||
        v.contains('laboratorio') ||
        v.contains('chavez') ||
        v.contains('hipermaxi farmacia') ||
        v.contains('bolivia') && v.contains('drogu')) {
      return 'cat_health';
    }

    // Supermercado y Alimentación
    if (v.contains('hipermaxi') ||
        v.contains('fidalga') ||
        v.contains('supermercado') ||
        v.contains('mercado') ||
        v.contains('tienda') ||
        v.contains('alimentos') ||
        v.contains('lacteos') ||
        v.contains('pil') ||
        v.contains('panaderia') ||
        v.contains('kantal') ||
        v.contains('sofia') ||
        v.contains('carnes') ||
        v.contains('frigorifico') ||
        v.contains('avicola')) {
      return 'cat_food';
    }

    // Restaurantes, Cafés y Salidas
    if (v.contains('restaurante') ||
        v.contains('snack') ||
        v.contains('cafe') ||
        v.contains('cafeteria') ||
        v.contains('burger') ||
        v.contains('pizza') ||
        v.contains('comida') ||
        v.contains('pollos') ||
        v.contains('chifa') ||
        v.contains('heladeria') ||
        v.contains('starbucks') ||
        v.contains('dumbo') ||
        v.contains('toby') ||
        v.contains('churrasqueria')) {
      return 'cat_food';
    }

    // Transporte y Combustible
    if (v.contains('ypfb') ||
        v.contains('surtidor') ||
        v.contains('gasolina') ||
        v.contains('estacion de servicio') ||
        v.contains('combustible') ||
        v.contains('gas natural') ||
        v.contains('gnv') ||
        v.contains('transporte') ||
        v.contains('linea') ||
        v.contains('boa') ||
        v.contains('boliviana de aviacion') ||
        v.contains('aerolinea') ||
        v.contains('peaje') ||
        v.contains('vias bolivia')) {
      return 'cat_transport';
    }

    // Servicios Básicos e Internet / Telecomunicaciones
    if (v.contains('cre') ||
        v.contains('saguapac') ||
        v.contains('delapaz') ||
        v.contains('selepaz') ||
        v.contains('elfec') ||
        v.contains('epsas') ||
        v.contains('ende') ||
        v.contains('tigo') ||
        v.contains('telecel') ||
        v.contains('entel') ||
        v.contains('viva') ||
        v.contains('cotas') ||
        v.contains('comteco') ||
        v.contains('itacamba') ||
        v.contains('servicio')) {
      return 'cat_services';
    }

    // Educación
    if (v.contains('colegio') ||
        v.contains('universidad') ||
        v.contains('univalle') ||
        v.contains('upb') ||
        v.contains('ucb') ||
        v.contains('utebs') ||
        v.contains('instituto') ||
        v.contains('libreria') ||
        v.contains('papeleria') ||
        v.contains('educacion')) {
      return 'cat_education';
    }

    // Entretenimiento
    if (v.contains('cine') ||
        v.contains('multicine') ||
        v.contains('center') ||
        v.contains('cinemark') ||
        v.contains('parque') ||
        v.contains('juegos') ||
        v.contains('teatro') ||
        v.contains('eventos')) {
      return 'cat_entertainment';
    }

    // Ropa y Calzado
    if (v.contains('boutique') ||
        v.contains('moda') ||
        v.contains('calzados') ||
        v.contains('textil') ||
        v.contains('manaco') ||
        v.contains('bata') ||
        v.contains('fair play') ||
        v.contains('ropa')) {
      return 'cat_shopping';
    }

    // Por defecto: Gasto de Alimentación / General
    return 'cat_food';
  }

  /// Parser flexible de fechas en varios formatos (DD/MM/YYYY, YYYY-MM-DD, etc.)
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
      'yyyyMMdd',
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
