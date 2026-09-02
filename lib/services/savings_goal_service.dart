import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/savings_goal.dart';

class SavingsGoalService {
  final FirebaseFirestore _firestore;

  SavingsGoalService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionPath = 'savings_goals';

  CollectionReference<Map<String, dynamic>> get _goalsCollection =>
      _firestore.collection(collectionPath);

  /// Stream en tiempo real de todas las metas de ahorro familiares
  Stream<List<SavingsGoal>> getGoalsStream() {
    return _goalsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SavingsGoal.fromSnapshot(doc)).toList());
  }

  /// Crear una nueva meta de ahorro
  Future<String> createGoal(SavingsGoal goal) async {
    final docRef = await _goalsCollection.add(goal.toMap());
    return docRef.id;
  }

  /// Registrar un aporte familiar a una meta
  Future<void> addContribution({
    required String goalId,
    required GoalContribution contribution,
  }) async {
    final docRef = _goalsCollection.doc(goalId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('La meta de ahorro no existe.');
      }

      final currentGoal = SavingsGoal.fromSnapshot(snapshot);
      final updatedAmount = currentGoal.currentAmount + contribution.amount;
      final isNowCompleted = updatedAmount >= currentGoal.targetAmount;

      final updatedContributions = List<GoalContribution>.from(currentGoal.contributions)
        ..add(contribution);

      transaction.update(docRef, {
        'currentAmount': updatedAmount,
        'isCompleted': isNowCompleted,
        'contributions': updatedContributions.map((c) => c.toMap()).toList(),
      });
    });
  }

  /// Actualizar información de una meta
  Future<void> updateGoal(SavingsGoal goal) async {
    await _goalsCollection.doc(goal.id).update(goal.toMap());
  }

  /// Eliminar una meta de ahorro
  Future<void> deleteGoal(String goalId) async {
    await _goalsCollection.doc(goalId).delete();
  }
}
