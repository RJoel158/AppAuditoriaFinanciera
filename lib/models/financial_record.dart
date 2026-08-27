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
  final double amount;
  final RecordType type;
  final String category;
  final String? imageUrl;
  final String? storagePath;
  final DateTime date;
  final DateTime createdAt;
  final String registeredBy;

  FinancialRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    this.imageUrl,
    this.storagePath,
    required this.date,
    required this.createdAt,
    this.registeredBy = 'Familia',
  });

  bool get isIncome => type == RecordType.income;
  bool get isExpense => type == RecordType.expense;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'amount': amount,
      'type': type.key,
      'category': category,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'registeredBy': registeredBy,
    };
  }

  factory FinancialRecord.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FinancialRecord(
      id: doc.id,
      title: data['title'] as String? ?? 'Sin concepto',
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: RecordType.fromString(data['type'] as String? ?? 'expense'),
      category: data['category'] as String? ?? 'otros_gastos',
      imageUrl: data['imageUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      registeredBy: data['registeredBy'] as String? ?? 'Familia',
    );
  }

  factory FinancialRecord.fromMap(Map<String, dynamic> data, String id) {
    return FinancialRecord(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: RecordType.fromString(data['type'] as String? ?? 'expense'),
      category: data['category'] as String? ?? 'otros_gastos',
      imageUrl: data['imageUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      registeredBy: data['registeredBy'] as String? ?? 'Familia',
    );
  }
}
