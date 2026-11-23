-- Lucca Eduardo

-- pedido_compra
SELECT pedido_id, CONCAT_WS(' - ', produto_id, NULLIF(TRIM(descricao_produto), '')) AS produto
FROM pedido_compra;

-- venda (nao tem descricao: busca em produtos_filial)
SELECT v.venda_id,
       CONCAT_WS(' - ', v.produto_id, NULLIF(TRIM(p.descricao), '')) AS produto
FROM venda v
LEFT JOIN (SELECT produto_id, MIN(descricao) AS descricao FROM produtos_filial GROUP BY produto_id) p
       ON p.produto_id = v.produto_id;

-- produtos_filial
SELECT filial_id, CONCAT_WS(' - ', produto_id, NULLIF(TRIM(descricao), '')) AS produto
FROM produtos_filial;


SELECT pedido_id,
       DATE_FORMAT(data_pedido, '%d/%m/%Y') AS data_pedido,
       DATE_FORMAT(data_entrega, '%d/%m/%Y') AS data_entrega     -- NULL continua NULL
FROM pedido_compra;

SELECT venda_id, DATE_FORMAT(data_emissao, '%d/%m/%Y') AS data_emissao
FROM venda;

-- 3A) PRINCIPAL: produtos com soma de quantidade requisitada > limite
WITH params AS (
    SELECT CAST(NULL AS DATE) AS ini,
           CAST(NULL AS DATE) AS fim,
           10                 AS limite
    -- exemplo fevereiro/2025: SELECT '2025-02-01' AS ini, '2025-03-01' AS fim, 10 AS limite
),
base AS (
    SELECT pc.*
    FROM pedido_compra pc
    CROSS JOIN params p
    WHERE (p.ini IS NULL OR pc.data_pedido >= p.ini)
      AND (p.fim IS NULL OR pc.data_pedido <  p.fim)
),
frequentes AS (
    SELECT produto_id
    FROM base
    GROUP BY produto_id
    HAVING SUM(qtde_pedida) > (SELECT limite FROM params)
)
SELECT
    CONCAT_WS(' - ', b.produto_id, NULLIF(TRIM(b.descricao_produto), '')) AS `Produto`,
    b.qtde_pedida                                                       AS `Qtde Requisitada`,
    DATE_FORMAT(b.data_pedido, '%d/%m/%Y')                                AS `Data Solicitacao`
FROM base b
JOIN frequentes f ON f.produto_id = b.produto_id
ORDER BY b.produto_id, b.data_pedido;

-- 3B) LITERAL: produtos requisitados em MAIS DE 10 pedidos distintos (nesta base: 0 linhas)
WITH params AS (
    SELECT CAST(NULL AS DATE) AS ini, CAST(NULL AS DATE) AS fim, 10 AS limite
),
base AS (
    SELECT pc.*
    FROM pedido_compra pc
    CROSS JOIN params p
    WHERE (p.ini IS NULL OR pc.data_pedido >= p.ini)
      AND (p.fim IS NULL OR pc.data_pedido <  p.fim)
),
frequentes AS (
    SELECT produto_id
    FROM base
    GROUP BY produto_id
    HAVING COUNT(DISTINCT pedido_id) > (SELECT limite FROM params)
)
SELECT
    CONCAT_WS(' - ', b.produto_id, NULLIF(TRIM(b.descricao_produto), '')) AS `Produto`,
    b.qtde_pedida                                                       AS `Qtde Requisitada`,
    DATE_FORMAT(b.data_pedido, '%d/%m/%Y')                                AS `Data Solicitacao`
FROM base b
JOIN frequentes f ON f.produto_id = b.produto_id
ORDER BY b.produto_id, b.data_pedido;

-- 3C) POR LINHA: so as requisicoes com quantidade requisitada > 10
SELECT
    CONCAT_WS(' - ', produto_id, NULLIF(TRIM(descricao_produto), '')) AS `Produto`,
    qtde_pedida                                                       AS `Qtde Requisitada`,
    DATE_FORMAT(data_pedido, '%d/%m/%Y')                                AS `Data Solicitacao`
FROM pedido_compra
WHERE qtde_pedida > 10
ORDER BY produto_id, data_pedido;

-- =============================================================================================
-- 4) TRIGGER: gera idfornecedor numerico automaticamente em produtos_filial
-- =============================================================================================
-- Regra: ao inserir um produto SEM idfornecedor,
--   a) se o mesmo produto ja existe em outra filial com fornecedor, reaproveita esse fornecedor;
--   b) senao cria um novo fornecedor (razao_social provisoria) e usa o id gerado (AUTO_INCREMENT).
-- Assim a relacao com a tabela fornecedor (FK produtos_filial_fornecedor_fk) sempre fica valida.
-- BEFORE INSERT: roda antes da checagem da FK, entao o fornecedor novo ja existe quando ela acontece.
--
-- NO DBEAVER: selecione do "CREATE TRIGGER" ate o "END" (sem DELIMITER) e execute com Ctrl+Enter.

DROP TRIGGER IF EXISTS trg_produtos_filial_gera_fornecedor;

DELIMITER $$

CREATE TRIGGER trg_produtos_filial_gera_fornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        SET NEW.idfornecedor = (SELECT pf.idfornecedor
                                  FROM produtos_filial pf
                                 WHERE pf.produto_id = NEW.produto_id
                                   AND pf.idfornecedor IS NOT NULL
                                 LIMIT 1);
    END IF;

    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO fornecedor (razao_social)
        VALUES (CONCAT('A DEFINIR - produto ', NEW.produto_id));
        SET NEW.idfornecedor = LAST_INSERT_ID();
    END IF;
END$$

DELIMITER ;
