/* =====================================================================
   08_testes_gatilhos.sql
   Demonstracao executavel de cada gatilho (para a defesa do projeto).

   - Cada teste corre num batch proprio, dentro de BEGIN TRAN ... ROLLBACK:
     NAO deixa dados na base de dados.
   - Mostra o estado ANTES, executa a acao, mostra o estado DEPOIS.
   - Os testes que devem falhar usam TRY/CATCH e mostram o erro esperado.
     Quando o gatilho faz ROLLBACK, a transacao do teste termina logo
     (o IF @@TRANCOUNT > 0 ROLLBACK final e so por seguranca).
   - Usa dados existentes (primeiro cliente, morada, categoria). Se faltar
     algum, cria-o dentro da propria transacao de teste. O produto, o cupao
     e as encomendas de teste sao sempre criados dentro da transacao.
   - Requer 05_completar_modelo.sql e 06_gatilhos.sql executados.
   - Ver os resultados no separador Messages e Results do SSMS.
   - Os valores de teste usam numeros inteiros (preco 100, desconto 10,
     portes 5), porque as colunas DECIMAL originais podem ter escala 0.
   ===================================================================== */

USE EcommerceDB;
GO

/* ---------------------------------------------------------------------
   TESTE 1 - Descontar stock ao inserir uma linha de encomenda
   Esperado: stock 10 -> 7 (venda de 3 unidades)
   --------------------------------------------------------------------- */
PRINT '=== TESTE 1: desconto de stock ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();

    PRINT 'ANTES (stock do produto):';
    SELECT ProdutoId, Nome, Stock FROM dbo.Produto WHERE ProdutoId = @ProdId;

    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 3, 100);

    PRINT 'DEPOIS (esperado: Stock = 7):';
    SELECT ProdutoId, Nome, Stock FROM dbo.Produto WHERE ProdutoId = @ProdId;
END TRY
BEGIN CATCH
    PRINT 'ERRO INESPERADO: ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 2 - Stock insuficiente
   Esperado: erro 547 (CHECK CK_Produto_Stock) e nada fica gravado
   --------------------------------------------------------------------- */
PRINT '=== TESTE 2: stock insuficiente (deve falhar) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();

    PRINT 'ANTES (stock do produto, esperado 10):';
    SELECT ProdutoId, Nome, Stock FROM dbo.Produto WHERE ProdutoId = @ProdId;

    PRINT 'Acao: vender 50 unidades (so ha 10)...';
    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 50, 100);

    PRINT 'ERRO: a venda devia ter falhado!';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
    IF XACT_STATE() = 1
    BEGIN
        PRINT 'DEPOIS (o stock nao mudou):';
        SELECT SKU, Stock FROM dbo.Produto WHERE SKU = 'TST-GATILHO';
    END;
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 3 - Total sem cupao e sem portes
   Esperado: 2 x 100 = 200
   --------------------------------------------------------------------- */
PRINT '=== TESTE 3: total sem cupao nem portes ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();

    PRINT 'ANTES (encomenda sem linhas, Total = 0):';
    SELECT EncomendaId, CupaoId, CustoPortes, Total FROM dbo.Encomenda WHERE EncomendaId = @EncId;

    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 2, 100);

    PRINT 'DEPOIS (esperado: Total = 200):';
    SELECT EncomendaId, CupaoId, CustoPortes, Total FROM dbo.Encomenda WHERE EncomendaId = @EncId;
END TRY
BEGIN CATCH
    PRINT 'ERRO INESPERADO: ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 4 - Total com cupao (10%) e portes (5), e uso do cupao
   Esperado: 200 - 10% + 5 = 185; UsosAtuais do cupao sobe 0 -> 1;
             ao mudar os portes para 10 o Total passa a 190
   --------------------------------------------------------------------- */
