package com.ecommerce.repositorio;

import com.ecommerce.modelo.AvaliacaoInfo;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class RepositorioAvaliacao extends RepositorioBase {

    public RepositorioAvaliacao(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    public List<AvaliacaoInfo> listarPorProduto(int produtoId) {
        String sql = """
                SELECT c.Nome, a.Nota, a.Comentario, a.DataAvaliacao
                FROM Avaliacao a JOIN Cliente c ON c.ClienteId = a.ClienteId
                WHERE a.ProdutoId = :produtoId
                ORDER BY a.DataAvaliacao DESC
                """;
        return jdbc.query(sql, params().addValue("produtoId", produtoId),
                (rs, n) -> new AvaliacaoInfo(rs.getString("Nome"), rs.getInt("Nota"), rs.getString("Comentario"),
                        rs.getTimestamp("DataAvaliacao") == null ? null : rs.getTimestamp("DataAvaliacao").toLocalDateTime()));
    }

    /** Se o cliente ja avaliou o produto, a UNIQUE (ClienteId, ProdutoId) provoca erro 2627 (-> 409). */
    public void criar(int clienteId, int produtoId, int nota, String comentario) {
        MapSqlParameterSource p = params().addValue("clienteId", clienteId).addValue("produtoId", produtoId)
                .addValue("nota", nota);
        texto(p, "comentario", comentario);
        jdbc.update("""
                INSERT INTO Avaliacao (ClienteId, ProdutoId, Nota, Comentario)
                VALUES (:clienteId, :produtoId, :nota, :comentario)
                """, p);
    }
}
