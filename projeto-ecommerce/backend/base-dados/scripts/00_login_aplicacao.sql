/* =====================================================================
   00_login_aplicacao.sql
   Cria um utilizador SQL (ecommerce_app) para o backend Java ligar a
   base de dados. Corre-se UMA vez no SSMS, com a tua autenticacao Windows.

   ANTES DE CORRER:
   1) Troca 'TROCA_ESTA_PASSWORD' por uma palavra-passe tua (nao a partilhes
      nem a ponhas no Git: vai depois para o application-local.properties).
   2) O SQL Server tem de aceitar login SQL ("modo misto"):
      SSMS -> botao direito no servidor -> Propriedades -> Seguranca ->
      "Autenticacao do SQL Server e do Windows" -> OK -> reiniciar o servico
      "SQL Server (SQLEXPRESS)" (SQL Server Configuration Manager).
   ===================================================================== */

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'ecommerce_app')
    CREATE LOGIN ecommerce_app WITH PASSWORD = N'basedados2026', CHECK_POLICY = OFF;
GO

USE EcommerceDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'ecommerce_app')
    CREATE USER ecommerce_app FOR LOGIN ecommerce_app;
GO

-- So precisa de ler e escrever dados (nao cria nem apaga tabelas)
ALTER ROLE db_datareader ADD MEMBER ecommerce_app;
ALTER ROLE db_datawriter ADD MEMBER ecommerce_app;
GO

-- Verificacao: deve devolver uma linha
SELECT name, type_desc FROM sys.database_principals WHERE name = N'ecommerce_app';
GO
