import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/financial_record.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionPath = 'financial_records';

  CollectionReference<Map<String, dynamic>> get _recordsCollection =>
      _firestore.collection(collectionPath);

  /// Configuración de Persistencia de Caché Local en Firestore
  static void configurePersistence() {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('Firestore: Persistencia local configurada exitosamente.');
    } catch (e) {
      debugPrint('Firestore: Nota de persistencia (ya inicializada o no soportada en web): $e');
    }
  }

  /// Stream en tiempo real con límite configurable (por defecto 15 para optimizar lectura)
  Stream<List<FinancialRecord>> getRecordsStream({
    int limit = 15,
    RecordType? filterType,
    String? filterCategory,
  }) {
    Query<Map<String, dynamic>> query = _recordsCollection
        .orderBy('date', descending: true);

    if (filterType != null) {
      query = query.where('type', isEqualTo: filterType.key);
    }

    if (filterCategory != null && filterCategory.isNotEmpty) {
      query = query.where('category', isEqualTo: filterCategory);
    }

    query = query.limit(limit);

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      return snapshot.docs.map((doc) => FinancialRecord.fromSnapshot(doc)).toList();
    });
  }

  /// Stream para calcular métricas en tiempo real de todos los registros del mes/año
  Stream<Map<String, double>> getSummaryStream() {
    return _recordsCollection.snapshots().map((snapshot) {
      double totalIncome = 0.0;
      double totalExpense = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final type = data['type'] as String? ?? 'expense';

        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }

      return {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': totalIncome - totalExpense,
      };
    });
  }

  /// Guardar un nuevo registro en Firestore
  Future<String> addRecord(FinancialRecord record) async {
    final docRef = await _recordsCollection.add(record.toMap());
    return docRef.id;
  }

  /// Actualizar un registro existente
  Future<void> updateRecord(FinancialRecord record) async {
    await _recordsCollection.doc(record.id).update(record.toMap());
  }

  /// Eliminar un registro
  Future<void> deleteRecord(String recordId) async {
    await _recordsCollection.doc(recordId).delete();
  }
}
