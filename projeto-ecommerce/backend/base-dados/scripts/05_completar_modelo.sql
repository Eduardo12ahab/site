/* =====================================================================
   05_completar_modelo.sql
   Completa a base de dados EcommerceDB (que ja tem 9 tabelas) com as
   5 tabelas em falta (modelo final de 14 tabelas), mais colunas novas e CHECK.

   - Pode ser corrido varias vezes (so cria o que ainda nao existe).
   - Nao apaga dados. Unica remocao: 2 UNIQUE duplicados (ver passo 4).
   - Ficheiro so com ASCII, para nao haver problemas de codificacao no SSMS.
   ===================================================================== */

USE EcommerceDB;
GO

/* ---------------------------------------------------------------------
   1. NOVAS TABELAS (por ordem de dependencias)
   --------------------------------------------------------------------- */

-- Fornecedor
IF OBJECT_ID(N'dbo.Fornecedor', N'U') IS NULL
CREATE TABLE dbo.Fornecedor (
    FornecedorId INT IDENTITY(1,1) CONSTRAINT PK_Fornecedor PRIMARY KEY,
    Nome         VARCHAR(150) NOT NULL,
    Email        VARCHAR(150) NULL,
    Telefone     VARCHAR(20)  NULL
);
GO

-- Carrinho (1 por cliente)
IF OBJECT_ID(N'dbo.Carrinho', N'U') IS NULL
CREATE TABLE dbo.Carrinho (
    CarrinhoId   INT IDENTITY(1,1) CONSTRAINT PK_Carrinho PRIMARY KEY,
    ClienteId    INT NOT NULL
        CONSTRAINT UQ_Carrinho_Cliente UNIQUE
        CONSTRAINT FK_Carrinho_Cliente FOREIGN KEY REFERENCES dbo.Cliente(ClienteId),
    DataCriacao  DATETIME NOT NULL CONSTRAINT DF_Carrinho_Data DEFAULT (GETDATE())
);
GO

-- ItemCarrinho (um produto aparece no maximo uma vez por carrinho)
IF OBJECT_ID(N'dbo.ItemCarrinho', N'U') IS NULL
CREATE TABLE dbo.ItemCarrinho (
    CarrinhoId  INT NOT NULL CONSTRAINT FK_ItemCarrinho_Carrinho FOREIGN KEY REFERENCES dbo.Carrinho(CarrinhoId) ON DELETE CASCADE,
    ProdutoId   INT NOT NULL CONSTRAINT FK_ItemCarrinho_Produto  FOREIGN KEY REFERENCES dbo.Produto(ProdutoId),
    Quantidade  INT NOT NULL CONSTRAINT CK_ItemCarrinho_Qtd CHECK (Quantidade > 0),
    DataAdicao  DATETIME NOT NULL CONSTRAINT DF_ItemCarrinho_Data DEFAULT (GETDATE()),
    CONSTRAINT PK_ItemCarrinho PRIMARY KEY (CarrinhoId, ProdutoId)
);
GO

-- Devolucao
IF OBJECT_ID(N'dbo.Devolucao', N'U') IS NULL
CREATE TABLE dbo.Devolucao (
    DevolucaoId    INT IDENTITY(1,1) CONSTRAINT PK_Devolucao PRIMARY KEY,
    EncomendaId    INT NOT NULL CONSTRAINT FK_Devolucao_Encomenda FOREIGN KEY REFERENCES dbo.Encomenda(EncomendaId),
    DataDevolucao  DATETIME NOT NULL CONSTRAINT DF_Devolucao_Data DEFAULT (GETDATE()),
    Motivo         VARCHAR(500) NULL,
    Estado         VARCHAR(20) NOT NULL CONSTRAINT DF_Devolucao_Estado DEFAULT ('Pedida')
        CONSTRAINT CK_Devolucao_Estado CHECK (Estado IN ('Pedida','Aprovada','Recusada','Concluida'))
);
GO

-- ItemDevolucao
IF OBJECT_ID(N'dbo.ItemDevolucao', N'U') IS NULL
CREATE TABLE dbo.ItemDevolucao (
    DevolucaoId  INT NOT NULL CONSTRAINT FK_ItemDevolucao_Devolucao FOREIGN KEY REFERENCES dbo.Devolucao(DevolucaoId) ON DELETE CASCADE,
    ProdutoId    INT NOT NULL CONSTRAINT FK_ItemDevolucao_Produto   FOREIGN KEY REFERENCES dbo.Produto(ProdutoId),
    Quantidade   INT NOT NULL CONSTRAINT CK_ItemDevolucao_Qtd CHECK (Quantidade > 0),
    Motivo       VARCHAR(500) NULL,
    CONSTRAINT PK_ItemDevolucao PRIMARY KEY (DevolucaoId, ProdutoId)
);
GO

/* ---------------------------------------------------------------------
   2. COLUNAS NOVAS EM TABELAS EXISTENTES
   --------------------------------------------------------------------- */

