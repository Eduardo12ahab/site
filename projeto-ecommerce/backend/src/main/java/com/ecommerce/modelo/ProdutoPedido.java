package com.ecommerce.modelo;

import java.math.BigDecimal;

public record ProdutoPedido(String sku, String nome, String descricao, BigDecimal preco, Integer estoque,
                            String imagem, Integer categoriaId, Integer fornecedorId, Boolean ativo) {
}
