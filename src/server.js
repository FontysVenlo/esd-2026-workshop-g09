const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const compression = require('compression');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(compression());
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
    latency: 0,                 // Artificial lag in ms (0 - 1500+)
    packetLoss: 0,              // Packet loss percentage (0 - 100)
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

// Master game state tracking all connected players & their WebSocket references
let players = {};
const playerSockets = {};

// --- SHARED SERVER-SYNCED EXP ORBS ---
const MAX_ORBS = 80;
let orbs = [];

function createRandomOrb(id) {
    return {
        id: id,
        x: Math.round((Math.random() - 0.5) * 3800),
        y: Math.round((Math.random() - 0.5) * 3800),
        val: 1
    };
}

for (let i = 0; i < MAX_ORBS; i++) {
    orbs.push(createRandomOrb(i));
}

// --- INBOUND NETWORK / DDoS LAG SIMULATOR (Client -> Server) ---
function processWithNetworkLag(callback) {
    // 1. Inbound Packet Loss (drops player updates before server sees them)
    if (adminConfig.packetLoss > 0 && Math.random() < (adminConfig.packetLoss / 100)) {
        return;
    }

    // 2. Inbound Latency + Jitter (spikes unpredictably when latency > 250ms to mimic DDoS)
    const baseLatency = Number(adminConfig.latency) || 0;
    if (baseLatency > 0) {
        const jitter = baseLatency > 250 ? Math.random() * (baseLatency * 0.5) : 0;
        setTimeout(callback, baseLatency + jitter);
    } else {
        callback();
    }
}

