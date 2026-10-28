package com.ecommerce.repositorio;

import com.ecommerce.modelo.ClienteResumo;
import com.ecommerce.modelo.Encomenda;
import com.ecommerce.modelo.LinhaInfo;
import com.ecommerce.modelo.MoradaEnvio;
import com.ecommerce.modelo.PagamentoInfo;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** SQL das encomendas, linhas e pagamentos. O stock e o Total sao tratados pelos gatilhos da BD. */
@Repository
public class RepositorioEncomenda extends RepositorioBase {

    public RepositorioEncomenda(NamedParameterJdbcTemplate jdbc) {
        super(jdbc);
    }

    // ---------------------------------------------------------------- Escrita (checkout)

    /** Devolve o CupaoId do codigo, se existir. */
    public Optional<Integer> buscarCupaoId(String codigo) {
        return jdbc.query("SELECT CupaoId FROM Cupao WHERE Codigo = :codigo",
                params().addValue("codigo", codigo), (rs, n) -> rs.getInt("CupaoId")).stream().findFirst();
    }

    /** Subtotal do carrinho com os precos atuais (so para decidir os portes). */
    public BigDecimal subtotalCarrinho(int clienteId) {
        BigDecimal v = jdbc.queryForObject("""
                SELECT ISNULL(SUM(ic.Quantidade * p.Preco), 0)
                FROM ItemCarrinho ic
                     JOIN Carrinho c ON c.CarrinhoId = ic.CarrinhoId
                     JOIN Produto p ON p.ProdutoId = ic.ProdutoId
                WHERE c.ClienteId = :clienteId
                """, params().addValue("clienteId", clienteId), BigDecimal.class);
        return v == null ? BigDecimal.ZERO : v;
    }

    /** INSERT da encomenda com Total 0 (os gatilhos calculam o total e validam o cupao). */
    public int inserir(int clienteId, int moradaId, Integer cupaoId, BigDecimal portes) {
        String sql = """
                INSERT INTO Encomenda (ClienteId, CupaoId, MoradaEnvioId, Estado, CustoPortes, Total)
                VALUES (:clienteId, :cupaoId, :moradaId, 'Pendente', :portes, 0)
                """;
        MapSqlParameterSource p = params().addValue("clienteId", clienteId)
                .addValue("moradaId", moradaId).addValue("portes", portes);
        inteiro(p, "cupaoId", cupaoId);
        return inserirComId(sql, p, "EncomendaId");
    }

    /** Copia os itens do carrinho para LinhaEncomenda com o preco atual (o gatilho desconta o stock). */
    public int inserirLinhasDoCarrinho(int encomendaId, int clienteId) {
        return jdbc.update("""
                INSERT INTO LinhaEncomenda (EncomendaId, ProdutoId, Quantidade, PrecoUnitario)
                SELECT :encomendaId, ic.ProdutoId, ic.Quantidade, p.Preco
                FROM ItemCarrinho ic
                     JOIN Carrinho c ON c.CarrinhoId = ic.CarrinhoId
                     JOIN Produto p ON p.ProdutoId = ic.ProdutoId
                WHERE c.ClienteId = :clienteId
                """, params().addValue("encomendaId", encomendaId).addValue("clienteId", clienteId));
    }

    /** Le o Total ja calculado pelos gatilhos. */
    public BigDecimal lerTotal(int encomendaId) {
        return jdbc.queryForObject("SELECT Total FROM Encomenda WHERE EncomendaId = :id",
                params().addValue("id", encomendaId), BigDecimal.class);
    }

    public void inserirPagamento(int encomendaId, String metodo, BigDecimal valor) {
        jdbc.update("""
                INSERT INTO Pagamento (EncomendaId, Metodo, Valor, Estado)
                VALUES (:encomendaId, :metodo, :valor, 'Pendente')
                """, params().addValue("encomendaId", encomendaId).addValue("metodo", metodo)
                .addValue("valor", valor));
    }

    // ---------------------------------------------------------------- Estados

    /** Estado atual da encomenda do cliente, com bloqueio de escrita para a transacao. */
    public Optional<String> estadoDoCliente(int encomendaId, int clienteId) {
        return jdbc.query("""
                SELECT Estado FROM Encomenda WITH (UPDLOCK, ROWLOCK)
                WHERE EncomendaId = :id AND ClienteId = :clienteId
                """, params().addValue("id", encomendaId).addValue("clienteId", clienteId),
                (rs, n) -> rs.getString("Estado")).stream().findFirst();
    }

