// ==================================================
// Biblioteca partilhada por todas as páginas.
// Todo o estado (sessão, carrinho, encomendas) vive no backend: aqui só há chamadas à API.
// ==================================================

// Imagem por defeito (SVG inline, sem pedidos de rede)
const IMG_PLACEHOLDER = 'data:image/svg+xml;utf8,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">' +
    '<rect width="400" height="400" fill="#e5e7eb"/>' +
    '<g fill="none" stroke="#9ca3af" stroke-width="12" stroke-linejoin="round">' +
    '<rect x="120" y="130" width="160" height="140" rx="14"/><circle cx="170" cy="180" r="14"/>' +
    '<path d="M130 255l50-45 35 30 25-20 30 35"/></g></svg>');

function escapeHtml(valor) {
    return String(valor === null || valor === undefined ? '' : valor)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function formatarMoeda(valor) {
    return new Intl.NumberFormat('pt-PT', { style: 'currency', currency: 'EUR' }).format(Number(valor) || 0);
}

function formatarData(valor) {
    if (!valor) return '';
    const d = new Date(valor);
    return isNaN(d) ? String(valor) : d.toLocaleString('pt-PT', { dateStyle: 'short', timeStyle: 'short' });
}

// <img> seguro: URL escapado e fallback para o SVG por defeito
function imgTag(url, alt, classe) {
    return `<img src="${escapeHtml(url || IMG_PLACEHOLDER)}" alt="${escapeHtml(alt || '')}"` +
        `${classe ? ` class="${escapeHtml(classe)}"` : ''} loading="lazy" ` +
        `onerror="this.onerror=null;this.src=IMG_PLACEHOLDER">`;
}

// Cor do selo de estado (encomendas, pagamentos, devoluções)
function badgeEstado(estado) {
    const cores = {
        Pendente: ['#fef3c7', '#92400e'], Pedida: ['#fef3c7', '#92400e'],
        Paga: ['#dbeafe', '#1e40af'], Aprovada: ['#dbeafe', '#1e40af'], Processado: ['#dbeafe', '#1e40af'],
        Enviada: ['#e0e7ff', '#3730a3'],
        Entregue: ['#d1fae5', '#065f46'], Concluida: ['#d1fae5', '#065f46'],
        Cancelada: ['#fee2e2', '#991b1b'], Recusada: ['#fee2e2', '#991b1b'], Falhado: ['#fee2e2', '#991b1b'],
        Reembolsado: ['#f3e8ff', '#6b21a8']
    };
    const c = cores[estado] || ['#e5e7eb', '#374151'];
    return `<span class="badge-estado" style="background:${c[0]};color:${c[1]};">${escapeHtml(estado)}</span>`;
}

// Aviso temporário no canto do ecrã
function mostrarAviso(mensagem, tipo) {
    const ok = tipo !== 'error';
    const el = document.createElement('div');
    el.textContent = mensagem;
    el.setAttribute('role', 'alert');
    el.style.cssText = 'position:fixed;top:20px;right:20px;z-index:10000;padding:1rem;border-radius:.5rem;' +
        'min-width:260px;max-width:90vw;font-size:.9rem;box-shadow:0 4px 12px rgba(0,0,0,.15);' +
        (ok ? 'background:#d1fae5;color:#065f46;border:1px solid #a7f3d0;'
            : 'background:#fee2e2;color:#991b1b;border:1px solid #fecaca;');
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 3500);
}

function irParaLogin() {
    location.href = '/login?next=' + encodeURIComponent(location.pathname + location.search);
}

// Chamada à API (mesma origem; o cookie JSESSIONID segue automaticamente).
// Devolve o JSON (ou null). Em erro lança Error com .status e a mensagem da API.
// 401 fora de login/sessão -> redireciona para /login?next=...
async function api(metodo, url, corpo, opcoes) {
    const opts = opcoes || {};
    const init = { method: metodo, credentials: 'same-origin', headers: { 'Accept': 'application/json' } };
    if (corpo !== undefined && corpo !== null) {
        init.headers['Content-Type'] = 'application/json';
        init.body = JSON.stringify(corpo);
    }
    let resp;
    try {
        resp = await fetch(url, init);
    } catch (e) {
        const err = new Error('Sem ligação ao servidor');
        err.status = 0;
        throw err;
    }
    let dados = null;
    const texto = await resp.text();
    if (texto) {
        try { dados = JSON.parse(texto); } catch (e) { dados = null; }
    }
    if (!resp.ok) {
        const err = new Error((dados && dados.message) || ('Erro ' + resp.status));
        err.status = resp.status;
        if (resp.status === 401 && !opts.semRedirect) irParaLogin();
        throw err;
    }
    return dados;
}

