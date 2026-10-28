# API REST do backend (Java / Spring Boot)

Base: `http://localhost:8080`. O frontend (Node, porta 3000) reencaminha tudo o que começa por `/api` para aqui, por isso o browser fala sempre com `http://localhost:3000/api/...` (mesma origem, o cookie de sessão passa).

Regras gerais:
- Respostas em JSON, UTF-8. Erros: `{ "message": "texto em português" }` com o código HTTP adequado (400 pedido inválido, 401 sem sessão, 403 sem permissão, 404 não existe, 409 conflito/regra de negócio, 500 erro interno).
- Sessão: `HttpSession` (cookie `JSESSIONID`). Após login, a sessão guarda `{ id, nome, email, isAdmin }`.
- Rotas `/api/admin/**` exigem `Papel = 'Admin'` (403 caso contrário). Rotas marcadas **(login)** exigem sessão (401 caso contrário).
- Acesso a dados: `JdbcTemplate` com SQL escrito à mão (sem JPA). A lógica de negócio que está nos gatilhos NÃO se repete no Java (ver `BASE-DADOS.md`).
- Os nomes dos campos JSON seguem o que o frontend já usa (`nome`, `preco`, `imagem`, `estoque`, `produtoId`, `quantidade`, `isAdmin`…).

## Saúde

| Método | Rota | Resposta |
|---|---|---|
| GET | `/api/health` | `{ "status": "OK", "bd": true, "tabelas": 14, "timestamp": "..." }` (faz uma query à BD; `bd:false` se falhar) |

## Produtos e categorias (público)

Objeto **Produto**:
```json
{ "id": 1, "sku": "TEL-001", "nome": "…", "descricao": "…", "preco": 349.9,
  "estoque": 25, "imagem": "https://…", "ativo": true,
  "categoriaId": 2, "categoria": "Telemóveis", "fornecedorId": null, "fornecedor": null,
  "avaliacao": 4.5, "numAvaliacoes": 12 }
```
`avaliacao` = média de `Avaliacao.Nota` (0 se não houver), `numAvaliacoes` = contagem.

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/produtos?categoria=<nome>&q=<texto>&ordenar=preco-asc\|preco-desc\|nome\|avaliacao` | Lista produtos **ativos** (filtros opcionais; `categoria` compara por nome, sem distinguir maiúsculas; `q` procura em nome/descrição) |
| GET | `/api/produtos/{id}` | Um produto (404 se não existir ou inativo) |
| GET | `/api/categorias` | Lista de nomes de categorias (array de strings) |
| GET | `/api/produtos/{id}/avaliacoes` | `[{ "cliente": "Nome", "nota": 5, "comentario": "…", "data": "…" }]` |
| POST | `/api/produtos/{id}/avaliacoes` **(login)** | Body `{ "nota": 1-5, "comentario": "…" }`. 409 se o cliente já avaliou este produto |

## Autenticação

| Método | Rota | Body | Resposta |
|---|---|---|---|
| POST | `/api/cadastro` | `{ nome, email, senha, telefone?, nif? }` | 201 `{ "message": "…", "userId": 7 }`. 400 se faltar algo (senha ≥ 6), 409 se o email já existe. Guarda `PasswordHash` com BCrypt. Cria também o `Carrinho` do cliente. |
| POST | `/api/login` | `{ email, senha }` | `{ "user": { id, nome, email, isAdmin }, "message": "…" }`. 401 se inválido. |
| POST | `/api/logout` | — | `{ "message": "Logout realizado" }` (invalida a sessão) |
| GET | `/api/usuario/atual` | — | O objeto `user`, ou 401 |

Verificação da palavra-passe: se `PasswordHash` começar por `$2` usa BCrypt; caso contrário (dados dummy antigos) compara por igualdade e, se coincidir, **atualiza o hash para BCrypt** na mesma operação.

## Carrinho (login)

O item usa o `ProdutoId` como identificador (a chave de `ItemCarrinho` é composta).

Objeto **Item**:
```json
{ "id": 3, "produtoId": 3, "quantidade": 2,
  "produto": { "id": 3, "nome": "…", "preco": 49.9, "imagem": "…", "estoque": 40 } }
