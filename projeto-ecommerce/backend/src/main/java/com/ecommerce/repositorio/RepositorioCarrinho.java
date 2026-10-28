package com.ecommerce.repositorio;

import com.ecommerce.modelo.Item;
import com.ecommerce.modelo.ProdutoResumo;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class RepositorioCarrinho extends RepositorioBase {

    public RepositorioCarrinho(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    // O ProdutoId serve de id do item (a chave de ItemCarrinho e composta)
    private static final RowMapper<Item> MAPEADOR = (rs, n) -> new Item(
            rs.getInt("ProdutoId"),
            rs.getInt("ProdutoId"),
            rs.getInt("Quantidade"),
            new ProdutoResumo(rs.getInt("ProdutoId"), rs.getString("Nome"), rs.getBigDecimal("Preco"),
                    rs.getString("ImagemUrl"), rs.getInt("Stock")));

    private static final String SELECT_ITEM = """
            SELECT ic.ProdutoId, ic.Quantidade, p.Nome, p.Preco, p.ImagemUrl, p.Stock
            FROM ItemCarrinho ic
                 JOIN Carrinho c ON c.CarrinhoId = ic.CarrinhoId
                 JOIN Produto p ON p.ProdutoId = ic.ProdutoId
            WHERE c.ClienteId = :clienteId
            """;

    /** Cria o carrinho do cliente (usado no registo). */
    public int criarCarrinho(int clienteId) {
        return inserirComId("INSERT INTO Carrinho (ClienteId) VALUES (:clienteId)",
                params().addValue("clienteId", clienteId), "CarrinhoId");
    }

    public List<Item> listar(int clienteId) {
        return jdbc.query(SELECT_ITEM + " ORDER BY ic.DataAdicao, ic.ProdutoId",
                params().addValue("clienteId", clienteId), MAPEADOR);
    }

    public Optional<Item> buscarItem(int clienteId, int produtoId) {
        return jdbc.query(SELECT_ITEM + " AND ic.ProdutoId = :produtoId",
                params().addValue("clienteId", clienteId).addValue("produtoId", produtoId), MAPEADOR)
                .stream().findFirst();
    }

    /** Soma a quantidade se o produto ja esta no carrinho; senao insere. */
    public void adicionar(int clienteId, int produtoId, int quantidade) {
        MapSqlParameterSource p = params().addValue("clienteId", clienteId).addValue("produtoId", produtoId)
                .addValue("quantidade", quantidade);
        int atualizadas = jdbc.update("""
                UPDATE ItemCarrinho SET Quantidade = Quantidade + :quantidade
                WHERE ProdutoId = :produtoId
                  AND CarrinhoId = (SELECT CarrinhoId FROM Carrinho WHERE ClienteId = :clienteId)
                """, p);
        if (atualizadas == 0) {
            // Carrinho em falta (clientes antigos): cria-o antes de inserir o item
            jdbc.update("""
                    INSERT INTO Carrinho (ClienteId)
                    SELECT :clienteId WHERE NOT EXISTS (SELECT 1 FROM Carrinho WHERE ClienteId = :clienteId)
                    """, p);
            jdbc.update("""
                    INSERT INTO ItemCarrinho (CarrinhoId, ProdutoId, Quantidade)
                    SELECT CarrinhoId, :produtoId, :quantidade FROM Carrinho WHERE ClienteId = :clienteId
                    """, p);
        }
    }

    /** Define a quantidade; devolve o numero de linhas afetadas (0 = item nao existe). */
    public int definirQuantidade(int clienteId, int produtoId, int quantidade) {
        return jdbc.update("""
                UPDATE ItemCarrinho SET Quantidade = :quantidade
                WHERE ProdutoId = :produtoId
                  AND CarrinhoId = (SELECT CarrinhoId FROM Carrinho WHERE ClienteId = :clienteId)
                """, params().addValue("clienteId", clienteId).addValue("produtoId", produtoId)
                .addValue("quantidade", quantidade));
    }

    public void remover(int clienteId, int produtoId) {
        jdbc.update("""
                DELETE FROM ItemCarrinho
                WHERE ProdutoId = :produtoId
                  AND CarrinhoId = (SELECT CarrinhoId FROM Carrinho WHERE ClienteId = :clienteId)
                """, params().addValue("clienteId", clienteId).addValue("produtoId", produtoId));
    }

    public void esvaziar(int clienteId) {
        jdbc.update("""
                DELETE FROM ItemCarrinho
                WHERE CarrinhoId = (SELECT CarrinhoId FROM Carrinho WHERE ClienteId = :clienteId)
                """, params().addValue("clienteId", clienteId));
    }
}
