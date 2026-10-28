package com.ecommerce.modelo;

import java.util.List;

public record DevolucaoPedido(Integer encomendaId, String motivo, List<ItemDevolucaoPedido> itens) {
}
