class_name MarkdownConverter
extends Node

# 简单 Markdown → BBCode 转换（覆盖常用元素）
static func to_bbcode(t: String) -> String:
	var lines = t.split("\n")
	for i in range(lines.size()):
		var line = lines[i]
		if line.begins_with("##"):
			line = line.trim_prefix("#").trim_prefix("#").trim_prefix(" ").trim_prefix("#").trim_prefix(" ")
			line = "[b][u][font_size=22]%s[/font_size][/u][/b]" % line
		elif line.begins_with("###"):
			line = line.trim_prefix("#").trim_prefix("#").trim_prefix("#").trim_prefix(" ")
			line = "[b][u][font_size=18]%s[/font_size][/u][/b]" % line
		elif line.begins_with("**") and line.ends_with("**"):
			line = "[b][font_size=17]%s[/font_size][/b]" % line.trim_prefix("**").trim_suffix("**")
		elif line.begins_with("- "):
			line = "  •  %s" % line.trim_prefix("- ")
		elif line.begins_with("|"):
			line = line.replace("|", "  ")
		elif line.begins_with("---"):
			line = "──────────────────────────────"
		var bold_start = line.find("**")
		if bold_start >= 0:
			var bold_end = line.find("**", bold_start + 2)
			if bold_end >= 0:
				line = line.left(bold_start) + "[b][font_size=17]" + line.substr(bold_start + 2, bold_end - bold_start - 2) + "[/font_size][/b]" + line.substr(bold_end + 2)
		lines[i] = line
	return "\n".join(lines)
