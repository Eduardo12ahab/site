package com.ecommerce.modelo;

import java.math.BigDecimal;

public record Resumo(int totalProdutos, int totalClientes, int totalEncomendas, BigDecimal receita,
                     int encomendasPendentes) {
}
