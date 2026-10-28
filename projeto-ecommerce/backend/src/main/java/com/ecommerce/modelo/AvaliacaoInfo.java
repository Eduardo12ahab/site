package com.ecommerce.modelo;

import java.time.LocalDateTime;

public record AvaliacaoInfo(String cliente, int nota, String comentario, LocalDateTime data) {
}
