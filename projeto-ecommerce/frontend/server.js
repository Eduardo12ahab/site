require('dotenv').config();
const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

// Proxy /api -> backend Java (registado ANTES de qualquer body parser).
// O cookie JSESSIONID passa nos dois sentidos (mesma origem para o browser).
const apiProxy = createProxyMiddleware({
    target: BACKEND_URL,
    changeOrigin: true,
    pathFilter: '/api',
    on: {
        error: (err, req, res) => {
            if (res && typeof res.writeHead === 'function' && !res.headersSent) {
                res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' });
                res.end(JSON.stringify({ message: 'Backend indisponível' }));
            } else if (res && typeof res.end === 'function') {
                res.end();
            }
        }
    }
});
app.use(apiProxy);

app.use(express.static(path.join(__dirname, 'public')));

const pagina = (...partes) => (req, res) => res.sendFile(path.join(__dirname, 'views', ...partes));

app.get('/', pagina('index.html'));
app.get('/produtos', pagina('produtos.html'));
app.get('/produto/:id', pagina('produto-detalhe.html'));
app.get('/carrinho', pagina('carrinho.html'));
app.get(['/checkout', '/checkout.html'], pagina('checkout.html'));
app.get('/encomendas', pagina('encomendas.html'));
app.get('/login', pagina('login.html'));
app.get('/cadastro', pagina('cadastro.html'));
app.get('/admin', pagina('admin', 'dashboard.html'));
app.get('/admin/produtos', pagina('admin', 'produtos.html'));
app.get('/admin/encomendas', pagina('admin', 'encomendas.html'));

app.get('/produto-:id', (req, res) => res.redirect(`/produto/${req.params.id}`));

app.listen(PORT, () => {
    console.log(`Frontend em http://localhost:${PORT} (API -> ${BACKEND_URL})`);
});
