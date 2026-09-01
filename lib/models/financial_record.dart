import 'package:cloud_firestore/cloud_firestore.dart';

enum RecordType {
  income,
  expense;

  static RecordType fromString(String value) {
    if (value.toLowerCase() == 'income' || value.toLowerCase() == 'ingreso') {
      return RecordType.income;
    }
    return RecordType.expense;
  }

  String get key => this == RecordType.income ? 'income' : 'expense';
  String get label => this == RecordType.income ? 'Ingreso' : 'Egreso';
}

class FinancialRecord {
  final String id;
  final String title;
  final String description;
  final double amount; // Monto en moneda base (Bs / BOB)
  final double originalAmount; // Monto ingresado originalmente
  final String currency; // 'BOB' o 'USD'
  final double exchangeRate; // Tipo de cambio usado (ej: 6.96)
  final RecordType type;
  final String category;
  final String? imageUrl;
  final String? storagePath;
  final DateTime date;
  final DateTime createdAt;
  final String registeredBy;
  final String memberId;

  // Campos de Auditoría & Eliminación Lógica
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedByMemberId;

  FinancialRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    double? originalAmount,
    this.currency = 'BOB',
    this.exchangeRate = 6.96,
    required this.type,
    required this.category,
    this.imageUrl,
    this.storagePath,
    required this.date,
    required this.createdAt,
    this.registeredBy = 'Papá / Admin',
    this.memberId = 'admin_papa',
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deletedByMemberId,
  }) : originalAmount = originalAmount ?? amount;

  bool get isIncome => type == RecordType.income;
  bool get isExpense => type == RecordType.expense;

  FinancialRecord copyWith({
    String? id,
    String? title,
    String? description,
    double? amount,
    double? originalAmount,
    String? currency,
    double? exchangeRate,
    RecordType? type,
    String? category,
    String? imageUrl,
    String? storagePath,
    DateTime? date,
    DateTime? createdAt,
    String? registeredBy,
    String? memberId,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedByMemberId,
  }) {
    return FinancialRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      originalAmount: originalAmount ?? this.originalAmount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      type: type ?? this.type,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      registeredBy: registeredBy ?? this.registeredBy,
      memberId: memberId ?? this.memberId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deletedByMemberId: deletedByMemberId ?? this.deletedByMemberId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'amount': amount,
      'originalAmount': originalAmount,
      'currency': currency,
      'exchangeRate': exchangeRate,
      'type': type.key,
      'category': category,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'registeredBy': registeredBy,
      'memberId': memberId,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedBy': deletedBy,
      'deletedByMemberId': deletedByMemberId,
    };
  }

  factory FinancialRecord.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final amountVal = (data['amount'] as num?)?.toDouble() ?? 0.0;
    return FinancialRecord(
      id: doc.id,
      title: data['title'] as String? ?? 'Sin concepto',
      description: data['description'] as String? ?? '',
      amount: amountVal,
      originalAmount: (data['originalAmount'] as num?)?.toDouble() ?? amountVal,
      currency: data['currency'] as String? ?? 'BOB',
      exchangeRate: (data['exchangeRate'] as num?)?.toDouble() ?? 6.96,
      type: RecordType.fromString(data['type'] as String? ?? 'expense'),
      category: data['category'] as String? ?? 'otros_gastos',
      imageUrl: data['imageUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      registeredBy: data['registeredBy'] as String? ?? 'Papá / Admin',
      memberId: data['memberId'] as String? ?? 'admin_papa',
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      deletedBy: data['deletedBy'] as String?,
      deletedByMemberId: data['deletedByMemberId'] as String?,
    );
  }
}
