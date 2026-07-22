import '../../enums/bank/value_column_type.dart';
import 'column.dart';
import 'registry.dart';

class Table {
  final String name;
  final List<Column> columns;
  final List<Registry> registries;

  const Table({
    required this.name,
    required this.columns,
    required this.registries,
  });

  Table insert(Registry registry) {
    for (var key in registry.data.keys) {
      if (!columns.any((column) => column.name == key)) {
        throw Exception(['unknow registry key']);
      }
    }

    for (var column in this.columns) {
      final data = registry.data.entries.firstWhere(
        (entry) => entry.key == column.name,
        orElse: () {
          throw Exception(['Registry key is different of column key']);
        },
      );
      if (data.value == null) {
        if (!column.canNull) {
          throw Exception(['Column not null cant support null value']);
        }
        continue;
      }
      if (!column.copampareType(data.value)) {
        throw Exception(['Registry value is different of column value']);
      }
    }
    final table = Table(
      name: this.name,
      columns: this.columns,
      registries: [...this.registries, registry],
    );
    return table;
  }

  List<Registry> scanAll() {
    return this.registries;
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'columns': columns, 'registries': registries};
  }

  factory Table.fromJson(Map<String, dynamic> json) {
    final List<Column> columns = (json['columns'] as List)
        .map((column) => Column.fromJson(column as Map<String, dynamic>))
        .toList();
    final registryDatas = (json['registries'] as List)
        .map(
          (registry) =>
              Registry.fromJson(registry as Map<String, dynamic>).data.map(
                (key, value) =>
                    columns.firstWhere((column) => column.name == key).type ==
                            ValueColumnType.dateTime &&
                        value != null
                    ? MapEntry(key, DateTime.parse(value))
                    : MapEntry(key, value),
              ),
        )
        .toList();

    return Table(
      name: json['name'] as String,
      columns: columns,
      registries: registryDatas.map((data) => Registry(data: data)).toList(),
    );
  }
}
