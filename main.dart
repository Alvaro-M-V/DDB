import 'class/bank/column.dart';
import 'class/bank/registry.dart';
import 'class/bank/structure.dart';
import 'class/bank/table.dart';
import 'enums/bank/value_column_type.dart';

Future<void> main() async {
  Structure structure = Structure(name: 'Oficina', tables: []);
  Table table = Table(
    name: 'cars',
    columns: [
      Column(name: 'name', type: ValueColumnType.string),
      Column(name: 'year', type: ValueColumnType.int),
      Column(name: 'isFunctional', type: ValueColumnType.bool),
    ],
    registries: [],
  );
  structure = structure.createTable(table);
  structure = structure.insertInto(
    'cars',
    Registry(data: {'name': 'opala', 'year': 1989, 'isFunctional': true}),
  );
  structure = structure.insertInto(
    'cars',
    Registry(data: {'name': 'Maveric', 'year': 1979, 'isFunctional': false}),
  );
  print(structure.searchTable('cars').scanAll().toString());
}
