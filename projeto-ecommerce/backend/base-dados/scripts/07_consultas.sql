/* =====================================================================
   07_consultas.sql
   Consultas SQL do relatorio (EcommerceDB, modelo de 14 tabelas).

   - Cada consulta esta numerada e tem um comentario a explicar o que faz.
   - Os UPDATE estao dentro de BEGIN TRAN ... ROLLBACK (nao alteram dados).
     Para aplicar de facto, troca ROLLBACK por COMMIT.
   - As vistas (parte 6) usam CREATE OR ALTER e sao a base dos relatorios
     expostos pelo backend.
   - Correr por blocos no SSMS (seleciona e F5) ou o ficheiro todo.
   ===================================================================== */

USE EcommerceDB;
GO

/* =====================================================================
   PARTE 1 - CONSULTAS BASICAS
   ===================================================================== */

-- 1. Produtos ativos com categoria e fornecedor (JOIN + LEFT JOIN)
SELECT p.ProdutoId, p.SKU, p.Nome, c.Nome AS Categoria, f.Nome AS Fornecedor,
       p.Preco, p.Stock
FROM dbo.Produto p
JOIN dbo.Categoria c       ON c.CategoriaId  = p.CategoriaId
LEFT JOIN dbo.Fornecedor f ON f.FornecedorId = p.FornecedorId
WHERE p.Ativo = 1
ORDER BY p.Nome;
GO

-- 2. Clientes com email terminado em @gmail.com (LIKE)
SELECT ClienteId, Nome, Email
FROM dbo.Cliente
WHERE Email LIKE '%@gmail.com';
GO

-- 3. Produtos cujo nome contem a palavra 'cabo' (LIKE com pesquisa parcial)
SELECT ProdutoId, SKU, Nome, Preco
FROM dbo.Produto
WHERE Nome LIKE '%cabo%'
ORDER BY Nome;
GO

-- 4. Categorias com o nome da categoria-pai (auto-juncao)
SELECT c.CategoriaId, c.Nome AS Categoria, pai.Nome AS CategoriaPai
FROM dbo.Categoria c
LEFT JOIN dbo.Categoria pai ON pai.CategoriaId = c.CategoriaPaiId
ORDER BY pai.Nome, c.Nome;
GO

-- 5. Moradas de cada cliente (JOIN Cliente - Morada)
SELECT c.Nome AS Cliente, m.Tipo, m.Rua, m.CodigoPostal, m.Cidade, m.Pais
FROM dbo.Cliente c
JOIN dbo.Morada m ON m.ClienteId = c.ClienteId
ORDER BY c.Nome, m.Tipo;
GO

/* =====================================================================
   PARTE 2 - AGREGACOES
   ===================================================================== */

-- 6. Numero de encomendas por cliente (COUNT, LEFT JOIN, GROUP BY)
SELECT c.ClienteId, c.Nome, COUNT(e.EncomendaId) AS TotalEncomendas
FROM dbo.Cliente c
LEFT JOIN dbo.Encomenda e ON e.ClienteId = c.ClienteId
GROUP BY c.ClienteId, c.Nome
ORDER BY TotalEncomendas DESC, c.Nome;
GO

-- 7. Total gasto por cliente, sem canceladas, so quem gastou mais de 100 (SUM, HAVING)
SELECT c.ClienteId, c.Nome, SUM(e.Total) AS TotalGasto
FROM dbo.Cliente c
JOIN dbo.Encomenda e ON e.ClienteId = c.ClienteId
WHERE e.Estado <> 'Cancelada'
GROUP BY c.ClienteId, c.Nome
HAVING SUM(e.Total) > 100
ORDER BY TotalGasto DESC;
GO

-- 8. Media de avaliacoes por produto (AVG, HAVING)
SELECT p.ProdutoId, p.Nome,
       AVG(CAST(a.Nota AS DECIMAL(4,2))) AS MediaNotas,
       COUNT(a.AvaliacaoId)              AS NumAvaliacoes
