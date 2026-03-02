import BitShares from 'btsdex';
import { parseSymbol } from './symbols.js';
export class Signer {
    accountName;
    connected = false;
    acc = null;
    setAccountName(accountName) {
        this.accountName = accountName;
    }
    async connect(node) {
        if (!this.connected) {
            await (node ? BitShares.connect(node) : BitShares.connect());
            this.connected = true;
        }
    }
    async login(accountName, wifOrPassword, isPassword = false) {
        await this.connect();
        this.accountName = accountName;
        this.acc = isPassword
            ? await BitShares.login(accountName, wifOrPassword)
            : new BitShares(accountName, wifOrPassword);
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
        const iam = await BitShares.accounts[this.accountName];
        return iam.balances;
    }
    // Public balances for any account (no private key required)
    async publicBalances(accountName) {
        await this.connect();
        const full = await BitShares.db.get_full_accounts([accountName], false);
        if (!full || !full[0] || !full[0][1])
            return [];
        const acct = full[0][1];
        const balances = acct.balances || [];
        const assetIds = balances.map((b) => b.asset_type);
        const assets = assetIds.length ? await BitShares.db.get_assets(assetIds) : [];
        const byId = {};
        for (const a of assets)
            byId[a.id] = a;
        return balances.map((b) => {
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
    async createLimitOrder(symbol, side, amount, price, params) {
        if (!this.acc) {
            throw new Error('Trading key not loaded: account is in view-only mode');
        }
        const { base, quote } = parseSymbol(symbol);
        if (side === 'buy') {
            return this.acc.buy(quote, base, amount, price, params?.fillOrKill ?? false, params?.expire);
        }
        return this.acc.sell(base, quote, amount, price, params?.fillOrKill ?? false, params?.expire);
    }
    async cancelOrder(orderId) {
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
            const iam = await BitShares.accounts[this.accountName];
            full = await BitShares.db.get_full_accounts([iam.id], false);
        }
        else {
            full = await BitShares.db.get_full_accounts([this.accountName], false);
        }
        return full?.[0]?.[1]?.limit_orders || [];
    }
}
