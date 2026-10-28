package com.ecommerce.excecao;

import org.springframework.http.HttpStatus;

/** Erro de negocio com o codigo HTTP a devolver e a mensagem em portugues. */
public class ExcecaoApi extends RuntimeException {

    private final HttpStatus estado;

    public ExcecaoApi(HttpStatus estado, String mensagem) {
        super(mensagem);
        this.estado = estado;
    }

    public HttpStatus getEstado() {
        return estado;
    }

    public static ExcecaoApi pedidoInvalido(String m) { return new ExcecaoApi(HttpStatus.BAD_REQUEST, m); }
    public static ExcecaoApi naoAutenticado(String m) { return new ExcecaoApi(HttpStatus.UNAUTHORIZED, m); }
    public static ExcecaoApi proibido(String m)       { return new ExcecaoApi(HttpStatus.FORBIDDEN, m); }
    public static ExcecaoApi naoEncontrado(String m)  { return new ExcecaoApi(HttpStatus.NOT_FOUND, m); }
    public static ExcecaoApi conflito(String m)       { return new ExcecaoApi(HttpStatus.CONFLICT, m); }
}
