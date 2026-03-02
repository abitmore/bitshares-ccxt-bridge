#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="bitshares-ccxt-bridge"
PROJECT_DIR="$PWD/$PROJECT_NAME"

log() { echo -e "\033[1;32m[INFO]\033[0m $*"; }

log "Creating project folder..."
mkdir -p "$PROJECT_DIR"/{src/rest,test}
cd "$PROJECT_DIR"

log "Writing .env.example..."
cat > .env.example <<'EOF'
XBTS_API=https://cmc.xbts.io/v2
BTS_NODE=wss://node.xbts.io/ws
BTS_ACCOUNT=youraccount
BTS_WIF=yourprivateactivekey
PORT=8787
EOF
log "Writing package.json..."
cat > package.json <<'EOF'
{
  "name": "bitshares-ccxt-bridge",
  "version": "0.2.0",
  "type": "module",
  "scripts": {
    "dev": "ts-node-dev src/rest/server.ts",
    "build": "tsc",
    "start": "node dist/rest/server.js",
    "test": "jest"
  },
  "dependencies": {
    "axios": "^1.7.2",
    "btsdex": "^0.7.9",
    "ccxt": "^4.3.0",
    "dotenv": "^16.4.5",
    "express": "^4.19.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/jest": "^29.5.12",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.1",
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.4.5"
  }
}
EOF

log "Writing tsconfig.json..."
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "moduleResolution": "node",
    "outDir": "dist",
    "rootDir": "src",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true
  }
}
EOF

log "Writing README.md..."
cat > README.md <<'EOF'
# BitShares CCXT Bridge

CCXT-compatible adapter for BitShares DEX using XBTS API + btsdex signer.

See `.env.example` for configuration.
EOF

log "Writing Dockerfile..."
cat > Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ENV NODE_ENV=production
EXPOSE 8787
CMD ["node","dist/rest/server.js"]
EOF

log "Writing docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: "3.9"
services:
  bts-ccxt:
    build: .
    environment:
      - XBTS_API=https://cmc.xbts.io/v2
      - BTS_NODE=wss://node.xbts.io/ws
      - BTS_ACCOUNT=${BTS_ACCOUNT}
      - BTS_WIF=${BTS_WIF}
      - PORT=8787
    ports:
      - "8787:8787"
EOF

log "Writing src/symbols.ts..."
cat > src/symbols.ts <<'EOF'
export type Pair = { base: string; quote: string };

export function parseSymbol(symbol: string): Pair {
  const [base, quote] = symbol.split('/');
  if (!base || !quote) throw new Error(`Invalid symbol: ${symbol}`);
  return { base: base.trim(), quote: quote.trim() };
}

export function xbtsTickerFromSymbol(symbol: string) {
  const { base, quote } = parseSymbol(symbol);
  return `${base}_${quote}`;
}

export function symbolFromXbtsTicker(t: string) {
  const [base, quote] = t.split('_');
  return `${base}/${quote}`;
}
EOF

log "Writing src/marketdata-xbts.ts..."
cat > src/marketdata-xbts.ts <<'EOF'
import axios from 'axios';

const BASE = process.env.XBTS_API || 'https://cmc.xbts.io/v2';

export async function getSummary() {
  return (await axios.get(`${BASE}/summary`)).data;
}

export async function getTicker(pair: string) {
  return (await axios.get(`${BASE}/tickers/${pair}`)).data;
}

export async function getOrderBook(pair: string, depth = 50) {
  return (await axios.get(`${BASE}/orderbook/${pair}`, { params: { depth } })).data;
}

export async function getTrades(pair: string, limit = 100) {
  return (await axios.get(`${BASE}/trades/${pair}`, { params: { limit } })).data;
}

export async function getMarketHistory(pair: string) {
  return (await axios.get(`${BASE}/history/market/${pair}`)).data;
}
EOF

log "Writing src/signer-btsdex.ts..."
cat > src/signer-btsdex.ts <<'EOF'
import BitShares from 'btsdex';
import { parseSymbol } from './symbols.js';

export class Signer {
  private accountName!: string;
  private connected = false;
  private acc: any | null = null;

  async connect(node?: string) {
    if (!this.connected) {
      await (node ? BitShares.connect(node) : BitShares.connect());
      this.connected = true;
    }
  }

  async login(accountName: string, wifOrPassword: string, isPassword = false) {
    await this.connect();
    this.accountName = accountName;
    this.acc = isPassword
      ? await BitShares.login(accountName, wifOrPassword)
      : new (BitShares as any)(accountName, wifOrPassword);
    return this.acc;
  }

  async balances() {
    const iam = await (BitShares as any).accounts[this.accountName];
    return iam.balances;
  }