// --- WEBSOCKET CONNECTION HANDLING ---
wss.on('connection', (ws) => {
    const playerId = Math.random().toString(36).substring(2, 9);
    const assignedCode = availableCodes.length > 0 ? availableCodes.pop() : "??";
    const startX = Math.round((Math.random() - 0.5) * 2000);
    const startY = Math.round((Math.random() - 0.5) * 2000);

    playerSockets[playerId] = ws;
    players[playerId] = {
        id: playerId,
        code: assignedCode,
        x: startX,
        y: startY,
        target_x: startX,
        target_y: startY,
        score: 0,
        lastInputTime: Date.now(),
        lastEatenTime: 0,
        prevAngle: null,
        rigidStreak: 0,
        lastBotAlert: 0
    };

    console.log(`[Connect] Player joined: ${playerId} (Code: ${assignedCode})`);

    ws.send(JSON.stringify({
        type: 'init',
        playerId: playerId,
        code: assignedCode,
        orbs: orbs
    }));

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            // Wrap incoming client traffic in Block 2 latency & packet loss
            processWithNetworkLag(() => {
                const player = players[playerId];
                if (!player) return;

                if (data.type === 'update') {
                    // --- BLOCK 4: RIGID INPUT BOT DETECTOR ---
                    // Must run BEFORE updating player.x / player.y so we compare old vs. new coordinates
                    if (adminConfig.botDetector && data.x !== undefined && data.y !== undefined) {
                        const dx = data.x - player.x;
                        const dy = data.y - player.y;
                        const dist = Math.sqrt(dx * dx + dy * dy);

                        if (dist > 2) {
                            const angle = Math.atan2(dy, dx);
                            if (player.prevAngle !== null && Math.abs(angle - player.prevAngle) < 0.0001) {
                                player.rigidStreak += 1;
                            } else {
                                player.rigidStreak = 0;
                            }
                            player.prevAngle = angle;

                            if (player.rigidStreak >= 15 && Date.now() - player.lastBotAlert > 5000) {
                                player.lastBotAlert = Date.now();
                                console.log(`[BOT DETECTOR] Flagged Player ${player.code} (${playerId}) — Zero-variance robotic pathing!`);
                                ws.send(JSON.stringify({
                                    type: 'alert',
                                    message: `[BOT DETECTOR] Player ${player.code} flagged for robotic straight-line movement!`
                                }));
                            }
                        }
                    } else {
                        player.rigidStreak = 0;
                        player.prevAngle = null;
                    }

                    if (data.x !== undefined) {
                        player.x = data.x;
                        player.target_x = data.x;
                    }
                    if (data.y !== undefined) {
                        player.y = data.y;
                        player.target_y = data.y;
                    }

                    // SCORE AUTHORITY SWITCH
                    if (adminConfig.authority === 'client') {
                        // EXPLOITABLE: Server blindly trusts whatever score the client sends
                        if (data.score !== undefined) player.score = data.score;
                    }
                }
                else if (data.type === 'respawn') {
                    player.score = 0;
                    if (data.x !== undefined) player.x = data.x;
                    if (data.y !== undefined) player.y = data.y;
                } 
                else if (data.type === 'player_eaten') {
                    // Larger player reports eating a smaller player
                    const victim = Object.values(players).find(p => p.code === data.victim_id);
                    if (victim && Date.now() - (victim.lastEatenTime || 0) > 1000) {
                        if (adminConfig.authority === 'client' || player.score > victim.score) {
                            victim.lastEatenTime = Date.now();
                            const gained = Math.max(1, victim.score);
                            player.score += gained;
                            victim.score = 0;
                            victim.x = Math.round((Math.random() - 0.5) * 2000);
                            victim.y = Math.round((Math.random() - 0.5) * 2000);

                            // Notify the victim's client directly so it triggers respawn()
                            const victimWs = playerSockets[victim.id];
                            if (victimWs && victimWs.readyState === WebSocket.OPEN) {
                                victimWs.send(JSON.stringify({ type: 'eaten' }));
                            }
                        }
                    }
                }
                else if (data.type === 'got_eaten') {
                    // Smaller player reports getting eaten (handles inactive/throttled eater browser tabs)
                    const eater = Object.values(players).find(p => p.code === data.eater_id);
                    if (eater && Date.now() - (player.lastEatenTime || 0) > 1000) {
                        if (adminConfig.authority === 'client' || eater.score > player.score) {
                            player.lastEatenTime = Date.now();
                            const gained = Math.max(1, player.score);
                            eater.score += gained;
                            player.score = 0;
                            player.x = Math.round((Math.random() - 0.5) * 2000);
                            player.y = Math.round((Math.random() - 0.5) * 2000);

                            // Notify eater so client-authoritative mode doesn't overwrite the reward
                            const eaterWs = playerSockets[eater.id];
                            if (eaterWs && eaterWs.readyState === WebSocket.OPEN) {
                                eaterWs.send(JSON.stringify({ type: 'ate_player', gained: gained }));
                            }
                        }
                    }
                }
                else if (data.type === 'eat_orb') {
                    if (adminConfig.authority === 'server') {
                        const gain = Math.min(Math.max(Number(data.amount) || 1, 1), 5);
                        player.score += gain;
                    }

                    if (data.orb_id !== undefined) {
                        const orbId = Number(data.orb_id);
                        const idx = orbs.findIndex(o => o.id === orbId);
                        if (idx !== -1) {
                            orbs[idx] = createRandomOrb(orbId);
                            const msg = JSON.stringify({ type: 'orb_moved', orb: orbs[idx] });
                            wss.clients.forEach((client) => {
                                if (client.readyState === WebSocket.OPEN) {
                                    client.send(msg);
                                }
                            });
                        }
                    }
                }
            });
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
        delete playerSockets[playerId];
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

    const publicPlayers = {};
    for (const id in players) {
        const p = players[id];
        publicPlayers[id] = {
            id: p.id,
            code: p.code,
            x: Math.round(p.x),
            y: Math.round(p.y),
            score: p.score
        };
    }

    const payload = JSON.stringify({
        type: 'state',
        players: publicPlayers,
        config: adminConfig
    });

    // Broadcast state to all clients
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            // Simulate Outbound Packet Loss
            if (adminConfig.packetLoss > 0 && Math.random() < (adminConfig.packetLoss / 100)) {
                return;
            }

            // Simulate Outbound Latency
            if (adminConfig.latency > 0) {
                setTimeout(() => {
                    if (client.readyState === WebSocket.OPEN) {
                        client.send(payload);
                    }
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

// Trigger a temporary 5-second DDoS congestion spike
app.post('/api/ddos', (req, res) => {
    const prevLatency = adminConfig.latency;
    const prevLoss = adminConfig.packetLoss;

    adminConfig.latency = 1200;
    adminConfig.packetLoss = 60;
    console.log('[DDoS SIM] Heavy congestion spike started (1200ms latency, 60% loss)');

    setTimeout(() => {
        adminConfig.latency = prevLatency;
        adminConfig.packetLoss = prevLoss;
        console.log('[DDoS SIM] Congestion spike cleared.');
    }, 5000);

    res.json({ success: true, message: '5s DDoS spike triggered' });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Workshop server running at http://localhost:${PORT}`);
});