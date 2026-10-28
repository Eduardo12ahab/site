package com.ecommerce.controlador;

import com.ecommerce.configuracao.Sessao;
import com.ecommerce.modelo.CadastroPedido;
import com.ecommerce.modelo.LoginPedido;
import com.ecommerce.modelo.Utilizador;
import com.ecommerce.servico.AutenticacaoServico;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class AutenticacaoControlador {

    private final AutenticacaoServico autenticacao;

    public AutenticacaoControlador(AutenticacaoServico autenticacao) {
        this.autenticacao = autenticacao;
    }

    @PostMapping("/api/cadastro")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> cadastro(@RequestBody CadastroPedido pedido) {
        int id = autenticacao.registar(pedido);
        return Map.of("message", "Conta criada com sucesso", "userId", id);
    }

    @PostMapping("/api/login")
    public Map<String, Object> login(@RequestBody LoginPedido pedido, HttpServletRequest request) {
        Utilizador utilizador = autenticacao.autenticar(pedido.email(), pedido.senha());
        HttpSession sessao = request.getSession(true);
        request.changeSessionId();   // evita fixacao de sessao
        sessao.setAttribute(Sessao.CHAVE, utilizador);
        return Map.of("user", utilizador, "message", "Login realizado");
    }

    @PostMapping("/api/logout")
    public Map<String, String> logout(HttpServletRequest request) {
        HttpSession sessao = request.getSession(false);
        if (sessao != null) {
            sessao.invalidate();
        }
        return Map.of("message", "Logout realizado");
    }

    @GetMapping("/api/usuario/atual")
    public Utilizador atual(HttpSession sessao) {
        return Sessao.exigir(sessao);
    }
}
