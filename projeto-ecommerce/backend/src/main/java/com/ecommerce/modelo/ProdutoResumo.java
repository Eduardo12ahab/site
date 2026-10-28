package com.ecommerce.modelo;

import java.math.BigDecimal;

/** Produto reduzido, usado dentro dos itens do carrinho. */
public record ProdutoResumo(int id, String nome, BigDecimal preco, String imagem, int estoque) {
}
