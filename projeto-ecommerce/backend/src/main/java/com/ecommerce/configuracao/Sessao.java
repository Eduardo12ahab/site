package com.ecommerce.configuracao;

import com.ecommerce.modelo.Utilizador;
import com.ecommerce.excecao.ExcecaoApi;
import jakarta.servlet.http.HttpSession;

/** Acesso ao utilizador guardado na HttpSession. */
public final class Sessao {

    public static final String CHAVE = "utilizador";

    private Sessao() {
    }

    /** Devolve o utilizador autenticado ou lanca 401. */
    public static Utilizador exigir(HttpSession sessao) {
        Object u = sessao.getAttribute(CHAVE);
        if (u instanceof Utilizador) {
            return (Utilizador) u;
        }
        throw ExcecaoApi.naoAutenticado("E necessario iniciar sessao");
    }
}
