# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

> Tom da reunião: o objetivo não é "provar que está certo", e sim mostrar ao cliente **o que bate, o que
> não bate e por quê**, para ele decidir cada ponto com segurança. Os números abaixo vêm da
> `base_teste.xlsx` importada; as consultas (códigos A1, B3…) estão em `sql/04_validacao.sql`.

## 1. Pontos a validar

1. **Escopo.** A base traz vendas de janeiro a março (12 linhas em janeiro, 14 em fevereiro e 7 em março).
   Confirmar que a validação é só de **01/02 a 28/02/2025** e que as demais linhas devem ser ignoradas.
2. **Totais de fevereiro.** Com a base atual: **14 linhas de venda, 173,22 unidades e R$ 14.093,17**
   (consulta A2). O cliente compara com o relatório do sistema dele. Se o total dele for outro, a
   diferença é a primeira pista (ver pontos 3 e 4).
3. **Produtos vendidos sem cadastro.** 6 das 14 linhas de fevereiro (**R$ 3.241,24, cerca de 23% do mês**)
   são de produtos P22 a P27, que não existem em `produtos_filial`, e as filiais 2 e 3 também não têm
   nenhum produto cadastrado (B3, B3b). Perguntar: são produtos novos? Falta o cadastro? Entram no total?
4. **Quantidade fracionada em "UN".** Vendas 16 e 26 (fevereiro) têm 37,11 e 3,11 unidades. É erro de
   digitação, é unidade errada (kg?) ou o sistema permite fração? (B4)
5. **Compras e recebimentos.** Os pedidos 19 a 29 estão com `ordem_compra = 0`, então aparecem como "não
   recebidos". Os pedidos 19 e 20 têm entrada (NFE19, NFE20) na ordem 19 e 20: o vínculo foi perdido.
   Os pedidos 21 a 29 repetem produtos já pedidos (P12 a P20): são pedidos novos ou duplicidade? (C1, C4, D1)
6. **Datas incoerentes.** 20 pedidos com entrega marcada **antes** do pedido e 9 entradas de mercadoria
   **antes** do pedido (C2, D3). Qual campo está certo?
7. **Quantidades recebidas.** Em 7 ordens entrou **mais** mercadoria do que foi pedida (D2) e a
   `qtde_entregue` do pedido não bate com o que está nas notas em **nenhuma** das 18 ordens vinculadas (C3).
8. **Preços.** O custo na nota difere do preço do pedido em 18 de 18 casos (D4); 4 produtos (P1, P8, P15, P18)
   têm preço de venda **menor** que o de compra (E1); os preços praticados em fevereiro diferem do `preco_venda`
   do cadastro em todos os 8 casos com cadastro (E4). Perguntar o que significam `preco_unitario`
   e `preco_venda` (são diferentes nos 20 produtos, E5).
9. **Fornecedor.** Em 22 de 29 pedidos o fornecedor do pedido é diferente do fornecedor cadastrado no
   produto (C7); F14, F15 e F16 não têm produto (E3). Qual é a fonte confiável?
10. **Regras de negócio.** O que é "requisitado" e "recebido" para o cliente? Como aparecem devoluções
    e cancelamentos? (A base não traz nenhuma quantidade negativa.)
11. **Decisão sobre cada erro:** corrigir na origem, corrigir aqui ou aceitar e ignorar.

## 2. Técnicas para garantir exatidão e precisão

- **Reconciliação de carga:** contar linhas e somar valores na planilha **e** no banco. A importação só é
  dada como válida quando as duas pontas fecham (A1; o `importar.py` já confere isso e sai com erro se não fechar).
- **Cálculo por duas vias:** refazer o total de fevereiro agrupando por produto, por dia e por filial
  (Parte 2, A3, A4); os três precisam dar R$ 14.093,17.
- **Integridade referencial:** procurar registros órfãos: venda sem produto (B3), entrada sem pedido (D1),
  produto sem fornecedor (E2).
- **Regras de consistência entre tabelas:** entrega não pode ser antes do pedido (C2), nota não pode ser
  antes do pedido (D3), recebido não pode superar o pedido (D2), entregue do pedido = soma das notas (C3).
- **Tipos e domínio:** `numeric` em vez de `float` para dinheiro/quantidade (sem erro de arredondamento);
  `NOT NULL` e chaves primárias corretas para o banco rejeitar dado ruim em vez de aceitá-lo.
- **Duplicidade:** chaves de negócio repetidas (B6, C4, D5, E3).
- **Formato:** horário `HH:MM:SS` (B5), espaços sobrando em `produto_id` (F1), descrições divergentes (F2).
- **Amostragem manual:** pegar ~10 vendas de fevereiro e conferir, linha a linha, com o documento
  original do cliente (nota/cupom).
