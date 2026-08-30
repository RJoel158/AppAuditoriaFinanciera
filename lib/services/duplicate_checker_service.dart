import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_record.dart';

class DuplicateCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'financial_records';

  /// Verifica si existe una transacción similar en una ventana de 30 minutos (100% Spark-safe sin índices compuestos)
  Future<FinancialRecord?> checkPotentialDuplicate({
    required double amount,
    required String category,
    required RecordType type,
    required DateTime date,
  }) async {
    try {
      // Obtenemos los últimos 20 registros ordenados por fecha (solo requiere el índice básico estándar)
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('date', descending: true)
          .limit(20)
          .get(const GetOptions(source: Source.serverAndCache));

      for (final doc in snapshot.docs) {
        final record = FinancialRecord.fromSnapshot(doc);
        final diffMinutes = date.difference(record.date).inMinutes.abs();

        if (diffMinutes <= 30 &&
            record.category == category &&
            record.type == type &&
            (record.amount - amount).abs() < 0.01) {
          return record;
        }
      }
    } catch (_) {}
    return null;
  }
}
