package com.ecommerce.controlador;

import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.ClienteAdmin;
import com.ecommerce.modelo.Devolucao;
import com.ecommerce.modelo.Encomenda;
import com.ecommerce.modelo.EstadoPedido;
import com.ecommerce.modelo.Produto;
import com.ecommerce.modelo.ProdutoPedido;
import com.ecommerce.modelo.Resumo;
import com.ecommerce.repositorio.RepositorioAdmin;
import com.ecommerce.repositorio.RepositorioCliente;
import com.ecommerce.repositorio.RepositorioDevolucao;
import com.ecommerce.repositorio.RepositorioEncomenda;
import com.ecommerce.repositorio.RepositorioProduto;
import com.ecommerce.servico.DevolucaoServico;
import com.ecommerce.servico.EncomendaServico;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Rotas /api/admin/** (o acesso de administrador e verificado pelo InterceptorSessao). */
@RestController
public class AdminControlador {

    private static final Set<String> ESTADOS_ENCOMENDA =
            Set.of("Pendente", "Paga", "Enviada", "Entregue", "Cancelada");
    private static final Set<String> ESTADOS_DEVOLUCAO =
            Set.of("Pedida", "Aprovada", "Recusada", "Concluida");

    private final RepositorioProduto produtos;
    private final RepositorioEncomenda encomendas;
    private final RepositorioDevolucao devolucoes;
    private final RepositorioCliente clientes;
    private final RepositorioAdmin admin;
    private final EncomendaServico encomendaServico;
    private final DevolucaoServico devolucaoServico;

    public AdminControlador(RepositorioProduto produtos, RepositorioEncomenda encomendas,
                            RepositorioDevolucao devolucoes, RepositorioCliente clientes,
                            RepositorioAdmin admin, EncomendaServico encomendaServico,
                            DevolucaoServico devolucaoServico) {
        this.produtos = produtos;
        this.encomendas = encomendas;
        this.devolucoes = devolucoes;
        this.clientes = clientes;
        this.admin = admin;
        this.encomendaServico = encomendaServico;
        this.devolucaoServico = devolucaoServico;
    }

    // ------------------------------------------------------------ Produtos

    @GetMapping("/api/admin/produtos")
    public List<Produto> listarProdutos() {
        return produtos.listar(null, null, null, false);
    }

    @PostMapping("/api/admin/produtos")
    @ResponseStatus(HttpStatus.CREATED)
    public Produto criarProduto(@RequestBody ProdutoPedido pedido) {
        validar(pedido);
        int id = produtos.criar(pedido);
        return produtos.buscar(id).orElseThrow();
    }

    @PutMapping("/api/admin/produtos/{id}")
    public Produto atualizarProduto(@PathVariable int id, @RequestBody ProdutoPedido pedido) {
        validar(pedido);
        Produto atual = produtos.buscar(id)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Produto nao encontrado"));
        boolean ativo = pedido.ativo() != null ? pedido.ativo() : atual.ativo();
        ProdutoPedido completo = new ProdutoPedido(pedido.sku(), pedido.nome(),
                pedido.descricao() != null ? pedido.descricao() : atual.descricao(),
                pedido.preco(),
                pedido.estoque() != null ? pedido.estoque() : atual.estoque(),
                pedido.imagem() != null ? pedido.imagem() : atual.imagem(),
                pedido.categoriaId(),
                pedido.fornecedorId() != null ? pedido.fornecedorId() : atual.fornecedorId(),
                pedido.ativo());
        produtos.atualizar(id, completo, ativo);
        return produtos.buscar(id).orElseThrow();
    }

    @DeleteMapping("/api/admin/produtos/{id}")
    public Map<String, String> desativarProduto(@PathVariable int id) {
        if (produtos.buscar(id).isEmpty()) {
            throw ExcecaoApi.naoEncontrado("Produto nao encontrado");
        }
        produtos.desativar(id);
        return Map.of("message", "Produto desativado");
    }

    private static void validar(ProdutoPedido p) {
        if (p.sku() == null || p.sku().isBlank() || p.nome() == null || p.nome().isBlank()
                || p.categoriaId() == null) {
            throw ExcecaoApi.pedidoInvalido("SKU, nome e categoria sao obrigatorios");
        }
        if (p.preco() == null || p.preco().compareTo(BigDecimal.ZERO) <= 0) {
            throw ExcecaoApi.pedidoInvalido("O preco deve ser superior a zero");
        }
        if (p.estoque() != null && p.estoque() < 0) {
            throw ExcecaoApi.pedidoInvalido("O stock nao pode ser negativo");
        }
    }

    // ------------------------------------------------------------ Encomendas

    @GetMapping("/api/admin/encomendas")
    public List<Encomenda> listarEncomendas(@RequestParam(required = false) String estado) {
        return encomendas.listar(null, estado, true);
    }

    @PutMapping("/api/admin/encomendas/{id}/estado")
    public Encomenda alterarEstadoEncomenda(@PathVariable int id, @RequestBody EstadoPedido pedido) {
        if (pedido.estado() == null || !ESTADOS_ENCOMENDA.contains(pedido.estado())) {
            throw ExcecaoApi.pedidoInvalido("Estado de encomenda invalido");
        }
        return encomendaServico.alterarEstado(id, pedido.estado());
    }

    // ------------------------------------------------------------ Devolucoes

    @GetMapping("/api/admin/devolucoes")
    public List<Devolucao> listarDevolucoes() {
        return devolucoes.listar(null);
    }

    @PutMapping("/api/admin/devolucoes/{id}/estado")
    public Map<String, String> alterarEstadoDevolucao(@PathVariable int id, @RequestBody EstadoPedido pedido) {
        if (pedido.estado() == null || !ESTADOS_DEVOLUCAO.contains(pedido.estado())) {
            throw ExcecaoApi.pedidoInvalido("Estado de devolucao invalido");
        }
        devolucaoServico.alterarEstado(id, pedido.estado());
        return Map.of("message", "Estado da devolucao atualizado", "estado", pedido.estado());
    }

    // ------------------------------------------------------------ Clientes, relatorios, resumo

    @GetMapping("/api/admin/clientes")
    public List<ClienteAdmin> listarClientes() {
        return clientes.listarAdmin();
    }

    @GetMapping("/api/admin/relatorios/{nome}")
    public List<Map<String, Object>> relatorio(@PathVariable String nome) {
        return admin.relatorio(nome)
                .orElseThrow(() -> ExcecaoApi.naoEncontrado("Relatorio desconhecido"));
    }

    @GetMapping("/api/admin/resumo")
    public Resumo resumo() {
        return admin.resumo();
    }
}
