import 'package:cloud_firestore/cloud_firestore.dart';

class GoalContribution {
  final String id;
  final String memberId;
  final String memberName;
  final double amount;
  final DateTime date;
  final String note;

  GoalContribution({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }

  factory GoalContribution.fromMap(Map<String, dynamic> map) {
    return GoalContribution(
      id: map['id'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      memberName: map['memberName'] as String? ?? 'Familiar',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String? ?? '',
    );
  }
}

class SavingsGoal {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final String currency; // 'BOB' o 'USD'
  final DateTime? deadline;
  final String iconName; // 'beach_access', 'savings', 'directions_car', etc.
  final int colorValue; // Hex integer color
  final String createdBy;
  final DateTime createdAt;
  final bool isCompleted;
  final List<GoalContribution> contributions;

  SavingsGoal({
    required this.id,
    required this.title,
    this.description = '',
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.currency = 'BOB',
    this.deadline,
    this.iconName = 'savings',
    this.colorValue = 0xFF10B981, // Emerald green
    required this.createdBy,
    required this.createdAt,
    this.isCompleted = false,
    this.contributions = const [],
  });

  double get progressPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity);

  int? get daysRemaining {
    if (deadline == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deadline!.year, deadline!.month, deadline!.day);
    return target.difference(today).inDays;
  }

  SavingsGoal copyWith({
    String? id,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    String? currency,
    DateTime? deadline,
    String? iconName,
    int? colorValue,
    String? createdBy,
    DateTime? createdAt,
    bool? isCompleted,
    List<GoalContribution>? contributions,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currency: currency ?? this.currency,
      deadline: deadline ?? this.deadline,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      contributions: contributions ?? this.contributions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'currency': currency,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'iconName': iconName,
      'colorValue': colorValue,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isCompleted': isCompleted,
      'contributions': contributions.map((c) => c.toMap()).toList(),
    };
  }

  factory SavingsGoal.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawContributions = data['contributions'] as List<dynamic>? ?? [];

    return SavingsGoal(
      id: doc.id,
      title: data['title'] as String? ?? 'Meta de Ahorro',
      description: data['description'] as String? ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'BOB',
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      iconName: data['iconName'] as String? ?? 'savings',
      colorValue: (data['colorValue'] as num?)?.toInt() ?? 0xFF10B981,
      createdBy: data['createdBy'] as String? ?? 'Familia',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      contributions: rawContributions
          .map((c) => GoalContribution.fromMap(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
