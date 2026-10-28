/* =====================================================================
   09_dados_de_teste.sql
   Dados DUMMY para testar e demonstrar o projeto.
   CORRER DEPOIS dos scripts 05 e 06 (os gatilhos tem de existir: sao eles
   que descontam o stock e calculam os totais das encomendas).

   - So insere se a base estiver vazia (Produto e Cliente sem linhas).
   - Contas de teste (palavras-passe de TESTE, guardadas com BCrypt):
       admin@tyvora.com    / admin123      (Admin)
       maria@exemplo.pt    / cliente123
       joao@exemplo.pt     / cliente123
       ana@exemplo.pt      / cliente123
   - Cria encomendas em varios estados (Pendente, Paga, Enviada, Entregue,
     Cancelada), uma devolucao pedida, avaliacoes e cupoes (valido, expirado
     e esgotado), para mostrar os gatilhos a funcionar.
   ===================================================================== */

USE EcommerceDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM dbo.Produto) OR EXISTS (SELECT 1 FROM dbo.Cliente)
BEGIN
    PRINT 'A base de dados ja tem dados (Produto ou Cliente). Nada foi inserido.';
    RETURN;
END;

BEGIN TRAN;

/* ---------- Categorias (com subcategorias) ---------- */
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Eletrónica', NULL);
DECLARE @catEletro INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Roupa', NULL);
DECLARE @catRoupa INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Calçado', NULL);
DECLARE @catCalcado INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Acessórios', NULL);
DECLARE @catAcess INT = SCOPE_IDENTITY();

INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Telemóveis', @catEletro);
DECLARE @catTel INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Computadores', @catEletro);
DECLARE @catPc INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Áudio', @catEletro);
DECLARE @catAudio INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'T-shirts', @catRoupa);
DECLARE @catTshirt INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Ténis', @catCalcado);
DECLARE @catTenis INT = SCOPE_IDENTITY();
INSERT INTO dbo.Categoria (Nome, CategoriaPaiId) VALUES (N'Relógios', @catAcess);
DECLARE @catRelogio INT = SCOPE_IDENTITY();

/* ---------- Fornecedores ---------- */
INSERT INTO dbo.Fornecedor (Nome, Email, Telefone) VALUES (N'TechPort Lda', N'vendas@techport.pt', N'210000001');
DECLARE @fTech INT = SCOPE_IDENTITY();
INSERT INTO dbo.Fornecedor (Nome, Email, Telefone) VALUES (N'ModaLisboa SA', N'encomendas@modalisboa.pt', N'210000002');
DECLARE @fModa INT = SCOPE_IDENTITY();
INSERT INTO dbo.Fornecedor (Nome, Email, Telefone) VALUES (N'DesportoMais Lda', N'geral@desportomais.pt', N'210000003');
DECLARE @fDesp INT = SCOPE_IDENTITY();

/* ---------- Produtos (12) ---------- */
INSERT INTO dbo.Produto (SKU, Nome, Descricao, Preco, Stock, ImagemUrl, Ativo, CategoriaId, FornecedorId) VALUES
 (N'TEL-001', N'Smartphone Premium Pro', N'Ecrã AMOLED 6,8", 256 GB, câmara tripla de 108 MP e bateria de 5000 mAh.', 349.90, 25, N'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400&h=400&fit=crop', 1, @catTel, @fTech),
 (N'TEL-002', N'Smartphone Essencial', N'Ecrã 6,1", 128 GB, ideal para o dia a dia.', 179.90, 40, NULL, 1, @catTel, @fTech),
 (N'PC-001',  N'Portátil Gamer RTX', N'RTX 4060, 16 GB RAM, SSD 1 TB, ecrã 144 Hz.', 799.90, 12, N'https://images.unsplash.com/photo-1603302576837-37561b2e2302?w=400&h=400&fit=crop', 1, @catPc, @fTech),
 (N'PC-002',  N'Portátil Escritório 15"', N'Intel i5, 8 GB RAM, SSD 512 GB.', 449.90, 18, NULL, 1, @catPc, @fTech),
 (N'AUD-001', N'Auscultadores Bluetooth Pro', N'Cancelamento de ruído ativo e 30 h de bateria.', 49.90, 60, N'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&h=400&fit=crop', 1, @catAudio, @fTech),
 (N'AUD-002', N'Coluna Portátil Mini', N'Coluna Bluetooth resistente à água, 12 h de autonomia.', 29.90, 80, NULL, 1, @catAudio, @fTech),
 (N'ROU-001', N'T-shirt Casual Premium', N'100% algodão penteado, corte moderno.', 19.90, 100, N'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400&h=400&fit=crop', 1, @catTshirt, @fModa),
 (N'ROU-002', N'T-shirt Desportiva', N'Tecido respirável, secagem rápida.', 24.90, 70, NULL, 1, @catTshirt, @fDesp),
 (N'CAL-001', N'Ténis Esportivos Pro', N'Amortecimento avançado, ideais para corrida.', 89.90, 35, N'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&h=400&fit=crop', 1, @catTenis, @fDesp),
 (N'CAL-002', N'Ténis Urbanos', N'Estilo casual, sola antiderrapante.', 59.90, 45, NULL, 1, @catTenis, @fModa),
 (N'REL-001', N'Smartwatch Fit', N'Monitor cardíaco, GPS e resistência à água.', 149.90, 20, N'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&h=400&fit=crop', 1, @catRelogio, @fTech),
 (N'REL-002', N'Relógio Clássico', N'Caixa em aço, bracelete em pele.', 79.90, 15, NULL, 1, @catRelogio, @fModa);

