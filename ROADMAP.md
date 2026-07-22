# DartDB — Roadmap Técnico

Banco de dados relacional escrito do zero em Dart, sem libs externas de banco. Documento de referência técnica do projeto — estado atual e próximas fases.

## Estado atual: Fase 2 completa (persistência em disco)

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

## Fase 2 — Persistência em disco ✅ (completa e testada de ponta a ponta)

Objetivo atingido: `Structure` sobrevive ao fim do processo. Provado com dois processos separados (um grava e encerra, outro só lê), preservando todos os tipos: `int`, `double`, `bool`, `string`, `dateTime` (preenchido e nulo), múltiplas tabelas, e objeto carregado permanece operável (`insertInto` roda nele).

### O que foi construído

**Cadeia de serialização (`toJson`/`fromJson`) nas 4 classes.** Formato: **JSON via `dart:convert`**.
- `Column`: `type` serializado como string via `ValueColumnType.name`; reconstruído via `ValueColumnType.values.byName(...)`.
- `Registry`: `toJson` devolve `{'data': data}`; `fromJson` reconstrói o Map cru (sem tratar `dateTime` — ver abaixo).
- `Table` e `Structure`: `toJson` passa as listas de filhos cruas (o `jsonEncode` chama `.toJson()` recursivo automaticamente na ida); `fromJson` reconstrói via `.map((m) => Filho.fromJson(m as Map<String, dynamic>)).toList()`.

**Persistência em disco (`dart:io`), só na `Structure`:**
- `Future<void> save(String path) async` — encadeia `this.toJson()` → `jsonEncode(...)` → `await File(path).writeAsString(...)`.
- `static Future<Structure> load(String path) async` — encadeia `await File(path).readAsString()` → `jsonDecode(...)` → `Structure.fromJson(...)`. É `static` (não factory) porque factory não pode ser `async` (`Factory bodies can't use 'async'`), e não é método de instância porque cria a `Structure` do zero.

**Tratamento de `DateTime` (assimétrico por necessidade):**
- **Ida** (`Structure.save`): via segundo parâmetro `toEncodable` do `jsonEncode` — `(obj) => obj is DateTime ? obj.toIso8601String() : (obj as dynamic).toJson()`. Um único ponto no topo trata toda a árvore. **Cuidado documentado:** passar `toEncodable` **substitui** o comportamento padrão de chamar `.toJson()`, então a função tem que tratar `DateTime` **e** delegar o resto pro `.toJson()`.
- **Volta** (`Table.fromJson`): a string ISO é indistinguível de uma coluna `string`, então a reconversão é decidida **pelo schema**, nunca pelo valor. Para cada campo `(key, value)` do `data`: acha a `Column` por `name == key`; se `type == dateTime && value != null` → `DateTime.parse(value)`, senão passa inalterado. A condição `value != null` é obrigatória (colunas `dateTime` com `canNull: true` gravam `null`, e `DateTime.parse(null)` estoura).

### Decisões de arquitetura

- **Um arquivo por `Structure` inteira** (não um por `Table`). `save`/`load` vivem só na `Structure`; tentativas de pôr em `Registry`/`Table` foram descartadas.
- **`DateTime` orquestrado com baixo acoplamento**: a ida mora no `Structure.save` (só o topo chama `jsonEncode`; detectar `is DateTime` não precisa do schema). A volta mora na `Table.fromJson` (precisa das `columns` + `registries` juntos). As classes-filhas (`Registry`, `Column`) permanecem desacopladas — nenhuma conhece o schema da outra. Regra que emergiu: "o pai orquestra só quando precisa cruzar dado das filhas" — na ida não há dado cruzado, na volta há.

### Notas técnicas de evolução (Fase 2)

- **Padrão de erro dominante da sessão: confundir *afirmar um tipo* com *construir/converter um valor*.** Reincidiu 5x — `enum == String`, `json['type'] as ValueColumnType`, `json['columns'] as List<Column>`, `registry as Registry` dentro de `.map`, `json['type']` comparado direto. Raiz: `as` não executa transformação nenhuma (só afirma pro compilador), e `==` entre tipos diferentes é sempre `false`. **Consolidado ao fim**: depois que `ValueColumnType.values.byName` fez sentido no caso escalar, o usuário generalizou pra listas (`.map(...fromJson...).toList()`) sem dica.
- **Recorrente ao longo da fase: colocar lógica na classe errada.** `save`/`load` foram criados em `Registry` e depois em `Table` antes de irem pra `Structure`; o `toEncodable` idem. Corrigido por rastreamento ("quem realmente chama `jsonEncode`?"), mas o reflexo de duplicar em vez de localizar apareceu duas vezes. Ainda não consolidado.
- **Novo, aplicado com dica: factory de corpo com variável local.** A volta exigiu reusar as `columns` reconstruídas em dois lugares (campo `columns:` + conversão de `dateTime`); o usuário não percebeu sozinho que isso força abandonar o `return Table(...)` de expressão única e usar corpo `{ }` com `final columns` local. Conceito novo, precisou ser apontado.
- **Bordas encontradas por teste, não por revisão** (reforça rodar de verdade): `DateTime.parse(null)` só apareceu ao testar coluna `dateTime` nulável; a pegadinha do `toEncodable` substituir o `toJson` padrão só apareceu rodando probe isolado.

### Pendências herdadas da Fase 1 (ainda abertas)

- `Column.copampareType` — typo no nome.
- `Structure.searchTable` — sem `orElse` (lança `StateError` genérico).
- `throw Exception(['string'])` com colchetes espalhado — trocar por `Exception('string')` ou exceptions próprias.
- **Nova, da Fase 2:** `ValueColumnType.values.byName(...)` e `DateTime.parse(...)` lançam erros genéricos em arquivo corrompido/editado à mão — candidatos a exceptions próprias (ex: `CorruptedFileException`) quando a fase de tratamento de erros chegar.

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
