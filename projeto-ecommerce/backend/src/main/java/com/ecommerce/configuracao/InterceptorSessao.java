package com.ecommerce.configuracao;

import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.Utilizador;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/** Verifica a sessao: 401 sem login nas rotas (login), 403 nas rotas /api/admin se nao for admin. */
@Component
public class InterceptorSessao implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest pedido, HttpServletResponse resposta, Object handler) {
        // Pedidos CORS de verificacao nao levam cookie
        if ("OPTIONS".equals(pedido.getMethod())) {
            return true;
        }
        String caminho = pedido.getRequestURI();
        if (!exigeLogin(pedido.getMethod(), caminho)) {
            return true;
        }
        HttpSession sessao = pedido.getSession(false);
        Object u = sessao == null ? null : sessao.getAttribute(Sessao.CHAVE);
        if (!(u instanceof Utilizador)) {
            throw ExcecaoApi.naoAutenticado("E necessario iniciar sessao");
        }
        if (caminho.startsWith("/api/admin") && !((Utilizador) u).admin()) {
            throw ExcecaoApi.proibido("Acesso reservado a administradores");
        }
        return true;
    }

    /** Rotas publicas: saude, cadastro, login, logout e leitura de produtos/categorias/avaliacoes. */
    private boolean exigeLogin(String metodo, String caminho) {
        if (caminho.equals("/api/health") || caminho.equals("/api/cadastro")
                || caminho.equals("/api/login") || caminho.equals("/api/logout")
                || caminho.equals("/api/categorias")) {
            return false;
        }
        if (caminho.startsWith("/api/produtos")) {
            return !"GET".equals(metodo);   // so o POST de avaliacoes exige login
        }
        return true;
    }
}
