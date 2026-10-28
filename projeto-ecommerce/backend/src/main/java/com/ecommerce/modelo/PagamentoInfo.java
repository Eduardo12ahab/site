package com.ecommerce.modelo;

import java.math.BigDecimal;

public record PagamentoInfo(String metodo, String estado, BigDecimal valor) {
}
