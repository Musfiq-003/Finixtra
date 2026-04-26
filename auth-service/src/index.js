const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgres://finixtra:enterprise_password@postgres:5432/finixtra_db'
});

const app = express();
app.use(express.json());

const JWT_SECRET = process.env.JWT_SECRET || 'enterprise_secret_key_finixtra';

app.post('/auth/register', async (req, res) => {
    const { email, password, device_fingerprint, ip_address } = req.body;
    
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        
        const hashedPassword = await bcrypt.hash(password, 12);
        
        const userRes = await client.query(
            `INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id`,
            [email, hashedPassword]
        );
        const userId = userRes.rows[0].id;
        
        if (device_fingerprint) {
            await client.query(
                `INSERT INTO device_logs (user_id, device_fingerprint, ip_address) VALUES ($1, $2, $3)`,
                [userId, device_fingerprint, ip_address || req.ip]
            );
        }
        
        await client.query('COMMIT');
        res.status(201).json({ message: "User registered securely.", user_id: userId });
    } catch (e) {
        await client.query('ROLLBACK');
        if (e.code === '23505') { 
            return res.status(400).json({ error: "Email already registered." });
        }
        res.status(500).json({ error: "Registration failed", details: e.message });
    } finally {
        client.release();
    }
});

app.post('/auth/login', async (req, res) => {
    const { email, password, current_device_fingerprint, ip_address } = req.body;
    
    try {
        const userRes = await pool.query(`SELECT * FROM users WHERE email = $1`, [email]);
        if (userRes.rows.length === 0) {
            return res.status(401).json({ error: "Invalid credentials" });
        }
        
        const user = userRes.rows[0];
        if (!(await bcrypt.compare(password, user.password_hash))) {
            return res.status(401).json({ error: "Invalid credentials" });
        }
        
        if (current_device_fingerprint) {
            const deviceRes = await pool.query(
                `SELECT * FROM device_logs WHERE user_id = $1 AND device_fingerprint = $2`,
                [user.id, current_device_fingerprint]
            );
            
            if (deviceRes.rows.length === 0) {
                await pool.query(
                    `INSERT INTO device_logs (user_id, device_fingerprint, ip_address) VALUES ($1, $2, $3)`,
                    [user.id, current_device_fingerprint, ip_address || req.ip]
                );
                return res.status(403).json({ error: "Device anomaly detected. OTP Required.", require_otp: true, user_id: user.id });
            } else {
                await pool.query(`UPDATE device_logs SET last_login = CURRENT_TIMESTAMP WHERE id = $1`, [deviceRes.rows[0].id]);
            }
        }
        
        const token = jwt.sign({ id: user.id }, JWT_SECRET, { expiresIn: '15m' });
        const refreshToken = jwt.sign({ id: user.id }, JWT_SECRET + '_refresh', { expiresIn: '7d' });
        
        res.json({ token, refresh_token: refreshToken, user_id: user.id });
    } catch (e) {
        res.status(500).json({ error: "Login failed", details: e.message });
    }
});

app.listen(3001, () => console.log('Enterprise Auth Service running on port 3001'));
