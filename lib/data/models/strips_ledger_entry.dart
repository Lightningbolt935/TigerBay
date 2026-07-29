/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — StripsLedgerEntry Model
/// ═══════════════════════════════════════════════════════════════════════════
/// Maps 1-to-1 with `public.strips_ledger`. Records every Strips transaction
/// (earn, redeem, bonus) with a descriptive label and timestamp.
class StripsLedgerEntry {
  final int id;
  final String userId;
  final int amount;
  final String transactionType;
  final String description;
  final DateTime createdAt;

  const StripsLedgerEntry({
    required this.id,
    required this.userId,
    required this.amount,
    required this.transactionType,
    required this.description,
    required this.createdAt,
  });

  /// Whether this entry represents an earn/bonus (positive balance change).
  bool get isEarned =>
      transactionType == 'earn' || transactionType == 'bonus';

  /// Whether this entry represents a redemption (negative balance change).
  bool get isRedeemed => transactionType == 'redeem';

  /// Display string: "+X Strips" for earned, "-X Strips" for redeemed.
  String get displayAmount {
    if (isEarned) return '+$amount Strips';
    return '-$amount Strips';
  }

  /// Formatted timestamp for list display.
  String get formattedDate {
    final d = createdAt;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$minute $period';
  }

  factory StripsLedgerEntry.fromMap(Map<String, dynamic> map) {
    return StripsLedgerEntry(
      id: _safeInt(map['id']) ?? 0,
      userId: (map['user_id'] as String?) ?? '',
      amount: _safeInt(map['amount']) ?? 0,
      transactionType: (map['transaction_type'] as String?) ?? 'earn',
      description: (map['description'] as String?) ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'transaction_type': transactionType,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StripsLedgerEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'StripsLedgerEntry(id: $id, type: $transactionType, '
      'amount: $amount, desc: $description)';

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
