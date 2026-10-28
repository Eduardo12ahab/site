# Base de dados — EcommerceDB (SQL Server)

Servidor de desenvolvimento: `localhost\SQLEXPRESS`, base de dados `EcommerceDB`.
Modelo final: **14 tabelas** (sem IA, sem Inventario, ListaDesejos, Entrega, Promocao).
Scripts em `backend/base-dados/scripts/`:

| Script | Função |
|---|---|
| `05_completar_modelo.sql` | Cria as 5 tabelas em falta (Fornecedor, Carrinho, ItemCarrinho, Devolucao, ItemDevolucao), `Cliente.Papel`, `Produto.FornecedorId` e as CHECK. |
| `06_gatilhos.sql` | Cria funções e gatilhos (lógica de negócio na BD). |
| `07_consultas.sql` | Consultas SQL do relatório (SELECT/UPDATE/vistas), todas com os nomes reais. |
| `08_testes_gatilhos.sql` | Demonstração dos gatilhos (cada teste dentro de `BEGIN TRAN ... ROLLBACK`). |

## Tabelas

Tipos: dinheiro em `DECIMAL(10,2)` (`Preco`, `CustoPortes`, `Total`, `PrecoUnitario`, `Valor`) e percentagens em `DECIMAL(5,2)` (`Cupao.PercentagemDesconto`), confirmado na BD real. No Java usar `BigDecimal`.

| Tabela | Colunas (PK sublinhada com `*`) |
|---|---|
| **Cliente** | `ClienteId*` INT identity, `Nome` varchar(150), `Email` varchar(150) UNIQUE, `PasswordHash` varchar(255), `NIF` varchar(20) null, `DataNascimento` date null, `Telefone` varchar(20) null, `DataRegisto` datetime default GETDATE(), `Papel` varchar(20) default 'Cliente' CHECK IN ('Cliente','Admin') |
| **Morada** | `MoradaId*`, `ClienteId` FK→Cliente, `Tipo` varchar(20) default 'Envio', `Rua` varchar(200), `CodigoPostal` varchar(10), `Cidade` varchar(100), `Pais` varchar(100) default 'Portugal' |
| **Categoria** | `CategoriaId*`, `Nome` varchar(100), `CategoriaPaiId` FK→Categoria null |
| **Fornecedor** | `FornecedorId*`, `Nome` varchar(150), `Email` varchar(150) null, `Telefone` varchar(20) null |
| **Produto** | `ProdutoId*`, `SKU` varchar(30) UNIQUE, `Nome` varchar(150), `Descricao` varchar(max) null, `Preco` decimal CHECK >0, `Stock` int default 0 CHECK >=0, `ImagemUrl` varchar(500) null, `Ativo` bit default 1, `CategoriaId` FK→Categoria, `FornecedorId` FK→Fornecedor null |
| **Cupao** | `CupaoId*`, `Codigo` varchar(30) UNIQUE, `PercentagemDesconto` decimal CHECK 0..100, `DataValidade` date, `UsosMaximos` int, `UsosAtuais` int default 0 |
| **Encomenda** | `EncomendaId*`, `ClienteId` FK→Cliente, `CupaoId` FK→Cupao null, `MoradaEnvioId` FK→Morada, `DataEncomenda` datetime default GETDATE(), `DataAtualizacao` datetime default GETDATE(), `Estado` varchar(20) default 'Pendente', `CustoPortes` decimal default 0, `Total` decimal default 0 |
| **LinhaEncomenda** | PK composta (`EncomendaId` FK→Encomenda, `ProdutoId` FK→Produto), `Quantidade` int CHECK >0, `PrecoUnitario` decimal |
| **Pagamento** | `PagamentoId*`, `EncomendaId` FK→Encomenda UNIQUE, `Metodo` varchar(30) CHECK IN ('MBWay','Cartao','Multibanco','Paypal'), `Valor` decimal, `DataPagamento` datetime default GETDATE(), `Estado` varchar(20) default 'Processado' |
| **Avaliacao** | `AvaliacaoId*`, `ClienteId` FK, `ProdutoId` FK, `Nota` tinyint CHECK 1..5, `Comentario` varchar(max) null, `DataAvaliacao` datetime default GETDATE(); UNIQUE (`ClienteId`,`ProdutoId`) |
| **Carrinho** | `CarrinhoId*`, `ClienteId` FK→Cliente UNIQUE (1 carrinho por cliente), `DataCriacao` datetime default GETDATE() |
| **ItemCarrinho** | PK composta (`CarrinhoId` FK→Carrinho ON DELETE CASCADE, `ProdutoId` FK→Produto), `Quantidade` int CHECK >0, `DataAdicao` datetime default GETDATE() |
| **Devolucao** | `DevolucaoId*`, `EncomendaId` FK→Encomenda, `DataDevolucao` datetime default GETDATE(), `Motivo` varchar(500) null, `Estado` varchar(20) default 'Pedida' |
| **ItemDevolucao** | PK composta (`DevolucaoId` FK→Devolucao ON DELETE CASCADE, `ProdutoId` FK→Produto), `Quantidade` int CHECK >0, `Motivo` varchar(500) null |

