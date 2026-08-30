# Multiplayer Architecture

The current export runs a single Godot dedicated-server process. It owns ENet,
personal lobbies, matchmaking, logical raid sessions, and at most one active
local Raid Scene world.

```text
Client request
  -> NetworkManager (ENet/RPC routing)
  -> MatchmakingManager (queue and 2–4 player batching)
  -> SessionManager (session ID, members, load state, cleanup)
  -> Main local world host (instantiates the current RaidScene)
  -> RaidScene (players, enemies, projectiles, damage simulation)
```

## Ownership

- `NetworkManager`: connection lifecycle, peer registry, RPC validation/routing,
  and client-facing status messages. It does not own matchmaking queues or
  session data.
- `MatchmakingManager`: queue membership and match selection only. When a batch
  is ready it emits `match_ready(members)`; it never instantiates a Raid Scene.
- `SessionManager`: creates `raid_N` IDs, tracks player-to-session mapping,
  member/loaded state, and closes an empty session. Its public boundary is
  `create_session`, `get_session`, `get_session_members`,
  `get_player_session`, `begin_loading`, `mark_player_loaded`, and
  `remove_player`.
- `Main`: current-process local-world host. The single server-only method
  `_create_local_server_raid_world` is the only place that instantiates the
  authoritative Raid Scene for a session.
- `RaidScene`: gameplay state for that local world. Raid RPC fan-out uses
  `NetworkManager.get_session_members(raid_session_id)`, not all connected peers.

## Current limit and future replacement boundary

`SessionManager.MAX_ACTIVE_SESSIONS` is currently `1`, because `Main` has one
authoritative local Raid Scene and `GameState` remains a single-world gameplay
state. Additional completed matches remain logical sessions in
`WAITING_FOR_WORLD` until a local slot opens.

To move to dedicated raid-server processes later, replace the local-world
activation path behind `SessionManager.activate_session()` / `world_requested`:
allocate an external server and return a session descriptor instead of asking
`Main` to instantiate a local Raid Scene. Matchmaking, player-session mapping,
and client lobby requests do not need to know how that world was allocated.

## Session isolation

Each `RaidScene` is assigned `raid_session_id` before entering the tree. Player
spawn, snapshots, enemy state, projectile state, cast effects, and extraction
fan-out select recipients through that session's member list. Enemies and
projectiles live under that Raid Scene's runtime actor/effect roots, giving them
the same local-world ownership as their players.

## Leave paths

- Extraction: Raid gameplay asks `NetworkManager`; it routes to
  `SessionManager.remove_player(peer, "extracted")`, returns only that client to
  its personal lobby, and leaves other session members active.
- Disconnect: `NetworkManager` removes the peer from matchmaking and then asks
  `SessionManager` to remove it from its session. An empty session is closed in
  `SessionManager`; the queue itself remains available.
