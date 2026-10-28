package com.ecommerce.modelo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record ClienteAdmin(int id, String nome, String email, String papel, LocalDateTime dataRegisto,
                           int numEncomendas, BigDecimal totalGasto) {
}
