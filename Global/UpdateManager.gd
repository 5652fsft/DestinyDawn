extends Node
# 自动更新：GitHub Release 检查 + 流式下载 + 安装（Windows 用 bat 延迟替换）
# VERSION 为游戏内唯一版本来源，发布时同步修改 export_presets.cfg 路径。

const VERSION = "1.7.1"
const REPO = "5652fsft/DestinyDawn"
const API_URL = "https://api.github.com/repos/%s/releases/latest" % REPO

# 内置加速镜像（格式：镜像前缀 + 原始 URL）
const MIRROR_URLS: Dictionary = {
	"direct": "",
	"ghfast": "https://ghfast.top/",
	"ghproxy": "https://ghproxy.net/",
}

const UPDATE_DIR_NAME = ".dd_update"
const CHUNK_SIZE = 64 * 1024
const CONNECT_TIMEOUT_MS = 15000
const READ_TIMEOUT_MS = 30000

enum CheckState { IDLE, CHECKING, UP_TO_DATE, UPDATE_AVAILABLE, ERROR }
enum DownloadState { IDLE, DOWNLOADING, READY, INSTALLING, ERROR }

signal check_state_changed(state: int, message: String)
signal download_state_changed(state: int, progress: int, total: int, message: String)

# 最近一次检查结果（供 UI 直接读取）
var latest_version: String = ""
var latest_asset_url: String = ""
var latest_asset_name: String = ""
var latest_asset_size: int = 0
var release_url: String = ""
var current_check_state: int = CheckState.IDLE
var last_check_message: String = ""
var update_dismissed: bool = false

var _checking: bool = false
var _downloading: bool = false
var _download_total: int = 0

# 状态更新入口：记录当前状态供 UI 查询，并广播信号
func _set_check_state(state: int, message: String):
	current_check_state = state
	last_check_message = message
	check_state_changed.emit(state, message)

# ============================================================
#  版本比较
# ============================================================

static func _parse_version(s: String) -> Array[int]:
	var t = s.strip_edges().trim_prefix("v")
	var parts = t.split(".")
	var out: Array[int] = []
	for p in parts:
		var n = int(p)
		out.append(n if n >= 0 else 0)
	return out

# 返回 remote 是否比 local 新（语义化 a.b.c 比较）
static func is_newer(local_v: String, remote_v: String) -> bool:
	var a = _parse_version(local_v)
	var b = _parse_version(remote_v)
	for i in range(max(a.size(), b.size())):
		var x = a[i] if i < a.size() else 0
		var y = b[i] if i < b.size() else 0
		if x != y:
			return y > x
	return false

# ============================================================
#  检查更新（HTTPClient 小请求，支持代理）
# ============================================================

func check_for_update() -> void:
	if _checking:
		return
	_checking = true
	_set_check_state(CheckState.CHECKING, "")
	latest_version = ""
	latest_asset_url = ""
	latest_asset_name = ""
	latest_asset_size = 0
	release_url = ""

	var body: Dictionary = {"ok": false, "code": 0, "body": ""}
	for url in _url_candidates(API_URL):
		body = await _http_get(url)
		if body.ok:
			break

	if not body.ok:
		_checking = false
		if body.code == 404:
			_set_check_state(CheckState.ERROR, "未找到发布版本（仓库尚未发布 Release）")
		else:
			_set_check_state(CheckState.ERROR, "网络连接失败，请检查网络或更换更新通道")
		return

	var json = JSON.parse_string(body.body)
	if not (json is Dictionary):
		_checking = false
		_set_check_state(CheckState.ERROR, "更新服务器响应异常")
		return

	var tag: String = json.get("tag_name", "")
	if tag.is_empty():
		_checking = false
		_set_check_state(CheckState.ERROR, "未找到发布版本")
		return
	latest_version = tag.trim_prefix("v")
	release_url = json.get("html_url", "")

	for asset in json.get("assets", []):
		var name: String = asset.get("name", "")
		if _is_platform_asset(name):
			latest_asset_url = asset.get("browser_download_url", "")
			latest_asset_name = name
			latest_asset_size = asset.get("size", 0)
			break

	_checking = false
	if is_newer(VERSION, latest_version):
		_set_check_state(CheckState.UPDATE_AVAILABLE, latest_version)
	else:
		_set_check_state(CheckState.UP_TO_DATE, latest_version)

