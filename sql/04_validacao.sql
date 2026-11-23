-- Lucca Eduardo

SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM venda;


SELECT COUNT(*)                                     AS linhas,
       COUNT(DISTINCT venda_id)                     AS vendas,
       COUNT(DISTINCT produto_id)                   AS produtos,
       COUNT(DISTINCT data_emissao)                 AS dias_com_venda,
       MIN(data_emissao)                            AS primeira_data,
       MAX(data_emissao)                            AS ultima_data,
       SUM(qtde_vendida)                            AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total_rs
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01';

-- A3. vendas por dia (dias sem venda ou picos estranhos chamam atencao)
SELECT data_emissao, COUNT(*) AS linhas, ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
GROUP BY data_emissao ORDER BY data_emissao;

-- A4. vendas por filial em fevereiro
SELECT filial_id, COUNT(*) AS linhas, ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
GROUP BY filial_id ORDER BY filial_id;

-- A5. top 10 produtos de fevereiro (o cliente costuma reconhecer os campeoes de venda)
SELECT produto_id, SUM(qtde_vendida) AS qtde, ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
FROM venda
WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
GROUP BY produto_id ORDER BY valor_rs DESC LIMIT 10;

-- B1. quantidade nula/zero/negativa ou preco unitario zero/negativo   (base atual: 0 linhas)
SELECT * FROM venda WHERE qtde_vendida IS NULL OR qtde_vendida <= 0 OR valor_unitario <= 0;

-- B2. vendas FORA de fevereiro misturadas na base (a validacao e so de fev/2025)  (19 linhas: 12 jan + 7 mar)
SELECT DATE_FORMAT(data_emissao, '%Y-%m') AS mes, COUNT(*) AS linhas,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
FROM venda GROUP BY mes ORDER BY mes;

-- B3. produto/filial vendido SEM cadastro em produtos_filial   (13 linhas, 8 produtos P21-P28; 6 linhas em fev)
--     Inclui P27/P28 vendidos nas filiais 2 e 3, que nem existem em produtos_filial.
SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id, v.qtde_vendida, v.valor_unitario
FROM venda v
LEFT JOIN produtos_filial p ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id
WHERE p.produto_id IS NULL
ORDER BY v.data_emissao;

-- B3b. quanto de fevereiro fica sem cadastro (impacto para o cliente)
SELECT COUNT(*) AS linhas, ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2) AS valor_rs
FROM venda v
LEFT JOIN produtos_filial p ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id
WHERE p.produto_id IS NULL
  AND v.data_emissao >= '2025-02-01' AND v.data_emissao < '2025-03-01';

-- B4. quantidade FRACIONADA em unidade 'UN' (unidade nao se vende em pedacos)   (5 linhas; 2 em fev: vendas 16 e 26)
SELECT * FROM venda WHERE unidade_medida = 'UN' AND qtde_vendida <> FLOOR(qtde_vendida);

-- B5. horario fora do formato HH:MM:SS   (base atual: 0 linhas; todos 08:00:00)
SELECT * FROM venda WHERE horariomov NOT REGEXP '^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$';

-- B6. possivel duplicidade: mesma venda/produto/qtde/valor/horario variando so o "item"  (0 linhas)
SELECT filial_id, venda_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario,
       COUNT(*) AS repeticoes
FROM venda
GROUP BY filial_id, venda_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario
HAVING COUNT(*) > 1;

-- B7. unidade de medida vazia ou mais de uma unidade para o mesmo produto   (0 linhas)
SELECT * FROM venda WHERE unidade_medida IS NULL OR TRIM(unidade_medida) = '';
SELECT produto_id, COUNT(DISTINCT unidade_medida) AS unidades
FROM venda GROUP BY produto_id HAVING COUNT(DISTINCT unidade_medida) > 1;

-- =============================================================================================
-- C) ERROS EM PEDIDO_COMPRA
-- =============================================================================================
-- C1. ordem_compra = 0 (pedido sem vinculo com entradas)   (11 linhas: pedidos 19 a 29)
--     Pedidos 19 e 20 tem entradas (NFE19/NFE20) gravadas na ordem 19 e 20 -> o vinculo foi perdido.
SELECT pedido_id, produto_id, ordem_compra, data_pedido, qtde_pedida
FROM pedido_compra WHERE ordem_compra = 0 ORDER BY pedido_id;

-- C2. data de entrega ANTERIOR a data do pedido   (20 linhas)
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra WHERE data_entrega < data_pedido ORDER BY pedido_id;

