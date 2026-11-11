# Compiles every GDScript in the project and reports the ones that fail.
# Used by CI (.github/workflows/godot-ci.yml):
#   godot --headless --path . --script res://tools/check_scripts.gd
extends SceneTree


func _init() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	var bad: Array[String] = []
	for path in files:
		var s = load(path)
		if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate():
			bad.append(path)
	for p in bad:
		printerr("SCRIPT CHECK FAILED: " + p)
	print("SCRIPT CHECK: %d scripts, %d failed" % [files.size(), bad.size()])
	quit(1 if not bad.is_empty() else 0)


func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d in ["addons", "build", "web", "python_server", "relay", "web-scraper-tool", "docs", "report"]:
			continue
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and dir.path_join(f) != "res://tools/check_scripts.gd":
			out.append(dir.path_join(f))
