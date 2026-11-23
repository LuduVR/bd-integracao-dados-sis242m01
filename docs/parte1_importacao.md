# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **Importação:** o script `scripts/importar.py` (Python, `pandas` + `openpyxl` para ler a planilha e
  `psycopg2` para gravar no PostgreSQL), **corrigido** em relação ao script original do estagiário.
  Ele também aceita `--sgbd mysql` (usa `mysql-connector-python` e `INSERT IGNORE`); esse modo MySQL
  **não foi testado**: para o MySQL, o DBeaver (importação de planilha/CSV) é a alternativa segura.
- **Criação das tabelas:** `sql/01_ddl_postgres.sql` (ou `sql/01_ddl_mysql.sql`), rodado antes da importação.
- **Ordem de carga:** `fornecedor` → `produtos_filial` → `pedido_compra` → `entradas_mercadoria` → `venda`
  (produtos depende de fornecedor por chave estrangeira).
- **Como rodar:**
  ```
  pip install pandas openpyxl psycopg2-binary
  # (opcional) DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, ARQUIVO_XLSX
  python scripts/importar.py
  ```

## Estrutura da planilha

Arquivo `dados/base_teste.xlsx`, 5 abas. Tipos conforme lidos da planilha.

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor (20 linhas) | idfornecedor | texto | Valores `F1` … `F20` (com prefixo "F") |
| | razao_social | texto | `Fornecedor n LTDA` |
| produtos_filial (20) | filial_id | inteiro | Só existe a filial 1 |
| | idproduto | texto | **Na planilha chama-se `idproduto`; no banco é `produto_id`** (P1 … P20) |
| | descricao | texto | |
| | estoque | inteiro | |
| | preco_unitario, preco_compra, preco_venda | decimal | |
| | idfornecedor | texto | `F8`, `F9`… (com prefixo "F") |
| pedido_compra (29) | pedido_id, item, ordem_compra, filial_id, fornecedor_id | inteiro | `fornecedor_id` aqui é **numérico** (1..20) |
| | data_pedido, data_entrega | data | |
| | produto_id, descricao_produto | texto | |
| | qtde_pedida, qtde_entregue | inteiro | **Não existe coluna `qtde_pendente`** (o DDL exige; é calculada) |
| | preco_compra | decimal | |
| | colunas M:W | (sem cabeçalho) | **Lixo:** 99 células preenchidas nas linhas 22 a 30 (pedidos 21 a 29) |
| entradas_mercadoria (20) | data_entrada | data | |
| | nro_nfe | texto | `NFE1` … `NFE20` |
| | item, ordem_compra, filial_id | inteiro | |
| | produto_id, descricao_produto | texto | |
| | qtde_recebida | inteiro | |
| | custo_unitario | decimal | |
| venda (33) | venda_id, filial_id, item | inteiro | filiais 1, 2 e 3 |
| | data_emissao | data | de janeiro a março/2025 |
| | horariomov | texto | sempre `08:00:00` |
| | produto_id, unidade_medida | texto | `P1` … `P28`; sempre `UN` |
| | qtde_vendida | decimal | fracionada em 5 linhas |
| | valor_unitario | decimal | |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | A PK usa `ordem_compra`, que **não existe** na tabela (e é a coluna que liga a entrada ao pedido) | Coluna `ordem_compra bigint NOT NULL` criada |
| produtos_filial | Falta a vírgula depois de `idfonecedor int4 NULL` (erro de sintaxe) | Vírgula adicionada |
| produtos_filial | PK usa `idproduto`, mas a coluna é `produto_id` | PK `(filial_id, produto_id)` |
| produtos_filial | `filial_id` é NULL e faz parte da PK | `NOT NULL` |
| produtos_filial / fornecedor | Erros de digitação: `decricao`, `idfonecedor`, `idforncedor` | `descricao`, `idfornecedor` |
| fornecedor | PK `(idforncedor, idproduto)`: `idproduto` não existe em fornecedor, e fornecedor não depende de produto | PK só em `idfornecedor` |
| fornecedor / produtos_filial / pedido_compra | Id do fornecedor é `varchar(25)` em uma tabela e `int4` nas outras: impossível ligar | Tudo `integer` (a Parte 3 pede id numérico) |
| pedido_compra / venda / entradas | `float8` em chaves (`pedido_id`, `item`, `ordem_compra`) e em dinheiro | `bigint`/`integer` nas chaves; `numeric(12,4)` em preços; `numeric(14,3)` em quantidades |
| todas | Defaults que escondem dado faltando: `produto_id DEFAULT ''` ou `'0'`, `filial_id DEFAULT 1`, `ordem_compra DEFAULT 0`, `fornecedor_id DEFAULT 0` | Removidos: dado ausente passa a ser rejeitado pelo banco |
| todas | `::character varying` e `public.` só funcionam no PostgreSQL | Versão separada para MySQL |
| produtos_filial | `produto_id varchar(255)` enquanto as outras tabelas usam `varchar(25)` | Padronizado em 25 |
| (geral) | Nenhum relacionamento (FK) declarado | FK `produtos_filial → fornecedor` criada; as demais ficam opcionais no fim do DDL (rodar depois de validar os órfãos) |