PRINT '=== TESTE 4: total com cupao e portes ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Cupao (Codigo, PercentagemDesconto, DataValidade, UsosMaximos, UsosAtuais)
        VALUES ('TST-CUPAO', 10, DATEADD(DAY, 30, CAST(GETDATE() AS DATE)), 5, 0);
    DECLARE @CupaoId INT = SCOPE_IDENTITY();

    PRINT 'ANTES (cupao):';
    SELECT CupaoId, Codigo, PercentagemDesconto, UsosMaximos, UsosAtuais FROM dbo.Cupao WHERE CupaoId = @CupaoId;

    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CupaoId, CustoPortes) VALUES (@ClienteId, @MoradaId, @CupaoId, 5);
    DECLARE @EncId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 2, 100);

    PRINT 'DEPOIS (esperado: Total = 185 e UsosAtuais = 1):';
    SELECT e.EncomendaId, e.CustoPortes, e.Total, c.UsosAtuais
    FROM dbo.Encomenda e JOIN dbo.Cupao c ON c.CupaoId = e.CupaoId
    WHERE e.EncomendaId = @EncId;

    UPDATE dbo.Encomenda SET CustoPortes = 10 WHERE EncomendaId = @EncId;

    PRINT 'DEPOIS de mudar os portes para 10 (esperado: Total = 190):';
    SELECT EncomendaId, CustoPortes, Total FROM dbo.Encomenda WHERE EncomendaId = @EncId;
END TRY
BEGIN CATCH
    PRINT 'ERRO INESPERADO: ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 5 - Cupao expirado
   Esperado: erro 50002
   --------------------------------------------------------------------- */
PRINT '=== TESTE 5: cupao expirado (deve falhar com 50002) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Cupao (Codigo, PercentagemDesconto, DataValidade, UsosMaximos, UsosAtuais)
        VALUES ('TST-EXPIRADO', 10, DATEADD(DAY, -1, CAST(GETDATE() AS DATE)), 5, 0);
    DECLARE @CupaoId INT = SCOPE_IDENTITY();

    PRINT 'Acao: criar encomenda com cupao que expirou ontem...';
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CupaoId) VALUES (@ClienteId, @MoradaId, @CupaoId);

    PRINT 'ERRO: a encomenda devia ter sido recusada!';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 6 - Cupao esgotado (UsosAtuais = UsosMaximos)
   Esperado: erro 50002
   --------------------------------------------------------------------- */
PRINT '=== TESTE 6: cupao esgotado (deve falhar com 50002) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Cupao (Codigo, PercentagemDesconto, DataValidade, UsosMaximos, UsosAtuais)
        VALUES ('TST-ESGOTADO', 10, DATEADD(DAY, 30, CAST(GETDATE() AS DATE)), 1, 1);
    DECLARE @CupaoId INT = SCOPE_IDENTITY();

    PRINT 'Acao: criar encomenda com cupao ja usado no maximo (1 de 1)...';
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CupaoId) VALUES (@ClienteId, @MoradaId, @CupaoId);

    PRINT 'ERRO: a encomenda devia ter sido recusada!';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 7 - Transicoes de estado validas
   Esperado: Pendente -> Paga -> Enviada -> Entregue sem erros, e
             DataAtualizacao acompanha cada mudanca
   --------------------------------------------------------------------- */
PRINT '=== TESTE 7: transicoes de estado validas ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 1, 100);

    PRINT 'ANTES:';
    SELECT EncomendaId, Estado, DataAtualizacao FROM dbo.Encomenda WHERE EncomendaId = @EncId;

    UPDATE dbo.Encomenda SET Estado = 'Paga' WHERE EncomendaId = @EncId;
    PRINT 'Pendente -> Paga:';
    SELECT EncomendaId, Estado, DataAtualizacao FROM dbo.Encomenda WHERE EncomendaId = @EncId;

    UPDATE dbo.Encomenda SET Estado = 'Enviada' WHERE EncomendaId = @EncId;
    PRINT 'Paga -> Enviada:';
    SELECT EncomendaId, Estado, DataAtualizacao FROM dbo.Encomenda WHERE EncomendaId = @EncId;

    UPDATE dbo.Encomenda SET Estado = 'Entregue' WHERE EncomendaId = @EncId;
    PRINT 'DEPOIS - Enviada -> Entregue (esperado: Estado = Entregue):';
    SELECT EncomendaId, Estado, DataAtualizacao FROM dbo.Encomenda WHERE EncomendaId = @EncId;
