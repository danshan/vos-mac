extends RefCounted

const MAX_INTEGER: int = 9007199254740991


static func parse_object(text: String, cancel: Callable = Callable()) -> Dictionary:
	if cancelled(cancel):
		return {}
	# V2 uses integer/rational numbers. Reject Godot's relaxed JSON syntax and duplicate keys.
	if text.to_utf8_buffer().has(0):
		return {}
	var number := RegEx.new()
	number.compile("^-?(0|[1-9][0-9]*)$")
	var stack: Array[Dictionary] = []
	var index := 0
	var previous := ""
	while index < text.length():
		if index % 16384 == 0 and cancelled(cancel):
			return {}
		var ch := text[index]
		if ch == '"':
			var start := index
			index += 1
			while index < text.length() and text[index] != '"':
				if index % 16384 == 0 and cancelled(cancel):
					return {}
				if text.unicode_at(index) < 32:
					return {}
				if text[index] == "\\":
					var length := _escape_length(text, index)
					if length == 0:
						return {}
					index += length
				else:
					index += 1
			if index >= text.length():
				return {}
			if not stack.is_empty() and stack.back()["object"] and stack.back()["key"]:
				var key: Variant = JSON.parse_string(text.substr(start, index - start + 1))
				if not key is String or stack.back()["seen"].has(key):
					return {}
				stack.back()["seen"][key] = true
				stack.back()["key"] = false
			previous = "value"
		elif ch == "{" or ch == "[":
			if stack.size() >= 128:
				return {}
			stack.append({"object": ch == "{", "key": ch == "{", "seen": {}})
			previous = ch
		elif ch == "}" or ch == "]":
			if stack.is_empty() or previous == ",":
				return {}
			stack.pop_back()
			previous = ch
		elif ch in [",", ":"]:
			if ch == "," and not stack.is_empty() and stack.back()["object"]:
				stack.back()["key"] = true
			previous = ch
		elif not ch in [" ", "\t", "\n", "\r"]:
			var start := index
			while index < text.length() and not text[index] in [" ", "\t", "\n", "\r", ",", "]", "}", ":", "[", "{", '"']:
				if index % 16384 == 0 and cancelled(cancel):
					return {}
				index += 1
			var token := text.substr(start, index - start)
			if not token in ["true", "false", "null"] and number.search(token) == null:
				return {}
			index -= 1
			previous = "value"
		index += 1
	if cancelled(cancel):
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary or cancelled(cancel):
		return {}
	return json.data


static func _escape_length(text: String, index: int) -> int:
	if index + 1 >= text.length():
		return 0
	if text[index + 1] in ['"', "\\", "/", "b", "f", "n", "r", "t"]:
		return 2
	if text[index + 1] != "u" or index + 6 > text.length():
		return 0
	var hex := text.substr(index + 2, 4)
	for ch: String in hex:
		if not "0123456789abcdefABCDEF".contains(ch):
			return 0
	var code := hex.hex_to_int()
	if code == 0 or (code >= 0xdc00 and code <= 0xdfff):
		return 0
	if code >= 0xd800 and code <= 0xdbff:
		if index + 12 > text.length() or text.substr(index + 6, 2) != "\\u":
			return 0
		var low := text.substr(index + 8, 4)
		for ch: String in low:
			if not "0123456789abcdefABCDEF".contains(ch):
				return 0
		if low.hex_to_int() < 0xdc00 or low.hex_to_int() > 0xdfff:
			return 0
		return 12
	return 6


static func fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() != names.size():
		return false
	for name: String in names:
		if not value.has(name):
			return false
	return true


static func integer(value: Variant, maximum: int = MAX_INTEGER) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
			and value >= 0 and value <= maximum and float(value) == floor(float(value))


static func identifier(value: Variant, prefix: String) -> bool:
	if not value is String or not value.begins_with(prefix) or value.length() != prefix.length() + 64:
		return false
	for ch: String in value.substr(prefix.length()):
		if not "0123456789abcdef".contains(ch):
			return false
	return true


static func text(value: Variant, nonempty: bool = false) -> bool:
	return value is String and (not nonempty or not value.is_empty()) and not value.to_utf8_buffer().has(0)


static func relative_path(value: Variant, portable: bool = true) -> bool:
	if not value is String or value.is_empty() or value.contains("\\") or value.to_utf8_buffer().has(0):
		return false
	if value.length() > 1 and value[1] == ":" and "abcdefghijklmnopqrstuvwxyz".contains(value[0].to_lower()):
		return false
	var parts: PackedStringArray = value.split("/")
	if portable and parts.size() > 64:
		return false
	for part: String in parts:
		if part in ["", ".", ".."]:
			return false
	if portable:
		var alphabet := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
		if not alphabet.contains(value[0]):
			return false
		for ch: String in value:
			if not (alphabet + "._/-").contains(ch):
				return false
	return true


static func ratio(value: Variant, minimum: float, maximum: float) -> bool:
	return fields(value, ["numerator", "denominator"]) \
			and (value["numerator"] is int or value["numerator"] is float) \
			and integer(absf(float(value["numerator"]))) \
			and integer(value["denominator"], 4294967295) and value["denominator"] > 0 \
			and ratio_value(value) >= minimum and ratio_value(value) <= maximum


static func ratio_value(value: Dictionary) -> float:
	return float(value["numerator"]) / float(value["denominator"])


static func sha256(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return "sha256:" + hash.finish().hex_encode()


static func number_bytes(value: int, width: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	for shift in range((width - 1) * 8, -1, -8):
		bytes.append((value >> shift) & 255)
	return bytes


static func framed(bytes: PackedByteArray) -> PackedByteArray:
	return number_bytes(bytes.size(), 8) + bytes


static func digest_bytes(value: String) -> PackedByteArray:
	return value.right(64).hex_decode()


static func shape(value: Variant, required: Array, optional: Array) -> bool:
	if not value is Dictionary:
		return false
	for key: String in required:
		if not value.has(key):
			return false
	for key: Variant in value:
		if not required.has(key) and not optional.has(key):
			return false
	return true


static func cancelled(check: Callable) -> bool:
	return check.is_valid() and bool(check.call())