-- C3. qtde_entregue do pedido diferente do que realmente entrou em entradas_mercadoria   (18 de 18 vinculados)
SELECT pc.ordem_compra, pc.produto_id, SUM(pc.qtde_entregue) AS entregue_no_pedido,
       COALESCE(MAX(e.recebido), 0) AS recebido_nas_entradas
FROM pedido_compra pc
LEFT JOIN (SELECT ordem_compra, produto_id, SUM(qtde_recebida) AS recebido
           FROM entradas_mercadoria GROUP BY ordem_compra, produto_id) e
       ON e.ordem_compra = pc.ordem_compra AND e.produto_id = pc.produto_id
GROUP BY pc.ordem_compra, pc.produto_id
HAVING SUM(pc.qtde_entregue) <> COALESCE(MAX(e.recebido), 0);

-- C4. mesmo produto pedido mais de uma vez (pedidos 21-29 repetem P12-P20 com ordem_compra 0)   (9 produtos)
SELECT produto_id, COUNT(DISTINCT pedido_id) AS pedidos, GROUP_CONCAT(pedido_id ORDER BY pedido_id SEPARATOR ',') AS ids
FROM pedido_compra GROUP BY produto_id HAVING COUNT(DISTINCT pedido_id) > 1 ORDER BY 1;

-- C5. quantidade pedida invalida ou entregue maior que o pedido   (0 linhas)
SELECT * FROM pedido_compra
WHERE qtde_pedida IS NULL OR qtde_pedida <= 0 OR qtde_entregue > qtde_pedida OR data_pedido IS NULL;

-- C6. qtde_pendente diferente de pedida - entregue   (0 linhas: a planilha NAO traz a coluna;
--     o importar.py a calcula. Por isso ela nao serve como prova do pendente: use as entradas, consulta C3.)
SELECT pedido_id, produto_id, qtde_pedida, qtde_entregue, qtde_pendente
FROM pedido_compra WHERE NOT (qtde_pendente <=> (qtde_pedida - qtde_entregue));

-- C7. fornecedor do pedido DIFERENTE do fornecedor cadastrado para o produto   (22 de 29 linhas)
SELECT pc.pedido_id, pc.produto_id, pc.fornecedor_id AS fornecedor_no_pedido, pf.idfornecedor AS fornecedor_no_cadastro
FROM pedido_compra pc
JOIN produtos_filial pf ON pf.produto_id = pc.produto_id AND pf.filial_id = pc.filial_id
WHERE NOT (pc.fornecedor_id <=> pf.idfornecedor)
ORDER BY pc.pedido_id;

-- C8. fornecedor do pedido inexistente / preco de compra zero   (0 linhas)
SELECT pc.* FROM pedido_compra pc
LEFT JOIN fornecedor f ON f.idfornecedor = pc.fornecedor_id
WHERE pc.fornecedor_id IS NULL OR f.idfornecedor IS NULL OR pc.preco_compra IS NULL OR pc.preco_compra <= 0;

-- D1. entrada SEM pedido correspondente (ordem_compra + produto)   (2 linhas: NFE19 e NFE20, ordem 19 e 20)
SELECT e.* FROM entradas_mercadoria e
WHERE NOT EXISTS (SELECT 1 FROM pedido_compra pc
                  WHERE pc.ordem_compra = e.ordem_compra AND pc.produto_id = e.produto_id);

-- D2. recebido a MAIS do que foi pedido   (7 casos: pedidos 2, 3, 5, 7, 11, 15, 16)
SELECT e.ordem_compra, e.produto_id, e.recebido, p.pedido
FROM (SELECT ordem_compra, produto_id, SUM(qtde_recebida) AS recebido
      FROM entradas_mercadoria GROUP BY ordem_compra, produto_id) e
JOIN (SELECT ordem_compra, produto_id, SUM(qtde_pedida) AS pedido
      FROM pedido_compra GROUP BY ordem_compra, produto_id) p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.recebido > p.pedido
ORDER BY e.ordem_compra;

-- D3. entrada ANTES do pedido (impossivel)   (9 linhas)
SELECT e.nro_nfe, e.ordem_compra, e.produto_id, pc.data_pedido, e.data_entrada
FROM entradas_mercadoria e
JOIN pedido_compra pc ON pc.ordem_compra = e.ordem_compra AND pc.produto_id = e.produto_id
WHERE e.data_entrada < pc.data_pedido
ORDER BY e.ordem_compra;