// ---------- Sessão e menu ----------
const Tyvora = {
    user: null,
    async carregarUser() {
        try {
            this.user = await api('GET', '/api/usuario/atual', null, { semRedirect: true });
        } catch (e) {
            this.user = null;
        }
        return this.user;
    },
    // Para páginas que exigem login: redireciona se não houver sessão
    async exigirLogin() {
        await this.pronto;
        if (!this.user) { irParaLogin(); return null; }
        return this.user;
    },
    async exigirAdmin() {
        const u = await this.exigirLogin();
        if (!u) return null;
        if (!u.isAdmin) { location.href = '/'; return null; }
        return u;
    },
    async logout() {
        try { await api('POST', '/api/logout', null, { semRedirect: true }); } catch (e) { /* ignora */ }
        location.href = '/';
    },
    async atualizarContador() {
        let total = 0;
        if (this.user) {
            try {
                const itens = await api('GET', '/api/carrinho', null, { semRedirect: true });
                total = (itens || []).reduce((s, i) => s + (Number(i.quantidade) || 0), 0);
            } catch (e) { total = 0; }
        }
        document.querySelectorAll('.cart-count').forEach(el => {
            el.textContent = total;
            // '' devolve o display definido no CSS de cada página (inline-flex, flex...)
            el.style.display = total > 0 ? '' : 'none';
        });
    },
    // Menu comum: Início, Produtos, Minhas encomendas, Administração, Login/Sair, Carrinho
    desenharNav() {
        const u = this.user;
        const p = location.pathname;
        const ativo = (href) => ((href === '/' ? p === '/' : p === href || p.startsWith(href + '/')) ? ' active' : '');
        const link = (href, texto) => `<li><a href="${href}" class="nav-link${ativo(href)}">${texto}</a></li>`;
        let html = link('/', 'Início') + link('/produtos', 'Produtos');
        if (u) html += link('/encomendas', 'Minhas encomendas');
        if (u && u.isAdmin) html += link('/admin', 'Administração');
        html += u
            ? `<li><a href="#" class="nav-link" id="logout-btn" title="${escapeHtml(u.nome)}">Sair</a></li>`
            : `<li><a href="/login" class="nav-link">Iniciar sessão</a></li>`;
        html += `<li><button class="cart-btn" type="button" onclick="window.location.href='/carrinho'">` +
            `<i class="fas fa-shopping-bag"></i><span>Carrinho</span><span class="cart-count">0</span></button></li>`;
        document.querySelectorAll('ul.nav-links').forEach(ul => { ul.innerHTML = html; });
        // Variante sem <ul> (página de checkout): <nav class="nav"> com ligações diretas
        document.querySelectorAll('nav.nav').forEach(nav => {
            const a = (href, texto, extra) => `<a href="${href}" class="nav-link${ativo(href)}"${extra || ''}>${texto}</a>`;
            nav.innerHTML = a('/', 'Início') + a('/produtos', 'Produtos') +
                (u ? a('/encomendas', 'Minhas encomendas') : '') +
                (u && u.isAdmin ? a('/admin', 'Administração') : '') +
                (u ? a('#', 'Sair', ' id="logout-btn"') : a('/login', 'Iniciar sessão')) +
                `<a href="/carrinho" class="cart-button" aria-label="Abrir carrinho"><i class="fas fa-shopping-bag"></i>` +
                `<span class="cart-count">0</span></a>`;
        });
        document.querySelectorAll('#logout-btn').forEach(a => a.addEventListener('click', (e) => {
            e.preventDefault();
            Tyvora.logout();
        }));
    }
};

// Adicionar ao carrinho (POST /api/carrinho). Sem sessão -> /login?next=...
async function adicionarAoCarrinho(produtoId, quantidade, botao) {
    await Tyvora.pronto;
    if (!Tyvora.user) { irParaLogin(); return false; }
    try {
        await api('POST', '/api/carrinho', { produtoId: Number(produtoId), quantidade: quantidade || 1 });
        await Tyvora.atualizarContador();
        mostrarAviso('Produto adicionado ao carrinho');
        if (botao) {
            const original = botao.innerHTML;
            botao.innerHTML = '<i class="fas fa-check"></i> Adicionado!';
            botao.disabled = true;
            setTimeout(() => { botao.innerHTML = original; botao.disabled = false; }, 1200);
        }
        return true;
    } catch (e) {
        mostrarAviso(e.message, 'error');
        return false;
    }
}

// Cartão de produto (campos da API; promoções/destaques não existem)
function cartaoProduto(p) {
    const semStock = Number(p.estoque) === 0;
    const aval = Number(p.avaliacao) > 0
        ? `<div style="font-size:.8rem;color:var(--text-muted);margin-bottom:.4rem;">` +
          `<i class="fas fa-star" style="color:#f59e0b;"></i> ${Number(p.avaliacao).toFixed(1)}` +
          ` (${Number(p.numAvaliacoes) || 0})</div>` : '';
    return `
        <div class="produto-card">
            <div class="produto-img-container">${imgTag(p.imagem, p.nome, 'produto-img')}</div>
            <div class="produto-info">
                <div class="produto-categoria">${escapeHtml(p.categoria || '')}</div>
                <h3 class="produto-titulo">${escapeHtml(p.nome)}</h3>
                <p class="produto-descricao">${escapeHtml(p.descricao || '')}</p>
                ${aval}
                <div class="produto-preco"><span class="preco-atual">${formatarMoeda(p.preco)}</span></div>
                <div class="produto-acoes">
                    <button class="btn-add-cart" data-id="${escapeHtml(p.id)}" type="button"${semStock ? ' disabled' : ''}>
                        <i class="fas fa-cart-plus"></i> ${semStock ? 'Esgotado' : 'Adicionar'}
                    </button>
                    <button class="btn-detalhes" type="button" onclick="window.location.href='/produto/${encodeURIComponent(p.id)}'">Detalhes</button>
                </div>
            </div>
        </div>`;
}

// Liga os botões "Adicionar" dentro de um contentor
function ligarBotoesAdicionar(contentor) {
    contentor.querySelectorAll('.btn-add-cart').forEach(btn => {
        btn.addEventListener('click', () => adicionarAoCarrinho(btn.dataset.id, 1, btn));
    });
}

Tyvora.pronto = new Promise((resolve) => {
    const iniciar = async () => {
        await Tyvora.carregarUser();
        Tyvora.desenharNav();
        await Tyvora.atualizarContador();
        resolve(Tyvora.user);
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar);
    else iniciar();
});
