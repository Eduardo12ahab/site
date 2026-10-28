package com.ecommerce.servico;

import com.ecommerce.excecao.ExcecaoApi;
import com.ecommerce.modelo.CadastroPedido;
import com.ecommerce.modelo.Utilizador;
import com.ecommerce.repositorio.RepositorioCarrinho;
import com.ecommerce.repositorio.RepositorioCliente;
import com.ecommerce.repositorio.RepositorioCliente.Credenciais;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
public class AutenticacaoServico {

    private final RepositorioCliente clientes;
    private final RepositorioCarrinho carrinhos;
    private final PasswordEncoder codificador;

    public AutenticacaoServico(RepositorioCliente clientes, RepositorioCarrinho carrinhos,
                               PasswordEncoder codificador) {
        this.clientes = clientes;
        this.carrinhos = carrinhos;
        this.codificador = codificador;
    }

    /** Regista o cliente e cria o respetivo carrinho, numa unica transacao. */
    @Transactional
    public int registar(CadastroPedido p) {
        if (vazio(p.nome()) || vazio(p.email()) || vazio(p.senha())) {
            throw ExcecaoApi.pedidoInvalido("Nome, email e senha sao obrigatorios");
        }
        if (p.senha().length() < 6) {
            throw ExcecaoApi.pedidoInvalido("A senha deve ter pelo menos 6 caracteres");
        }
        String email = p.email().trim().toLowerCase();
        if (clientes.buscarPorEmail(email).isPresent()) {
            throw ExcecaoApi.conflito("Ja existe uma conta com esse email");
        }
        // Email duplicado em corrida: a UNIQUE da BD (erro 2627) tambem da 409
        int id = clientes.criar(p.nome().trim(), email, codificador.encode(p.senha()),
                vazio(p.telefone()) ? null : p.telefone().trim(), vazio(p.nif()) ? null : p.nif().trim());
        carrinhos.criarCarrinho(id);
        return id;
    }

    /** Valida o login; devolve o utilizador ou lanca 401. */
    @Transactional
    public Utilizador autenticar(String email, String senha) {
        if (vazio(email) || vazio(senha)) {
            throw ExcecaoApi.pedidoInvalido("Email e senha sao obrigatorios");
        }
        Optional<Credenciais> encontrado = clientes.buscarPorEmail(email.trim().toLowerCase());
        if (encontrado.isEmpty()) {
            throw ExcecaoApi.naoAutenticado("Email ou senha invalidos");
        }
        Credenciais c = encontrado.get();
        String hash = c.passwordHash() == null ? "" : c.passwordHash();
        boolean valida;
        if (hash.startsWith("$2")) {
            valida = codificador.matches(senha, hash);
        } else {
            // Dados antigos (texto simples): compara e, se coincidir, passa a BCrypt
            valida = hash.equals(senha);
            if (valida) {
                clientes.atualizarHash(c.id(), codificador.encode(senha));
            }
        }
        if (!valida) {
            throw ExcecaoApi.naoAutenticado("Email ou senha invalidos");
        }
        return new Utilizador(c.id(), c.nome(), c.email(), "Admin".equals(c.papel()));
    }

    private static boolean vazio(String s) {
        return s == null || s.isBlank();
    }
}
