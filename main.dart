import 'class/bank/column.dart';
import 'class/bank/registry.dart';
import 'class/bank/structure.dart';
import 'class/bank/table.dart';
import 'enums/bank/value_column_type.dart';

void main() {
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
  try {
    structure = structure.insertInto(
      'cars',
      Registry(
        data: {
          'name': 'opala',
          'year': 1989,
          'isFunctional': true,
          'buy': false,
        },
      ),
    );
  } catch (e) {
    print('Error: $e');
  }
  try {
    structure = structure.insertInto(
      'cars',
      Registry(data: {'neme': 'opala', 'year': 1989, 'isFunctional': true}),
    );
  } catch (e) {
    print('Error: $e');
  }
  try {
    structure = structure.insertInto(
      'cars',
      Registry(data: {'name': 'opala', 'year': false, 'isFunctional': true}),
    );
  } catch (e) {
    print('Error: $e');
  }
  print(structure.searchTable('cars').scanAll().toString());
}
