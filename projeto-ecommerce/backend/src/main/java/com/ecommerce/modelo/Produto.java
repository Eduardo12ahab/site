package com.ecommerce.modelo;

import java.math.BigDecimal;

public record Produto(int id, String sku, String nome, String descricao, BigDecimal preco, int estoque,
                      String imagem, boolean ativo, Integer categoriaId, String categoria,
                      Integer fornecedorId, String fornecedor, BigDecimal avaliacao, int numAvaliacoes) {
}
