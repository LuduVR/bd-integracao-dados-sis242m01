-- Lucca Eduardo

SELECT
    v.produto_id,
    COALESCE(p.descricao, '(sem cadastro)')              AS descricao,
    SUM(v.qtde_vendida)                                  AS qtde_total,
    ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2)     AS valor_total_rs
FROM venda v
LEFT JOIN (
    SELECT produto_id, MIN(descricao) AS descricao
    FROM produtos_filial
    GROUP BY produto_id
) p ON p.produto_id = v.produto_id
WHERE v.data_emissao >= '2025-02-01'
AND v.data_emissao < '2025-03-01'
GROUP BY v.produto_id, p.descricao
ORDER BY valor_total_rs DESC;


-- A entrada se liga ao pedido por ordem_compra (e pelo produto).
-- Nao uso o campo "item" no vinculo porque a numeracao de item do pedido pode nao coincidir com a da NF.

-- Nunca recebidos: (base_teste.xlsx: 11 linhas = pedidos 19 a 29, todos com ordem_compra = 0;
-- os pedidos 19 e 20 SO aparecem aqui por causa desse erro de dado: suas entradas NFE19/NFE20
-- estao na ordem 19 e 20. Ver 04_validacao.sql C1/D1.)
-- Nunca recebidos: linha do pedido sem NENHUMA entrada para a mesma ordem_compra + produto.
SELECT
    pc.produto_id,
    pc.descricao_produto,
    pc.pedido_id,
    pc.ordem_compra,
    pc.data_pedido,
    pc.qtde_pedida,
    pc.filial_id
FROM pedido_compra pc
WHERE NOT EXISTS (
    SELECT 1
    FROM entradas_mercadoria em
    WHERE em.ordem_compra = pc.ordem_compra
      AND em.produto_id   = pc.produto_id
)
ORDER BY pc.data_pedido, pc.produto_id;

-- 2b) Visao completa (base_teste.xlsx: 19 linhas = 9 grupos com ordem 0 + 10 recebimentos parciais): tambem pega recebimento PARCIAL (recebido < pedido), calculado a partir das
-- entradas reais. Nao confio na coluna qtde_pendente/qtde_entregue do pedido porque ela e digitada
-- e pode estar inconsistente (conferir em 04_validacao.sql).
WITH req AS (
    SELECT ordem_compra, produto_id,
           MIN(descricao_produto) AS descricao_produto,
           SUM(qtde_pedida)       AS qtde_pedida
    FROM pedido_compra
    GROUP BY ordem_compra, produto_id
),
rec AS (
    SELECT ordem_compra, produto_id, SUM(qtde_recebida) AS qtde_recebida
    FROM entradas_mercadoria
    GROUP BY ordem_compra, produto_id
)
SELECT
    r.ordem_compra,
    r.produto_id,
    r.descricao_produto,
    r.qtde_pedida,
    COALESCE(c.qtde_recebida, 0)                    AS qtde_recebida,
    r.qtde_pedida - COALESCE(c.qtde_recebida, 0)   AS qtde_nao_recebida
FROM req r
LEFT JOIN rec c
       ON c.ordem_compra = r.ordem_compra
      AND c.produto_id   = r.produto_id
WHERE COALESCE(c.qtde_recebida, 0) < r.qtde_pedida
ORDER BY qtde_nao_recebida DESC;