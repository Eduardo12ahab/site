package com.ecommerce.repositorio;

import com.ecommerce.modelo.Produto;
import com.ecommerce.modelo.ProdutoPedido;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@Repository
public class RepositorioProduto extends RepositorioBase {

    public RepositorioProduto(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    // Produto + categoria + fornecedor + media das avaliacoes (1 casa decimal, 0 se nao houver)
    private static final String SELECT_PRODUTO = """
            SELECT p.ProdutoId, p.SKU, p.Nome, p.Descricao, p.Preco, p.Stock, p.ImagemUrl, p.Ativo,
                   p.CategoriaId, c.Nome AS Categoria, p.FornecedorId, f.Nome AS Fornecedor,
                   ISNULL(ROUND(AVG(CAST(a.Nota AS DECIMAL(5,2))), 1), 0) AS Avaliacao,
                   COUNT(a.AvaliacaoId) AS NumAvaliacoes
            FROM Produto p
                 JOIN Categoria c ON c.CategoriaId = p.CategoriaId
                 LEFT JOIN Fornecedor f ON f.FornecedorId = p.FornecedorId
                 LEFT JOIN Avaliacao a ON a.ProdutoId = p.ProdutoId
            """;

    private static final String GROUP_PRODUTO = """
            GROUP BY p.ProdutoId, p.SKU, p.Nome, p.Descricao, p.Preco, p.Stock, p.ImagemUrl, p.Ativo,
                     p.CategoriaId, c.Nome, p.FornecedorId, f.Nome
            """;

    private static final RowMapper<Produto> MAPEADOR = (rs, n) -> new Produto(
            rs.getInt("ProdutoId"),
            rs.getString("SKU"),
            rs.getString("Nome"),
            rs.getString("Descricao"),
            rs.getBigDecimal("Preco"),
            rs.getInt("Stock"),
            rs.getString("ImagemUrl"),
            rs.getBoolean("Ativo"),
            rs.getObject("CategoriaId", Integer.class),
            rs.getString("Categoria"),
            rs.getObject("FornecedorId", Integer.class),
            rs.getString("Fornecedor"),
            rs.getBigDecimal("Avaliacao").setScale(1, java.math.RoundingMode.HALF_UP),
            rs.getInt("NumAvaliacoes"));

    // Ordenacoes permitidas (lista fechada, nunca texto vindo do cliente)
    private static final Map<String, String> ORDENACOES = Map.of(
            "preco-asc", "p.Preco ASC",
            "preco-desc", "p.Preco DESC",
            "nome", "p.Nome ASC",
            "avaliacao", "Avaliacao DESC");

    /** Lista produtos com filtros opcionais; soAtivos=false inclui os inativos (admin). */
    public List<Produto> listar(String categoria, String q, String ordenar, boolean soAtivos) {
        StringBuilder sql = new StringBuilder(SELECT_PRODUTO);
        sql.append("WHERE (:soAtivos = 0 OR p.Ativo = 1)\n");
        MapSqlParameterSource p = params().addValue("soAtivos", soAtivos ? 1 : 0);
        if (categoria != null && !categoria.isBlank()) {
            sql.append("AND LOWER(c.Nome) = LOWER(:categoria)\n");
            p.addValue("categoria", categoria.trim());
        }
        if (q != null && !q.isBlank()) {
            sql.append("AND (p.Nome LIKE :q OR p.Descricao LIKE :q)\n");
            p.addValue("q", "%" + q.trim() + "%");
        }
        sql.append(GROUP_PRODUTO);
        sql.append("ORDER BY ").append((ordenar == null ? "p.ProdutoId ASC" : ORDENACOES.getOrDefault(ordenar, "p.ProdutoId ASC")));
        return jdbc.query(sql.toString(), p, MAPEADOR);
    }

    public Optional<Produto> buscar(int id) {
        String sql = SELECT_PRODUTO + "WHERE p.ProdutoId = :id\n" + GROUP_PRODUTO;
        return jdbc.query(sql, params().addValue("id", id), MAPEADOR).stream().findFirst();
    }

    public List<String> listarCategorias() {
        return jdbc.query("SELECT Nome FROM Categoria ORDER BY Nome", (rs, n) -> rs.getString("Nome"));
    }

    public int criar(ProdutoPedido d) {
        String sql = """
                INSERT INTO Produto (SKU, Nome, Descricao, Preco, Stock, ImagemUrl, Ativo, CategoriaId, FornecedorId)
                VALUES (:sku, :nome, :descricao, :preco, :stock, :imagem, 1, :categoriaId, :fornecedorId)
                """;
        return inserirComId(sql, parametros(d), "ProdutoId");
    }

    public void atualizar(int id, ProdutoPedido d, boolean ativo) {
        String sql = """
                UPDATE Produto
                SET SKU = :sku, Nome = :nome, Descricao = :descricao, Preco = :preco, Stock = :stock,
                    ImagemUrl = :imagem, Ativo = :ativo, CategoriaId = :categoriaId, FornecedorId = :fornecedorId
                WHERE ProdutoId = :id
                """;
        jdbc.update(sql, parametros(d).addValue("id", id).addValue("ativo", ativo));
    }

    /** Eliminacao logica. */
    public int desativar(int id) {
        return jdbc.update("UPDATE Produto SET Ativo = 0 WHERE ProdutoId = :id", params().addValue("id", id));
    }

    private MapSqlParameterSource parametros(ProdutoPedido d) {
        MapSqlParameterSource p = params()
                .addValue("sku", d.sku())
                .addValue("nome", d.nome())
                .addValue("preco", d.preco())
                .addValue("stock", d.estoque() == null ? 0 : d.estoque())
                .addValue("categoriaId", d.categoriaId());
        texto(p, "descricao", d.descricao());
        texto(p, "imagem", d.imagem());
        inteiro(p, "fornecedorId", d.fornecedorId());
        return p;
    }
}
