extends Node
## LAN multiplayer (phones on the same Wi-Fi). Host-authoritative: the host runs the race sim and
## streams snapshots; clients send race calls. Discovery is a UDP broadcast beacon; manual IP join
## is the fallback (some routers/Android builds filter broadcasts).
##   Co-op: everyone races for the host's team against the AI field; team points decide the result.
##   Versus: each player races for their own team — circuit (with or without the AI field), drag, hillclimb.

signal hosts_changed(list: Array)
signal lobby_changed(state: Dictionary)
signal race_setup(setup: Dictionary)
signal snap(s: Dictionary)
signal msgs(arr: Array)
signal results(res: Dictionary)
signal closed(reason: String)
signal joined()

const PORT := 47810
const DISC_PORT := 47811
const MAX_PEERS := 4
const GAME_ID := "topprix1"

var role := "off"            # off | host | client
var peer: ENetMultiplayerPeer
var lobby := {}
var slots := {}              # host: peer_id -> garage slot
var hosts := {}              # client: ip -> beacon info
var udp_tx: PacketPeerUDP
var udp_rx: PacketPeerUDP
var beacon_t := 0.0
var race_view: RaceView      # host: where remote race calls are applied
var in_race := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _shutdown("Couldn't reach the host."))
	multiplayer.server_disconnected.connect(func(): _shutdown("Host left the session."))

func my_id() -> int:
	return multiplayer.get_unique_id() if role != "off" else 1

# ---------------- hosting / joining ----------------
func host(mode: String) -> int:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PEERS)
	if err != OK: return err
	multiplayer.multiplayer_peer = peer
	role = "host"
	lobby = {"mode": mode, "race_id": "", "fmt_id": "", "duel": "circuit", "field": true, "cls": "open",
		"host": Game.player.name, "team": Game.player.team, "col": Game.player.col, "players": {}}
	slots.clear()
	_register(1, _my_info(), Game.race_slot())
	udp_tx = PacketPeerUDP.new()
	udp_tx.set_broadcast_enabled(true)
	return OK

func join(ip: String) -> int:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK: return err
	multiplayer.multiplayer_peer = peer
	role = "client"
	return OK

func leave() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	role = "off"
	in_race = false
	lobby = {}
	slots.clear()
	udp_tx = null

func _shutdown(reason: String) -> void:
	var was := role
	leave()
	if was != "off": closed.emit(reason)

func _my_info() -> Dictionary:
	var s := Game.slot()
	var b: Dictionary = Data.body(s.veh.body)
	return {"name": Game.player.name, "team": Game.player.team, "col": Game.player.col, "label": s.label,
		"cls": b.cls, "kind": b.kind, "ready": false}

# ---------------- discovery ----------------
func listen(on: bool) -> void:
	if on and udp_rx == null:
		udp_rx = PacketPeerUDP.new()
		udp_rx.set_broadcast_enabled(true)
		if udp_rx.bind(DISC_PORT) != OK: udp_rx = null
	elif not on and udp_rx:
		udp_rx.close(); udp_rx = null
	hosts.clear()

func _process(delta: float) -> void:
	if role == "host" and udp_tx and not in_race:
		beacon_t -= delta
		if beacon_t <= 0:
			beacon_t = 1.0
			var pkt := JSON.stringify({"g": GAME_ID, "name": lobby.host, "team": lobby.team, "mode": lobby.mode, "n": lobby.players.size()}).to_utf8_buffer()
			for addr in ["255.255.255.255", "127.0.0.1"]:
				udp_tx.set_dest_address(addr, DISC_PORT)
				udp_tx.put_packet(pkt)
	if udp_rx:
		var changed := false
		while udp_rx.get_available_packet_count() > 0:
			var data := udp_rx.get_packet()
			var ip := udp_rx.get_packet_ip()
			var info = JSON.parse_string(data.get_string_from_utf8())
			if typeof(info) == TYPE_DICTIONARY and info.get("g") == GAME_ID:
				info.ip = ip
				info.seen = Time.get_ticks_msec()
				changed = changed or not hosts.has(ip)
				hosts[ip] = info
		for ip in hosts.keys():
			if Time.get_ticks_msec() - hosts[ip].seen > 4000:
				hosts.erase(ip); changed = true
		if changed: hosts_changed.emit(hosts.values())

# ---------------- lobby ----------------
func _on_connected() -> void:
	rpc_id(1, "rpc_register", _my_info(), _slot_payload(Game.race_slot()))
	joined.emit()

static func _slot_payload(s: Dictionary) -> Dictionary:
	return {"label": s.label, "veh": s.veh, "drv": s.drv, "ctx": s.get("ctx", {})}

func _on_peer_connected(_id: int) -> void:
	pass  # clients register themselves

func _on_peer_disconnected(id: int) -> void:
	if role != "host": return
	lobby.players.erase(id)
	slots.erase(id)
	if in_race and race_view and race_view.sim:
		for e in race_view.sim.ents:
			if e.human and int(e.owner) == id and not e.fin and not e.dnf:
				e.owner = 1  # host's crew brings it home
	_push_lobby()

