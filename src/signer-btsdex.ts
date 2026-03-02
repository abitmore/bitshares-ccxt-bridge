import BitShares from 'btsdex';
import { parseSymbol } from './symbols.js';

export class Signer {
  private accountName!: string;
  private connected = false;
  private acc: any | null = null;

  setAccountName(accountName: string) {
    this.accountName = accountName;
  }

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
    await this.connect();
    if (!this.accountName) {
      throw new Error('No account configured');
    }
    if (!this.acc) {
      return this.publicBalances(this.accountName);
    }
    const iam = await (BitShares as any).accounts[this.accountName];
    return iam.balances;
  }

  // Public balances for any account (no private key required)
  async publicBalances(accountName: string) {
    await this.connect();
    const full = await (BitShares as any).db.get_full_accounts([accountName], false);
    if (!full || !full[0] || !full[0][1]) return [];
    const acct = full[0][1];
    const balances = acct.balances || [];
    const assetIds = balances.map((b: any) => b.asset_type);
    const assets = assetIds.length ? await (BitShares as any).db.get_assets(assetIds) : [];
    const byId: Record<string, any> = {};
    for (const a of assets) byId[a.id] = a;
    return balances.map((b: any) => {
      const a = byId[b.asset_type];
      const precision = a?.precision ?? 0;
      const denom = Math.pow(10, precision);
      const total = typeof b.balance === 'number' ? b.balance / denom : parseFloat(b.balance) / denom;
      return {
        symbol: a?.symbol || b.asset_type,
        total,
      };
    });
  }

  async createLimitOrder(
    symbol: string,
    side: 'buy' | 'sell',
    amount: number,
    price: number,
    params?: { fillOrKill?: boolean; expire?: string }
  ) {
    if (!this.acc) {
      throw new Error('Trading key not loaded: account is in view-only mode');
    }
    const { base, quote } = parseSymbol(symbol);
    if (side === 'buy') {
      return this.acc.buy(quote, base, amount, price, params?.fillOrKill ?? false, params?.expire);
    }
    return this.acc.sell(base, quote, amount, price, params?.fillOrKill ?? false, params?.expire);
  }

  async cancelOrder(orderId: string) {
    if (!this.acc) {
      throw new Error('Trading key not loaded: account is in view-only mode');
    }
    return this.acc.cancelOrder(orderId);
  }

  async openOrders() {
    await this.connect();
    if (!this.accountName) {
      throw new Error('No account configured');
    }

    let full;
    if (this.acc) {
      const iam = await (BitShares as any).accounts[this.accountName];
      full = await (BitShares as any).db.get_full_accounts([iam.id], false);
    } else {
      full = await (BitShares as any).db.get_full_accounts([this.accountName], false);
    }
    return full?.[0]?.[1]?.limit_orders || [];
  }
}
