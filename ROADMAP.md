# DartDB — Roadmap Técnico

Banco de dados relacional escrito do zero em Dart, sem libs externas de banco. Documento de referência técnica do projeto — estado atual e próximas fases.

## Estado atual: Fase 1 completa (modelo de dados em memória)

### Estrutura de arquivos
```
enums/bank/value_column_type.dart   -> enum ValueColumnType
class/bank/column.dart              -> Column
class/bank/registry.dart            -> Registry
class/bank/table.dart               -> Table
class/bank/structure.dart           -> Structure
main.dart                           -> smoke test manual
```

### Classes

**`ValueColumnType`** (enum): `int`, `double`, `string`, `bool`, `dateTime`.

**`Column`** — definição de schema de uma coluna, imutável.
- `name` (String), `type` (ValueColumnType), `isKey` (bool, default false), `canNull` (bool, default false)
- `copampareType(Object object)` — switch sobre `type`, usa `is` pra validar se `object` é do tipo Dart correspondente. Retorna `bool`.
- *(nota: nome tem typo — "copampareType", não corrigido ainda)*

**`Registry`** — uma linha de dados.
- `data`: `Map<String, dynamic>` (nome da coluna -> valor)
- `toString()` sobrescrito, retorna `data.toString()`

**`Table`** — schema + dados, imutável.
- `name` (String), `columns` (`List<Column>`), `registries` (`List<Registry>`)
- `insert(Registry registry) -> Table`: valida (chave extra não mapeada em nenhuma coluna, coluna sem valor correspondente, nulo em coluna `canNull: false`, tipo incompatível via `Column.copampareType`) e devolve uma **Table nova** com o registro adicionado. Não muta `this`.
- `scanAll() -> List<Registry>`: retorna todos os registros.

**`Structure`** — o "banco", imutável.
- `name` (String), `tables` (`List<Table>`)
- `createTable(Table table) -> Structure`: adiciona tabela nova, devolve Structure nova.
- `searchTable(String name) -> Table`: busca por nome (`firstWhere` sem `orElse` — lança `StateError` genérico se não achar).
- `updateTable(Table table) -> Structure`: substitui, na lista de tabelas, a tabela com mesmo `name` pela recebida (via `.map()`), devolve Structure nova.
- `insertInto(String name, Registry registry) -> Structure`: composição de `searchTable` + `Table.insert` + `updateTable` num passo atômico. **Ponto de entrada recomendado pra inserir dados** — usar `.insert()` direto numa `Table` obtida de `searchTable` não propaga a mudança pro `Structure` (bug já encontrado e resolvido).

### Decisão de arquitetura: imutabilidade total
Toda operação que "modificaria" um objeto (`insert`, `createTable`, `updateTable`) na verdade constrói e devolve uma instância nova, sem mutar a anterior. Não é imposto pelo compilador (Dart `final` só impede reatribuição, não mutação de coleções) — é convenção seguida manualmente: nunca chamar `.add()`/`.remove()` em listas guardadas em campos `final`, sempre reconstruir via spread (`[...lista, item]`) ou `.map()`.

Motivação: viabilizar histórico de snapshots pra transações/rollback na Fase 6, sem precisar de lógica de "desfazer" manual — cada versão anterior já existe intacta na memória.

### Pendências de polimento (baixa prioridade, não bloqueiam próxima fase)
- `Column.copampareType` — corrigir typo do nome.
- `Structure.searchTable` — adicionar `orElse` com exception customizada em vez de deixar o `StateError` genérico do `firstWhere` estourar.
- `throw Exception(['string'])` espalhado pelo código — trocar por `Exception('string')` (sem colchetes) ou por classes de exception próprias (ex: `SchemaViolationException`, `TableNotFoundException`) pra permitir `catch` seletivo por tipo.

---

## Fase 2 — Persistência em disco

Objetivo: `Structure` sobreviver ao fim do processo — salvar em arquivo e recarregar.

Tarefas:
- Decidir formato de serialização inicial (recomendado: JSON via `dart:convert`, simples de debugar; formato binário próprio fica pra depois se performance virar problema).
- `toJson()` em `Registry`, `Column`, `Table`, `Structure` (cadeia de serialização).
- `fromJson()` (constructor factory) equivalente pra cada classe, reconstruindo os objetos a partir do `Map` decodificado.
- Tratamento de `ValueColumnType` no JSON (serializar como string via `.name`, desserializar via `ValueColumnType.values.byName(...)`).
- Tratamento de `DateTime` no JSON (não tem representação nativa em JSON — serializar como ISO 8601 string via `.toIso8601String()` / `DateTime.parse()`).
- API de entrada: `Structure.save(String path)` e `Structure.load(String path)` (ou factory `Structure.fromFile`), usando `dart:io` (`File`).
- Definir: um arquivo por `Structure` inteira, ou um arquivo por `Table`? (trade-off simplicidade vs. permitir carregar tabelas individualmente).

