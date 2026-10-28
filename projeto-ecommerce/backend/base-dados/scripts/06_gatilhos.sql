/* =====================================================================
   06_gatilhos.sql
   Funcao e gatilhos (triggers) da logica de negocio do EcommerceDB.

   - Idempotente: usa CREATE OR ALTER (SQL Server 2016 SP1 ou superior).
   - Requer o script 05_completar_modelo.sql ja executado.
   - Ficheiro so com ASCII, para nao haver problemas de codificacao no SSMS.
   - Todos os gatilhos sao set-based (funcionam com varias linhas) e, quando
     fazem THROW, fazem antes ROLLBACK TRANSACTION.
   - Codigos de erro: 50002 cupao, 50003 transicao de estado,
     50004 encomenda sem linhas, 50005 devolucao nao entregue.
     (Stock insuficiente = erro 547 da CHECK CK_Produto_Stock.)
   ===================================================================== */

USE EcommerceDB;
GO

/* ---------------------------------------------------------------------
   1. Funcao: total da encomenda = linhas - desconto do cupao + portes
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_TotalEncomenda (@EncomendaId INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @subtotal DECIMAL(12,2) =
        (SELECT ISNULL(SUM(Quantidade * PrecoUnitario), 0)
         FROM dbo.LinhaEncomenda
         WHERE EncomendaId = @EncomendaId);

    DECLARE @pct DECIMAL(5,2) =
        (SELECT ISNULL(c.PercentagemDesconto, 0)
         FROM dbo.Encomenda e
         LEFT JOIN dbo.Cupao c ON c.CupaoId = e.CupaoId
         WHERE e.EncomendaId = @EncomendaId);

    DECLARE @portes DECIMAL(10,2) =
        (SELECT CustoPortes FROM dbo.Encomenda WHERE EncomendaId = @EncomendaId);

    RETURN ROUND(@subtotal * (1 - ISNULL(@pct, 0) / 100.0), 2) + ISNULL(@portes, 0);
END;
GO

/* ---------------------------------------------------------------------
   2. Descontar stock ao inserir linhas de encomenda
   Se o stock ficar negativo, a CHECK CK_Produto_Stock faz falhar o UPDATE
   (erro 547) e a transacao da compra e revertida.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_LinhaEncomenda_DescontaStock
ON dbo.LinhaEncomenda
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.Stock = p.Stock - x.Qtd
    FROM dbo.Produto p
    JOIN (SELECT ProdutoId, SUM(Quantidade) AS Qtd
          FROM inserted
          GROUP BY ProdutoId) x ON x.ProdutoId = p.ProdutoId;
END;
GO

/* ---------------------------------------------------------------------
   3. Recalcular o Total da encomenda
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_LinhaEncomenda_Total
ON dbo.LinhaEncomenda
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE e
    SET e.Total = dbo.fn_TotalEncomenda(e.EncomendaId)
    FROM dbo.Encomenda e
    WHERE e.EncomendaId IN (SELECT EncomendaId FROM inserted
                            UNION
                            SELECT EncomendaId FROM deleted);
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Encomenda_Total
ON dbo.Encomenda
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- So recalcula se mudou o cupao ou os portes (evita recursao)
    IF NOT (UPDATE(CupaoId) OR UPDATE(CustoPortes)) RETURN;

    UPDATE e
    SET e.Total = dbo.fn_TotalEncomenda(e.EncomendaId)
    FROM dbo.Encomenda e
    JOIN inserted i ON i.EncomendaId = e.EncomendaId;
END;
GO

/* ---------------------------------------------------------------------
   4. Validar o cupao e contar a utilizacao (ao inserir a encomenda)
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Encomenda_UsaCupao
ON dbo.Encomenda
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM (SELECT CupaoId, COUNT(*) AS Usos
                     FROM inserted
                     WHERE CupaoId IS NOT NULL
                     GROUP BY CupaoId) i
               JOIN dbo.Cupao c ON c.CupaoId = i.CupaoId
               WHERE c.DataValidade < CAST(GETDATE() AS DATE)
                  OR c.UsosAtuais + i.Usos > c.UsosMaximos)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, 'Cupao expirado ou sem utilizacoes disponiveis.', 1;
    END;

    UPDATE c
    SET c.UsosAtuais = c.UsosAtuais + i.Usos
    FROM dbo.Cupao c
    JOIN (SELECT CupaoId, COUNT(*) AS Usos
          FROM inserted
          WHERE CupaoId IS NOT NULL
          GROUP BY CupaoId) i ON i.CupaoId = c.CupaoId;
END;
GO

/* ---------------------------------------------------------------------
   5. Validar transicoes de estado da encomenda
   Pendente -> Paga | Cancelada ; Paga -> Enviada | Cancelada ;
   Enviada -> Entregue. Entregue e Cancelada sao estados finais.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Encomenda_Estado
ON dbo.Encomenda
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Estado) RETURN;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.EncomendaId = i.EncomendaId
        WHERE i.Estado <> d.Estado
          AND NOT (   (d.Estado = 'Pendente' AND i.Estado IN ('Paga', 'Cancelada'))
                   OR (d.Estado = 'Paga'     AND i.Estado IN ('Enviada', 'Cancelada'))
                   OR (d.Estado = 'Enviada'  AND i.Estado = 'Entregue'))
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, 'Transicao de estado da encomenda nao permitida.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.EncomendaId = i.EncomendaId
        WHERE i.Estado = 'Paga' AND d.Estado <> 'Paga'
          AND NOT EXISTS (SELECT 1 FROM dbo.LinhaEncomenda l
                          WHERE l.EncomendaId = i.EncomendaId)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, 'Uma encomenda sem linhas nao pode ser paga.', 1;
    END;

    -- Este UPDATE nao altera Estado, por isso os gatilhos de Estado
    -- regressam logo (IF NOT UPDATE(Estado) RETURN) mesmo que haja recursao.
    UPDATE e
    SET e.DataAtualizacao = GETDATE()
    FROM dbo.Encomenda e
    JOIN inserted i ON i.EncomendaId = e.EncomendaId
    JOIN deleted  d ON d.EncomendaId = i.EncomendaId
    WHERE i.Estado <> d.Estado;
END;
GO

/* ---------------------------------------------------------------------
   6. Cancelar encomenda repoe o stock das linhas
   So atua nas transicoes validas (Pendente/Paga -> Cancelada).
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Encomenda_CancelaRepoeStock
ON dbo.Encomenda
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Estado) RETURN;

    UPDATE p
    SET p.Stock = p.Stock + x.Qtd
    FROM dbo.Produto p
    JOIN (SELECT l.ProdutoId, SUM(l.Quantidade) AS Qtd
          FROM dbo.LinhaEncomenda l
          JOIN inserted i ON i.EncomendaId = l.EncomendaId
          JOIN deleted  d ON d.EncomendaId = i.EncomendaId
          WHERE i.Estado = 'Cancelada'
            AND d.Estado IN ('Pendente', 'Paga')
          GROUP BY l.ProdutoId) x ON x.ProdutoId = p.ProdutoId;
END;
GO

/* ---------------------------------------------------------------------
   7. So se pode devolver uma encomenda entregue
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Devolucao_SoEntregue
ON dbo.Devolucao
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.Encomenda e ON e.EncomendaId = i.EncomendaId
               WHERE e.Estado <> 'Entregue')
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50005, 'So e possivel devolver encomendas entregues.', 1;
    END;
END;
GO

/* ---------------------------------------------------------------------
   8. Devolucao concluida repoe o stock dos itens devolvidos
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Devolucao_ReporStock
ON dbo.Devolucao
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Estado) RETURN;

    UPDATE p
    SET p.Stock = p.Stock + x.Qtd
    FROM dbo.Produto p
    JOIN (SELECT idv.ProdutoId, SUM(idv.Quantidade) AS Qtd
          FROM dbo.ItemDevolucao idv
          JOIN inserted i ON i.DevolucaoId = idv.DevolucaoId
          JOIN deleted  d ON d.DevolucaoId = i.DevolucaoId
          WHERE i.Estado = 'Concluida'
            AND d.Estado <> 'Concluida'
          GROUP BY idv.ProdutoId) x ON x.ProdutoId = p.ProdutoId;
END;
GO

/* ---------------------------------------------------------------------
   9. Verificacao: deve listar 8 gatilhos
   --------------------------------------------------------------------- */
SELECT t.name AS Gatilho, OBJECT_NAME(t.parent_id) AS Tabela, t.is_disabled AS Desativado
FROM sys.triggers t
WHERE t.parent_class = 1
ORDER BY OBJECT_NAME(t.parent_id), t.name;
GO
