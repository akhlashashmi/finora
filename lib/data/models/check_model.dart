class CheckModel {
  final String id;
  final String? title;
  final double number;
  final bool isSelected;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String listId;

  CheckModel({
    required this.id,
    this.title,
    required this.number,
    this.isSelected = false,
    required this.createdAt,
    required this.updatedAt,
    required this.listId,
  });

  // ADDED COPYWITH METHOD
  CheckModel copyWith({
    String? id,
    String? title,
    double? number,
    bool? isSelected,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? listId,
  }) {
    return CheckModel(
      id: id ?? this.id,
      title: title ?? this.title,
      number: number ?? this.number,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      listId: listId ?? this.listId,
    );
  }

  factory CheckModel.fromJson(Map<String, dynamic> json) => CheckModel(
    id: json['id'] as String,
    title: json['title'] as String?,
    number: (json['number'] as num).toDouble(),
    isSelected: json['isSelected'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    listId: json['listId'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'number': number,
    'isSelected': isSelected,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'listId': listId,
  };
}