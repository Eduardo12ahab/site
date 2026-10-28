package com.ecommerce.controlador;

import com.ecommerce.configuracao.Sessao;
import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.Item;
import com.ecommerce.modelo.ItemCarrinhoPedido;
import com.ecommerce.repositorio.RepositorioCarrinho;
import com.ecommerce.repositorio.RepositorioProduto;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class CarrinhoControlador {

    private final RepositorioCarrinho carrinho;
    private final RepositorioProduto produtos;

    public CarrinhoControlador(RepositorioCarrinho carrinho, RepositorioProduto produtos) {
        this.carrinho = carrinho;
        this.produtos = produtos;
    }

    @GetMapping("/api/carrinho")
    public List<Item> listar(HttpSession sessao) {
        return carrinho.listar(Sessao.exigir(sessao).id());
    }

    @PostMapping("/api/carrinho")
    public List<Item> adicionar(@RequestBody ItemCarrinhoPedido pedido, HttpSession sessao) {
        int clienteId = Sessao.exigir(sessao).id();
        if (pedido.produtoId() == null) {
            throw ExcecaoApi.pedidoInvalido("produtoId e obrigatorio");
        }
        if (pedido.quantidade() == null || pedido.quantidade() < 1) {
            throw ExcecaoApi.pedidoInvalido("A quantidade deve ser pelo menos 1");
        }
        boolean existe = produtos.buscar(pedido.produtoId()).map(p -> p.ativo()).orElse(false);
        if (!existe) {
            throw ExcecaoApi.naoEncontrado("Produto nao encontrado");
        }
        carrinho.adicionar(clienteId, pedido.produtoId(), pedido.quantidade());
        return carrinho.listar(clienteId);
    }

    @PutMapping("/api/carrinho/{produtoId}")
    public Item alterar(@PathVariable int produtoId, @RequestBody ItemCarrinhoPedido pedido,
                        HttpSession sessao) {
        int clienteId = Sessao.exigir(sessao).id();
        if (pedido.quantidade() == null || pedido.quantidade() < 1) {
            throw ExcecaoApi.pedidoInvalido("A quantidade deve ser pelo menos 1");
        }
        if (carrinho.definirQuantidade(clienteId, produtoId, pedido.quantidade()) == 0) {
            throw ExcecaoApi.naoEncontrado("Item nao esta no carrinho");
        }
        return carrinho.buscarItem(clienteId, produtoId).orElseThrow();
    }

    @DeleteMapping("/api/carrinho/{produtoId}")
    public Map<String, String> remover(@PathVariable int produtoId, HttpSession sessao) {
        carrinho.remover(Sessao.exigir(sessao).id(), produtoId);
        return Map.of("message", "Item removido do carrinho");
    }
}
