package com.ecommerce.modelo;

import com.fasterxml.jackson.annotation.JsonProperty;

/** Utilizador guardado na sessao. */
public record Utilizador(int id, String nome, String email, @JsonProperty("isAdmin") boolean admin) {
}
