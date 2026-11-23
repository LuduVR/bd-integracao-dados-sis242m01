-- Lucca Eduardo
-- Os erros corrigidos sao os mesmos listados em 01_ddl_postgres.sql. Adaptacoes especificas do MySQL


Create database if not exists FornecedorSQL;
USE FornecedorSQL;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;

CREATE TABLE fornecedor (
    idfornecedor  INT           NOT NULL AUTO_INCREMENT,
    razao_social  VARCHAR(255)  NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE produtos_filial (
    filial_id       INT            NOT NULL,
    produto_id      VARCHAR(25)    NOT NULL,
    descricao       VARCHAR(255)   NOT NULL,
    estoque         DECIMAL(14,3)  NOT NULL DEFAULT 0,
    preco_unitario  DECIMAL(12,4)  NOT NULL DEFAULT 0,
    preco_compra    DECIMAL(12,4)  NOT NULL DEFAULT 0,
    preco_venda     DECIMAL(12,4)  NOT NULL DEFAULT 0,
    idfornecedor    INT            NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT produtos_filial_fornecedor_fk FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venda (
    venda_id        BIGINT         NOT NULL,
    data_emissao    DATE           NOT NULL,
    horariomov      VARCHAR(8)     NOT NULL DEFAULT '00:00:00',
    produto_id      VARCHAR(25)    NOT NULL,
    qtde_vendida    DECIMAL(14,3)  NULL,
    valor_unitario  DECIMAL(12,4)  NOT NULL DEFAULT 0,
    filial_id       BIGINT         NOT NULL,
    item            INT            NOT NULL DEFAULT 0,
    unidade_medida  VARCHAR(3)     NULL,
    CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pedido_compra (
    pedido_id          BIGINT         NOT NULL,
    data_pedido        DATE           NULL,
    item               INT            NOT NULL DEFAULT 0,
    produto_id         VARCHAR(25)    NOT NULL,
    descricao_produto  VARCHAR(255)   NULL,
    ordem_compra       BIGINT         NOT NULL,
    qtde_pedida        DECIMAL(14,3)  NULL,
    filial_id          INT            NULL,
    data_entrega       DATE           NULL,
    qtde_entregue      DECIMAL(14,3)  NOT NULL DEFAULT 0,
    qtde_pendente      DECIMAL(14,3)  NOT NULL DEFAULT 0,
    preco_compra       DECIMAL(12,4)  NULL DEFAULT 0,
    fornecedor_id      INT            NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE entradas_mercadoria (
    data_entrada       DATE           NULL,
    nro_nfe            VARCHAR(255)   NOT NULL,
    item               INT            NOT NULL DEFAULT 0,
    produto_id         VARCHAR(25)    NOT NULL,
    descricao_produto  VARCHAR(255)   NULL,
    qtde_recebida      DECIMAL(14,3)  NULL,
    filial_id          INT            NULL,
    custo_unitario     DECIMAL(12,4)  NOT NULL DEFAULT 0,
    ordem_compra       BIGINT         NOT NULL,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX ix_venda_data_emissao    ON venda (data_emissao);
CREATE INDEX ix_venda_produto         ON venda (produto_id);
CREATE INDEX ix_pedido_ordem_compra   ON pedido_compra (ordem_compra, produto_id);
CREATE INDEX ix_pedido_data           ON pedido_compra (data_pedido);
CREATE INDEX ix_entrada_ordem_compra  ON entradas_mercadoria (ordem_compra, produto_id);

