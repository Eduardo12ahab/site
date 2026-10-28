package com.ecommerce.controlador;

import com.ecommerce.configuracao.Sessao;
import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.Encomenda;
import com.ecommerce.modelo.EncomendaPedido;
import com.ecommerce.repositorio.RepositorioEncomenda;
import com.ecommerce.servico.EncomendaServico;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class EncomendaControlador {

    private final EncomendaServico servico;
    private final RepositorioEncomenda encomendas;

    public EncomendaControlador(EncomendaServico servico, RepositorioEncomenda encomendas) {
        this.servico = servico;
        this.encomendas = encomendas;
    }

    @PostMapping("/api/encomendas")
    @ResponseStatus(HttpStatus.CREATED)
    public Encomenda criar(@RequestBody EncomendaPedido pedido, HttpSession sessao) {
        return servico.criar(Sessao.exigir(sessao).id(), pedido);
    }

    @GetMapping("/api/encomendas")
    public List<Encomenda> listar(HttpSession sessao) {
        return encomendas.listar(Sessao.exigir(sessao).id(), null, false);
    }

    @GetMapping("/api/encomendas/{id}")
    public Encomenda obter(@PathVariable int id, HttpSession sessao) {
        return encomendas.buscar(id, Sessao.exigir(sessao).id(), false)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Encomenda nao encontrada"));
    }

    @PostMapping("/api/encomendas/{id}/pagar")
    public Encomenda pagar(@PathVariable int id, HttpSession sessao) {
        return servico.pagar(id, Sessao.exigir(sessao).id());
    }

    @PostMapping("/api/encomendas/{id}/cancelar")
    public Encomenda cancelar(@PathVariable int id, HttpSession sessao) {
        return servico.cancelar(id, Sessao.exigir(sessao).id());
    }
}
