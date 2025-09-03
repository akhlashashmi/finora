import 'package:finora/data/models/check_model.dart';

class ListPageModel {
  final String id;
  final String name;
  final double budget;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CheckModel> checks;
  final int sortOrder;
  final bool isPinned;
  final bool isProtected;

  ListPageModel({
    required this.id,
    required this.name,
    this.budget = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.checks = const [],
    this.sortOrder = 0,
    this.isPinned = false,
    this.isProtected = false,
  });

  ListPageModel copyWith({
    String? id,
    String? name,
    double? budget,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CheckModel>? checks,
    int? sortOrder,
    bool? isPinned,
    bool? isProtected,
  }) {
    return ListPageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      budget: budget ?? this.budget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checks: checks ?? this.checks,
      sortOrder: sortOrder ?? this.sortOrder,
      isPinned: isPinned ?? this.isPinned,
      isProtected: isProtected ?? this.isProtected,
    );
  }

  factory ListPageModel.fromJson(Map<String, dynamic> json) {
    return ListPageModel(
      id: json['id'] as String,
      name: json['name'] as String,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      checks: (json['checks'] as List<dynamic>?)
          ?.map((e) => CheckModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      sortOrder: json['sortOrder'] as int? ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isProtected: json['isProtected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'budget': budget,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'checks': checks.map((c) => c.toJson()).toList(),
    'sortOrder': sortOrder,
    'isPinned': isPinned,
    'isProtected': isProtected,
  };
}