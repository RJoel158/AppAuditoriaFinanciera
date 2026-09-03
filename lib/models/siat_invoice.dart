import 'financial_record.dart';

class SiatInvoice {
  final String nit;
  final String cuf;
  final String invoiceNumber;
  final double amount;
  final DateTime date;
  final String vendorName;
  final String? pdfUrl;
  final String rawQrUrl;
  final String suggestedCategory;
  final String? buyerNit;
  final String? authorizationNumber;
  final String? controlCode;
  final String? downloadedPdfPath;
  final String? readableNotes;
  final List<InvoiceItem> items;

  SiatInvoice({
    required this.nit,
    required this.cuf,
    required this.invoiceNumber,
    required this.amount,
    required this.date,
    required this.vendorName,
    this.pdfUrl,
    required this.rawQrUrl,
    this.suggestedCategory = 'cat_food',
    this.buyerNit,
    this.authorizationNumber,
    this.controlCode,
    this.downloadedPdfPath,
    this.readableNotes,
    this.items = const [],
  });

  SiatInvoice copyWith({
    String? nit,
    String? cuf,
    String? invoiceNumber,
    double? amount,
    DateTime? date,
    String? vendorName,
    String? pdfUrl,
    String? rawQrUrl,
    String? suggestedCategory,
    String? buyerNit,
    String? authorizationNumber,
    String? controlCode,
    String? downloadedPdfPath,
    String? readableNotes,
    List<InvoiceItem>? items,
  }) {
    return SiatInvoice(
      nit: nit ?? this.nit,
      cuf: cuf ?? this.cuf,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      vendorName: vendorName ?? this.vendorName,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      rawQrUrl: rawQrUrl ?? this.rawQrUrl,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      buyerNit: buyerNit ?? this.buyerNit,
      authorizationNumber: authorizationNumber ?? this.authorizationNumber,
      controlCode: controlCode ?? this.controlCode,
      downloadedPdfPath: downloadedPdfPath ?? this.downloadedPdfPath,
      readableNotes: readableNotes ?? this.readableNotes,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nit': nit,
      'cuf': cuf,
      'invoiceNumber': invoiceNumber,
      'amount': amount,
      'date': date.toIso8601String(),
      'vendorName': vendorName,
      'pdfUrl': pdfUrl,
      'rawQrUrl': rawQrUrl,
      'suggestedCategory': suggestedCategory,
      'buyerNit': buyerNit,
      'authorizationNumber': authorizationNumber,
      'controlCode': controlCode,
      'downloadedPdfPath': downloadedPdfPath,
      'readableNotes': readableNotes,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }
}