END TRY
BEGIN CATCH
    PRINT 'ERRO INESPERADO: ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 8 - Transicao de estado invalida (Pendente -> Entregue)
   Esperado: erro 50003
   --------------------------------------------------------------------- */
PRINT '=== TESTE 8: transicao invalida Pendente -> Entregue (deve falhar com 50003) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 1, 100);

    PRINT 'ANTES:';
    SELECT EncomendaId, Estado FROM dbo.Encomenda WHERE EncomendaId = @EncId;

    PRINT 'Acao: Pendente -> Entregue (salta Paga e Enviada)...';
    UPDATE dbo.Encomenda SET Estado = 'Entregue' WHERE EncomendaId = @EncId;

    PRINT 'ERRO: a transicao devia ter sido recusada!';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 8b - Transicao invalida a partir de um estado final
   (Cancelada -> Paga). Esperado: erro 50003
   --------------------------------------------------------------------- */
PRINT '=== TESTE 8b: transicao invalida Cancelada -> Paga (deve falhar com 50003) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 1, 100);
    UPDATE dbo.Encomenda SET Estado = 'Cancelada' WHERE EncomendaId = @EncId;

    PRINT 'ANTES (encomenda cancelada):';
    SELECT EncomendaId, Estado FROM dbo.Encomenda WHERE EncomendaId = @EncId;

    PRINT 'Acao: Cancelada -> Paga...';
    UPDATE dbo.Encomenda SET Estado = 'Paga' WHERE EncomendaId = @EncId;

    PRINT 'ERRO: a transicao devia ter sido recusada!';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 9 - Encomenda sem linhas nao pode passar a Paga
   Esperado: erro 50004
   --------------------------------------------------------------------- */
PRINT '=== TESTE 9: encomenda sem linhas -> Paga (deve falhar com 50004) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();

    PRINT 'ANTES (encomenda sem linhas):';
    SELECT EncomendaId, Estado,
           (SELECT COUNT(*) FROM dbo.LinhaEncomenda WHERE EncomendaId = @EncId) AS NumLinhas
    FROM dbo.Encomenda WHERE EncomendaId = @EncId;

    PRINT 'Acao: Pendente -> Paga sem linhas...';
    UPDATE dbo.Encomenda SET Estado = 'Paga' WHERE EncomendaId = @EncId;

    PRINT 'ERRO: a transicao devia ter sido recusada!';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 10 - Cancelar a encomenda repoe o stock
   Esperado: stock 10 -> 7 (venda de 3) -> 10 (cancelamento)
   --------------------------------------------------------------------- */
PRINT '=== TESTE 10: cancelamento repoe stock ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 3, 100);

    PRINT 'ANTES (apos a venda; esperado: Stock = 7):';
    SELECT p.ProdutoId, p.Stock, e.Estado
    FROM dbo.Produto p, dbo.Encomenda e
    WHERE p.ProdutoId = @ProdId AND e.EncomendaId = @EncId;

    UPDATE dbo.Encomenda SET Estado = 'Cancelada' WHERE EncomendaId = @EncId;

    PRINT 'DEPOIS (esperado: Stock = 10, Estado = Cancelada):';
    SELECT p.ProdutoId, p.Stock, e.Estado
    FROM dbo.Produto p, dbo.Encomenda e
    WHERE p.ProdutoId = @ProdId AND e.EncomendaId = @EncId;
END TRY
BEGIN CATCH
    PRINT 'ERRO INESPERADO: ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 11 - Devolucao de encomenda nao entregue
   Esperado: erro 50005
   --------------------------------------------------------------------- */