    public boolean existe(int encomendaId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM Encomenda WHERE EncomendaId = :id",
                params().addValue("id", encomendaId), Integer.class);
        return n != null && n > 0;
    }

    /** Os gatilhos validam a transicao (erro 50003 -> 409). */
    public void atualizarEstado(int encomendaId, String estado) {
        jdbc.update("UPDATE Encomenda SET Estado = :estado WHERE EncomendaId = :id",
                params().addValue("estado", estado).addValue("id", encomendaId));
    }

    public void atualizarEstadoPagamento(int encomendaId, String estado) {
        jdbc.update("UPDATE Pagamento SET Estado = :estado WHERE EncomendaId = :id",
                params().addValue("estado", estado).addValue("id", encomendaId));
    }

    // ---------------------------------------------------------------- Leitura

    private static final String SELECT_ENCOMENDA = """
            SELECT e.EncomendaId, e.DataEncomenda, e.Estado, e.CustoPortes, e.Total, cu.Codigo AS Cupao,
                   m.Rua, m.CodigoPostal, m.Cidade, m.Pais,
                   pg.Metodo, pg.Estado AS EstadoPagamento, pg.Valor,
                   cl.ClienteId, cl.Nome AS NomeCliente, cl.Email AS EmailCliente
            FROM Encomenda e
                 JOIN Cliente cl ON cl.ClienteId = e.ClienteId
                 JOIN Morada m ON m.MoradaId = e.MoradaEnvioId
                 LEFT JOIN Cupao cu ON cu.CupaoId = e.CupaoId
                 LEFT JOIN Pagamento pg ON pg.EncomendaId = e.EncomendaId
            WHERE 1 = 1
            """;

    /** Lista encomendas (mais recentes primeiro); clienteId e estado sao filtros opcionais. */
    public List<Encomenda> listar(Integer clienteId, String estado, boolean comCliente) {
        StringBuilder sql = new StringBuilder(SELECT_ENCOMENDA);
        MapSqlParameterSource p = params();
        if (clienteId != null) {
            sql.append(" AND e.ClienteId = :clienteId");
            p.addValue("clienteId", clienteId);
        }
        if (estado != null && !estado.isBlank()) {
            sql.append(" AND e.Estado = :estado");
            p.addValue("estado", estado);
        }
        sql.append(" ORDER BY e.DataEncomenda DESC, e.EncomendaId DESC");
        List<Encomenda> cabecalhos = jdbc.query(sql.toString(), p, mapeador(comCliente));
        // Junta as linhas de cada encomenda
        List<Encomenda> completas = new ArrayList<>();
        for (Encomenda c : cabecalhos) {
            completas.add(comLinhas(c));
        }
        return completas;
    }

    /** Uma encomenda; se clienteId != null so a devolve se for desse cliente. */
    public Optional<Encomenda> buscar(int encomendaId, Integer clienteId, boolean comCliente) {
        StringBuilder sql = new StringBuilder(SELECT_ENCOMENDA).append(" AND e.EncomendaId = :id");
        MapSqlParameterSource p = params().addValue("id", encomendaId);
        if (clienteId != null) {
            sql.append(" AND e.ClienteId = :clienteId");
            p.addValue("clienteId", clienteId);
        }
        return jdbc.query(sql.toString(), p, mapeador(comCliente)).stream().findFirst().map(this::comLinhas);
    }

    private List<LinhaInfo> linhas(int encomendaId) {
        return jdbc.query("""
                SELECT l.ProdutoId, p.Nome, l.Quantidade, l.PrecoUnitario
                FROM LinhaEncomenda l JOIN Produto p ON p.ProdutoId = l.ProdutoId
                WHERE l.EncomendaId = :id ORDER BY l.ProdutoId
                """, params().addValue("id", encomendaId),
                (rs, n) -> new LinhaInfo(rs.getInt("ProdutoId"), rs.getString("Nome"), rs.getInt("Quantidade"),
                        rs.getBigDecimal("PrecoUnitario")));
    }

    private Encomenda comLinhas(Encomenda e) {
        return new Encomenda(e.id(), e.data(), e.estado(), e.portes(), e.total(), e.cupao(), e.morada(),
                e.pagamento(), linhas(e.id()), e.cliente());
    }

    private static RowMapper<Encomenda> mapeador(boolean comCliente) {
        return (rs, n) -> {
            String metodo = rs.getString("Metodo");
            PagamentoInfo pagamento = metodo == null ? null
                    : new PagamentoInfo(metodo, rs.getString("EstadoPagamento"), rs.getBigDecimal("Valor"));
            ClienteResumo cliente = comCliente
                    ? new ClienteResumo(rs.getInt("ClienteId"), rs.getString("NomeCliente"),
                            rs.getString("EmailCliente"))
                    : null;
            return new Encomenda(
                    rs.getInt("EncomendaId"),
                    rs.getTimestamp("DataEncomenda") == null ? null : rs.getTimestamp("DataEncomenda").toLocalDateTime(),
                    rs.getString("Estado"),
                    rs.getBigDecimal("CustoPortes"),
                    rs.getBigDecimal("Total"),
                    rs.getString("Cupao"),
                    new MoradaEnvio(rs.getString("Rua"), rs.getString("CodigoPostal"), rs.getString("Cidade"),
                            rs.getString("Pais")),
                    pagamento,
                    List.of(),
                    cliente);
        };
    }
}