/* ---------- Clientes (1 admin + 3 clientes) e respetivos carrinhos ---------- */
-- Palavras-passe de teste com BCrypt: admin123 e cliente123
INSERT INTO dbo.Cliente (Nome, Email, PasswordHash, NIF, Telefone, Papel) VALUES
 (N'Administrador', N'admin@tyvora.com', N'$2b$10$KyssNUWYnYkgtSMa8N/3ke.FJ6WJK2ggdW3yqlFz1PDh0Pxiwf8ti', NULL, N'910000000', N'Admin'),
 (N'Maria Silva',   N'maria@exemplo.pt', N'$2b$10$eyqMVq0iH4Z8/QNcBuJj2uB8HFvme6GsZrv//dCYdhhx1Rhb09lK6', N'123456789', N'911111111', N'Cliente'),
 (N'João Santos',   N'joao@exemplo.pt',  N'$2b$10$eyqMVq0iH4Z8/QNcBuJj2uB8HFvme6GsZrv//dCYdhhx1Rhb09lK6', N'234567890', N'922222222', N'Cliente'),
 (N'Ana Costa',     N'ana@exemplo.pt',   N'$2b$10$eyqMVq0iH4Z8/QNcBuJj2uB8HFvme6GsZrv//dCYdhhx1Rhb09lK6', N'345678901', N'933333333', N'Cliente');

DECLARE @cMaria INT = (SELECT ClienteId FROM dbo.Cliente WHERE Email = N'maria@exemplo.pt');
DECLARE @cJoao  INT = (SELECT ClienteId FROM dbo.Cliente WHERE Email = N'joao@exemplo.pt');
DECLARE @cAna   INT = (SELECT ClienteId FROM dbo.Cliente WHERE Email = N'ana@exemplo.pt');

INSERT INTO dbo.Carrinho (ClienteId)
SELECT ClienteId FROM dbo.Cliente;

-- Um item ja no carrinho da Ana (para testar o checkout logo)
INSERT INTO dbo.ItemCarrinho (CarrinhoId, ProdutoId, Quantidade)
SELECT ca.CarrinhoId, p.ProdutoId, 2
FROM dbo.Carrinho ca, dbo.Produto p
WHERE ca.ClienteId = @cAna AND p.SKU = N'AUD-002';

/* ---------- Moradas ---------- */
INSERT INTO dbo.Morada (ClienteId, Tipo, Rua, CodigoPostal, Cidade, Pais) VALUES
 (@cMaria, N'Envio', N'Rua das Flores 25', N'1000-100', N'Lisboa', N'Portugal'),
 (@cJoao,  N'Envio', N'Avenida da Liberdade 100', N'4000-200', N'Porto', N'Portugal'),
 (@cAna,   N'Envio', N'Rua do Comércio 7', N'3000-300', N'Coimbra', N'Portugal');

DECLARE @mMaria INT = (SELECT MoradaId FROM dbo.Morada WHERE ClienteId = @cMaria);
DECLARE @mJoao  INT = (SELECT MoradaId FROM dbo.Morada WHERE ClienteId = @cJoao);
DECLARE @mAna   INT = (SELECT MoradaId FROM dbo.Morada WHERE ClienteId = @cAna);

/* ---------- Cupoes: valido, expirado e esgotado ---------- */
INSERT INTO dbo.Cupao (Codigo, PercentagemDesconto, DataValidade, UsosMaximos, UsosAtuais) VALUES
 (N'BEMVINDO10', 10, '2027-12-31', 100, 0),
 (N'EXPIRADO5',   5, '2025-01-01', 100, 0),
 (N'ESGOTADO20', 20, '2027-12-31',   1, 1);