FROM dbo.Produto p
JOIN dbo.Avaliacao a ON a.ProdutoId = p.ProdutoId
GROUP BY p.ProdutoId, p.Nome
HAVING COUNT(a.AvaliacaoId) >= 1
ORDER BY MediaNotas DESC, p.Nome;
GO

-- 9. Numero de encomendas e valor total por estado (GROUP BY)
SELECT Estado, COUNT(*) AS NumEncomendas, SUM(Total) AS ValorTotal
FROM dbo.Encomenda
GROUP BY Estado
ORDER BY NumEncomendas DESC;
GO

-- 10. Numero de produtos e stock total por categoria (COUNT, SUM)
SELECT c.Nome AS Categoria, COUNT(p.ProdutoId) AS NumProdutos,
       ISNULL(SUM(p.Stock), 0) AS StockTotal
FROM dbo.Categoria c
LEFT JOIN dbo.Produto p ON p.CategoriaId = c.CategoriaId
GROUP BY c.Nome
ORDER BY StockTotal DESC;
GO

/* =====================================================================
   PARTE 3 - SUBCONSULTAS
   ===================================================================== */

-- 11. Clientes que nunca fizeram encomendas (NOT EXISTS)
SELECT c.ClienteId, c.Nome, c.Email
FROM dbo.Cliente c
WHERE NOT EXISTS (SELECT 1 FROM dbo.Encomenda e WHERE e.ClienteId = c.ClienteId);
GO

-- 12. Produtos mais caros do que a media (subconsulta > AVG)
SELECT ProdutoId, Nome, Preco
FROM dbo.Produto
WHERE Preco > (SELECT AVG(Preco) FROM dbo.Produto)
ORDER BY Preco DESC;
GO

-- 13. Produtos que nunca foram vendidos (NOT EXISTS)
SELECT p.ProdutoId, p.SKU, p.Nome, p.Stock
FROM dbo.Produto p
WHERE NOT EXISTS (SELECT 1 FROM dbo.LinhaEncomenda l WHERE l.ProdutoId = p.ProdutoId);
GO

-- 14. Encomendas com pagamento ainda pendente
SELECT e.EncomendaId, c.Nome AS Cliente, e.Total, pg.Estado AS EstadoPagamento
FROM dbo.Encomenda e
JOIN dbo.Cliente   c  ON c.ClienteId    = e.ClienteId
JOIN dbo.Pagamento pg ON pg.EncomendaId = e.EncomendaId
WHERE pg.Estado = 'Pendente';
GO

-- 15. Clientes cujo total gasto e superior a media dos totais das encomendas
SELECT c.ClienteId, c.Nome, SUM(e.Total) AS TotalGasto
FROM dbo.Cliente c
JOIN dbo.Encomenda e ON e.ClienteId = c.ClienteId
WHERE e.Estado <> 'Cancelada'
GROUP BY c.ClienteId, c.Nome
HAVING SUM(e.Total) > (SELECT AVG(Total) FROM dbo.Encomenda WHERE Estado <> 'Cancelada')
ORDER BY TotalGasto DESC;
GO

/* =====================================================================
   PARTE 4 - JUNCOES MULTIPLAS
   ===================================================================== */

-- 16. Detalhe completo de uma encomenda (cliente, linhas, morada, pagamento, cupao)
--     Usa a encomenda mais recente; troca por um EncomendaId concreto se quiseres.
DECLARE @EncDetalhe INT = (SELECT TOP 1 EncomendaId FROM dbo.Encomenda ORDER BY EncomendaId DESC);

SELECT e.EncomendaId, c.Nome AS Cliente, p.Nome AS Produto,
       l.Quantidade, l.PrecoUnitario,
       (l.Quantidade * l.PrecoUnitario) AS Subtotal,
       cu.Codigo AS Cupao, cu.PercentagemDesconto,
       e.CustoPortes, e.Total AS TotalEncomenda, e.Estado,
       m.Rua, m.CodigoPostal, m.Cidade, m.Pais,
       pg.Metodo AS MetodoPagamento, pg.Estado AS EstadoPagamento
