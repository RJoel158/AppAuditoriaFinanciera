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

  /// Stream en tiempo real con límite configurable y filtrado en memoria
  /// (Evita requerir índices compuestos en la consola de Firebase)
  Stream<List<FinancialRecord>> getRecordsStream({
    int limit = 15,
    RecordType? filterType,
    String? filterCategory,
  }) {
    // Consultamos ordenado por fecha de forma simple
    final query = _recordsCollection
        .orderBy('date', descending: true)
        .limit(limit * 3);

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      var list = snapshot.docs.map((doc) => FinancialRecord.fromSnapshot(doc)).toList();

      // Filtrado limpio en cliente
      if (filterType != null) {
        list = list.where((r) => r.type == filterType).toList();
      }

      if (filterCategory != null && filterCategory.isNotEmpty) {
        list = list.where((r) => r.category == filterCategory).toList();
      }

      if (list.length > limit) {
        list = list.sublist(0, limit);
      }

      return list;
    });
  }

  /// Stream para calcular métricas en tiempo real de todos los registros
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
