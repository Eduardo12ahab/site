package com.ecommerce.controlador;

import com.ecommerce.configuracao.Sessao;
import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.Morada;
import com.ecommerce.modelo.MoradaPedido;
import com.ecommerce.repositorio.RepositorioMorada;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class MoradaControlador {

    private final RepositorioMorada moradas;

    public MoradaControlador(RepositorioMorada moradas) {
        this.moradas = moradas;
    }

    @GetMapping("/api/moradas")
    public List<Morada> listar(HttpSession sessao) {
        return moradas.listar(Sessao.exigir(sessao).id());
    }

    @PostMapping("/api/moradas")
    @ResponseStatus(HttpStatus.CREATED)
    public Morada criar(@RequestBody MoradaPedido pedido, HttpSession sessao) {
        int clienteId = Sessao.exigir(sessao).id();
        if (vazio(pedido.rua()) || vazio(pedido.codigoPostal()) || vazio(pedido.cidade())) {
            throw ExcecaoApi.pedidoInvalido("Rua, codigo postal e cidade sao obrigatorios");
        }
        return moradas.criar(clienteId, pedido);
    }

    private static boolean vazio(String s) {
        return s == null || s.isBlank();
    }
}
