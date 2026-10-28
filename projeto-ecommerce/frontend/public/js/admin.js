// Estrutura comum das páginas de administração (requer main.js)

function mensagemErro(el, texto) {
    el.innerHTML = `<div class="msg-erro">${escapeHtml(texto)}</div>`;
}

// Desenha a barra lateral e o topo; devolve o utilizador admin (ou null se redirecionou)
async function iniciarAdmin(ativo) {
    const user = await Tyvora.exigirAdmin();
    if (!user) return null;
    const itens = [
        ['/admin', 'fa-tachometer-alt', 'Painel'],
        ['/admin/produtos', 'fa-box', 'Produtos'],
        ['/admin/encomendas', 'fa-shopping-cart', 'Encomendas, devoluções e relatórios'],
        ['/', 'fa-store', 'Ver loja']
    ];
    const aside = document.getElementById('admin-sidebar');
    if (aside) {
        aside.innerHTML = `
            <div class="admin-logo"><div class="logo"><i class="fas fa-cog logo-icon"></i> TYVORA ADMIN</div></div>
            <nav><ul class="admin-nav">${itens.map(i =>
                `<li><a href="${i[0]}" class="${i[0] === ativo ? 'active' : ''}"><i class="fas ${i[1]}"></i> ${i[2]}</a></li>`
            ).join('')}</ul></nav>`;
    }
    const quem = document.getElementById('admin-user');
    if (quem) {
        quem.innerHTML = `<span>${escapeHtml(user.nome)}</span>
            <button type="button" class="btn btn-outline" id="admin-sair"><i class="fas fa-sign-out-alt"></i> Sair</button>`;
        document.getElementById('admin-sair').addEventListener('click', () => Tyvora.logout());
    }
    return user;
}

// Tabela genérica a partir de um array de objetos
function tabelaGenerica(linhas) {
    if (!linhas || linhas.length === 0) return '<p class="msg-vazio">Sem resultados.</p>';
    const colunas = Object.keys(linhas[0]);
    const celula = (v) => (v === null || v === undefined) ? '' :
        (typeof v === 'object' ? JSON.stringify(v) : String(v));
    return `<div class="tabela-wrap"><table class="tabela"><thead><tr>${
        colunas.map(c => `<th>${escapeHtml(c)}</th>`).join('')}</tr></thead><tbody>${
        linhas.map(l => `<tr>${colunas.map(c => `<td>${escapeHtml(celula(l[c]))}</td>`).join('')}</tr>`).join('')
    }</tbody></table></div>`;
}
