import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus {
  pending,
  approved,
  rejected;

  static RequestStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
      case 'aprobado':
        return RequestStatus.approved;
      case 'rejected':
      case 'rechazado':
        return RequestStatus.rejected;
      default:
        return RequestStatus.pending;
    }
  }

  String get key => name;
  String get label {
    switch (this) {
      case RequestStatus.approved:
        return 'Aprobado';
      case RequestStatus.rejected:
        return 'Rechazado';
      case RequestStatus.pending:
        return 'Pendiente';
    }
  }
}

class PinResetRequest {
  final String id;
  final String userId;
  final String alias;
  final String displayName;
  final String note;
  final RequestStatus status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  PinResetRequest({
    required this.id,
    required this.userId,
    required this.alias,
    required this.displayName,
    this.note = '',
    this.status = RequestStatus.pending,
    required this.requestedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  bool get isPending => status == RequestStatus.pending;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'alias': alias,
      'displayName': displayName,
      'note': note,
      'status': status.key,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
    };
  }

  factory PinResetRequest.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PinResetRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      alias: data['alias'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      note: data['note'] as String? ?? '',
      status: RequestStatus.fromString(data['status'] as String? ?? 'pending'),
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'] as String?,
    );
  }
}