-- Cliente.Papel: distingue clientes de administradores
IF COL_LENGTH(N'dbo.Cliente', N'Papel') IS NULL
    ALTER TABLE dbo.Cliente ADD Papel VARCHAR(20) NOT NULL
        CONSTRAINT DF_Cliente_Papel DEFAULT ('Cliente');
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Cliente_Papel')
    ALTER TABLE dbo.Cliente ADD CONSTRAINT CK_Cliente_Papel CHECK (Papel IN ('Cliente','Admin'));
GO

-- Produto.FornecedorId (opcional, porque ja existem produtos sem fornecedor)
IF COL_LENGTH(N'dbo.Produto', N'FornecedorId') IS NULL
    ALTER TABLE dbo.Produto ADD FornecedorId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Produto_Fornecedor')
    ALTER TABLE dbo.Produto ADD CONSTRAINT FK_Produto_Fornecedor
        FOREIGN KEY (FornecedorId) REFERENCES dbo.Fornecedor(FornecedorId);
GO



/* ---------------------------------------------------------------------
   3. CHECK EM TABELAS EXISTENTES
   Se algum falhar, e porque os dados dummy tem valores fora da regra:
   corrige os dados e volta a correr o script.
   --------------------------------------------------------------------- */

-- Remove CHECK antigas (nome automatico) sobre Estado em Encomenda e Pagamento:
-- as das tabelas originais nao aceitavam todos os estados do modelo (ex.: 'Pendente').
-- As CK_Encomenda_Estado e CK_Pagamento_Estado abaixo passam a ser as unicas.
DECLARE @sqlAntigas NVARCHAR(MAX) = N'';
SELECT @sqlAntigas += N'ALTER TABLE dbo.' + QUOTENAME(OBJECT_NAME(cc.parent_object_id))
                    + N' DROP CONSTRAINT ' + QUOTENAME(cc.name) + N';' + CHAR(10)
FROM sys.check_constraints cc
WHERE cc.parent_object_id IN (OBJECT_ID(N'dbo.Encomenda'), OBJECT_ID(N'dbo.Pagamento'))
  AND cc.definition LIKE N'%Estado%'
  AND cc.name NOT IN (N'CK_Encomenda_Estado', N'CK_Pagamento_Estado');
IF LEN(@sqlAntigas) > 0
BEGIN
    PRINT @sqlAntigas;
    EXEC sp_executesql @sqlAntigas;
END;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Avaliacao_Nota')
    ALTER TABLE dbo.Avaliacao ADD CONSTRAINT CK_Avaliacao_Nota CHECK (Nota BETWEEN 1 AND 5);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Produto_Preco')
    ALTER TABLE dbo.Produto ADD CONSTRAINT CK_Produto_Preco CHECK (Preco > 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Produto_Stock')
    ALTER TABLE dbo.Produto ADD CONSTRAINT CK_Produto_Stock CHECK (Stock >= 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_LinhaEncomenda_Qtd')
    ALTER TABLE dbo.LinhaEncomenda ADD CONSTRAINT CK_LinhaEncomenda_Qtd CHECK (Quantidade > 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Cupao_Desconto')
    ALTER TABLE dbo.Cupao ADD CONSTRAINT CK_Cupao_Desconto CHECK (PercentagemDesconto BETWEEN 0 AND 100);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Encomenda_Estado')
    ALTER TABLE dbo.Encomenda ADD CONSTRAINT CK_Encomenda_Estado
        CHECK (Estado IN ('Pendente','Paga','Enviada','Entregue','Cancelada'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Pagamento_Estado')
    ALTER TABLE dbo.Pagamento ADD CONSTRAINT CK_Pagamento_Estado
        CHECK (Estado IN ('Pendente','Processado','Falhado','Reembolsado'));
GO

/* ---------------------------------------------------------------------
   4. LIMPEZA: UNIQUE duplicados (ja existe UQ_Cliente_Email e UQ_Cupao_Codigo)
   --------------------------------------------------------------------- */

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ__Cliente__A9D10534CFB4FF77')
    ALTER TABLE dbo.Cliente DROP CONSTRAINT UQ__Cliente__A9D10534CFB4FF77;
GO
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ__Cupao__06370DAC6EFEE62F')
    ALTER TABLE dbo.Cupao DROP CONSTRAINT UQ__Cupao__06370DAC6EFEE62F;
GO

/* ---------------------------------------------------------------------
   5. VERIFICACAO: deve listar 14 tabelas
   --------------------------------------------------------------------- */

SELECT COUNT(*) AS TotalTabelas FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo');
SELECT name AS Tabela FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') ORDER BY name;
GO

/* Para tornar um cliente administrador (troca o email):
   UPDATE dbo.Cliente SET Papel = 'Admin' WHERE Email = 'o_teu_email@exemplo.pt';
*/
