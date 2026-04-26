const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const { createClient } = require('redis');
const axios = require('axios');

const app = express();
app.use(express.json());
app.use(cors());

const pool = new Pool({
    user: process.env.DB_USER || 'finixtra_user',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'finixtra_db',
    password: process.env.DB_PASSWORD || 'finixtra_password',
    port: process.env.DB_PORT || 5432,
});

const redisClient = createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379'
});

redisClient.on('error', err => console.error('Redis Client Error', err));

app.get('/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.json({ status: 'healthy', database: 'connected', timestamp: new Date() });
    } catch (error) {
        res.status(500).json({ status: 'unhealthy', error: error.message });
    }
});

app.post('/api/v1/auth/login', async (req, res) => {
    try {
        const authResponse = await axios.post('http://auth-service:3001/auth/login', req.body);
        res.json(authResponse.data);
    } catch (err) {
        const errorDetails = err.response ? err.response.data : err.message;
        res.status(err.response ? err.response.status : 500).json(errorDetails);
    }
});

app.post('/api/v1/auth/register', async (req, res) => {
    try {
        const authResponse = await axios.post('http://auth-service:3001/auth/register', req.body);
        res.json(authResponse.data);
    } catch (err) {
        const errorDetails = err.response ? err.response.data : err.message;
        res.status(err.response ? err.response.status : 500).json(errorDetails);
    }
});

app.post('/api/v1/wallet/transfer', async (req, res) => {
    const { from_wallet, to_wallet, amount, user_id, device_id, location, idempotency_key } = req.body;
    
    try {
        const device_risk = device_id ? 0.1 : 0.8;
        const geo_risk = location ? 0.2 : 0.6;
        const velocity_risk = 0.3;

        const fraudResponse = await axios.post('http://ai-fraud-engine:8000/fraud/risk-score', {
            user_id: String(user_id), 
            amount: parseFloat(amount), 
            device_risk, 
            geo_risk, 
            velocity_risk
        });
        
        const { risk_score, action } = fraudResponse.data;
        
        if (action === 'BLOCK' || risk_score > 0.7) {
            return res.status(403).json({ status: 'blocked', reason: 'High fraud risk detected', risk_score });
        } else if (action === 'CHALLENGE_OTP') {
            return res.status(403).json({ status: 'challenge', reason: 'Additional verification required (OTP)', risk_score });
        }
        
        const walletResponse = await axios.post('http://wallet-service:4000/wallet/transfer', {
            from_wallet, to_wallet, amount, idempotency_key
        });

        res.json({ 
            status: 'success', 
            message: 'Transfer successful', 
            risk_score, 
            wallet_response: walletResponse.data 
        });
    } catch (err) {
        const errorDetails = err.response ? err.response.data : err.message;
        res.status(500).json({ error: 'Transfer failed', details: errorDetails });
    }
});

app.post('/api/v1/wallet/sync-offline', async (req, res) => {
    const { transactions } = req.body;
    try {
        const syncResponse = await axios.post('http://wallet-service:4000/wallet/sync-offline', {
            transactions
        });
        res.json(syncResponse.data);
    } catch (err) {
        const errorDetails = err.response ? err.response.data : err.message;
        res.status(500).json({ error: 'Offline sync failed', details: errorDetails });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
    try {
        await redisClient.connect();
        console.log(`🚀 FINIXTRA API Gateway running on port ${PORT}`);
    } catch (e) {
        console.error('Failed to connect to Redis', e);
    }
});