Diagrama de relações (1:N salvo indicação): Categoria→Produto, Categoria→Categoria (pai), Fornecedor→Produto, Cliente→Morada, Cliente→Encomenda, Cliente 1:1 Carrinho, Carrinho→ItemCarrinho, Cliente→Avaliacao, Produto→Avaliacao, Cupao→Encomenda, Morada→Encomenda (envio), Encomenda→LinhaEncomenda, Produto→LinhaEncomenda, Encomenda 1:1 Pagamento, Encomenda→Devolucao, Devolucao→ItemDevolucao, Produto→ItemDevolucao, Produto→ItemCarrinho.

## Estados

| Coluna | Valores (CHECK) | Regras |
|---|---|---|
| `Encomenda.Estado` | Pendente, Paga, Enviada, Entregue, Cancelada | Transições: Pendente→Paga, Pendente→Cancelada, Paga→Enviada, Paga→Cancelada (com reembolso), Enviada→Entregue. Entregue e Cancelada são finais. |
| `Pagamento.Estado` | Pendente, Processado, Falhado, Reembolsado | Criado `Pendente` ao finalizar a compra; `Processado` quando pago (encomenda passa a Paga); `Reembolsado` ao cancelar uma encomenda Paga. |
| `Devolucao.Estado` | Pedida, Aprovada, Recusada, Concluida | Só encomendas **Entregue**. A encomenda mantém-se Entregue. Stock só volta quando a devolução passa a Concluida. |

## O que a BD faz sozinha (gatilhos de `06_gatilhos.sql`) e o que NÃO deve ser feito no Java

| Gatilho / função | Efeito | Consequência para o backend |
|---|---|---|
| `trg_LinhaEncomenda_DescontaStock` | Ao inserir `LinhaEncomenda`, desconta `Produto.Stock` (falha por CHECK se não houver stock) | **Não** descontar stock no Java; apanhar o erro SQL (stock insuficiente) e responder 409. |
| `fn_TotalEncomenda`, `trg_LinhaEncomenda_Total`, `trg_Encomenda_Total` | `Encomenda.Total` = linhas − cupão + `CustoPortes` | **Não** calcular `Total` no Java; inserir a encomenda com `Total` 0 e ler depois. |
| `trg_Encomenda_UsaCupao` | Valida cupão (validade, utilizações) e incrementa `UsosAtuais` ao inserir a encomenda | Enviar `CupaoId` no INSERT; apanhar o erro (cupão inválido → 400). |
| `trg_Encomenda_Estado` | Valida transições de estado; encomenda sem linhas não pode ser Paga; atualiza `DataAtualizacao` | Apanhar o erro (transição inválida → 409). |
| `trg_Encomenda_CancelaRepoeStock` | Ao passar a Cancelada, repõe o stock das linhas | **Não** repor stock no Java. |
| `trg_Devolucao_SoEntregue` | Impede devolução de encomenda não entregue | Apanhar o erro (→ 409). |
| `trg_Devolucao_ReporStock` | Ao passar a Concluida, repõe o stock dos itens | **Não** repor stock no Java. |

O Java trata do que a BD não faz: criar `Encomenda` + `LinhaEncomenda` (com `PrecoUnitario` = preço atual do produto) + `Pagamento` (Pendente) **numa transação**, esvaziar o carrinho, e na confirmação de pagamento atualizar `Pagamento.Estado` e `Encomenda.Estado` (também numa transação).

Erros dos gatilhos usam `THROW` com números 50002–50005 (ver `06_gatilhos.sql`), o que permite ao Java distinguir cada caso por `SQLException.getErrorCode()`.
