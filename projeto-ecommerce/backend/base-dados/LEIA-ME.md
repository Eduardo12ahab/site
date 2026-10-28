# Base de dados EcommerceDB (SQL Server)

Scripts T-SQL do modelo final de 14 tabelas. Descricao completa das tabelas e regras em `../../documentacao/BASE-DADOS.md`.

## Pre-requisitos

- SQL Server (por exemplo `localhost\SQLEXPRESS`) e SQL Server Management Studio (SSMS).
- A base de dados `EcommerceDB` ja criada, com as 9 tabelas originais (pode estar vazia: o script 09 insere dados de teste).
- SQL Server 2016 SP1 ou superior (os scripts usam `CREATE OR ALTER`).

## Ordem de execucao

Abrir cada ficheiro no SSMS, ligar ao servidor e executar (F5) pela ordem:

| Ordem | Script | O que faz |
|---|---|---|
| 0 | `scripts/00_login_aplicacao.sql` | Cria o utilizador SQL `ecommerce_app` para o backend Java (trocar antes a palavra-passe no script). So 1 vez. |
| 1 | `scripts/05_completar_modelo.sql` | Cria as 5 tabelas em falta (Fornecedor, Carrinho, ItemCarrinho, Devolucao, ItemDevolucao), `Cliente.Papel`, `Produto.FornecedorId` e as restricoes CHECK. |
| 2 | `scripts/06_gatilhos.sql` | Cria a funcao `fn_TotalEncomenda` e 8 gatilhos (stock, total, cupao, estados da encomenda, devolucoes). Pode ser repetido (CREATE OR ALTER). |
| 3 | `scripts/07_consultas.sql` | 31 consultas numeradas do relatorio (basicas, agregacoes, subconsultas, juncoes, UPDATE, 3 vistas e os 6 relatorios do backend). Os UPDATE estao em `BEGIN TRAN ... ROLLBACK`. |
| 4 | `scripts/08_testes_gatilhos.sql` | Demonstracao de cada gatilho (ANTES / acao / DEPOIS), cada teste em transacao com ROLLBACK: nao deixa dados. |
| 5 | `scripts/09_dados_de_teste.sql` | Dados dummy (12 produtos, 4 contas, encomendas em varios estados, cupoes, avaliacoes). Correr depois do 06. So insere se a base estiver vazia. |

Os scripts 06 a 08 dependem do 05. O 07 cria as vistas `vw_VendasProduto`, `vw_ClientesAtivos` e `vw_StockBaixo`.

## Verificacao

```sql
USE EcommerceDB;
SELECT COUNT(*) AS TotalTabelas FROM sys.tables;   -- esperado: 14

SELECT t.name AS Gatilho, OBJECT_NAME(t.parent_id) AS Tabela
FROM sys.triggers t
WHERE t.parent_class = 1
ORDER BY Tabela, Gatilho;                          -- esperado: 8 gatilhos
```

Gatilhos esperados: `trg_LinhaEncomenda_DescontaStock`, `trg_LinhaEncomenda_Total`, `trg_Encomenda_Total`, `trg_Encomenda_UsaCupao`, `trg_Encomenda_Estado`, `trg_Encomenda_CancelaRepoeStock`, `trg_Devolucao_SoEntregue`, `trg_Devolucao_ReporStock`.

## Codigos de erro dos gatilhos

| Codigo | Significado |
|---|---|
| 547 | Stock insuficiente (CHECK `CK_Produto_Stock`) |
| 50002 | Cupao expirado ou sem utilizacoes |
| 50003 | Transicao de estado da encomenda nao permitida |
| 50004 | Encomenda sem linhas nao pode ser paga |
| 50005 | Devolucao so de encomendas entregues |

## Notas

- Os scripts 00 a 08 sao so ASCII; o 09 tem acentos e esta gravado em UTF-8 com BOM (o SSMS le-o bem).
- Nos testes (08) os gatilhos que fazem `THROW` revertem a transacao inteira (ROLLBACK), por isso o teste termina nesse ponto.
