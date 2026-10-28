# Projeto Loja Online — como arrancar

Este é o **único ficheiro que precisas de abrir** para pôr o projeto a funcionar. Segue os passos por ordem.

## O que é
- **Base de dados:** SQL Server (`EcommerceDB`, 14 tabelas).
- **Backend:** Java (Spring Boot), porta **8080**. Faz as chamadas à base de dados.
- **Frontend:** Node/Express, porta **3000**. Mostra as páginas e passa os pedidos `/api` ao backend.

```
Browser  ->  frontend :3000  ->  backend :8080  ->  SQL Server
```

## Antes de começar (uma vez só)
Precisas de ter instalado: **JDK 25**, **Node.js**, **SQL Server + SSMS**, e no VS Code a extensão **Extension Pack for Java**.

No **SQL Server Configuration Manager**, para o backend Java conseguir ligar ao `SQLEXPRESS`:
1. **Protocolos do SQLEXPRESS -> TCP/IP: Ativado.**
2. Garante que o serviço **SQL Server Browser** está a correr (`Get-Service SQLBrowser`; se estiver parado: `Set-Service SQLBrowser -StartupType Automatic; Start-Service SQLBrowser`).
3. Reinicia o serviço **SQL Server (SQLEXPRESS)**.

**Porque é que o backend não usa a tua conta do Windows:** no SSMS entras com autenticação Windows (sem palavra-passe), mas o Java precisa de um utilizador SQL (nome + palavra-passe). O script `00_login_aplicacao.sql` (Passo 1) cria-o. O SQL Server tem de estar em **"modo misto"** (Autenticação do SQL Server e do Windows): SSMS -> botão direito no servidor -> Propriedades -> Segurança -> escolher esse modo -> reiniciar o serviço.

## Passo 1 — Base de dados (SSMS)
Liga-te a `localhost\SQLEXPRESS` (autenticação Windows, como já fazes), base `EcommerceDB`, e corre por esta ordem os ficheiros de `backend/base-dados/scripts/`:

1. `00_login_aplicacao.sql` — cria o utilizador SQL para o backend. **Antes de correr, troca `TROCA_ESTA_PASSWORD` por uma palavra-passe tua** (e lembra-te dela para o Passo 2).
2. `05_completar_modelo.sql` — cria as tabelas que faltam (devem ficar **14**)
3. `06_gatilhos.sql` — cria os gatilhos (a lógica de stock, totais e estados)
4. `09_dados_de_teste.sql` — **dados dummy** (12 produtos, 4 contas, encomendas em vários estados, cupões, avaliações). Só insere se a base estiver vazia.

Verifica:
```sql
SELECT COUNT(*) FROM sys.tables;     -- 14
SELECT name FROM sys.triggers;       -- 8 gatilhos
```
(Os scripts `07_consultas.sql` e `08_testes_gatilhos.sql` são para a demonstração e o relatório; podes correr mais tarde.)

## Passo 2 — Backend (VS Code)
1. Abre a pasta `backend/` no VS Code.
2. A ligação já está configurada por defeito: utilizador `ecommerce_app` e a palavra-passe do projeto (ver `application.properties`). Se mudaste a palavra-passe no script `00`, define a variável `DB_PASS` ou copia `application-local.properties.example` para `application-local.properties` e ativa o perfil `local`.
   - O URL por defeito usa o nome da instância (`instanceName=SQLEXPRESS`), por isso não depende de nenhuma porta. Exige o TCP/IP ativo e o **SQL Server Browser** a correr.
3. Abre `AplicacaoEcommerce.java` e carrega em **Run** por cima do `main`.
4. Testa no browser: **http://localhost:8080/api/health** — deve aparecer `"bd": true`.

Se aparecer "porta em uso", há outra execução a correr: pára-a (quadrado vermelho) antes de voltar a correr.

## Passo 3 — Frontend
Num terminal:
```bash
cd frontend
npm install
npm start
```
Abre **http://localhost:3000**.

## Passo 4 — Testar
1. Entra em `/login` com uma conta de teste (palavras-passe de teste do script 09): `maria@exemplo.pt` / `cliente123` (cliente) ou `admin@tyvora.com` / `admin123` (administrador). Também podes registar uma conta nova em `/cadastro`.
2. Adiciona produtos ao carrinho, vai a `/checkout`, escolhe uma morada e finaliza. Paga a encomenda.
3. Vê `/encomendas`. Para testar o admin, no SSMS torna a tua conta administradora:
   ```sql
   UPDATE Cliente SET Papel = 'Admin' WHERE Email = 'o_teu_email';
   ```
   (Não é preciso se usares o `admin@tyvora.com`.) Depois vai a `/admin` e `/admin/encomendas` para marcar a encomenda como Enviada e Entregue.

## Se algo falhar
- `/api/health` com `"bd": false` -> a ligação ao SQL Server falhou (utilizador, palavra-passe, TCP/IP ou nome da instância).
- Páginas a dar erro 502 -> o backend não está a correr (Passo 2).
- Erro ao correr o script 05 -> copia a mensagem; pode ser um dado antigo que viola uma regra nova.

## Para saber mais (opcional)
- `documentacao/Relatorio.html` — o relatório do trabalho (UML, gatilhos, consultas).
- `documentacao/API.md` — lista das rotas da API.
- `documentacao/BASE-DADOS.md` — as tabelas e o que cada gatilho faz.
