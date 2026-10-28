package com.ecommerce.modelo;

import java.time.LocalDateTime;
import java.util.List;

public record Devolucao(int id, int encomendaId, LocalDateTime data, String motivo, String estado,
                        List<ItemDevolucaoInfo> itens) {
}
