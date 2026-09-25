import 'package:flutter/foundation.dart';

@immutable
class Branch {
  final int id;
  final String title;
  final String imageUrl;
  final String? city;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;

  const Branch({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.city,
    this.address,
    this.isActive = true,
    this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as int,
      title: json['title'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      city: json['city'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image_url': imageUrl,
        'city': city,
        'address': address,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };

  Branch copyWith({
    int? id,
    String? title,
    String? imageUrl,
    String? city,
    String? address,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      Branch(
        id: id ?? this.id,
        title: title ?? this.title,
        imageUrl: imageUrl ?? this.imageUrl,
        city: city ?? this.city,
        address: address ?? this.address,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) => other is Branch && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Branch(id: $id, title: $title)';

  static const List<Branch> defaultBranches = [
    Branch(
      id: 1,
      title: 'TigerBay London',
      imageUrl: '',
      city: 'London',
      address: 'London, UK',
      isActive: true,
    ),
  ];
}
