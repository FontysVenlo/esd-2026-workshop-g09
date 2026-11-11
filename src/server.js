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
    
    // Change these to the preferred username and password
    const ADMIN_USER = "admin";
    const ADMIN_PASS = "workshop2026!"; 

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

// Serve static files (Godot Web Export)
app.use(express.static('public'));

// --- ADMIN SWITCHBOARD CONFIGURATION ---
let adminConfig = {
    authority: 'client',        // 'client' (Workshop 1 exploit) or 'server'
    prediction: true,           // Client-side prediction toggle
    interpolation: true,        // Entity interpolation toggle
    cheat_access: false,        // Block 3: In-game exploit menu unlock flag
    latency: 0,                 // Artificial lag in ms (0 - 300)
    packetLoss: 0,              // Packet loss percentage (0 - 10)
    interestManagement: false,  // Visibility filter
    serverClock: false,         // Tick rate validation
    botDetector: false          // Flag regular inputs
};

// --- UNIQUE 2-CHARACTER CODE POOL SYSTEM ---
const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const NUMBERS = "0123456789";

function createCodePool() {
    const pool = [];
    
    for (let l of LETTERS) {
        for (let n of NUMBERS) {
            pool.push(`${l}${n}`);
        }
    }
    
    for (let n of NUMBERS) {
        for (let l of LETTERS) {
            pool.push(`${n}${l}`);
        }
    }

    for (let i = pool.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [pool[i], pool[j]] = [pool[j], pool[i]];
    }
    
    return pool;
}

const availableCodes = createCodePool();

// Master game state tracking all connected players
let players = {};

// --- WEBSOCKET CONNECTION HANDLING ---
wss.on('connection', (ws) => {
    const playerId = Math.random().toString(36).substring(2, 9);
    const assignedCode = availableCodes.length > 0 ? availableCodes.pop() : "??";

    players[playerId] = {
        id: playerId,
        code: assignedCode,
        x: 100,
        y: 100,
        target_x: 100,
        target_y: 100,
        score: 0,
        lastInputTime: Date.now()
    };

    console.log(`[Connect] Player joined: ${playerId} (Code: ${assignedCode})`);

    ws.send(JSON.stringify({
        type: 'init',
        playerId: playerId,
        code: assignedCode
    }));

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            const player = players[playerId];
            if (!player) return;

            if (data.type === 'update') {
                if (adminConfig.authority === 'client') {
                    // Client-authoritative: Server blindly accepts incoming coordinates and score
                    if (data.x !== undefined) player.x = data.x;
                    if (data.y !== undefined) player.y = data.y;
                    if (data.score !== undefined) player.score = data.score;
                } else {
                    // Server-authoritative: Server accepts target destination
                    if (data.target_x !== undefined) player.target_x = data.target_x;
                    if (data.target_y !== undefined) player.target_y = data.target_y;

                    // Bot Detector (Rigid Input Check)
                    if (adminConfig.botDetector) {
                        const now = Date.now();
                        const timeDiff = now - player.lastInputTime;
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
        const player = players[playerId];
        if (player && player.code !== "??") {
            availableCodes.push(player.code);
        }
        delete players[playerId];
        console.log(`[Disconnect] Player left: ${playerId}`);
    });
});

// --- GAME TICK LOOP (20 Hz / Every 50ms) ---
setInterval(() => {
    // Process server-side player movement if authority is set to "server"
    if (adminConfig.authority === 'server') {
        const speed = 200 * 0.05; // 200 px/sec * 0.05s tick interval = 10 px per tick

        for (let id in players) {
            const p = players[id];
            const dx = p.target_x - p.x;
            const dy = p.target_y - p.y;
            const dist = Math.sqrt(dx * dx + dy * dy);

            if (dist > 5) {
                p.x += (dx / dist) * speed;
                p.y += (dy / dist) * speed;
            }
        }
    }

    const payload = JSON.stringify({
        type: 'state',
        players: players,
        config: adminConfig
    });

    // Broadcast state to all clients
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            // Simulate Packet Loss
            if (adminConfig.packetLoss > 0 && Math.random() < (adminConfig.packetLoss / 100)) {
                return;
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