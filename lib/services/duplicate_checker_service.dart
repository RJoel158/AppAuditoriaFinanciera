import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_record.dart';

class DuplicateCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'financial_records';

  /// Verifica si existe una transacción similar en una ventana de 30 minutos
  Future<FinancialRecord?> checkPotentialDuplicate({
    required double amount,
    required String category,
    required RecordType type,
    required DateTime date,
  }) async {
    try {
      final startTime = date.subtract(const Duration(minutes: 30));
      final endTime = date.add(const Duration(minutes: 30));

      // Consulta acotada por tiempo y categoría (compatible con Firestore Spark)
      final snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .where('type', isEqualTo: type.key)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .limit(5)
          .get(const GetOptions(source: Source.serverAndCache));

      for (final doc in snapshot.docs) {
        final record = FinancialRecord.fromSnapshot(doc);
        // Comparación de monto con tolerancia de centavos
        if ((record.amount - amount).abs() < 0.01) {
          return record;
        }
      }
    } catch (_) {
      // Si la consulta compuesta requiere índice en Firestore, fallback local por seguridad
      try {
        final snapshot = await _firestore
            .collection(_collection)
            .orderBy('date', descending: true)
            .limit(10)
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
    }
    return null;
  }
}
