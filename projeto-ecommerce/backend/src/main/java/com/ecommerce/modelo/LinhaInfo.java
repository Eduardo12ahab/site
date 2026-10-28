package com.ecommerce.modelo;

import java.math.BigDecimal;

public record LinhaInfo(int produtoId, String nome, int quantidade, BigDecimal precoUnitario) {
}
