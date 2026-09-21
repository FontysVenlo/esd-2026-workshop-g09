# General Notes

Client–server, server authoritative
Central server owns the true game state. Most modern competitive online games lean this way.
Pros: strong consistency, easier cheat prevention.
Cons: server cost, latency, scaling complexity.
Security angle: cheating shifts from “fake the world state” to “abuse inputs, timing, information, or bugs.”

Client-authoritative / partially client-authoritative
Client is trusted for some state such as position, actions, or physics.
Pros: responsive, simpler backend, less server computation.
Cons: fundamentally weaker trust model.
Security angle: probably the clearest architecture for demonstrating why trusting the client is dangerous.

Peer-to-peer
Players communicate directly rather than going through one dedicated authoritative server.
Pros: cheaper infrastructure, potentially lower latency between nearby peers.
Cons: NAT/networking complexity, host exposure, weaker trust boundaries.
Security angle: tampered messages, malicious peers, information leakage, disruption.

Listen server / player-hosted server
One player's machine acts as both client and server.
Pros: cheap, easy for small games.
Cons: host advantage, host migration issues, the authoritative machine belongs to a player.
Security angle: useful for discussing what happens when the attacker controls the “server.”

Deterministic lockstep
Players exchange commands/inputs and every machine independently simulates the same world. Commonly associated with RTS-style networking.
Pros: very bandwidth-efficient for large simulations.
Cons: deterministic simulation is difficult; often sensitive to slow/malicious participants.
Security angle: illegal inputs, desynchronization, delaying commands.

Rollback / input prediction
Especially relevant to fighting games. Clients predict what remote players do, then rewind/resimulate when the real input arrives.
Pros: excellent responsiveness under moderate latency.
Cons: implementation complexity and visible corrections under bad networking.
Security angle: timing and input manipulation rather than simple state spoofing.

# Game stuff

Backend / networking type    Typical game examples    Why it fits
Dedicated, server-authoritative client/server    Counter-Strike 2, Valorant, Overwatch 2, Fortnite, Apex Legends    Competitive action games generally need the server to decide the authoritative state so clients cannot simply declare “I hit him” or “I moved here.”
Player-hosted / listen server    Older Call of Duty titles, many co-op survival games, small-session games    One player's machine hosts the match while also playing. Cheap and convenient, but the host has a privileged position.
Dedicated sandbox server    Minecraft Java/Bedrock servers    The world runs on a server process that clients connect to; Minecraft officially supports both self-hosted and dedicated server software. Minecraft.net
Deterministic lockstep    Age of Empires, StarCraft/Warcraft-era RTS designs, Command & Conquer-style RTSs    Instead of continuously transmitting every unit's position, peers/server exchange player commands and reproduce the simulation locally. Especially attractive when thousands of units exist.
Rollback P2P    Street Fighter 6, Guilty Gear Strive, Skullgirls, many modern fighting games    Fighting games need immediate local input response. Rollback predicts missing remote input and rewinds/resimulates when the actual input arrives. GGPO popularized this model. GGPO
Traditional delay-based P2P    Many older fighting games    Both players wait a few frames for remote input before advancing. Simpler than rollback, but high latency makes controls feel sluggish.
MMO authoritative backend    World of Warcraft, Final Fantasy XIV, RuneScape    Persistent state—characters, inventories, combat, economy—is controlled by backend servers and often divided across zones/services/shards.
Peer-to-peer co-op / host authority    Older console co-op and many small indie multiplayer games    One peer commonly acts as host rather than paying for dedicated infrastructure.

# Most important aspects

Model Who owns truth? What crosses network? Main reason to use it Main drawback Interesting cheat surface
Server authoritative Server Inputs + state updates Fairness/control Cost + latency input/protocol abuse
Client authoritative    Client partly/full    Claimed state    Simplicity/responsiveness    Trust    state manipulation
P2P    Peers    State or inputs    Low infra cost    Trust/network complexity    malicious peer
Listen server    Host player    State/inputs    Easy hosting    Host is privileged    host manipulation
Lockstep    All peers simulate    Inputs    Low bandwidth    stalls/desync    illegal/delayed inputs
Rollback    Distributed prediction    Inputs    Responsiveness    complexity    timing/input abuse