-- D4. custo da entrada diferente do preco combinado no pedido   (18 de 18 vinculados)
SELECT e.ordem_compra, e.produto_id, e.custo_unitario, pc.preco_compra
FROM entradas_mercadoria e
JOIN pedido_compra pc ON pc.ordem_compra = e.ordem_compra AND pc.produto_id = e.produto_id
WHERE ROUND(e.custo_unitario, 2) <> ROUND(pc.preco_compra, 2)
ORDER BY e.ordem_compra;

-- D5. quantidade/custo invalidos ou mesma NF-e em ordens diferentes   (0 linhas)
SELECT * FROM entradas_mercadoria WHERE qtde_recebida IS NULL OR qtde_recebida <= 0 OR custo_unitario <= 0;
SELECT nro_nfe, COUNT(DISTINCT ordem_compra) AS ordens
FROM entradas_mercadoria GROUP BY nro_nfe HAVING COUNT(DISTINCT ordem_compra) > 1;

-- E1. preco de venda MENOR que o de compra (venda com prejuizo) ou estoque negativo   (4 produtos: P1, P8, P15, P18)
SELECT filial_id, produto_id, preco_compra, preco_venda, estoque
FROM produtos_filial WHERE preco_venda < preco_compra OR estoque < 0 ORDER BY produto_id;

-- E2. produto sem fornecedor ou com fornecedor inexistente   (0 linhas)
SELECT p.* FROM produtos_filial p
LEFT JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
WHERE p.idfornecedor IS NULL OR f.idfornecedor IS NULL;

-- E3. fornecedores sem nenhum produto (F14, F15, F16)   e   razao social duplicada (0)
SELECT f.* FROM fornecedor f
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.idfornecedor = f.idfornecedor);
SELECT UPPER(TRIM(razao_social)) AS razao, COUNT(*) AS qtd
FROM fornecedor GROUP BY UPPER(TRIM(razao_social)) HAVING COUNT(*) > 1;

-- E4. valor unitario VENDIDO em fevereiro diferente do preco_venda do cadastro   (8 de 8 linhas que tem cadastro)
SELECT v.venda_id, v.produto_id, v.valor_unitario AS vendido_por, p.preco_venda AS cadastro_preco_venda
FROM venda v
JOIN produtos_filial p ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id
WHERE v.data_emissao >= '2025-02-01' AND v.data_emissao < '2025-03-01'
  AND ROUND(v.valor_unitario, 2) <> ROUND(p.preco_venda, 2)
ORDER BY v.venda_id;

-- E5. preco_unitario sempre diferente de preco_venda (significado dos dois campos nao esta claro)   (20 de 20)
--     -> PERGUNTA PARA O CLIENTE, nao e necessariamente erro.
SELECT COUNT(*) AS produtos, SUM(CASE WHEN preco_unitario <> preco_venda THEN 1 ELSE 0 END) AS diferentes
FROM produtos_filial;

-- F1. produto_id com espaco sobrando (impede o join e esconde vendas)   (0 linhas)
SELECT 'venda' AS tabela, produto_id FROM venda WHERE produto_id <> TRIM(produto_id)
UNION ALL SELECT 'pedido_compra',       produto_id FROM pedido_compra       WHERE produto_id <> TRIM(produto_id)
UNION ALL SELECT 'entradas_mercadoria', produto_id FROM entradas_mercadoria WHERE produto_id <> TRIM(produto_id)
UNION ALL SELECT 'produtos_filial',     produto_id FROM produtos_filial     WHERE produto_id <> TRIM(produto_id);

-- F2. mesmo produto_id com descricoes diferentes entre as tabelas   (0 linhas)
SELECT produto_id, COUNT(DISTINCT UPPER(TRIM(d))) AS descricoes
FROM (SELECT produto_id, descricao AS d FROM produtos_filial
      UNION ALL SELECT produto_id, descricao_produto FROM pedido_compra
      UNION ALL SELECT produto_id, descricao_produto FROM entradas_mercadoria) x
WHERE d IS NOT NULL AND TRIM(d) <> ''
GROUP BY produto_id HAVING COUNT(DISTINCT UPPER(TRIM(d))) > 1;

-- F3. produto sem descricao em pedido/entrada (afetaria a concatenacao da Parte 3)   (0 linhas)
SELECT 'pedido_compra' AS tabela, produto_id FROM pedido_compra
 WHERE descricao_produto IS NULL OR TRIM(descricao_produto) = ''
UNION ALL
SELECT 'entradas_mercadoria', produto_id FROM entradas_mercadoria
 WHERE descricao_produto IS NULL OR TRIM(descricao_produto) = '';