- **Rastreabilidade:** nada foi corrigido em silêncio; o que veio errado entrou como veio e está listado
  abaixo para decisão do cliente.

## 3. Consultas preparadas para a reunião

Todas em `sql/04_validacao.sql` (e as da Parte 2 em `sql/02_consultas.sql`).

| Código | O que mostra | Para que serve na reunião |
| --- | --- | --- |
| A1 | Linhas por tabela | "Chegaram todas as linhas da planilha?" (20 / 20 / 29 / 20 / 33) |
| A2 | Resumo de fevereiro | Totais para o cliente comparar com o sistema dele |
| A3 / A4 | Vendas por dia / por filial | Achar dia faltando ou valor fora do padrão |
| A5 | 10 produtos que mais venderam | O cliente reconhece os campeões de venda? |
| 02 · consulta 1 | Total por produto (qtde e R$) em fevereiro | A consulta pedida na Parte 2 |
| 02 · consultas 2a / 2b | Requisitados e não recebidos / recebidos parcialmente | O resultado de compras que ele quer ver |
| B2 | Vendas por mês | Mostra que a base não é só de fevereiro |
| B3 / B3b | Venda sem cadastro e quanto vale em fevereiro | Ponto 3 |
| B4 | Fração em unidade "UN" | Ponto 4 |
| C1 / D1 | Pedidos com ordem 0 / entradas sem pedido | Ponto 5 |
| C2 / D3 | Datas incoerentes | Ponto 6 |
| C3 / D2 / D4 | Quantidade e custo divergentes | Pontos 7 e 8 |
| E1 / E4 / E5 | Preços do cadastro e praticados | Ponto 8 |
| C7 / E3 | Fornecedor divergente / sem produto | Ponto 9 |

Cada consulta de erro deve voltar **vazia** depois que o cliente corrigir a origem: esse é o critério de "aceito".

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | Produto/filial vendido sem cadastro em `produtos_filial` (P21 a P28; filiais 2 e 3 sem nenhum cadastro) | 13 linhas (6 em fevereiro, R$ 3.241,24) | B3, B3b |
| venda | Quantidade fracionada em unidade `UN` | 5 linhas (2 em fevereiro: vendas 16 e 26) | B4 |
| venda | Linhas fora de fevereiro misturadas (12 em janeiro, 7 em março) | 19 linhas | B2 |
| pedido_compra | `ordem_compra = 0` (pedidos 19 a 29): sem vínculo com entradas | 11 linhas | C1 |
| pedido_compra | Pedidos 21 a 29 repetem produtos P12 a P20 já pedidos | 9 produtos | C4 |
| pedido_compra | Colunas soltas M:W sem cabeçalho, com cópia dos pedidos 12 a 20 (não importadas) | 99 células, 9 linhas | (só na planilha; ver Parte 1) |
| pedido_compra | Data de entrega anterior à data do pedido | 20 linhas | C2 |
| pedido_compra | `qtde_entregue` diferente do recebido nas entradas | 18 de 18 vinculados | C3 |
| pedido_compra | Fornecedor do pedido ≠ fornecedor cadastrado do produto | 22 de 29 linhas | C7 |
| pedido_compra | Planilha sem `qtde_pendente` (campo calculado, não serve como prova) | 29 linhas | C6 |
| entradas_mercadoria | Entrada sem pedido correspondente (NFE19 e NFE20, por causa da ordem 0) | 2 linhas | D1 |
| entradas_mercadoria | Quantidade recebida maior que a pedida | 7 ordens (pedidos 2, 3, 5, 7, 11, 15, 16) | D2 |
| entradas_mercadoria | Entrada anterior à data do pedido | 9 linhas | D3 |
| entradas_mercadoria | Custo da nota diferente do preço do pedido | 18 de 18 vinculados | D4 |
| produtos_filial | Preço de venda menor que o de compra (P1, P8, P15, P18) | 4 produtos | E1 |
| produtos_filial | `preco_unitario` sempre diferente de `preco_venda` (significado a esclarecer) | 20 de 20 | E5 |
| venda × cadastro | Valor vendido em fevereiro diferente do `preco_venda` do cadastro | 8 de 8 com cadastro | E4 |
| fornecedor | Fornecedores sem nenhum produto (F14, F15, F16) | 3 | E3 |
| fornecedor / produtos_filial | Id vem como texto `F8`, mas é numérico em `pedido_compra` (tratado na importação) | 40 linhas | Parte 1 |

**Verificados e sem erro** (consultas voltam vazias): valor/quantidade zero ou negativo (B1), horário
(B5), duplicidade (B6), unidade vazia (B7), entregue maior que pedido (C5), fornecedor inexistente (C8),
quantidade/custo inválido nas entradas (D5), produto sem fornecedor (E2), espaços e descrições divergentes (F1 a F3).
