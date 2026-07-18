import 'registry.dart';
import 'table.dart';

class Structure {
  final String name;
  final List<Table> tables;

  const Structure({required this.name, required this.tables});

  Structure createTable(Table table) {
    final Structure structure = Structure(
      name: this.name,
      tables: [...tables, table],
    );
    return structure;
  }

  Table searchTable(String name) {
    return this.tables.firstWhere((table) => table.name == name);
  }

  Structure updateTable(Table table) {
    Structure structure = Structure(
      name: this.name,
      tables: this.tables.map((t) => t.name == table.name ? table : t).toList(),
    );
    return structure;
  }

  Structure insertInto(String name, Registry registry) {
    Table table = this.searchTable(name).insert(registry);
    Structure structure = updateTable(table);

    return structure;
  }
}
