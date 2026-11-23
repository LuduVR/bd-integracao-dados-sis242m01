-- Lucca Eduardo
--  1. entradas_mercadoria: a PK cita a coluna ORDEM_COMPRA, que NAO existe na tabela
--  2. produtos_filial: falta a virgula depois de "idfonecedor int4 NULL" (erro de sintaxe).
--  3. produtos_filial: a PK usa "idproduto", mas a coluna se chama "produto_id". -> PK (filial_id, produto_id).
--  4. produtos_filial: filial_id e NULL, mas faz parte da PK. -> NOT NULL.
--  5. fornecedor: a PK usa "idproduto", coluna que nao existe na tabela. Alem disso um fornecedor
--  6. Erros de digitacao: "decricao" -> descricao; "idfonecedor" e "idforncedor" -> idfornecedor.
--  7. Tipo do id do fornecedor: varchar(25) em fornecedor, mas int4 em produtos_filial e
--  8. float8 (ponto flutuante) em colunas que sao chave (pedido_id, item, ordem_compra): chave com
--  9. float8 para dinheiro (preco_*) e erro de arredondamento. -> numeric(12,4). Quantidades -> numeric(14,3).
-- 10. Defaults que escondem dado faltando: produto_id DEFAULT '' (venda), produto_id DEFAULT '0',
-- 11. Sintaxe '...'::character varying so existe no PostgreSQL (MySQL nao aceita) e "public." tambem.
-- 12. Os nomes no texto do PDF (vendas, pedidos_compra, produtos) diferem do DDL (venda, pedido_compra,
-- 13. Tamanho de produto_id varia (25 em umas tabelas, 255 em produtos_filial) -> padronizado em 25.
-- 14. Na PLANILHA os ids de fornecedor vem como texto ('F1'..'F20') em fornecedor e produtos_filial, mas

Create database Post;
use Post;

CREATE TABLE fornecedor (
    idfornecedor  integer AUTO_INCREMENT,
    razao_social  varchar(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

CREATE TABLE produtos_filial (
    filial_id       integer       NOT NULL,
    produto_id      varchar(25)   NOT NULL,
    descricao       varchar(255)  NOT NULL,
    estoque         numeric(14,3) NOT NULL DEFAULT 0,
    preco_unitario  numeric(12,4) NOT NULL DEFAULT 0,
    preco_compra    numeric(12,4) NOT NULL DEFAULT 0,
    preco_venda     numeric(12,4) NOT NULL DEFAULT 0,
    idfornecedor    integer       NULL,   -- preenchido pela trigger (03_transformacoes.sql) quando vier nulo
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT produtos_filial_fornecedor_fk FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor)
);

CREATE TABLE venda (
    venda_id        bigint        NOT NULL,
    data_emissao    date          NOT NULL,
    horariomov      varchar(8)    NOT NULL DEFAULT '00:00:00',
    produto_id      varchar(25)   NOT NULL,
    qtde_vendida    numeric(14,3) NULL,
    valor_unitario  numeric(12,4) NOT NULL DEFAULT 0,
    filial_id       bigint        NOT NULL,
    item            integer       NOT NULL DEFAULT 0,
    unidade_medida  varchar(3)    NULL,
    CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

CREATE TABLE pedido_compra (
    pedido_id          bigint        NOT NULL,
    data_pedido        date          NULL,
    item               integer       NOT NULL DEFAULT 0,
    produto_id         varchar(25)   NOT NULL,
    descricao_produto  varchar(255)  NULL,
    ordem_compra       bigint        NOT NULL,
    qtde_pedida        numeric(14,3) NULL,
    filial_id          integer       NULL,
    data_entrega       date          NULL,
    qtde_entregue      numeric(14,3) NOT NULL DEFAULT 0,
    qtde_pendente      numeric(14,3) NOT NULL DEFAULT 0,
    preco_compra       numeric(12,4) NULL DEFAULT 0,
    fornecedor_id      integer       NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE TABLE entradas_mercadoria (
    data_entrada       date          NULL,
    nro_nfe            varchar(255)  NOT NULL,
    item               integer       NOT NULL DEFAULT 0,
    produto_id         varchar(25)   NOT NULL,
    descricao_produto  varchar(255)  NULL,
    qtde_recebida      numeric(14,3) NULL,
    filial_id          integer       NULL,
    custo_unitario     numeric(12,4) NOT NULL DEFAULT 0,
    ordem_compra       bigint        NOT NULL,   -- liga a entrada ao pedido_compra (faltava no enunciado)
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE INDEX ix_venda_data_emissao      ON venda (data_emissao);
CREATE INDEX ix_venda_produto           ON venda (produto_id);
CREATE INDEX ix_pedido_ordem_compra     ON pedido_compra (ordem_compra, produto_id);
CREATE INDEX ix_pedido_data             ON pedido_compra (data_pedido);
CREATE INDEX ix_entrada_ordem_compra    ON entradas_mercadoria (ordem_compra, produto_id);