DECLARE @cupBV INT = (SELECT CupaoId FROM dbo.Cupao WHERE Codigo = N'BEMVINDO10');

/* =====================================================================
   Encomendas. O gatilho desconta o stock ao inserir LinhaEncomenda e calcula
   o Total (linhas - cupao + portes). Os estados avancam com UPDATEs validos.
   ===================================================================== */
DECLARE @e INT;

-- 1) Maria: encomenda PENDENTE (pagamento por fazer)
INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CustoPortes) VALUES (@cMaria, @mMaria, 4.99);
SET @e = SCOPE_IDENTITY();
INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
SELECT @e, ProdutoId, 1, Preco FROM dbo.Produto WHERE SKU = N'AUD-001';
INSERT INTO dbo.Pagamento (EncomendaId, Metodo, Valor, Estado)
SELECT @e, N'MBWay', Total, N'Pendente' FROM dbo.Encomenda WHERE EncomendaId = @e;

-- 2) Maria: encomenda PAGA
INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CustoPortes) VALUES (@cMaria, @mMaria, 0);
SET @e = SCOPE_IDENTITY();
INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
SELECT @e, ProdutoId, 1, Preco FROM dbo.Produto WHERE SKU = N'PC-001';
INSERT INTO dbo.Pagamento (EncomendaId, Metodo, Valor, Estado)
SELECT @e, N'Cartao', Total, N'Pendente' FROM dbo.Encomenda WHERE EncomendaId = @e;
UPDATE dbo.Pagamento SET Estado = N'Processado' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Paga' WHERE EncomendaId = @e;

-- 3) Joao: encomenda ENVIADA
INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CustoPortes) VALUES (@cJoao, @mJoao, 4.99);
SET @e = SCOPE_IDENTITY();
INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
SELECT @e, ProdutoId, 2, Preco FROM dbo.Produto WHERE SKU = N'ROU-001';
INSERT INTO dbo.Pagamento (EncomendaId, Metodo, Valor, Estado)
SELECT @e, N'Multibanco', Total, N'Pendente' FROM dbo.Encomenda WHERE EncomendaId = @e;
UPDATE dbo.Pagamento SET Estado = N'Processado' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Paga' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Enviada' WHERE EncomendaId = @e;

-- 4) Joao: encomenda ENTREGUE (com cupao BEMVINDO10) + devolucao PEDIDA de 1 item
INSERT INTO dbo.Encomenda (ClienteId, CupaoId, MoradaEnvioId, CustoPortes) VALUES (@cJoao, @cupBV, @mJoao, 0);
SET @e = SCOPE_IDENTITY();
INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
SELECT @e, ProdutoId, 2, Preco FROM dbo.Produto WHERE SKU = N'CAL-001';
INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
SELECT @e, ProdutoId, 1, Preco FROM dbo.Produto WHERE SKU = N'REL-001';
INSERT INTO dbo.Pagamento (EncomendaId, Metodo, Valor, Estado)
SELECT @e, N'Cartao', Total, N'Pendente' FROM dbo.Encomenda WHERE EncomendaId = @e;
UPDATE dbo.Pagamento SET Estado = N'Processado' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Paga' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Enviada' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Entregue' WHERE EncomendaId = @e;

INSERT INTO dbo.Devolucao (EncomendaId, Motivo) VALUES (@e, N'O tamanho não serve');
INSERT INTO dbo.ItemDevolucao (DevolucaoId, ProdutoId, Quantidade, Motivo)
SELECT SCOPE_IDENTITY(), ProdutoId, 1, N'Tamanho errado' FROM dbo.Produto WHERE SKU = N'CAL-001';

-- 5) Ana: encomenda ENTREGUE
INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CustoPortes) VALUES (@cAna, @mAna, 4.99);
SET @e = SCOPE_IDENTITY();
INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
SELECT @e, ProdutoId, 1, Preco FROM dbo.Produto WHERE SKU = N'TEL-001';
INSERT INTO dbo.Pagamento (EncomendaId, Metodo, Valor, Estado)
SELECT @e, N'MBWay', Total, N'Pendente' FROM dbo.Encomenda WHERE EncomendaId = @e;
UPDATE dbo.Pagamento SET Estado = N'Processado' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Paga' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Enviada' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Entregue' WHERE EncomendaId = @e;

