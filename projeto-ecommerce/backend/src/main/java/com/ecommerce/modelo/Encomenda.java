package com.ecommerce.modelo;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/** Encomenda completa. O campo cliente so aparece nas rotas de administracao. */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record Encomenda(int id, LocalDateTime data, String estado, BigDecimal portes, BigDecimal total,
                        String cupao, MoradaEnvio morada, PagamentoInfo pagamento, List<LinhaInfo> linhas,
                        ClienteResumo cliente) {
}
