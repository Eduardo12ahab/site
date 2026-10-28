package com.ecommerce.repositorio;

import com.ecommerce.modelo.Resumo;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** Resumo do painel de administracao e relatorios (um SELECT por relatorio). */
@Repository
public class RepositorioAdmin extends RepositorioBase {

    public RepositorioAdmin(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    // Relatorios: nome na URL -> consulta SQL (sem parametros vindos do cliente)
    private static final Map<String, String> RELATORIOS = new LinkedHashMap<>();

    static {
        // Unidades vendidas e receita por produto (encomendas nao canceladas)
        RELATORIOS.put("vendas-produto", """
                SELECT p.ProdutoId AS produtoId, p.Nome AS nome,
                       SUM(l.Quantidade) AS unidadesVendidas,
                       SUM(l.Quantidade * l.PrecoUnitario) AS receita
                FROM LinhaEncomenda l
                     JOIN Encomenda e ON e.EncomendaId = l.EncomendaId
                     JOIN Produto p ON p.ProdutoId = l.ProdutoId
                WHERE e.Estado <> 'Cancelada'
                GROUP BY p.ProdutoId, p.Nome
                ORDER BY receita DESC
                """);
        // Clientes com encomendas e o total gasto
        RELATORIOS.put("clientes-ativos", """
                SELECT c.ClienteId AS clienteId, c.Nome AS nome, c.Email AS email,
                       COUNT(e.EncomendaId) AS numEncomendas, SUM(e.Total) AS totalGasto
                FROM Cliente c
                     JOIN Encomenda e ON e.ClienteId = c.ClienteId
                WHERE e.Estado <> 'Cancelada'
                GROUP BY c.ClienteId, c.Nome, c.Email
                ORDER BY totalGasto DESC
                """);
        // Produtos ativos com stock abaixo de 10
        RELATORIOS.put("stock-baixo", """
                SELECT ProdutoId AS produtoId, SKU AS sku, Nome AS nome, Stock AS estoque
                FROM Produto
                WHERE Stock < 10 AND Ativo = 1
                ORDER BY Stock, Nome
                """);
        // Os 5 produtos mais vendidos
        RELATORIOS.put("top-produtos", """
                SELECT TOP 5 p.ProdutoId AS produtoId, p.Nome AS nome, SUM(l.Quantidade) AS unidadesVendidas
                FROM LinhaEncomenda l
                     JOIN Encomenda e ON e.EncomendaId = l.EncomendaId
                     JOIN Produto p ON p.ProdutoId = l.ProdutoId
                WHERE e.Estado <> 'Cancelada'
                GROUP BY p.ProdutoId, p.Nome
                ORDER BY unidadesVendidas DESC
                """);
        // Media de avaliacoes por produto
        RELATORIOS.put("media-avaliacoes", """
                SELECT p.ProdutoId AS produtoId, p.Nome AS nome,
                       ROUND(AVG(CAST(a.Nota AS DECIMAL(5,2))), 1) AS media, COUNT(*) AS numAvaliacoes
                FROM Avaliacao a
                     JOIN Produto p ON p.ProdutoId = a.ProdutoId
                GROUP BY p.ProdutoId, p.Nome
                ORDER BY media DESC, numAvaliacoes DESC
                """);
        // Encomendas por pagar
        RELATORIOS.put("encomendas-pendentes", """
                SELECT e.EncomendaId AS encomendaId, c.Nome AS cliente, e.DataEncomenda AS data, e.Total AS total
                FROM Encomenda e
                     JOIN Cliente c ON c.ClienteId = e.ClienteId
                WHERE e.Estado = 'Pendente'
                ORDER BY e.DataEncomenda
                """);
    }

    /** Executa o relatorio pelo nome; vazio se o nome nao existe. */
    public Optional<List<Map<String, Object>>> relatorio(String nome) {
        String sql = RELATORIOS.get(nome);
        if (sql == null) {
            return Optional.empty();
        }
        return Optional.of(jdbc.queryForList(sql, params()));
    }

    public Resumo resumo() {
        String sql = """
                SELECT (SELECT COUNT(*) FROM Produto) AS totalProdutos,
                       (SELECT COUNT(*) FROM Cliente WHERE Papel = 'Cliente') AS totalClientes,
                       (SELECT COUNT(*) FROM Encomenda) AS totalEncomendas,
                       (SELECT ISNULL(SUM(Total), 0) FROM Encomenda
                         WHERE Estado IN ('Paga', 'Enviada', 'Entregue')) AS receita,
                       (SELECT COUNT(*) FROM Encomenda WHERE Estado = 'Pendente') AS encomendasPendentes
                """;
        return jdbc.queryForObject(sql, params(), (rs, n) -> new Resumo(
                rs.getInt("totalProdutos"), rs.getInt("totalClientes"), rs.getInt("totalEncomendas"),
                rs.getBigDecimal("receita"), rs.getInt("encomendasPendentes")));
    }

    /** Usado pelo /api/health. */
    public int contarTabelas() {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM sys.tables", params(), Integer.class);
        return n == null ? 0 : n;
    }
}
