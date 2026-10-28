package com.ecommerce.servico;

import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.Devolucao;
import com.ecommerce.modelo.DevolucaoPedido;
import com.ecommerce.modelo.ItemDevolucaoPedido;
import com.ecommerce.repositorio.RepositorioDevolucao;
import com.ecommerce.repositorio.RepositorioEncomenda;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class DevolucaoServico {

    private final RepositorioDevolucao devolucoes;
    private final RepositorioEncomenda encomendas;

    public DevolucaoServico(RepositorioDevolucao devolucoes, RepositorioEncomenda encomendas) {
        this.devolucoes = devolucoes;
        this.encomendas = encomendas;
    }

    /** Cria Devolucao + ItemDevolucao numa transacao (409 se a encomenda nao esta Entregue, via gatilho). */
    @Transactional
    public Devolucao criar(int clienteId, DevolucaoPedido p) {
        if (p.encomendaId() == null || p.itens() == null || p.itens().isEmpty()) {
            throw ExcecaoApi.pedidoInvalido("Indique a encomenda e os itens a devolver");
        }
        encomendas.estadoDoCliente(p.encomendaId(), clienteId)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Encomenda nao encontrada"));

        // O gatilho trg_Devolucao_SoEntregue rejeita aqui encomendas nao entregues
        int devolucaoId = devolucoes.criar(p.encomendaId(), p.motivo());
        for (ItemDevolucaoPedido item : p.itens()) {
            if (item.produtoId() == null || item.quantidade() == null || item.quantidade() < 1) {
                throw ExcecaoApi.pedidoInvalido("Item de devolucao invalido");
            }
            int comprada = devolucoes.quantidadeComprada(p.encomendaId(), item.produtoId());
            int jaDevolvida = devolucoes.quantidadeJaDevolvida(p.encomendaId(), item.produtoId());
            if (item.quantidade() + jaDevolvida > comprada) {
                throw ExcecaoApi.pedidoInvalido("Quantidade a devolver superior a comprada");
            }
            devolucoes.inserirItem(devolucaoId, item.produtoId(), item.quantidade());
        }
        List<Devolucao> doCliente = devolucoes.listar(clienteId);
        return doCliente.stream().filter(d -> d.id() == devolucaoId).findFirst().orElseThrow();
    }

    @Transactional
    public void alterarEstado(int devolucaoId, String estado) {
        String atual = devolucoes.estado(devolucaoId)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Devolucao nao encontrada"));
        // Transicoes permitidas: Pedida -> Aprovada | Recusada; Aprovada -> Concluida
        boolean permitida = ("Pedida".equals(atual) && ("Aprovada".equals(estado) || "Recusada".equals(estado)))
                || ("Aprovada".equals(atual) && "Concluida".equals(estado));
        if (!permitida) {
            throw ExcecaoApi.conflito("Transicao de estado da devolucao invalida");
        }
        devolucoes.atualizarEstado(devolucaoId, estado);
    }
}
