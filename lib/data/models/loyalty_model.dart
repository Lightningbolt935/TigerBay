class LoyaltyModel {
  final String id;
  final String userId;
  final int pointsBalance;
  final double cashValue; // 1 point = £0.10
  final String? linkedPhysicalCardNumber;
  final bool physicalCardLinked;
  final List<LoyaltyTransaction> transactions;

  const LoyaltyModel({
    required this.id,
    required this.userId,
    required this.pointsBalance,
    required this.cashValue,
    this.linkedPhysicalCardNumber,
    this.physicalCardLinked = false,
    this.transactions = const [],
  });

  factory LoyaltyModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      pointsBalance: json['points_balance'] as int? ?? 0,
      cashValue: (json['cash_value'] as num?)?.toDouble() ?? 0.0,
      linkedPhysicalCardNumber: json['linked_physical_card_number'] as String?,
      physicalCardLinked: json['physical_card_linked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'points_balance': pointsBalance,
        'cash_value': cashValue,
        'linked_physical_card_number': linkedPhysicalCardNumber,
        'physical_card_linked': physicalCardLinked,
      };

  String get maskedCardNumber {
    if (linkedPhysicalCardNumber == null) return '';
    final n = linkedPhysicalCardNumber!.replaceAll(' ', '');
    if (n.length < 8) return n;
    return '${n.substring(0, 4)} •••• •••• ${n.substring(n.length - 4)}';
  }
}

class LoyaltyTransaction {
  final String id;
  final String userId;
  final int points;
  final TransactionType type;
  final String description;
  final String? branchName;
  final double? spendAmount;
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.userId,
    required this.points,
    required this.type,
    required this.description,
    this.branchName,
    this.spendAmount,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      points: json['points'] as int,
      type: TransactionType.fromString(json['type'] as String),
      description: json['description'] as String? ?? '',
      branchName: json['branch_name'] as String?,
      spendAmount: (json['spend_amount'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isEarned => type == TransactionType.earned;
}

enum TransactionType {
  earned('earned'),
  redeemed('redeemed'),
  adjusted('adjusted'),
  expired('expired');

  final String value;
  const TransactionType(this.value);

  static TransactionType fromString(String s) {
    return TransactionType.values.firstWhere(
      (e) => e.value == s.toLowerCase(),
      orElse: () => TransactionType.earned,
    );
  }
}
