@tool
extends EditorPlugin

const DOCUMENTATION_ROOT := "res://src"

var _refresh_queued := false


func _enter_tree() -> void:
	var editor_file_system := EditorInterface.get_resource_filesystem()
	if not editor_file_system.filesystem_changed.is_connected(_queue_documentation_refresh):
		editor_file_system.filesystem_changed.connect(_queue_documentation_refresh)
	_queue_documentation_refresh()


func _exit_tree() -> void:
	var editor_file_system := EditorInterface.get_resource_filesystem()
	if editor_file_system.filesystem_changed.is_connected(_queue_documentation_refresh):
		editor_file_system.filesystem_changed.disconnect(_queue_documentation_refresh)


func _queue_documentation_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_documentation.call_deferred()


func _refresh_documentation() -> void:
	_refresh_queued = false
	var script_paths := PackedStringArray()
	_collect_script_paths(DOCUMENTATION_ROOT, script_paths)
	script_paths.sort()

	var script_editor := EditorInterface.get_script_editor()
	for script_path: String in script_paths:
		var documented_script := ResourceLoader.load(script_path) as Script
		if documented_script != null:
			script_editor.update_docs_from_script(documented_script)

	# Rebuild the visible property controls so an already selected component picks
	# up the refreshed documentation without requiring the user to reselect it.
	var inspector := EditorInterface.get_inspector()
	var inspected_object := inspector.get_edited_object()
	if inspected_object != null:
		inspector.edit(inspected_object)


func _collect_script_paths(directory_path: String, script_paths: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_warning("Could not scan %s for Inspector documentation." % directory_path)
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if not entry_name.begins_with("."):
			var entry_path := directory_path.path_join(entry_name)
			if directory.current_is_dir():
				_collect_script_paths(entry_path, script_paths)
			elif entry_name.get_extension().to_lower() == "gd":
				script_paths.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
