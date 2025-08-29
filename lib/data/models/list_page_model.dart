import 'package:finora/data/models/check_model.dart';

class ListPageModel {
  final String id;
  final String name;
  final double budget;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CheckModel> checks;

  ListPageModel({
    required this.id,
    required this.name,
    this.budget = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.checks = const [],
  });

  // ADDED COPYWITH METHOD
  ListPageModel copyWith({
    String? id,
    String? name,
    double? budget,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CheckModel>? checks,
  }) {
    return ListPageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      budget: budget ?? this.budget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checks: checks ?? this.checks,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'budget': budget,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'checks': checks.map((c) => c.toJson()).toList(),
  };
}