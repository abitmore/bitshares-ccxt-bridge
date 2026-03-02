import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { BitSharesCCXT } from '../adapter.js';
dotenv.config();
const app = express();
app.use(cors());
app.use(express.json());
const ex = new BitSharesCCXT();
const configuredAccount = process.env.BTS_ACCOUNT ? String(process.env.BTS_ACCOUNT).trim() : '';
const configuredWif = process.env.BTS_WIF ? String(process.env.BTS_WIF).trim() : '';
const configuredViewOnly = String(process.env.BTS_VIEW_ONLY || '').toLowerCase() === 'true';
if (configuredAccount && (configuredViewOnly || !configuredWif)) {
    ex.setAccountName(configuredAccount);
    console.log(`[startup] Account ${configuredAccount} loaded in view-only mode`);
}
// Small helper to wrap route handlers
const route = (fn) => (req, res) => fn(req, res).catch(err => {
    console.error(err);
    res.status(500).json({ error: err?.message || 'internal error' });
});
app.get('/describe', route(async (_req, res) => {
    res.json(await ex.describe());
}));
app.get('/markets', route(async (_req, res) => {
    res.json(await ex.fetchMarkets());
}));
app.get('/ticker', route(async (req, res) => {
    const { symbol } = req.query;
    if (!symbol)
        return res.status(400).json({ error: 'symbol required' });
    res.json(await ex.fetchTicker(String(symbol)));
}));
app.get('/orderbook', route(async (req, res) => {
    const { symbol, limit } = req.query;
    if (!symbol)
        return res.status(400).json({ error: 'symbol required' });
    res.json(await ex.fetchOrderBook(String(symbol), limit ? Number(limit) : 50));
}));
app.get('/trades', route(async (req, res) => {
    const { symbol, since, limit } = req.query;
    if (!symbol)
        return res.status(400).json({ error: 'symbol required' });
    const list = await ex.fetchTrades(String(symbol), since ? Number(since) : undefined, limit ? Number(limit) : 100);
    res.json(list);
}));
app.get('/ohlcv', route(async (req, res) => {
    const { symbol, timeframe } = req.query;
    if (!symbol)
        return res.status(400).json({ error: 'symbol required' });
    res.json(await ex.fetchOHLCV(String(symbol), timeframe ? String(timeframe) : undefined));
}));
// New CCXT compliance endpoints
app.get('/currencies', route(async (_req, res) => {
    res.json(await ex.fetchCurrencies());
}));
app.get('/tradingFees', route(async (_req, res) => {
    res.json(await ex.fetchTradingFees());
}));
app.get('/tradingLimits', route(async (req, res) => {
    const { symbols } = req.query;
    const symbolList = symbols ? String(symbols).split(',') : undefined;
    res.json(await ex.fetchTradingLimits(symbolList));
}));
app.get('/order/:id', route(async (req, res) => {
    const { id } = req.params;
    const { symbol } = req.query;
    res.json(await ex.fetchOrder(id, symbol ? String(symbol) : undefined));
}));
app.get('/orders', route(async (req, res) => {
    const { symbol, since, limit } = req.query;
    res.json(await ex.fetchOrders(symbol ? String(symbol) : undefined, since ? Number(since) : undefined, limit ? Number(limit) : undefined));
}));
app.get('/myTrades', route(async (req, res) => {
    const { symbol, since, limit } = req.query;
    res.json(await ex.fetchMyTrades(symbol ? String(symbol) : undefined, since ? Number(since) : undefined, limit ? Number(limit) : undefined));
}));
app.put('/order/:id', route(async (req, res) => {
    const { id } = req.params;
    const { symbol, type, side, amount, price, params } = req.body || {};
    if (!symbol || !type || !side || amount == null || price == null) {
        return res.status(400).json({ error: 'symbol, type, side, amount, price required' });
    }
    res.json(await ex.editOrder(id, String(symbol), String(type), String(side), Number(amount), Number(price), params));
}));
// Auth/account related endpoints
app.post('/login', route(async (req, res) => {
    const { account, keyOrPassword, isPassword, node } = req.body || {};
    if (!account || !keyOrPassword)
        return res.status(400).json({ error: 'account and keyOrPassword required' });
    await ex.login(String(account), String(keyOrPassword), Boolean(isPassword), node ? String(node) : undefined);
    res.json({ ok: true });
}));
app.get('/balance', route(async (_req, res) => {
    res.json(await ex.fetchBalance());
}));
// Public balance by account (no login required)
app.get('/balancePublic', route(async (req, res) => {
    const { account } = req.query;
    if (!account)
        return res.status(400).json({ error: 'account required' });
    const data = await ex.fetchPublicBalance(String(account));
    res.json(data);
}));
app.get('/openOrders', route(async (req, res) => {
    const { symbol, since, limit } = req.query;
    res.json(await ex.fetchOpenOrders(symbol ? String(symbol) : undefined, since ? Number(since) : undefined, limit ? Number(limit) : undefined));
}));
app.post('/order', route(async (req, res) => {
    const { symbol, type, side, amount, price, params } = req.body || {};
    if (!symbol || !type || !side || amount == null || price == null) {
        return res.status(400).json({ error: 'symbol, type, side, amount, price required' });
    }
    const result = await ex.createOrder(String(symbol), String(type), String(side), Number(amount), Number(price), params);
    res.json(result);
}));
app.delete('/order', route(async (req, res) => {
    const { id } = req.query;
    if (!id)
        return res.status(400).json({ error: 'id required' });
    const result = await ex.cancelOrder(String(id));
    res.json(result);
}));
const port = process.env.PORT || 8787;
app.listen(port, () => {
    console.log(`BitShares CCXT REST API running on port ${port}`);
});
