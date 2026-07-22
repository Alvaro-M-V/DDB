import 'dart:convert';
import 'dart:io';
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

  Map<String, dynamic> toJson() {
    return {'name': name, 'tables': tables};
  }

  factory Structure.fromJson(Map<String, dynamic> json) {
    return Structure(
      name: json['name'] as String,
      tables: (json['tables'] as List)
          .map((table) => Table.fromJson(table as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> save(String path) async {
    final classMap = this.toJson();
    final mapString = jsonEncode(
      classMap,
      toEncodable: (obj) {
        if (obj is DateTime) {
          return (obj.toIso8601String());
        } else {
          return (obj as dynamic).toJson();
        }
      },
    );
    await File(path).writeAsString(mapString);
  }

  static Future<Structure> load(String path) async {
    final String result = await File(path).readAsString();
    final Map<String, dynamic> resolvedResult = jsonDecode(result);
    return Structure.fromJson(resolvedResult);
  }
}
