const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(express.json());

// --- BASIC AUTHENTICATION MIDDLEWARE ---
const adminAuth = (req, res, next) => {
    const authHeader = req.headers.authorization;
    
    // Change these to your preferred username and password
    const ADMIN_USER = "admin";
    const ADMIN_PASS = "workshop2026"; 

    if (authHeader) {
        const base64Credentials = authHeader.split(' ')[1];
        const credentials = Buffer.from(base64Credentials, 'base64').toString('utf8');
        const [user, pass] = credentials.split(':');

        if (user === ADMIN_USER && pass === ADMIN_PASS) {
            return next();
        }
    }

    res.setHeader('WWW-Authenticate', 'Basic realm="Workshop Admin Panel"');
    res.status(401).send('Authentication required.');
};

// PROTECT ADMIN PAGE: This must come BEFORE express.static
app.get('/admin.html', adminAuth, (req, res) => {
    res.sendFile(__dirname + '/public/admin.html');
});

// Serve all other static files (your Godot HTML5 game export) from the 'public' folder
app.use(express.static('public'));

// --- ADMIN SWITCHBOARD CONFIGURATION ---
// These map directly to your live workshop admin controls
let adminConfig = {
    authority: 'client',        // 'client' (Workshop 1 exploit) or 'server'
    prediction: true,           // Client-side prediction toggle
    interpolation: true,        // Entity interpolation toggle
    latency: 0,                 // Artificial lag in ms (0 - 300)
    packetLoss: 0,              // Packet loss percentage (0 - 10)
    interestManagement: false,  // Fog of war / visibility filter
    serverClock: false,         // Strict tick rate validation (Speedhack defense)
    botDetector: false          // Flag regular inputs
};

// Master game state tracking all connected players
let players = {};

// --- WEBSOCKET CONNECTION HANDLING ---
wss.on('connection', (ws) => {
    const playerId = Math.random().toString(36).substring(2, 9);
    
    // Initialize new player
    players[playerId] = {
        id: playerId,
        x: 100,
        y: 100,
        score: 0,
        lastInputTime: Date.now()
    };

    console.log(`[Connect] Player joined: ${playerId}`);

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            const player = players[playerId];
            if (!player) return;

            // HANDLE BLOCK 1 & 2: Client vs Server Authority
            if (data.type === 'update') {
                if (adminConfig.authority === 'client') {
                    // UNSECURED: Server blindly trusts whatever coordinates/score the client sends
                    if (data.x !== undefined) player.x = data.x;
                    if (data.y !== undefined) player.y = data.y;
                    if (data.score !== undefined) player.score = data.score;
                } else {
                    // SECURED: Server processes raw inputs (WASD) and calculates position itself
                    const speed = 5;
                    if (data.input === 'W') player.y -= speed;
                    if (data.input === 'S') player.y += speed;
                    if (data.input === 'A') player.x -= speed;
                    if (data.input === 'D') player.x += speed;

                    // HANDLE BLOCK 4: Simple Bot Detector (Checks input regularity)
                    if (adminConfig.botDetector) {
                        const now = Date.now();
                        const timeDiff = now - player.lastInputTime;
                        // If inputs arrive at an exact rigid interval (e.g., macro automation), flag it
                        if (timeDiff > 40 && timeDiff < 60) {
                            ws.send(JSON.stringify({ type: 'alert', message: 'Bot detected! Input timing too regular.' }));
                        }
                        player.lastInputTime = now;
                    }
                }
            }
        } catch (err) {
            console.error('Invalid message format', err);
        }
    });

    ws.on('close', () => {
        delete players[playerId];
        console.log(`[Disconnect] Player left: ${playerId}`);
    });
});

// --- GAME TICK LOOP (20 Hz / Every 50ms) ---
setInterval(() => {
    const payload = JSON.stringify({
        type: 'state',
        players: players,
        config: adminConfig
    });

    // Broadcast state to all connected clients
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            // Simulate Packet Loss
            if (adminConfig.packetLoss > 0 && Math.random() < (adminConfig.packetLoss / 100)) {
                return; // Drop packet intentionally
            }

            // Simulate Latency
            if (adminConfig.latency > 0) {
                setTimeout(() => {
                    client.send(payload);
                }, adminConfig.latency);
            } else {
                client.send(payload);
            }
        }
    });
}, 50);

// --- ADMIN API ENDPOINTS ---
app.post('/api/config', (req, res) => {
    adminConfig = { ...adminConfig, ...req.body };
    console.log('[Admin Update]', adminConfig);
    res.json({ success: true, adminConfig });
});

app.get('/api/config', (req, res) => {
    res.json(adminConfig);
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Workshop server running at http://localhost:${PORT}`);
});