PRINT '=== TESTE 11: devolucao de encomenda nao entregue (deve falhar com 50005) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();

    PRINT 'ANTES (encomenda Pendente, sem devolucoes):';
    SELECT e.EncomendaId, e.Estado,
           (SELECT COUNT(*) FROM dbo.Devolucao d WHERE d.EncomendaId = e.EncomendaId) AS NumDevolucoes
    FROM dbo.Encomenda e WHERE e.EncomendaId = @EncId;

    PRINT 'Acao: pedir devolucao de uma encomenda Pendente...';
    INSERT INTO dbo.Devolucao (EncomendaId, Motivo) VALUES (@EncId, 'Teste de gatilho');

    PRINT 'ERRO: a devolucao devia ter sido recusada!';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   TESTE 12 - Devolucao concluida repoe o stock
   Esperado: stock 10 -> 7 (venda de 3) -> 7 (devolucao Aprovada)
             -> 9 (devolucao Concluida com 2 unidades)
   --------------------------------------------------------------------- */
PRINT '=== TESTE 12: devolucao concluida repoe stock ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @ClienteId INT = (SELECT TOP 1 ClienteId FROM dbo.Cliente ORDER BY ClienteId);
    IF @ClienteId IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nome, Email, PasswordHash) VALUES ('Cliente Teste', 'teste.gatilhos@exemplo.pt', 'x');
        SET @ClienteId = SCOPE_IDENTITY();
    END;
    DECLARE @MoradaId INT = (SELECT TOP 1 MoradaId FROM dbo.Morada WHERE ClienteId = @ClienteId ORDER BY MoradaId);
    IF @MoradaId IS NULL
    BEGIN
        INSERT INTO dbo.Morada (ClienteId, Rua, CodigoPostal, Cidade) VALUES (@ClienteId, 'Rua de Teste 1', '1000-001', 'Lisboa');
        SET @MoradaId = SCOPE_IDENTITY();
    END;
    DECLARE @CatId INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    IF @CatId IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nome) VALUES ('Categoria Teste');
        SET @CatId = SCOPE_IDENTITY();
    END;
    INSERT INTO dbo.Produto (SKU, Nome, Preco, Stock, CategoriaId) VALUES ('TST-GATILHO', 'Produto de Teste', 100, 10, @CatId);
    DECLARE @ProdId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId) VALUES (@ClienteId, @MoradaId);
    DECLARE @EncId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario) VALUES (@EncId, @ProdId, 3, 100);
    UPDATE dbo.Encomenda SET Estado = 'Paga'     WHERE EncomendaId = @EncId;
    UPDATE dbo.Encomenda SET Estado = 'Enviada'  WHERE EncomendaId = @EncId;
    UPDATE dbo.Encomenda SET Estado = 'Entregue' WHERE EncomendaId = @EncId;

    INSERT INTO dbo.Devolucao (EncomendaId, Motivo) VALUES (@EncId, 'Teste de gatilho');
    DECLARE @DevId INT = SCOPE_IDENTITY();
    INSERT INTO dbo.ItemDevolucao (DevolucaoId, ProdutoId, Quantidade) VALUES (@DevId, @ProdId, 2);

    PRINT 'ANTES (devolucao Pedida; esperado: Stock = 7):';
    SELECT d.DevolucaoId, d.Estado, p.Stock
    FROM dbo.Devolucao d, dbo.Produto p
    WHERE d.DevolucaoId = @DevId AND p.ProdutoId = @ProdId;

    UPDATE dbo.Devolucao SET Estado = 'Aprovada' WHERE DevolucaoId = @DevId;
    PRINT 'Aprovada (o stock ainda nao muda; esperado: Stock = 7):';
    SELECT d.DevolucaoId, d.Estado, p.Stock
    FROM dbo.Devolucao d, dbo.Produto p
    WHERE d.DevolucaoId = @DevId AND p.ProdutoId = @ProdId;

    UPDATE dbo.Devolucao SET Estado = 'Concluida' WHERE DevolucaoId = @DevId;
    PRINT 'DEPOIS - Concluida (esperado: Stock = 9):';
    SELECT d.DevolucaoId, d.Estado, p.Stock
    FROM dbo.Devolucao d, dbo.Produto p
    WHERE d.DevolucaoId = @DevId AND p.ProdutoId = @ProdId;
END TRY
BEGIN CATCH
    PRINT 'ERRO INESPERADO: ' + ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO

PRINT '=== Fim dos testes: nenhuma alteracao foi gravada (tudo em ROLLBACK) ===';
GO
