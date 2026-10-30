class_name WebBridge
extends Node
## Puente con la página anfitriona.
## Juego -> host: {"source":"pochland","type":"ready"|"stats"|"event", ...}
## Host -> juego: {"source":"pochland-host","type":"pause"|"resume"|"mute", ...}

signal host_message(data: Dictionary)

var enabled := false
var _callback_ref: Variant


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		call_deferred("_setup")


func _setup() -> void:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_callback_ref = JavaScriptBridge.create_callback(_on_message)
	window.__pochRecv = _callback_ref
	JavaScriptBridge.eval("""
(function () {
  if (window.__pochHostBridge) return;
  window.__pochHostBridge = true;
  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || d.source !== 'pochland-host') return;
    if (window.__pochRecv) {
      try { window.__pochRecv(JSON.stringify(d)); } catch (err) {}
    }
  }, false);
})();
""", true)
	enabled = true


func _on_message(args: Array) -> void:
	if args.is_empty():
		return
	var text := str(args[0])
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		host_message.emit(data)


func send(payload: Dictionary) -> void:
	if not enabled:
		return
	var json := JSON.stringify(payload)
	JavaScriptBridge.eval("try{window.parent.postMessage(%s, '*');}catch(e){}" % json, true)


func send_ready() -> void:
	send({"source": "pochland", "type": "ready"})


func send_stats(sync: int, packets: int, best: int) -> void:
	send({"source": "pochland", "type": "stats", "sync": sync, "packets": packets, "best": best})


func send_event(name: String) -> void:
	send({"source": "pochland", "type": "event", "name": name})