func _http_get(url: String) -> Dictionary:
	var parsed = _parse_url(url)
	if parsed.is_empty():
		return {"ok": false, "code": 0, "body": ""}
	var client = HTTPClient.new()
	_apply_proxy(client)
	var tls_opts: TLSOptions = TLSOptions.client() if parsed.tls else null
	var err = client.connect_to_host(parsed.host, parsed.port, tls_opts)
	if err != OK:
		print("[Update] connect 失败: ", err, " url=", url)
		client.close()
		return {"ok": false, "code": 0, "body": ""}

	var deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if Time.get_ticks_msec() > deadline:
			client.close()
			return {"ok": false, "code": 0, "body": ""}
		await get_tree().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		print("[Update] 连接未建立，status=", client.get_status())
		client.close()
		return {"ok": false, "code": 0, "body": ""}

	err = client.request(HTTPClient.METHOD_GET, parsed.path, ["User-Agent: DestinyDawn/" + VERSION])
	if err != OK:
		client.close()
		return {"ok": false, "code": 0, "body": ""}

	var resp_body := PackedByteArray()
	deadline = Time.get_ticks_msec() + READ_TIMEOUT_MS
	while true:
		client.poll()
		var status = client.get_status()
		if status == HTTPClient.STATUS_BODY:
			var chunk = client.read_response_body_chunk()
			if not chunk.is_empty():
				resp_body.append_array(chunk)
				deadline = Time.get_ticks_msec() + READ_TIMEOUT_MS
			if Time.get_ticks_msec() > deadline:
				break
			if resp_body.size() > 4 * 1024 * 1024:
				break
		elif status == HTTPClient.STATUS_DISCONNECTED:
			break
		elif status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE:
			print("[Update] 请求失败，status=", status)
			client.close()
			return {"ok": false, "code": 0, "body": ""}
		else:
			if Time.get_ticks_msec() > deadline:
				break
		await get_tree().process_frame

	var code = client.get_response_code()
	client.close()
	if code != 200:
		print("[Update] HTTP ", code, " url=", url)
		return {"ok": false, "code": code, "body": ""}
	return {"ok": true, "code": code, "body": resp_body.get_string_from_utf8()}

# 若配置了 HTTP 代理（如本地 Clash 127.0.0.1:7897），应用到客户端
func _apply_proxy(client: HTTPClient):
	var host: String = GlobalGameData.update_proxy_host.strip_edges()
	if host.is_empty():
		return
	var port: int = GlobalGameData.update_proxy_port
	if port <= 0 or port > 65535:
		port = 7897
	client.set_http_proxy(host, port)
	client.set_https_proxy(host, port)

# ============================================================
#  下载（HTTPClient 流式，避免大文件进内存）
# ============================================================

func download_update() -> void:
	if _downloading or latest_asset_url.is_empty():
		return
	_downloading = true
	_download_total = 0
	download_state_changed.emit(DownloadState.DOWNLOADING, 0, latest_asset_size, "")

	var save_path = _get_download_save_path()
	if save_path.is_empty():
		_downloading = false
		download_state_changed.emit(DownloadState.ERROR, 0, 0, "无法创建更新目录")
		return

	var ok: bool = false
	for url in _url_candidates(latest_asset_url):
		ok = await _stream_download(url, save_path)
		if ok:
			break

	if ok:
		var size = _file_size(save_path)
		if size == latest_asset_size:
			_downloading = false
			download_state_changed.emit(DownloadState.READY, size, latest_asset_size, latest_asset_name)
			return
		DirAccess.remove_absolute(save_path)
	_downloading = false
	download_state_changed.emit(DownloadState.ERROR, 0, 0, "下载失败，请重试或更换更新通道")

func _get_download_save_path() -> String:
	if OS.has_feature("editor"):
		var dir = "user://update"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		return ProjectSettings.globalize_path(dir + "/" + latest_asset_name)
	var exe_dir = OS.get_executable_path().get_base_dir()
	var staging = exe_dir + "/" + UPDATE_DIR_NAME
	if DirAccess.make_dir_recursive_absolute(staging) != OK and not DirAccess.dir_exists_absolute(staging):
		return ""
	return staging + "/" + latest_asset_name