---

## Fase 3 — Parser de SQL

Objetivo: aceitar comandos SQL como texto puro.

Sub-etapas:
1. **Tokenizer/Lexer**: transforma uma string SQL numa lista de tokens (keywords como `SELECT`/`INSERT`/`WHERE`, identificadores, literais numéricos/string, operadores, pontuação, parênteses).
2. **Parser**: consome a lista de tokens e monta uma AST (Abstract Syntax Tree) — uma classe por tipo de statement (`CreateTableStatement`, `InsertStatement`, `SelectStatement`, etc), cada uma guardando os dados estruturados do comando (nome de tabela, colunas, condições de WHERE, valores).

Ordem sugerida de comandos a suportar (do mais simples ao mais complexo):
- `CREATE TABLE nome (coluna TIPO, ...)`
- `INSERT INTO nome VALUES (...)` / `INSERT INTO nome (col1, col2) VALUES (...)`
- `SELECT * FROM nome` (sem filtro)
- `SELECT * FROM nome WHERE coluna = valor` (WHERE de igualdade simples)
- `SELECT col1, col2 FROM nome WHERE ...` (projeção de colunas)
- `UPDATE nome SET coluna = valor WHERE ...`
- `DELETE FROM nome WHERE ...`
- WHERE com operadores compostos (`AND`, `OR`, `>`, `<`, `!=`)

---

## Fase 4 — Query engine

Objetivo: executar a AST da Fase 3 contra o modelo de dados da Fase 1.

Tarefas:
- Executor por tipo de statement: `CreateTableStatement -> Structure.createTable`, `InsertStatement -> Structure.insertInto`, etc (reaproveita tudo que já existe).
- Para `SELECT`: implementar avaliação de expressões de `WHERE` contra cada `Registry` (filtro), e projeção (selecionar só as colunas pedidas do resultado).
- Erros de execução devem apontar pra problemas semânticos (tabela/coluna inexistente) além dos sintáticos já pegos no parser.

---

## Fase 5 — Índices

Objetivo: evitar full table scan em toda query.

Tarefas:
- Índice de hash simples primeiro: `Map<dynamic, List<Registry>>` por coluna indexada, pra igualdade (`WHERE coluna = valor`) em O(1) em vez de O(n).
- Estrutura de B-Tree depois, pra suportar range queries (`WHERE coluna > valor`) com boa complexidade.
- Definir como declarar uma coluna como indexada (extensão do `Column`, ou comando `CREATE INDEX`).
- Manter índice consistente com o padrão imutável já estabelecido (índice também é reconstruído/atualizado a cada `insert`/`update`/`delete`, não mutado in-place).

---

## Fase 6 — Transações

Objetivo: `BEGIN` / `COMMIT` / `ROLLBACK`, aproveitando a imutabilidade já construída.

Tarefas:
- Histórico de snapshots: uma pilha/lista de versões anteriores de `Structure` (cada operação bem-sucedida gera uma versão nova; a transação guarda a versão "antes de começar").
- `ROLLBACK`: simplesmente descartar a versão em progresso e voltar pra referência salva no início da transação (não precisa de lógica de "desfazer operação por operação").
- `COMMIT`: descartar o snapshot antigo (ou movê-lo pro histórico de undo, se quiser suportar desfazer commits também).
- Definir escopo de isolamento inicial (mais simples: uma transação ativa por vez, sem concorrência).

---

## Fase 7 (opcional) — Camada de rede

Objetivo: transformar isso num servidor de banco de verdade, acessível remotamente.

Tarefas:
- Servidor TCP (`dart:io`, `ServerSocket`) aceitando conexões.
- Protocolo simples baseado em texto pra começar (cliente manda uma linha de SQL, servidor devolve resultado serializado).
- Cliente de linha de comando separado, conectando no servidor e mandando comandos interativamente.
- Considerar depois: autenticação, múltiplas conexões concorrentes, protocolo binário mais eficiente.
