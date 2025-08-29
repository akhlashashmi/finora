import 'package:finora/data/models/list_page_model.dart';

class BackupModel {
  final String version;
  final DateTime createdAt;
  final List<ListPageModel> lists;

  BackupModel({
    required this.version,
    required this.createdAt,
    required this.lists,
  });

  // ADDED COPYWITH METHOD
  BackupModel copyWith({
    String? version,
    DateTime? createdAt,
    List<ListPageModel>? lists,
  }) {
    return BackupModel(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      lists: lists ?? this.lists,
    );
  }

  factory BackupModel.fromJson(Map<String, dynamic> json) {
    return BackupModel(
      version: json['version'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lists: (json['lists'] as List<dynamic>)
          .map((e) => ListPageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'lists': lists.map((l) => l.toJson()).toList(),
  };
}