FROM dbo.Encomenda e
JOIN dbo.Cliente c              ON c.ClienteId  = e.ClienteId
JOIN dbo.Morada m               ON m.MoradaId   = e.MoradaEnvioId
JOIN dbo.LinhaEncomenda l       ON l.EncomendaId = e.EncomendaId
JOIN dbo.Produto p              ON p.ProdutoId  = l.ProdutoId
LEFT JOIN dbo.Cupao cu          ON cu.CupaoId   = e.CupaoId
LEFT JOIN dbo.Pagamento pg      ON pg.EncomendaId = e.EncomendaId
WHERE e.EncomendaId = @EncDetalhe;
GO

-- 17. Devolucoes com cliente, encomenda e produtos devolvidos
SELECT d.DevolucaoId, d.Estado AS EstadoDevolucao, d.DataDevolucao,
       c.Nome AS Cliente, e.EncomendaId, p.Nome AS Produto, idv.Quantidade
FROM dbo.Devolucao d
JOIN dbo.Encomenda e        ON e.EncomendaId  = d.EncomendaId
JOIN dbo.Cliente c          ON c.ClienteId    = e.ClienteId
JOIN dbo.ItemDevolucao idv  ON idv.DevolucaoId = d.DevolucaoId
JOIN dbo.Produto p          ON p.ProdutoId    = idv.ProdutoId
ORDER BY d.DevolucaoId;
GO

-- 18. Conteudo dos carrinhos (Cliente - Carrinho - ItemCarrinho - Produto)
SELECT c.Nome AS Cliente, p.Nome AS Produto, ic.Quantidade,
       (ic.Quantidade * p.Preco) AS Subtotal
FROM dbo.Carrinho ca
JOIN dbo.Cliente c        ON c.ClienteId   = ca.ClienteId
JOIN dbo.ItemCarrinho ic  ON ic.CarrinhoId = ca.CarrinhoId
JOIN dbo.Produto p        ON p.ProdutoId   = ic.ProdutoId
ORDER BY c.Nome, p.Nome;
GO

/* =====================================================================
   PARTE 5 - ATUALIZACOES (dentro de transacao com ROLLBACK)
   ===================================================================== */

-- 19. Cancelar encomendas pendentes com mais de 30 dias
--     (o gatilho trg_Encomenda_CancelaRepoeStock repoe o stock das linhas)
BEGIN TRAN;
    UPDATE dbo.Encomenda
    SET Estado = 'Cancelada'
    WHERE Estado = 'Pendente'
      AND DataEncomenda < DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    SELECT @@ROWCOUNT AS EncomendasCanceladas;
ROLLBACK TRAN;   -- trocar por COMMIT TRAN para aplicar
GO

-- 20. Ajustar o preco (+10%) dos produtos de uma categoria
BEGIN TRAN;
    DECLARE @Cat INT = (SELECT TOP 1 CategoriaId FROM dbo.Categoria ORDER BY CategoriaId);
    UPDATE dbo.Produto
    SET Preco = ROUND(Preco * 1.10, 2)
    WHERE CategoriaId = @Cat;
    SELECT @@ROWCOUNT AS ProdutosAtualizados;
ROLLBACK TRAN;   -- trocar por COMMIT TRAN para aplicar
GO

-- 21. Desconto de 5% nos produtos com stock elevado (> 100)
BEGIN TRAN;
    UPDATE dbo.Produto
    SET Preco = ROUND(Preco * 0.95, 2)
    WHERE Stock > 100;
    SELECT @@ROWCOUNT AS ProdutosAtualizados;
ROLLBACK TRAN;   -- trocar por COMMIT TRAN para aplicar
GO

-- 22. Desativar produtos sem stock
BEGIN TRAN;
    UPDATE dbo.Produto
    SET Ativo = 0
    WHERE Stock = 0 AND Ativo = 1;
    SELECT @@ROWCOUNT AS ProdutosDesativados;
ROLLBACK TRAN;   -- trocar por COMMIT TRAN para aplicar
GO

