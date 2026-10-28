package com.ecommerce.controlador;

import com.ecommerce.configuracao.Sessao;
import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.AvaliacaoInfo;
import com.ecommerce.modelo.AvaliacaoPedido;
import com.ecommerce.modelo.Produto;
import com.ecommerce.modelo.Utilizador;
import com.ecommerce.repositorio.RepositorioAvaliacao;
import com.ecommerce.repositorio.RepositorioProduto;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class ProdutoControlador {

    private final RepositorioProduto produtos;
    private final RepositorioAvaliacao avaliacoes;

    public ProdutoControlador(RepositorioProduto produtos, RepositorioAvaliacao avaliacoes) {
        this.produtos = produtos;
        this.avaliacoes = avaliacoes;
    }

    @GetMapping("/api/produtos")
    public List<Produto> listar(@RequestParam(required = false) String categoria,
                                @RequestParam(required = false) String q,
                                @RequestParam(required = false) String ordenar) {
        return produtos.listar(categoria, q, ordenar, true);
    }

    @GetMapping("/api/produtos/{id}")
    public Produto obter(@PathVariable int id) {
        Produto p = produtos.buscar(id)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Produto nao encontrado"));
        if (!p.ativo()) {
            throw ExcecaoApi.naoEncontrado("Produto nao encontrado");
        }
        return p;
    }

    @GetMapping("/api/categorias")
    public List<String> categorias() {
        return produtos.listarCategorias();
    }

    @GetMapping("/api/produtos/{id}/avaliacoes")
    public List<AvaliacaoInfo> listarAvaliacoes(@PathVariable int id) {
        return avaliacoes.listarPorProduto(id);
    }

    @PostMapping("/api/produtos/{id}/avaliacoes")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, String> avaliar(@PathVariable int id, @RequestBody AvaliacaoPedido pedido,
                                       HttpSession sessao) {
        Utilizador u = Sessao.exigir(sessao);
        if (pedido.nota() == null || pedido.nota() < 1 || pedido.nota() > 5) {
            throw ExcecaoApi.pedidoInvalido("A nota deve estar entre 1 e 5");
        }
        if (produtos.buscar(id).isEmpty()) {
            throw ExcecaoApi.naoEncontrado("Produto nao encontrado");
        }
        // 409 se o cliente ja avaliou (UNIQUE na BD)
        avaliacoes.criar(u.id(), id, pedido.nota(), pedido.comentario());
        return Map.of("message", "Avaliacao registada");
    }
}
