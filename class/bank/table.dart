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
}