-- 6) Ana: encomenda CANCELADA (estava paga: pagamento reembolsado, o gatilho repoe o stock)
INSERT INTO dbo.Encomenda (ClienteId, MoradaEnvioId, CustoPortes) VALUES (@cAna, @mAna, 4.99);
SET @e = SCOPE_IDENTITY();
INSERT INTO dbo.LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
SELECT @e, ProdutoId, 3, Preco FROM dbo.Produto WHERE SKU = N'AUD-002';
INSERT INTO dbo.Pagamento (EncomendaId, Metodo, Valor, Estado)
SELECT @e, N'Cartao', Total, N'Pendente' FROM dbo.Encomenda WHERE EncomendaId = @e;
UPDATE dbo.Pagamento SET Estado = N'Processado' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Paga' WHERE EncomendaId = @e;
UPDATE dbo.Pagamento SET Estado = N'Reembolsado' WHERE EncomendaId = @e;
UPDATE dbo.Encomenda SET Estado = N'Cancelada' WHERE EncomendaId = @e;

/* ---------- Avaliacoes (1 por cliente e produto) ---------- */
INSERT INTO dbo.Avaliacao (ClienteId, ProdutoId, Nota, Comentario)
SELECT @cJoao, ProdutoId, 5, N'Muito confortáveis, recomendo!' FROM dbo.Produto WHERE SKU = N'CAL-001';
INSERT INTO dbo.Avaliacao (ClienteId, ProdutoId, Nota, Comentario)
SELECT @cJoao, ProdutoId, 4, N'Bom relógio pelo preço.' FROM dbo.Produto WHERE SKU = N'REL-001';
INSERT INTO dbo.Avaliacao (ClienteId, ProdutoId, Nota, Comentario)
SELECT @cAna, ProdutoId, 5, N'Excelente telemóvel, câmara fantástica.' FROM dbo.Produto WHERE SKU = N'TEL-001';
INSERT INTO dbo.Avaliacao (ClienteId, ProdutoId, Nota, Comentario)
SELECT @cMaria, ProdutoId, 4, N'Som muito bom e cancelamento de ruído eficaz.' FROM dbo.Produto WHERE SKU = N'AUD-001';
INSERT INTO dbo.Avaliacao (ClienteId, ProdutoId, Nota, Comentario)
SELECT @cAna, ProdutoId, 3, N'Cumpre, mas esperava melhor acabamento.' FROM dbo.Produto WHERE SKU = N'AUD-001';

COMMIT;

PRINT 'Dados de teste inseridos com sucesso.';
GO

/* ---------- Verificacao ---------- */
SELECT 'Categoria' AS Tabela, COUNT(*) AS Linhas FROM dbo.Categoria
UNION ALL SELECT 'Fornecedor', COUNT(*) FROM dbo.Fornecedor
UNION ALL SELECT 'Produto', COUNT(*) FROM dbo.Produto
UNION ALL SELECT 'Cliente', COUNT(*) FROM dbo.Cliente
UNION ALL SELECT 'Encomenda', COUNT(*) FROM dbo.Encomenda
UNION ALL SELECT 'LinhaEncomenda', COUNT(*) FROM dbo.LinhaEncomenda
UNION ALL SELECT 'Pagamento', COUNT(*) FROM dbo.Pagamento
UNION ALL SELECT 'Devolucao', COUNT(*) FROM dbo.Devolucao
UNION ALL SELECT 'Avaliacao', COUNT(*) FROM dbo.Avaliacao;

-- Estados das encomendas e totais calculados pelos gatilhos
SELECT EncomendaId, Estado, CustoPortes, Total FROM dbo.Encomenda ORDER BY EncomendaId;
GO

/* ---------- Para apagar tudo e repetir (descomenta, por esta ordem) ----------
DELETE FROM dbo.ItemDevolucao;  DELETE FROM dbo.Devolucao;
DELETE FROM dbo.Pagamento;      DELETE FROM dbo.LinhaEncomenda;
DELETE FROM dbo.Encomenda;      DELETE FROM dbo.ItemCarrinho;
DELETE FROM dbo.Carrinho;       DELETE FROM dbo.Avaliacao;
DELETE FROM dbo.Morada;         DELETE FROM dbo.Cliente;
DELETE FROM dbo.Cupao;          DELETE FROM dbo.Produto;
DELETE FROM dbo.Fornecedor;     DELETE FROM dbo.Categoria WHERE CategoriaPaiId IS NOT NULL;
DELETE FROM dbo.Categoria;
-- (o stock nao volta ao inicial: o script 09 recria os produtos com o stock original)
------------------------------------------------------------------------- */