@rpc("any_peer", "call_remote", "reliable")
func rpc_register(info: Dictionary, slot: Dictionary) -> void:
	if role != "host": return
	var id := multiplayer.get_remote_sender_id()
	if lobby.players.size() >= MAX_PEERS or in_race:
		peer.disconnect_peer(id)
		return
	_register(id, info, slot)

func _register(id: int, info: Dictionary, slot: Dictionary) -> void:
	lobby.players[id] = info
	slots[id] = slot
	_push_lobby()

@rpc("any_peer", "call_remote", "reliable")
func rpc_update_slot(info: Dictionary, slot: Dictionary) -> void:
	if role != "host": return
	_register(multiplayer.get_remote_sender_id(), info, slot)

func update_my_slot() -> void:
	if role == "host": _register(1, _my_info(), Game.race_slot())
	elif role == "client": rpc_id(1, "rpc_update_slot", _my_info(), _slot_payload(Game.race_slot()))

func set_lobby(key: String, value) -> void:
	if role != "host": return
	lobby[key] = value
	_push_lobby()

func _push_lobby() -> void:
	lobby_changed.emit(lobby)
	if role == "host": rpc("rpc_lobby", lobby)

@rpc("authority", "call_remote", "reliable")
func rpc_lobby(state: Dictionary) -> void:
	lobby = state
	lobby_changed.emit(lobby)

## Races the whole lobby can enter (class + duel type filters).
func eligible_races() -> Array:
	var classes := {}
	for id in lobby.get("players", {}):
		classes[lobby.players[id].cls] = true
	var out := []
	for r in Data.D.RACES:
		var ok := true
		for c in classes:
			if not Data.race_cls_ok(r, c): ok = false
		var lc: String = lobby.get("cls", "open")
		if lc != "open" and int(r.tier) != int(lc.substr(1)): ok = false
		if lobby.mode == "versus":
			match lobby.duel:
				"drag": ok = ok and r.style == "drag"
				"hill": ok = ok and r.style == "hill"
				_: ok = ok and r.style != "drag" and r.style != "hill"
		if ok: out.append(r)
	return out

# ---------------- race (host) ----------------
func host_start() -> Dictionary:
	if role != "host" or lobby.race_id == "": return {}
	var def: Dictionary = Data.race(lobby.race_id)
	var fmts := Data.formats_m1(def.id)
	var fm: Dictionary = fmts[0]
	for f in fmts:
		if f.id == lobby.fmt_id: fm = f
	var coop: bool = lobby.mode == "coop"
	var track := RaceSim.build_track(def, false, fm.laps if int(fm.laps) != int(def.laps) else null)
	var humans := []
	var ids: Array = lobby.players.keys()
	ids.sort()
	for id in ids:
		var info: Dictionary = lobby.players[id]
		var team: String = lobby.team if coop else info.team
		var key: String = "coop" if coop else "p%d" % id
		var he := Game.make_entry(slots[id], track, int(id), team, key, info.col)
		var lc: String = lobby.get("cls", "open")
		if lc != "open": Game.cap_entry(he, int(lc.substr(1)))
		humans.append(he)
	var opts := {"fmt": fm, "mode": Game.player.mode}
	if def.style == "drag":
		opts.n_rivals = 0 if humans.size() > 1 else 1
	elif not coop and not lobby.field:
		opts.n_rivals = 0
	var rs := RaceSim.create(def, humans, opts)
	var stat := []
	for e in rs.ents:
		stat.append({"idx": e.idx, "name": e.name, "team": e.team, "team_key": e.team_key, "col": e.col, "kind": e.kind,
			"human": e.human, "owner": e.get("owner", 0), "lane": e.lane, "prog": e.prog})
	var setup := {"race_id": def.id, "fmt": fm, "rain": rs.rain, "ents": stat, "mode": lobby.mode, "countdown": 1.6}
	in_race = true
	rpc("rpc_race_start", setup)
	return {"sim": rs, "setup": setup}

@rpc("authority", "call_remote", "reliable")
func rpc_race_start(setup: Dictionary) -> void:
	in_race = true
	race_setup.emit(setup)

func host_snapshot(s: Dictionary) -> void:
	if role == "host": rpc("rpc_snap", s)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_snap(s: Dictionary) -> void:
	snap.emit(s)

func host_msgs(arr: Array) -> void:
	if role == "host": rpc("rpc_msgs", arr)

@rpc("authority", "call_remote", "reliable")
func rpc_msgs(arr: Array) -> void:
	msgs.emit(arr)

func host_results(res: Dictionary) -> void:
	if role != "host": return
	in_race = false
	rpc("rpc_results", res)

@rpc("authority", "call_remote", "reliable")
func rpc_results(res: Dictionary) -> void:
	in_race = false
	results.emit(res)

# ---------------- race calls (client -> host) ----------------
func send_cmd(idx: int, kind: String, arg: String) -> void:
	if role == "client": rpc_id(1, "rpc_cmd", idx, kind, arg)

@rpc("any_peer", "call_remote", "reliable")
func rpc_cmd(idx: int, kind: String, arg: String) -> void:
	if role != "host" or race_view == null: return
	race_view.apply_cmd(idx, kind, arg, multiplayer.get_remote_sender_id())

func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and not a.begins_with("172.17.")):
			return a
	return "127.0.0.1"