## Erros encontrados no script de importação e como foram corrigidos

Resultado medido rodando o **script original** sobre a planilha (simulação em SQLite no modo estrito,
que imita as restrições de tipo e `NOT NULL` do PostgreSQL; não foi um PostgreSQL real):
**fornecedor 0/20, produtos_filial 0/20, venda 0/33, pedido_compra 29/29 e entradas 20/20 mas todas
sem data.** Mesmo assim ele imprimia "20 registros inseridos… Importação concluída com sucesso!".

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)`, mas o pandas já entrega `Timestamp` (não serial do Excel); o `except` engole o erro | **Todas** as datas viram `NULL`. Em `venda`, `data_emissao` é `NOT NULL`, então **nenhuma venda entra**; pedidos e entradas entram sem data | Função nova aceita Timestamp/date/serial/texto |
| Id de fornecedor `F1`…`F20` (texto) gravado em coluna inteira | Falha em **todas** as linhas de `fornecedor` e `produtos_filial` | `F8` → `8` (`id_fornecedor()`) |
| `conn.rollback()` dentro do loop, com `commit` só no fim da tabela | Um erro desfaz **todas** as linhas anteriores ainda não confirmadas; só as posteriores sobrevivem | `SAVEPOINT` por linha: só a linha com erro é desfeita |
| Mensagem usa `len(df)` ("N inseridos") e o "sucesso" final é fixo | Relatório mente: mostra 20/20/29/20/33 com o banco vazio | Conta o que realmente entrou, confere com `SELECT COUNT(*)` e sai com erro se divergir |
| `ON CONFLICT … DO NOTHING` | Linhas duplicadas na chave somem sem aviso | Contadas e listadas como "ignoradas" |
| `pedido_compra`: `df.iloc[:, :12]` e renomeação **por posição** | Se a ordem das colunas mudar, os dados vão para a coluna errada sem erro; o lixo das colunas M:W é descartado sem avisar | Leitura por **nome** de coluna; aviso explícito de que 11 colunas extras (9 linhas) foram ignoradas |
| `NaN → 0` em `ordem_compra` e `NaN → 1` em `filial_id` (venda) | Escondia dado faltando (acaba gravando ordem 0 / filial 1 inventadas) | Vazio vira `NULL` e o banco rejeita (NOT NULL) |
| `float()` em `pedido_id`, `item`, `ordem_compra` | Chaves inteiras enviadas como decimal | `int()` |
| `ON CONFLICT (idfornecedor)` sem a PK correspondente no DDL original | Erro de PostgreSQL (não há restrição única para o alvo) | Agora usa `ON CONFLICT DO NOTHING` com a PK correta do DDL |
| Caminho `dados/...` relativo ao diretório atual, senha no código, comentário "MySQL porta 3006", prefixo `public.` | Quebra ao rodar de outra pasta; porta do MySQL é **3306**; não roda no MySQL | Caminho relativo ao script, configuração por variáveis de ambiente, sem `public.`, opção `--sgbd mysql` |
| (novo, achado no meu teste) após importar ids explícitos em coluna `IDENTITY`, a sequência fica em 1 | A trigger da Parte 3 geraria id 1, que já existe | `setval` ao final da carga (PostgreSQL) |

## Tratamentos aplicados aos dados

- **Datas:** convertidas para o tipo `date` (aceita Timestamp, serial do Excel e texto ISO).
- **Texto:** `TRIM` em todos os campos de texto.
- **Id de fornecedor:** `F8` → `8` em `fornecedor` e `produtos_filial`, para ser compatível com
  `pedido_compra.fornecedor_id` (já numérico) e com a exigência de id numérico da Parte 3.
- **Números:** quantidades e preços lidos como decimal; chaves e itens como inteiro.
- **`qtde_pendente`:** a planilha não traz a coluna; é calculada na carga como `qtde_pedida − qtde_entregue`.
  Por isso ela **não serve como prova** de pendência (a verdade está nas entradas: ver `02_consultas.sql`, 2b).
- **Nome de coluna:** `idproduto` (planilha) → `produto_id` (banco), em `produtos_filial`.
- **Colunas soltas M:W de `pedido_compra`:** ignoradas (avisadas). Nas linhas dos pedidos 21 a 29 elas repetem
  os valores dos pedidos 12 a 20 (datas, produto, quantidades 91/48/43 etc.); parecem sobra de copiar/colar.
- **Dados do cliente não foram "consertados" em silêncio.** Por exemplo, os 11 pedidos com `ordem_compra = 0`
  e as datas de entrega anteriores ao pedido entraram **como vieram**, e são listados como erro em
  `sql/04_validacao.sql` para o cliente decidir.

## Conferência final

Valores obtidos rodando o `importar.py` corrigido sobre a planilha (mesma simulação em SQLite estrito;
**confirme no seu banco com a consulta A1 de `sql/04_validacao.sql`**).

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