  async createLimitOrder(
    symbol: string,
    side: 'buy' | 'sell',
    amount: number,
    price: number,
    params?: { fillOrKill?: boolean; expire?: string }
  ) {
    const { base, quote } = parseSymbol(symbol);
    if (side === 'buy') {
      return this.acc.buy(quote, base, amount, price, params?.fillOrKill ?? false, params?.expire);
    }
    return this.acc.sell(base, quote, amount, price, params?.fillOrKill ?? false, params?.expire);
  }

  async cancelOrder(orderId: string) {
    return this.acc.cancelOrder(orderId);
  }

  async openOrders() {
    const iam = await (BitShares as any).accounts[this.accountName];
    const full = await (BitShares as any).db.get_full_accounts([iam.id], false);
    return full[0][1].limit_orders;
  }
}
EOF

log "Writing src/adapter.ts..."
cat > src/adapter.ts <<'EOF'
import { getSummary, getTicker, getOrderBook, getTrades, getMarketHistory } from './marketdata-xbts.js';
import { xbtsTickerFromSymbol, symbolFromXbtsTicker } from './symbols.js';
import { Signer } from './signer-btsdex.js';

export class BitSharesCCXT {
  id = 'bitshares-dex';
  name = 'BitShares DEX (CCXT bridge)';
  signer = new Signer();
  marketsCache: any[] = [];

  async describe() {
    const summary = await getSummary();
    this.marketsCache = Object.entries(summary.tickers).map(([k, v]: any) => ({
      id: k,
      symbol: symbolFromXbtsTicker(k),
      base: v.base_symbol,
      quote: v.quote_symbol,
      active: v.isFrozen === 0,
      type: 'spot',
      spot: true
    }));
    return { id: this.id, name: this.name };
  }

  async fetchMarkets() {
    if (!this.marketsCache.length) await this.describe();
    return this.marketsCache;
  }

  async fetchTicker(symbol: string) {
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

  async fetchOrderBook(symbol: string, limit = 50) {
    const ob = await getOrderBook(xbtsTickerFromSymbol(symbol), limit);
    return {
      symbol,
      timestamp: ob.timestamp * 1000,
      bids: ob.bids.map((b: any) => [parseFloat(b.price), parseFloat(b.quote)]),
      asks: ob.asks.map((a: any) => [parseFloat(a.price), parseFloat(a.quote)]),
      info: ob
    };
  }

  async fetchTrades(symbol: string, since?: number, limit = 100) {
    const raw = await getTrades(xbtsTickerFromSymbol(symbol), limit);
    return raw
      .map((t: any) => ({
        id: String(t.trade_id),
        symbol,
        timestamp: t.timestamp * 1000,
        datetime: new Date(t.timestamp * 1000).toISOString(),
        price: parseFloat(t.price),
        amount: parseFloat(t.quote_volume),
        side: t.type === 'sell' ? 'sell' : 'buy',
        info: t
      }))
      .filter(x => !since || x.timestamp >= since);
  }

  async fetchOHLCV(symbol: string) {
    const raw = await getMarketHistory(xbtsTickerFromSymbol(symbol));
    return raw.map((c: any) => [
      Date.parse(c.date),
      parseFloat(c.open_price),
      parseFloat(c.high_price),
      parseFloat(c.low_price),
      parseFloat(c.close_price),
      parseFloat(c.base_volume)
    ]);
  }

  async login(account: string, keyOrPassword: string, isPassword = false, node?: string) {
    await this.signer.connect(node);
    await this.signer.login(account, keyOrPassword, isPassword);
  }

  async fetchBalance() {
    return this.signer.balances();
  }

  async createOrder(symbol: string, type: 'limit', side: 'buy'|'sell', amount: number, price: number, params?: any) {
    if (type !== 'limit') throw new Error('Only limit orders supported');
    return this.signer.createLimitOrder(symbol, side, amount, price, params);
  }

  async cancelOrder(id: string) {
    return this.signer.cancelOrder(id);
  }

  async fetchOpenOrders() {
    return this.signer.openOrders();
  }
}
EOF

log "Writing src/rest/server.ts..."
cat > src/rest/server.ts <<'EOF'
import express from 'express';
import dotenv from 'dotenv';
import { BitSharesCCXT } from '../adapter.js';

dotenv.config();
const app = express();
app.use(express.json());

const ex = new BitSharesCCXT();

app.get('/markets', async (_req, res) => {
  res.json(await ex.fetchMarkets());
});

app.get('/ticker', async (req, res) => {
  const { symbol } = req.query;
  if (!symbol) return res.status(400).json({ error: 'symbol required' });
  res.json(await ex.fetchTicker(String(symbol)));
});

const port = process.env.PORT || 8787;
app.listen(port, () => {
  console.log(`BitShares CCXT REST API running on port ${port}`);
});
EOF

# === Final setup steps ===
log "Installing dependencies..."
npm install

log "Initializing Git repository..."
git init
git add .
git commit -m "Initial commit: BitShares CCXT bridge scaffold"

log "✅ Setup complete. Your BitShares CCXT bridge is ready."

