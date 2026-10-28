package com.ecommerce.repositorio;

import com.ecommerce.modelo.ClienteAdmin;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class RepositorioCliente extends RepositorioBase {

    /** Dados necessarios para validar um login. */
    public record Credenciais(int id, String nome, String email, String passwordHash, String papel) {
    }

    public RepositorioCliente(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    public Optional<Credenciais> buscarPorEmail(String email) {
        String sql = "SELECT ClienteId, Nome, Email, PasswordHash, Papel FROM Cliente WHERE Email = :email";
        return jdbc.query(sql, params().addValue("email", email),
                (rs, n) -> new Credenciais(rs.getInt("ClienteId"), rs.getString("Nome"), rs.getString("Email"),
                        rs.getString("PasswordHash"), rs.getString("Papel"))).stream().findFirst();
    }

    /** Insere o cliente (Papel = 'Cliente') e devolve o novo ClienteId. */
    public int criar(String nome, String email, String hash, String telefone, String nif) {
        String sql = """
                INSERT INTO Cliente (Nome, Email, PasswordHash, Telefone, NIF, Papel)
                VALUES (:nome, :email, :hash, :telefone, :nif, 'Cliente')
                """;
        MapSqlParameterSource p = params()
                .addValue("nome", nome)
                .addValue("email", email)
                .addValue("hash", hash);
        texto(p, "telefone", telefone);
        texto(p, "nif", nif);
        return inserirComId(sql, p, "ClienteId");
    }

    public void atualizarHash(int clienteId, String hash) {
        jdbc.update("UPDATE Cliente SET PasswordHash = :hash WHERE ClienteId = :id",
                params().addValue("hash", hash).addValue("id", clienteId));
    }

    /** Lista de clientes com numero de encomendas e total gasto (encomendas nao canceladas). */
    public List<ClienteAdmin> listarAdmin() {
        String sql = """
                SELECT c.ClienteId, c.Nome, c.Email, c.Papel, c.DataRegisto,
                       COUNT(e.EncomendaId) AS NumEncomendas,
                       ISNULL(SUM(CASE WHEN e.Estado <> 'Cancelada' THEN e.Total END), 0) AS TotalGasto
                FROM Cliente c
                     LEFT JOIN Encomenda e ON e.ClienteId = c.ClienteId
                GROUP BY c.ClienteId, c.Nome, c.Email, c.Papel, c.DataRegisto
                ORDER BY c.ClienteId
                """;
        return jdbc.query(sql, (rs, n) -> new ClienteAdmin(rs.getInt("ClienteId"), rs.getString("Nome"),
                rs.getString("Email"), rs.getString("Papel"), rs.getTimestamp("DataRegisto") == null ? null : rs.getTimestamp("DataRegisto").toLocalDateTime(),
                rs.getInt("NumEncomendas"), rs.getBigDecimal("TotalGasto")));
    }
}
