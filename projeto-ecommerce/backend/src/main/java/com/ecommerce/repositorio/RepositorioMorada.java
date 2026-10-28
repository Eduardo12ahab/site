package com.ecommerce.repositorio;

import com.ecommerce.modelo.Morada;
import com.ecommerce.modelo.MoradaPedido;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class RepositorioMorada extends RepositorioBase {

    public RepositorioMorada(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    private static final RowMapper<Morada> MAPEADOR = (rs, n) -> new Morada(rs.getInt("MoradaId"),
            rs.getString("Tipo"), rs.getString("Rua"), rs.getString("CodigoPostal"), rs.getString("Cidade"),
            rs.getString("Pais"));

    public List<Morada> listar(int clienteId) {
        return jdbc.query("""
                SELECT MoradaId, Tipo, Rua, CodigoPostal, Cidade, Pais
                FROM Morada WHERE ClienteId = :clienteId ORDER BY MoradaId
                """, params().addValue("clienteId", clienteId), MAPEADOR);
    }

    public Morada criar(int clienteId, MoradaPedido m) {
        String rua = m.rua().trim();
        String codigoPostal = m.codigoPostal().trim();
        String cidade = m.cidade().trim();
        String pais = (m.pais() == null || m.pais().isBlank()) ? "Portugal" : m.pais().trim();
        int id = inserirComId("""
                INSERT INTO Morada (ClienteId, Tipo, Rua, CodigoPostal, Cidade, Pais)
                VALUES (:clienteId, 'Envio', :rua, :codigoPostal, :cidade, :pais)
                """, params().addValue("clienteId", clienteId).addValue("rua", rua)
                .addValue("codigoPostal", codigoPostal).addValue("cidade", cidade)
                .addValue("pais", pais), "MoradaId");
        return new Morada(id, "Envio", rua, codigoPostal, cidade, pais);
    }

    /** Verifica se a morada pertence ao cliente. */
    public boolean pertenceAoCliente(int moradaId, int clienteId) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM Morada WHERE MoradaId = :id AND ClienteId = :clienteId",
                params().addValue("id", moradaId).addValue("clienteId", clienteId), Integer.class);
        return n != null && n > 0;
    }
}
