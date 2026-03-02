import { getSummary, getTicker, getOrderBook, getTrades, getMarketHistory } from './marketdata-xbts.js';
import { xbtsTickerFromSymbol, symbolFromXbtsTicker } from './symbols.js';
import { Signer } from './signer-btsdex.js';
export class BitSharesCCXT {
    id = 'bitshares-dex';
    name = 'BitShares DEX (CCXT bridge)';
    signer = new Signer();
    marketsCache = [];
    setAccountName(account) {
        this.signer.setAccountName(account);
    }
    async describe() {
        const summary = await getSummary();
        this.marketsCache = Object.entries(summary.tickers).map(([k, v]) => ({
            id: k,
            symbol: symbolFromXbtsTicker(k),
            base: v.base_symbol,
            quote: v.quote_symbol,
            baseId: v.base_id ?? v.base_symbol,
            quoteId: v.quote_id ?? v.quote_symbol,
            active: v.isFrozen === 0,
            type: 'spot',
            spot: true,
            margin: false,
            swap: false,
            future: false,
            option: false,
            contract: false,
            taker: 0.001,
            maker: 0.001,
            // Best-effort precision/limits since XBTS summary does not expose them directly
            precision: { price: 8, amount: 8 },
            limits: {
                amount: { min: undefined, max: undefined },
                price: { min: undefined, max: undefined },
                cost: { min: undefined, max: undefined },
            },
            info: v
        }));
        return { id: this.id, name: this.name };
    }
    async fetchMarkets() {
        if (!this.marketsCache.length)
            await this.describe();
        return this.marketsCache;
    }
    async fetchTicker(symbol) {
        const t = await getTicker(xbtsTickerFromSymbol(symbol));
        const k = Object.keys(t)[0];
        const v = t[k];
        return {
            symbol,
            last: parseFloat(v.last),
            bid: parseFloat(v.buy),
            ask: parseFloat(v.sell),
            baseVolume: parseFloat(v.base_volume),
            quoteVolume: parseFloat(v.quote_volume),
            percentage: parseFloat(v.change),
            timestamp: v.timestamp ? v.timestamp * 1000 : Date.now(),
            info: v
        };
    }
    async fetchOrderBook(symbol, limit = 50) {
        const ob = await getOrderBook(xbtsTickerFromSymbol(symbol), limit);
        return {
            symbol,
            timestamp: ob.timestamp * 1000,
            bids: ob.bids.map((b) => [parseFloat(b.price), parseFloat(b.quote)]),
            asks: ob.asks.map((a) => [parseFloat(a.price), parseFloat(a.quote)]),
            info: ob
        };
    }
    async fetchTrades(symbol, since, limit = 100) {
        const raw = await getTrades(xbtsTickerFromSymbol(symbol), limit);
        return raw
            .map((t) => ({
            id: String(t.trade_id),
            symbol,
            timestamp: t.timestamp * 1000,
            datetime: new Date(t.timestamp * 1000).toISOString(),
            price: parseFloat(t.price),
            amount: parseFloat(t.quote_volume),
            side: t.type === 'sell' ? 'sell' : 'buy',
            info: t
        }))
            .filter((x) => !since || x.timestamp >= since);
    }
    async fetchOHLCV(symbol, timeframe) {
        // timeframe currently ignored by backend; placeholder for future support
        const raw = await getMarketHistory(xbtsTickerFromSymbol(symbol), timeframe);
        return raw.map((c) => [
            Date.parse(c.date),
            parseFloat(c.open_price),
            parseFloat(c.high_price),
            parseFloat(c.low_price),
            parseFloat(c.close_price),
            parseFloat(c.base_volume)
        ]);
    }
    async fetchCurrencies() {
        // Get currencies from markets cache
        if (!this.marketsCache.length)
            await this.describe();
        const currencies = {};
        this.marketsCache.forEach(market => {
            if (!currencies[market.base]) {
                currencies[market.base] = {
                    id: market.base,
                    code: market.base,
                    name: market.base,
                    active: true,
                    fee: undefined,
                    precision: 8,
                    limits: {
                        amount: { min: undefined, max: undefined },
                        withdraw: { min: undefined, max: undefined }
                    },
                    info: {}
                };
            }
            if (!currencies[market.quote]) {
                currencies[market.quote] = {
                    id: market.quote,
                    code: market.quote,
                    name: market.quote,
                    active: true,
                    fee: undefined,
                    precision: 8,
                    limits: {
                        amount: { min: undefined, max: undefined },
                        withdraw: { min: undefined, max: undefined }
                    },
                    info: {}
                };
            }
        });
        return currencies;
    }
    async fetchTradingFees() {
        // BitShares DEX typically has 0.1% maker/taker fees
        return {
            trading: {
                maker: 0.001,
                taker: 0.001,
                percentage: true,
                tierBased: false
            },
            funding: {
                withdraw: {},
                deposit: {}
            }
        };
    }
    async fetchOrder(id, symbol) {
        const orders = await this.fetchOpenOrders();
        const order = orders.find((o) => o.id === id);
        if (!order) {
            throw new Error(`Order ${id} not found`);
        }
        return order;
    }
    async fetchOrders(symbol, since, limit) {
        // For now, return only open orders as BitShares doesn't provide easy access to order history
        return this.fetchOpenOrders(symbol, since, limit);
    }
    async fetchMyTrades(symbol, since, limit) {
        // Get account history for trades
        await this.signer.connect();
        const accountName = this.signer.accountName;
        if (!accountName) {
            throw new Error('Must be logged in to fetch trades');
        }
        // This is a simplified implementation - in practice would need to parse account history
        // BitShares account history contains fill orders which represent trades
        return [];
    }
    async editOrder(id, symbol, type, side, amount, price, params) {
        // BitShares doesn't support direct order editing, need to cancel and recreate
        await this.cancelOrder(id);
        return this.createOrder(symbol, type, side, amount, price, params);
    }
    async fetchTradingLimits(symbols) {
        // Return basic limits structure - BitShares has flexible limits
        const limits = {};
        const markets = symbols ?
            this.marketsCache.filter(m => symbols.includes(m.symbol)) :
            this.marketsCache;
        markets.forEach(market => {
            limits[market.symbol] = {
                amount: { min: 0.00000001, max: 1000000000 },
                price: { min: 0.00000001, max: 1000000000 },
                cost: { min: 0.00000001, max: undefined }
            };
        });
        return limits;
    }
    async login(account, keyOrPassword, isPassword = false, node) {
        await this.signer.connect(node);
        await this.signer.login(account, keyOrPassword, isPassword);
    }
    async fetchBalance() {
        return this.signer.balances();
    }
    async fetchPublicBalance(account) {
        return this.signer.publicBalances(account);
    }
    async createOrder(symbol, type, side, amount, price, params) {
        if (type !== 'limit')
            throw new Error('Only limit orders supported');
        return this.signer.createLimitOrder(symbol, side, amount, price, params);
    }
    async cancelOrder(id) {
        return this.signer.cancelOrder(id);
    }
    async fetchOpenOrders(symbol, since, limit) {
        const orders = await this.signer.openOrders();
        // Convert BitShares order format to CCXT format
        return orders.map((order) => ({
            id: order.id,
            clientOrderId: undefined,
            datetime: new Date(order.expiration).toISOString(),
            timestamp: new Date(order.expiration).getTime(),
            lastTradeTimestamp: undefined,
            symbol: `${order.sell_price.base.symbol}/${order.sell_price.quote.symbol}`,
            type: 'limit',
            timeInForce: 'GTC',
            side: order.sell_price.base.amount > 0 ? 'sell' : 'buy',
            amount: parseFloat(order.for_sale) / Math.pow(10, order.sell_price.base.precision || 8),
            price: parseFloat(order.sell_price.quote.amount) / parseFloat(order.sell_price.base.amount),
            cost: undefined,
            average: undefined,
            filled: 0,
            remaining: parseFloat(order.for_sale) / Math.pow(10, order.sell_price.base.precision || 8),
            status: 'open',
            fee: undefined,
            trades: undefined,
            info: order
        })).filter((order) => {
            if (symbol && order.symbol !== symbol)
                return false;
            if (since && order.timestamp < since)
                return false;
            return true;
        }).slice(0, limit);
    }
}
