class_name MarkdownConverter
extends Node

static func to_bbcode(t: String) -> String:
	var lines = t.split("\n")
	var result = []
	var in_code_block = false
	var code_buffer = []
	var table_buffer = []
	var in_table = false

	for line in lines:
		if line.strip_edges() == "```":
			if in_code_block:
				result.append("[codeblock]" + "\n".join(code_buffer) + "[/codeblock]")
				code_buffer = []
				in_code_block = false
			else:
				if in_table:
					result.append(_build_table(table_buffer))
					table_buffer = []
					in_table = false
				in_code_block = true
			continue

		if in_code_block:
			code_buffer.append(line)
			continue

		if line.begins_with("|"):
			if not in_table:
				in_table = true
				table_buffer = []
			table_buffer.append(line)
			continue
		else:
			if in_table:
				result.append(_build_table(table_buffer))
				table_buffer = []
				in_table = false

		result.append(_process_line(line))

	if in_code_block and code_buffer.size() > 0:
		result.append("[codeblock]" + "\n".join(code_buffer) + "[/codeblock]")
	if in_table and table_buffer.size() > 0:
		result.append(_build_table(table_buffer))

	return "\n".join(result)


static func _process_line(line: String) -> String:
	var p = line

	if p.begins_with("# "):
		p = "[b][u][font_size=26]%s[/font_size][/u][/b]" % p.trim_prefix("# ").trim_prefix("#")
	elif p.begins_with("##"):
		p = p.trim_prefix("#").trim_prefix("#").trim_prefix(" ").trim_prefix("#").trim_prefix(" ")
		p = "[b][u][font_size=22]%s[/font_size][/u][/b]" % p
	elif p.begins_with("###"):
		p = p.trim_prefix("#").trim_prefix("#").trim_prefix("#").trim_prefix(" ")
		p = "[b][u][font_size=18]%s[/font_size][/u][/b]" % p
	elif p.begins_with("**") and p.ends_with("**"):
		p = "[b][font_size=17]%s[/font_size][/b]" % p.trim_prefix("**").trim_suffix("**")
	elif p.begins_with("- "):
		p = "  •  %s" % p.trim_prefix("- ")
	elif p.begins_with("---"):
		p = "──────────────────────────────"
	elif p.begins_with(">"):
		p = "[i][color=#ffffff]%s[/color][/i]" % p.trim_prefix(">").trim_prefix(" ")

	return _apply_inline_formatting(p)


static func _build_table(rows: Array) -> String:
	if rows.is_empty():
		return ""

	var data_rows = []
	var header_row = ""
	for i in range(rows.size()):
		var trimmed = rows[i].strip_edges()
		var stripped = trimmed.replace("|", "").replace("-", "").replace(":", "").strip_edges()
		if stripped.is_empty():
			continue
		if header_row.is_empty():
			header_row = rows[i]
		else:
			data_rows.append(rows[i])

	if header_row.is_empty():
		return ""

	var cells = _parse_table_row(header_row)
	var col_count = cells.size()
	if col_count == 0:
		return ""

	var bbcode = "[table=%d]" % col_count

	for cell in cells:
		bbcode += "[cell][b]%s[/b][/cell]" % _apply_inline_formatting(cell.strip_edges())

	for row in data_rows:
		bbcode += "\n"
		cells = _parse_table_row(row)
		for cell in cells:
			bbcode += "[cell]%s[/cell]" % _apply_inline_formatting(cell.strip_edges())

	bbcode += "\n[/table]"
	return bbcode


static func _apply_inline_formatting(t: String) -> String:
	var p = t
	var bold_start = p.find("**")
	if bold_start >= 0:
		var bold_end = p.find("**", bold_start + 2)
		if bold_end >= 0:
			p = p.left(bold_start) + "[b][font_size=17]" + p.substr(bold_start + 2, bold_end - bold_start - 2) + "[/font_size][/b]" + p.substr(bold_end + 2)

	var code_start = p.find("`")
	if code_start >= 0:
		var code_end = p.find("`", code_start + 1)
		if code_end >= 0:
			p = p.left(code_start) + "[code]" + p.substr(code_start + 1, code_end - code_start - 1) + "[/code]" + p.substr(code_end + 1)

	return p


static func _parse_table_row(line: String) -> Array:
	var content = line.strip_edges()
	if content.begins_with("|"):
		content = content.substr(1)
	if content.ends_with("|"):
		content = content.substr(0, content.length() - 1)

	var cells = []
	for cell in content.split("|"):
		cells.append(cell.strip_edges())
	return cells
