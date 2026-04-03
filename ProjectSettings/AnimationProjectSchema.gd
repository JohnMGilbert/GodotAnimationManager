extends RefCounted
class_name AnimationProjectSchema

const SCHEMA_VERSION := "aam.v1"

static func create_empty_project(project_name: String, created_at: String = "") -> Dictionary:
	var timestamp := created_at if created_at != "" else Time.get_datetime_string_from_system(true)

	return {
		"schema": SCHEMA_VERSION,
		"name": project_name,
		"created_at": timestamp,
		"animations": {},
		"current_animation": "",
		"assets": {
			"sprites": [],
			"audio": []
		},
		"export": {},
		"asset_tags": {}
	}


static func normalize_project_data(raw: Variant) -> Dictionary:
	var normalized := create_empty_project("")
	if not (raw is Dictionary):
		return normalized

	var source := raw as Dictionary

	var schema_val: Variant = source.get("schema", SCHEMA_VERSION)
	normalized["schema"] = String(schema_val) if schema_val is String else SCHEMA_VERSION

	var name_val: Variant = source.get("name", "")
	if name_val is String:
		normalized["name"] = name_val

	var created_at_val: Variant = source.get("created_at", "")
	if created_at_val is String:
		normalized["created_at"] = created_at_val

	var current_animation_val: Variant = source.get("current_animation", "")
	if current_animation_val is String:
		normalized["current_animation"] = current_animation_val

	var animations_val: Variant = source.get("animations", {})
	if animations_val is Dictionary:
		normalized["animations"] = animations_val

	var assets_val: Variant = source.get("assets", {})
	if assets_val is Dictionary:
		var assets := normalized["assets"] as Dictionary
		var sprites_val: Variant = assets_val.get("sprites", [])
		var audio_val: Variant = assets_val.get("audio", [])
		assets["sprites"] = _normalize_string_array(sprites_val)
		assets["audio"] = _normalize_string_array(audio_val)
		normalized["assets"] = assets

	var export_val: Variant = source.get("export", {})
	if export_val is Dictionary:
		normalized["export"] = export_val

	var tags_val: Variant = source.get("asset_tags", {})
	if tags_val is Dictionary:
		normalized["asset_tags"] = _normalize_tag_map(tags_val)

	return normalized


static func is_valid_project_data(raw: Variant) -> bool:
	if not (raw is Dictionary):
		return false

	var dict := raw as Dictionary
	var schema_val: Variant = dict.get("schema", "")
	return schema_val is String and String(schema_val).begins_with("aam.v")


static func _normalize_string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array or raw is PackedStringArray:
		for value in raw:
			if value is String:
				result.append(value)
	return result


static func _normalize_tag_map(raw: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for asset_id in raw.keys():
		if not (asset_id is String):
			continue
		normalized[String(asset_id)] = _normalize_string_array(raw[asset_id])
	return normalized
