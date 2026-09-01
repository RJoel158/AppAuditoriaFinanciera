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

  /// Stream en tiempo real con filtrado de registros activos (no eliminados)
  Stream<List<FinancialRecord>> getRecordsStream({
    int limit = 15,
    RecordType? filterType,
    String? filterCategory,
  }) {
    final query = _recordsCollection
        .orderBy('date', descending: true)
        .limit(limit * 3);

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      var list = snapshot.docs.map((doc) => FinancialRecord.fromSnapshot(doc)).toList();

      // 1. Filtrar únicamente registros activos (excluir eliminación lógica)
      list = list.where((r) => !r.isDeleted).toList();

      // 2. Filtrado por tipo (Ingreso / Egreso)
      if (filterType != null) {
        list = list.where((r) => r.type == filterType).toList();
      }

      // 3. Filtrado por categoría
      if (filterCategory != null && filterCategory.isNotEmpty) {
        list = list.where((r) => r.category == filterCategory).toList();
      }

      if (list.length > limit) {
        list = list.sublist(0, limit);
      }

      return list;
    });
  }

  /// Stream para calcular métricas en tiempo real ignorando registros eliminados
  Stream<Map<String, double>> getSummaryStream() {
    return _recordsCollection.snapshots().map((snapshot) {
      double totalIncome = 0.0;
      double totalExpense = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final isDeleted = data['isDeleted'] as bool? ?? false;
        if (isDeleted) continue; // Omitir registros eliminados

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

  /// Stream para el Panel de Auditoría de Administrador (Incluye activos y eliminados)
  Stream<List<FinancialRecord>> getAuditRecordsStream({int limit = 100}) {
    return _recordsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FinancialRecord.fromSnapshot(doc)).toList();
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

  /// Eliminación Lógica (Soft Delete): Preserva el histórico para auditoría
  Future<void> softDeleteRecord(
    String recordId, {
    required String deletedBy,
    required String deletedByMemberId,
  }) async {
    await _recordsCollection.doc(recordId).update({
      'isDeleted': true,
      'deletedAt': Timestamp.fromDate(DateTime.now()),
      'deletedBy': deletedBy,
      'deletedByMemberId': deletedByMemberId,
    });
  }

  /// Restaurar un registro eliminado lógicamente
  Future<void> restoreRecord(String recordId) async {
    await _recordsCollection.doc(recordId).update({
      'isDeleted': false,
      'deletedAt': null,
      'deletedBy': null,
      'deletedByMemberId': null,
    });
  }

  /// Eliminación Física Permanente (Solo para purga manual por Admin si es necesario)
  Future<void> hardDeleteRecord(String recordId) async {
    await _recordsCollection.doc(recordId).delete();
  }
}