func _stream_download(url: String, save_path: String) -> bool:
	var parsed = _parse_url(url)
	if parsed.is_empty():
		return false
	var client = HTTPClient.new()
	_apply_proxy(client)
	var tls_opts: TLSOptions = TLSOptions.client() if parsed.tls else null
	var err = client.connect_to_host(parsed.host, parsed.port, tls_opts)
	if err != OK:
		client.close()
		return false

	var deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if Time.get_ticks_msec() > deadline:
			client.close()
			return false
		await get_tree().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return false

	err = client.request(HTTPClient.METHOD_GET, parsed.path, ["User-Agent: DestinyDawn/" + VERSION])
	if err != OK:
		client.close()
		return false

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		client.close()
		return false

	var total_len = 0
	var total_read = 0
	var last_activity = Time.get_ticks_msec()
	var succeeded = false
	while true:
		client.poll()
		var status = client.get_status()
		if status == HTTPClient.STATUS_BODY:
			if total_len == 0:
				total_len = client.get_response_body_length()
				if total_len <= 0:
					total_len = latest_asset_size
			var chunk = client.read_response_body_chunk()
			if not chunk.is_empty():
				file.store_buffer(chunk)
				total_read += chunk.size()
				last_activity = Time.get_ticks_msec()
				download_state_changed.emit(DownloadState.DOWNLOADING, total_read, total_len)
			elif Time.get_ticks_msec() - last_activity > READ_TIMEOUT_MS:
				break
			if total_len > 0 and total_read >= total_len:
				succeeded = true
				break
		elif status == HTTPClient.STATUS_DISCONNECTED:
			succeeded = total_read >= total_len and total_len > 0
			break
		elif status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_REQUESTING:
			if Time.get_ticks_msec() - last_activity > READ_TIMEOUT_MS:
				break
		elif status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE:
			break
		else:
			break
		await get_tree().process_frame

	file.close()
	client.close()
	return succeeded

# ============================================================
#  安装（Windows：bat 延迟替换 exe；Android：浏览器下载）
# ============================================================

func install_update() -> void:
	if OS.get_name() != "Windows" or latest_asset_name.is_empty():
		return
	if OS.has_feature("editor"):
		print("[Update] 编辑器内跳过安装")
		return
	var exe_dir = OS.get_executable_path().get_base_dir()
	var staging = exe_dir + "/" + UPDATE_DIR_NAME
	var new_exe = staging + "/" + latest_asset_name
	var current_exe = OS.get_executable_path()
	var bat_path = staging + "/install_update.bat"

	var bat = "@echo off\r\n"
	bat += "rem DestinyDawn auto update installer\r\n"
	bat += "timeout /t 3 /nobreak >nul\r\n"
	bat += "move /y \"" + new_exe + "\" \"" + current_exe + "\" >nul 2>&1\r\n"
	bat += "if errorlevel 1 goto :fail\r\n"
	bat += "start \"\" \"" + current_exe + "\"\r\n"
	bat += "del \"" + bat_path + "\"\r\n"
	bat += "exit /b 0\r\n"
	bat += ":fail\r\n"
	bat += "del \"" + bat_path + "\"\r\n"
	bat += "exit /b 1\r\n"
	var f = FileAccess.open(bat_path, FileAccess.WRITE)
	if not f:
		download_state_changed.emit(DownloadState.ERROR, 0, 0, "无法写入安装脚本")
		return
	f.store_string(bat)
	f.close()

	download_state_changed.emit(DownloadState.INSTALLING, 0, 0, "")
	OS.create_process("cmd.exe", ["/c", bat_path])
	get_tree().quit()

# Android：无自动安装能力，交给系统浏览器打开 release 下载页
func open_release_page() -> void:
	if release_url.is_empty():
		return
	OS.shell_open(release_url)

# ============================================================
#  工具
# ============================================================

# 依据当前代理设置生成候选 URL 列表（镜像优先，直连兜底）
func _url_candidates(original: String) -> Array[String]:
	var out: Array[String] = []
	var mode: String = GlobalGameData.proxy_mode
	if mode == "custom" and not GlobalGameData.proxy_prefix.is_empty():
		out.append(GlobalGameData.proxy_prefix + original)
	elif mode != "direct" and MIRROR_URLS.has(mode):
		out.append(MIRROR_URLS[mode] + original)
	out.append(original)
	return out

func _is_platform_asset(name: String) -> bool:
	if OS.get_name() == "Android":
		return name.ends_with(".apk")
	return name.ends_with(".exe")

static func _parse_url(url: String) -> Dictionary:
	var tls = true
	var rest = url
	if rest.begins_with("https://"):
		rest = rest.trim_prefix("https://")
	elif rest.begins_with("http://"):
		rest = rest.trim_prefix("http://")
		tls = false
	else:
		return {}
	var slash = rest.find("/")
	var host: String = rest
	var path: String = "/"
	if slash != -1:
		host = rest.substr(0, slash)
		path = rest.substr(slash)
	var port = 443 if tls else 80
	if ":" in host:
		var parts = host.split(":")
		host = parts[0]
		port = int(parts[1])
	return {"host": host, "port": port, "path": path, "tls": tls}

static func _file_size(path: String) -> int:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return -1
	var size = f.get_length()
	f.close()
	return size