```

| Método | Rota | Body | Resposta |
|---|---|---|---|
| GET | `/api/carrinho` | — | `[Item]` |
| POST | `/api/carrinho` | `{ produtoId, quantidade }` | Soma à quantidade existente (ou cria). Devolve `[Item]` atualizado. 404 produto inexistente, 400 quantidade < 1 |
| PUT | `/api/carrinho/{produtoId}` | `{ quantidade }` | Devolve o `Item`. 404 se não está no carrinho |
| DELETE | `/api/carrinho/{produtoId}` | — | `{ "message": "Item removido do carrinho" }` |

## Moradas (login)

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/moradas` | `[{ id, tipo, rua, codigoPostal, cidade, pais }]` do cliente |
| POST | `/api/moradas` | Body `{ rua, codigoPostal, cidade, pais? }` → 201 com a morada criada |

## Encomendas (login)

Objeto **Encomenda**:
```json
{ "id": 12, "data": "2026-02-01T10:30:00", "estado": "Pendente",
  "portes": 4.99, "total": 54.89, "cupao": "NATAL10",
  "morada": { "rua": "…", "codigoPostal": "…", "cidade": "…", "pais": "…" },
  "pagamento": { "metodo": "MBWay", "estado": "Pendente", "valor": 54.89 },
  "linhas": [ { "produtoId": 3, "nome": "…", "quantidade": 2, "precoUnitario": 49.9 } ] }
```

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/encomendas` | Body `{ moradaId, metodoPagamento, cupao? }`. **Numa transação:** cria `Encomenda` (Pendente, portes fixos 4.99, grátis acima de 50 € de subtotal), `LinhaEncomenda` por cada item do carrinho (`PrecoUnitario` = preço atual), `Pagamento` (Pendente, `Valor` = total lido depois dos gatilhos) e esvazia o carrinho. 201 com a **Encomenda**. 400 carrinho vazio ou morada/cupão inválidos, 409 stock insuficiente. |
| GET | `/api/encomendas` | `[Encomenda]` do cliente, mais recentes primeiro |
| GET | `/api/encomendas/{id}` | Uma encomenda do cliente (404 se de outro cliente) |
| POST | `/api/encomendas/{id}/pagar` | Numa transação: `Pagamento.Estado='Processado'`, `Encomenda.Estado='Paga'`. 409 se já não está Pendente |
| POST | `/api/encomendas/{id}/cancelar` | Numa transação: se Paga, `Pagamento.Estado='Reembolsado'`; `Encomenda.Estado='Cancelada'` (o stock volta por gatilho). 409 se já Enviada/Entregue/Cancelada |

## Devoluções (login)

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/devolucoes` | Body `{ encomendaId, motivo, itens: [{ produtoId, quantidade }] }`. Cria `Devolucao` (Pedida) + `ItemDevolucao`. 409 se a encomenda não está Entregue (gatilho). 400 se a quantidade excede a comprada |
| GET | `/api/devolucoes` | `[{ id, encomendaId, data, motivo, estado, itens:[{produtoId,nome,quantidade}] }]` do cliente |

## Administração (`Papel = 'Admin'`)

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/admin/produtos` | Todos os produtos (incluindo inativos), formato **Produto** |
| POST | `/api/admin/produtos` | Body `{ sku, nome, descricao, preco, estoque, imagem, categoriaId, fornecedorId? }` → 201 |
| PUT | `/api/admin/produtos/{id}` | Mesmos campos (e `ativo`) → produto atualizado |
| DELETE | `/api/admin/produtos/{id}` | "Eliminação" lógica: `Ativo = 0` |
| GET | `/api/admin/encomendas?estado=` | `[Encomenda + cliente:{id,nome,email}]` de todos os clientes |
| PUT | `/api/admin/encomendas/{id}/estado` | Body `{ estado }` (Enviada, Entregue, …). Erro de transição inválida (gatilho) → 409 |
| GET | `/api/admin/devolucoes` | Todas as devoluções |
| PUT | `/api/admin/devolucoes/{id}/estado` | Body `{ estado }` (Aprovada, Recusada, Concluida) |
| GET | `/api/admin/clientes` | `[{ id, nome, email, papel, dataRegisto, numEncomendas, totalGasto }]` |
| GET | `/api/admin/relatorios/{nome}` | Corre uma das consultas de `07_consultas.sql` e devolve um array de objetos. `nome` ∈ `vendas-produto`, `clientes-ativos`, `stock-baixo`, `top-produtos`, `media-avaliacoes`, `encomendas-pendentes` |
| GET | `/api/admin/resumo` | `{ totalProdutos, totalClientes, totalEncomendas, receita, encomendasPendentes }` |
