package com.ecommerce.repositorio;

import com.ecommerce.modelo.Devolucao;
import com.ecommerce.modelo.ItemDevolucaoInfo;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;

@Repository
public class RepositorioDevolucao extends RepositorioBase {

    public RepositorioDevolucao(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    /** Cria a devolucao (Pedida). O gatilho rejeita encomendas nao entregues (erro 50005 -> 409). */
    public int criar(int encomendaId, String motivo) {
        MapSqlParameterSource p = params().addValue("encomendaId", encomendaId);
        texto(p, "motivo", motivo);
        return inserirComId("""
                INSERT INTO Devolucao (EncomendaId, Motivo, Estado)
                VALUES (:encomendaId, :motivo, 'Pedida')
                """, p, "DevolucaoId");
    }

    public void inserirItem(int devolucaoId, int produtoId, int quantidade) {
        jdbc.update("""
                INSERT INTO ItemDevolucao (DevolucaoId, ProdutoId, Quantidade)
                VALUES (:devolucaoId, :produtoId, :quantidade)
                """, params().addValue("devolucaoId", devolucaoId).addValue("produtoId", produtoId)
                .addValue("quantidade", quantidade));
    }

    /** Quantidade comprada de um produto numa encomenda (0 se nao consta). */
    public int quantidadeComprada(int encomendaId, int produtoId) {
        Integer q = jdbc.query("""
                SELECT Quantidade FROM LinhaEncomenda WHERE EncomendaId = :encomendaId AND ProdutoId = :produtoId
                """, params().addValue("encomendaId", encomendaId).addValue("produtoId", produtoId),
                (rs, n) -> rs.getInt("Quantidade")).stream().findFirst().orElse(0);
        return q;
    }

    /** Quantidade deste produto ja incluida em devolucoes da encomenda (as recusadas nao contam). */
    public int quantidadeJaDevolvida(int encomendaId, int produtoId) {
        Integer q = jdbc.queryForObject("""
                SELECT ISNULL(SUM(i.Quantidade), 0)
                FROM ItemDevolucao i JOIN Devolucao d ON d.DevolucaoId = i.DevolucaoId
                WHERE d.EncomendaId = :encomendaId AND i.ProdutoId = :produtoId AND d.Estado <> 'Recusada'
                """, params().addValue("encomendaId", encomendaId).addValue("produtoId", produtoId),
                Integer.class);
        return q == null ? 0 : q;
    }

    /** Estado atual de uma devolucao (vazio se nao existe). */
    public java.util.Optional<String> estado(int devolucaoId) {
        return jdbc.query("SELECT Estado FROM Devolucao WHERE DevolucaoId = :id",
                params().addValue("id", devolucaoId), (rs, n) -> rs.getString("Estado")).stream().findFirst();
    }

    /** Devolucoes de um cliente (clienteId != null) ou de todos (null, admin). */
    public List<Devolucao> listar(Integer clienteId) {
        StringBuilder sql = new StringBuilder("""
                SELECT d.DevolucaoId, d.EncomendaId, d.DataDevolucao, d.Motivo, d.Estado
                FROM Devolucao d JOIN Encomenda e ON e.EncomendaId = d.EncomendaId
                WHERE 1 = 1
                """);
        MapSqlParameterSource p = params();
        if (clienteId != null) {
            sql.append(" AND e.ClienteId = :clienteId");
            p.addValue("clienteId", clienteId);
        }
        sql.append(" ORDER BY d.DataDevolucao DESC, d.DevolucaoId DESC");
        List<Devolucao> cabecalhos = jdbc.query(sql.toString(), p, (rs, n) -> new Devolucao(
                rs.getInt("DevolucaoId"), rs.getInt("EncomendaId"),
                rs.getTimestamp("DataDevolucao") == null ? null : rs.getTimestamp("DataDevolucao").toLocalDateTime(),
                rs.getString("Motivo"),
                rs.getString("Estado"), List.of()));
        List<Devolucao> completas = new ArrayList<>();
        for (Devolucao d : cabecalhos) {
            completas.add(new Devolucao(d.id(), d.encomendaId(), d.data(), d.motivo(), d.estado(), itens(d.id())));
        }
        return completas;
    }

    private List<ItemDevolucaoInfo> itens(int devolucaoId) {
        return jdbc.query("""
                SELECT i.ProdutoId, p.Nome, i.Quantidade
                FROM ItemDevolucao i JOIN Produto p ON p.ProdutoId = i.ProdutoId
                WHERE i.DevolucaoId = :id ORDER BY i.ProdutoId
                """, params().addValue("id", devolucaoId),
                (rs, n) -> new ItemDevolucaoInfo(rs.getInt("ProdutoId"), rs.getString("Nome"),
                        rs.getInt("Quantidade")));
    }

    /** O gatilho repoe o stock quando o estado passa a Concluida. Devolve as linhas afetadas. */
    public int atualizarEstado(int devolucaoId, String estado) {
        return jdbc.update("UPDATE Devolucao SET Estado = :estado WHERE DevolucaoId = :id",
                params().addValue("estado", estado).addValue("id", devolucaoId));
    }

    public boolean existe(int devolucaoId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM Devolucao WHERE DevolucaoId = :id",
                params().addValue("id", devolucaoId), Integer.class);
        return n != null && n > 0;
    }
}
