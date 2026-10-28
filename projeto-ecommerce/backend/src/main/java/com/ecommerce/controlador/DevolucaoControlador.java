package com.ecommerce.controlador;

import com.ecommerce.configuracao.Sessao;
import com.ecommerce.modelo.Devolucao;
import com.ecommerce.modelo.DevolucaoPedido;
import com.ecommerce.repositorio.RepositorioDevolucao;
import com.ecommerce.servico.DevolucaoServico;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class DevolucaoControlador {

    private final DevolucaoServico servico;
    private final RepositorioDevolucao devolucoes;

    public DevolucaoControlador(DevolucaoServico servico, RepositorioDevolucao devolucoes) {
        this.servico = servico;
        this.devolucoes = devolucoes;
    }

    @PostMapping("/api/devolucoes")
    @ResponseStatus(HttpStatus.CREATED)
    public Devolucao criar(@RequestBody DevolucaoPedido pedido, HttpSession sessao) {
        return servico.criar(Sessao.exigir(sessao).id(), pedido);
    }

    @GetMapping("/api/devolucoes")
    public List<Devolucao> listar(HttpSession sessao) {
        return devolucoes.listar(Sessao.exigir(sessao).id());
    }
}
