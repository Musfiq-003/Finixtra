const express = require('express');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL || 'postgres://finixtra:enterprise_password@localhost:5432/finixtra_db' });
const app = express();
app.use(express.json());

app.post('/wallet/transfer', async (req, res) => {
    const { from_wallet, to_wallet, amount, idempotency_key } = req.body;
    if (amount <= 0) return res.status(400).json({ error: "Invalid amount" });

    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        const { rows } = await client.query(
            `SELECT id FROM wallets WHERE id IN ($1, $2) FOR UPDATE`,
            [from_wallet, to_wallet]
        );
        if (rows.length !== 2) throw new Error("Wallet(s) not found");

        const balanceRes = await client.query(
            `SELECT COALESCE(SUM(amount), 0) as balance FROM ledger_entries WHERE wallet_id = $1 AND status = 'COMPLETED'`,
            [from_wallet]
        );
        if (parseFloat(balanceRes.rows[0].balance) < amount) {
            throw new Error("Insufficient funds");
        }

        const txIdRes = await client.query('SELECT uuid_generate_v4() as tx_id');
        const txId = txIdRes.rows[0].tx_id;

        await client.query(
            `INSERT INTO ledger_entries (transaction_id, wallet_id, amount, type, status) VALUES 
            ($1, $2, $3, 'DEBIT', 'COMPLETED'),
            ($1, $4, $5, 'CREDIT', 'COMPLETED')`,
            [txId, from_wallet, -amount, to_wallet, amount]
        );

        await client.query('COMMIT');
        res.json({ success: true, transaction_id: txId, status: "COMPLETED" });
    } catch (e) {
        await client.query('ROLLBACK');
        res.status(400).json({ error: e.message });
    } finally {
        client.release();
    }
});

app.post('/wallet/sync-offline', async (req, res) => {
    const { transactions } = req.body;
    if (!Array.isArray(transactions) || transactions.length === 0) {
        return res.status(400).json({ error: "Invalid transactions array" });
    }

    const client = await pool.connect();
    const results = [];
    try {
        await client.query('BEGIN');
        
        for (const tx of transactions) {
            const { from_wallet, to_wallet, amount, signature, timestamp } = tx;
            
            if (!signature) {
                results.push({ tx, status: 'FAILED', reason: 'Missing cryptographic signature' });
                continue;
            }

            const { rows } = await client.query(
                `SELECT id FROM wallets WHERE id IN ($1, $2) FOR UPDATE`,
                [from_wallet, to_wallet]
            );
            
            if (rows.length !== 2) {
                results.push({ tx, status: 'FAILED', reason: 'Wallet(s) not found' });
                continue;
            }

            const balanceRes = await client.query(
                `SELECT COALESCE(SUM(amount), 0) as balance FROM ledger_entries WHERE wallet_id = $1 AND status = 'COMPLETED'`,
                [from_wallet]
            );
            if (parseFloat(balanceRes.rows[0].balance) < amount) {
                results.push({ tx, status: 'FAILED', reason: 'Insufficient funds' });
                continue;
            }

            const txIdRes = await client.query('SELECT uuid_generate_v4() as tx_id');
            const txId = txIdRes.rows[0].tx_id;

            await client.query(
                `INSERT INTO ledger_entries (transaction_id, wallet_id, amount, type, status, is_offline_sync, offline_signature, created_at) VALUES 
                ($1, $2, $3, 'DEBIT', 'COMPLETED', true, $6, $7),
                ($1, $4, $5, 'CREDIT', 'COMPLETED', true, $6, $7)`,
                [txId, from_wallet, -amount, to_wallet, amount, signature, timestamp || new Date()]
            );
            
            results.push({ tx_id: txId, original_tx: tx, status: 'COMPLETED' });
        }

        await client.query('COMMIT');
        res.json({ success: true, processed: results.length, results });
    } catch (e) {
        await client.query('ROLLBACK');
        res.status(500).json({ error: "Offline sync failed: " + e.message });
    } finally {
        client.release();
    }
});

app.listen(4000, () => console.log('Wallet Ledger Service running on 4000'));
