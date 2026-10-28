package com.ecommerce.servico;

import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.Encomenda;
import com.ecommerce.modelo.EncomendaPedido;
import com.ecommerce.repositorio.RepositorioCarrinho;
import com.ecommerce.repositorio.RepositorioEncomenda;
import com.ecommerce.repositorio.RepositorioMorada;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

/**
 * Operacoes compostas sobre encomendas. Cada metodo @Transactional corre numa unica transacao:
 * se qualquer SQL (ou gatilho) falhar, tudo sofre rollback.
 */
@Service
public class EncomendaServico {

    private static final BigDecimal PORTES = new BigDecimal("4.99");
    private static final BigDecimal PORTES_GRATIS_A_PARTIR_DE = new BigDecimal("50");

    private final RepositorioEncomenda encomendas;
    private final RepositorioCarrinho carrinhos;
    private final RepositorioMorada moradas;

    public EncomendaServico(RepositorioEncomenda encomendas, RepositorioCarrinho carrinhos,
                            RepositorioMorada moradas) {
        this.encomendas = encomendas;
        this.carrinhos = carrinhos;
        this.moradas = moradas;
    }

    /** Checkout: Encomenda + LinhaEncomenda + Pagamento + esvaziar carrinho. */
    @Transactional
    public Encomenda criar(int clienteId, EncomendaPedido pedido) {
        if (pedido.moradaId() == null || !moradas.pertenceAoCliente(pedido.moradaId(), clienteId)) {
            throw ExcecaoApi.pedidoInvalido("Morada invalida");
        }
        // A CHECK de Pagamento.Metodo so aceita estes valores
        if (pedido.metodoPagamento() == null
                || !java.util.Set.of("MBWay", "Cartao", "Multibanco", "Paypal").contains(pedido.metodoPagamento().trim())) {
            throw ExcecaoApi.pedidoInvalido("Metodo de pagamento invalido (MBWay, Cartao, Multibanco ou Paypal)");
        }
        BigDecimal subtotal = encomendas.subtotalCarrinho(clienteId);
        if (carrinhos.listar(clienteId).isEmpty()) {
            throw ExcecaoApi.pedidoInvalido("O carrinho esta vazio");
        }
        Integer cupaoId = null;
        if (pedido.cupao() != null && !pedido.cupao().isBlank()) {
            cupaoId = encomendas.buscarCupaoId(pedido.cupao().trim())
                    .orElseThrow(() -> ExcecaoApi.pedidoInvalido("Cupao invalido"));
        }
        // Portes: gratis a partir de 50 EUR de subtotal
        BigDecimal portes = subtotal.compareTo(PORTES_GRATIS_A_PARTIR_DE) >= 0 ? BigDecimal.ZERO : PORTES;

        // 1) Encomenda com Total 0 (o gatilho valida o cupao; os outros calculam o total)
        int encomendaId = encomendas.inserir(clienteId, pedido.moradaId(), cupaoId, portes);
        // 2) Linhas (o gatilho desconta o stock; sem stock => erro 547 => 409)
        encomendas.inserirLinhasDoCarrinho(encomendaId, clienteId);
        // 3) Total ja calculado pelos gatilhos -> Pagamento Pendente
        BigDecimal total = encomendas.lerTotal(encomendaId);
        encomendas.inserirPagamento(encomendaId, pedido.metodoPagamento().trim(), total);
        // 4) Esvaziar o carrinho
        carrinhos.esvaziar(clienteId);

        return encomendas.buscar(encomendaId, clienteId, false).orElseThrow();
    }

    /** Pagamento: Pagamento -> Processado e Encomenda -> Paga (so se estiver Pendente). */
    @Transactional
    public Encomenda pagar(int encomendaId, int clienteId) {
        String estado = encomendas.estadoDoCliente(encomendaId, clienteId)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Encomenda nao encontrada"));
        if (!"Pendente".equals(estado)) {
            throw ExcecaoApi.conflito("A encomenda ja nao esta pendente");
        }
        encomendas.atualizarEstadoPagamento(encomendaId, "Processado");
        encomendas.atualizarEstado(encomendaId, "Paga");
        return encomendas.buscar(encomendaId, clienteId, false).orElseThrow();
    }

    /** Cancelamento: se estava Paga, reembolsa; o gatilho repoe o stock e valida a transicao. */
    @Transactional
    public Encomenda cancelar(int encomendaId, int clienteId) {
        String estado = encomendas.estadoDoCliente(encomendaId, clienteId)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Encomenda nao encontrada"));
        if ("Cancelada".equals(estado)) {
            throw ExcecaoApi.conflito("A encomenda ja esta cancelada");
        }
        if ("Paga".equals(estado)) {
            encomendas.atualizarEstadoPagamento(encomendaId, "Reembolsado");
        }
        // Enviada/Entregue/Cancelada: o gatilho lanca 50003 e a transacao faz rollback (409)
        encomendas.atualizarEstado(encomendaId, "Cancelada");
        return encomendas.buscar(encomendaId, clienteId, false).orElseThrow();
    }

    /** Alteracao de estado pelo administrador (os gatilhos validam a transicao). */
    @Transactional
    public Encomenda alterarEstado(int encomendaId, String novoEstado) {
        String estadoAtual = encomendas.buscar(encomendaId, null, false)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Encomenda nao encontrada")).estado();
        // Mantem o Pagamento coerente com a Encomenda (se o gatilho recusar a transicao, tudo faz rollback)
        if ("Paga".equals(novoEstado)) {
            encomendas.atualizarEstadoPagamento(encomendaId, "Processado");
        }
        if ("Cancelada".equals(novoEstado) && "Paga".equals(estadoAtual)) {
            encomendas.atualizarEstadoPagamento(encomendaId, "Reembolsado");
        }
        encomendas.atualizarEstado(encomendaId, novoEstado);
        return encomendas.buscar(encomendaId, null, true).orElseThrow();
    }
}
