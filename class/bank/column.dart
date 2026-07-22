import '../../enums/bank/value_column_type.dart';

class Column {
  final String name;
  final ValueColumnType type;
  final bool isKey;
  final bool canNull;

  const Column({
    required this.name,
    required this.type,
    this.isKey = false,
    this.canNull = false,
  });

  bool copampareType(Object object) {
    bool condition;
    switch (this.type) {
      case ValueColumnType.bool:
        object is bool ? condition = true : condition = false;
        break;
      case ValueColumnType.int:
        object is int ? condition = true : condition = false;
        break;
      case ValueColumnType.double:
        object is double ? condition = true : condition = false;
        break;
      case ValueColumnType.string:
        object is String ? condition = true : condition = false;
        break;
      case ValueColumnType.dateTime:
        object is DateTime ? condition = true : condition = false;
        break;
    }
    return condition;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'canNull': canNull,
      'isKey': isKey,
    };
  }

  factory Column.fromJson(Map<String, dynamic> json) {
    return Column(
      name: json['name'] as String,
      type: ValueColumnType.values.byName(json['type']),
      canNull: json['canNull'] as bool,
      isKey: json['isKey'] as bool,
    );
  }
}