/* =====================================================================
   PARTE 6 - VISTAS
   (CREATE VIEW tem de ser o primeiro comando do batch, por isso o GO)
   ===================================================================== */

-- 23. Vista: vendas por produto (sem encomendas canceladas)
CREATE OR ALTER VIEW dbo.vw_VendasProduto AS
SELECT p.ProdutoId, p.Nome,
       SUM(l.Quantidade)                   AS TotalVendido,
       SUM(l.Quantidade * l.PrecoUnitario) AS Receita
FROM dbo.Produto p
JOIN dbo.LinhaEncomenda l ON l.ProdutoId   = p.ProdutoId
JOIN dbo.Encomenda      e ON e.EncomendaId = l.EncomendaId
WHERE e.Estado <> 'Cancelada'
GROUP BY p.ProdutoId, p.Nome;
GO

-- 24. Vista: clientes ativos (com pelo menos uma encomenda)
CREATE OR ALTER VIEW dbo.vw_ClientesAtivos AS
SELECT c.ClienteId, c.Nome, c.Email,
       COUNT(e.EncomendaId) AS NumEncomendas,
       SUM(e.Total)         AS TotalGasto
FROM dbo.Cliente c
JOIN dbo.Encomenda e ON e.ClienteId = c.ClienteId
GROUP BY c.ClienteId, c.Nome, c.Email;
GO

-- 25. Vista: produtos com stock baixo (menos de 10 unidades)
CREATE OR ALTER VIEW dbo.vw_StockBaixo AS
SELECT ProdutoId, SKU, Nome, Stock
FROM dbo.Produto
WHERE Stock < 10;
GO

/* =====================================================================
   PARTE 7 - OS 6 RELATORIOS EXPOSTOS PELO BACKEND
   ===================================================================== */

-- 26. Relatorio vendas-produto (usa a vista vw_VendasProduto)
SELECT ProdutoId, Nome, TotalVendido, Receita
FROM dbo.vw_VendasProduto
ORDER BY Receita DESC;
GO

-- 27. Relatorio clientes-ativos (usa a vista vw_ClientesAtivos)
SELECT ClienteId, Nome, Email, NumEncomendas, TotalGasto
FROM dbo.vw_ClientesAtivos
ORDER BY TotalGasto DESC;
GO

-- 28. Relatorio stock-baixo (usa a vista vw_StockBaixo)
SELECT ProdutoId, SKU, Nome, Stock
FROM dbo.vw_StockBaixo
ORDER BY Stock, Nome;
GO

-- 29. Relatorio top-produtos: 5 produtos mais vendidos por quantidade
SELECT TOP 5 p.ProdutoId, p.Nome, SUM(l.Quantidade) AS TotalVendido
FROM dbo.Produto p
JOIN dbo.LinhaEncomenda l ON l.ProdutoId   = p.ProdutoId
JOIN dbo.Encomenda e      ON e.EncomendaId = l.EncomendaId
WHERE e.Estado <> 'Cancelada'
GROUP BY p.ProdutoId, p.Nome
ORDER BY TotalVendido DESC, p.Nome;
GO

-- 30. Relatorio media-avaliacoes: media e numero de avaliacoes por produto
SELECT p.ProdutoId, p.Nome,
       AVG(CAST(a.Nota AS DECIMAL(4,2))) AS MediaNotas,
       COUNT(a.AvaliacaoId)              AS NumAvaliacoes
FROM dbo.Produto p
JOIN dbo.Avaliacao a ON a.ProdutoId = p.ProdutoId
GROUP BY p.ProdutoId, p.Nome
ORDER BY MediaNotas DESC, p.Nome;
GO

-- 31. Relatorio encomendas-pendentes: encomendas por pagar, mais antigas primeiro
SELECT e.EncomendaId, c.Nome AS Cliente, e.DataEncomenda, e.Total
FROM dbo.Encomenda e
JOIN dbo.Cliente c ON c.ClienteId = e.ClienteId
WHERE e.Estado = 'Pendente'
ORDER BY e.DataEncomenda;
GO
