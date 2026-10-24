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

// Serve all other static files (your Godot HTML5 game export) from the 'public' folder
app.use(express.static('public'));

// --- ADMIN SWITCHBOARD CONFIGURATION ---
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

// --- UNIQUE 2-CHARACTER CODE POOL SYSTEM ---
const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const NUMBERS = "0123456789";

function createCodePool() {
    const pool = [];
    
    // Pattern 1: Letter + Number (e.g., K7, B3) -> 260 codes
    for (let l of LETTERS) {
        for (let n of NUMBERS) {
            pool.push(`${l}${n}`);
        }
    }
    
    // Pattern 2: Number + Letter (e.g., 7K, 3B) -> 260 codes
    for (let n of NUMBERS) {
        for (let l of LETTERS) {
            pool.push(`${n}${l}`);
        }
    }

    // Fisher-Yates shuffle so codes are assigned in random order
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
    
    // Grab the next unique 2-character code from the pool
    const assignedCode = availableCodes.length > 0 ? availableCodes.pop() : "??";

    // Initialize new player with assigned code
    players[playerId] = {
        id: playerId,
        code: assignedCode,
        x: 100,
        y: 100,
        score: 0,
        lastInputTime: Date.now()
    };

    console.log(`[Connect] Player joined: ${playerId} (Code: ${assignedCode})`);

    // Send the assigned player ID and unique code directly to the connecting client
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

            // HANDLE BLOCK 1 & 2: Client vs Server Authority
            if (data.type === 'update') {
                if (adminConfig.authority === 'client') {
                    // UNSECURED: Server blindly trusts whatever coordinates/score the client sends
                    if (data.x !== undefined) player.x = data.x;
                    if (data.y !== undefined) player.y = data.y;
                    if (data.score !== undefined) player.score = data.score;
                } else {
                    // SECURED: Server processes raw inputs / target mouse coords
                    if (data.target_x !== undefined) player.x = data.target_x;
                    if (data.target_y !== undefined) player.y = data.target_y;

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
        const player = players[playerId];
        if (player && player.code !== "??") {
            // Recycle the code back into the available pool for new players
            availableCodes.push(player.code);
        }
        
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