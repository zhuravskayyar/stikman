extends Node

signal status_changed(message: String, can_retry: bool, can_install: bool)

const RELEASE_API := "https://api.github.com/repos/zhuravskayyar/stikman/releases/latest"
const WINDOWS_ASSET := "NotebookArena.exe"
const ANDROID_ASSET := "NotebookArena.apk"

var status_message := ""
var can_retry := false
var can_install := false
var _latest_request: HTTPRequest
var _download_request: HTTPRequest
var _latest_version := ""
var _download_url := ""
var _expected_digest := ""
var _download_path := ""

func _ready() -> void:
	status_message = "GitHub: перевіряю версію гри…"

func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0.0"))

func check_for_updates() -> void:
	if _latest_request != null or _download_request != null:
		return
	_latest_version = ""
	_download_url = ""
	_expected_digest = ""
	_set_status("GitHub: перевіряю актуальну версію…", false, false)
	_latest_request = HTTPRequest.new()
	_latest_request.timeout = 20.0
	_latest_request.max_redirects = 5
	_latest_request.request_completed.connect(_on_latest_release_completed)
	add_child(_latest_request)
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28"
	])
	var error := _latest_request.request(RELEASE_API, headers)
	if error != OK:
		_latest_request.queue_free()
		_latest_request = null
		_set_status("GitHub: не вдалося почати перевірку", true, false)

func open_downloaded_update() -> void:
	if not can_install or _download_path.is_empty():
		return
	if OS.has_feature("android"):
		if not _launch_android_installer():
			_set_status("APK завантажено, але Android не відкрив інсталятор. Натисни ще раз.", false, true)
	else:
		_apply_windows_update()

func _launch_android_installer() -> bool:
	var android_runtime: Object = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		return false
	var activity: Object = android_runtime.getActivity()
	var file_class: Object = JavaClassWrapper.wrap("java.io.File")
	var uri_class: Object = JavaClassWrapper.wrap("android.net.Uri")
	var file_provider: Object = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
	var intent_class: Object = JavaClassWrapper.wrap("android.content.Intent")
	var apk_file: Object = file_class.File(ProjectSettings.globalize_path(_download_path))
	var apk_uri: Object = file_provider.getUriForFile(activity, "com.notebookarena.game.fileprovider", apk_file)
	var intent: Object = intent_class.Intent()
	intent.setAction(intent_class.ACTION_VIEW)
	intent.setDataAndType(apk_uri, "application/vnd.android.package-archive")
	intent.addFlags(intent_class.FLAG_GRANT_READ_URI_PERMISSION | intent_class.FLAG_ACTIVITY_NEW_TASK)
	var open_installer := func() -> void:
		activity.startActivity(intent)
	activity.runOnUiThread(android_runtime.createRunnableFromGodotCallable(open_installer))
	return true

func _on_latest_release_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_instance_valid(_latest_request):
		_latest_request.queue_free()
	_latest_request = null
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_status("GitHub: немає зв'язку, перевірю пізніше", true, false)
		return
	if response_code == 404:
		_set_status("GitHub: релізи ще не опубліковано", false, false)
		return
	if response_code != 200:
		_set_status("GitHub: сервер відповів %d" % response_code, true, false)
		return
	var release_data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not release_data is Dictionary:
		_set_status("GitHub: некоректна відповідь версій", true, false)
		return
	_latest_version = str(release_data.get("tag_name", "")).trim_prefix("v")
	if _latest_version.is_empty():
		_set_status("GitHub: у релізу немає номера версії", true, false)
		return
	if not _is_newer_version(_latest_version, current_version()):
		_set_status("GitHub: встановлена версія актуальна · " + current_version(), false, false)
		return
	if OS.has_feature("web"):
		_refresh_browser_build()
		return
	var asset_name := ""
	if OS.has_feature("windows"):
		asset_name = WINDOWS_ASSET
	elif OS.has_feature("android"):
		asset_name = ANDROID_ASSET
	else:
		_set_status("Знайдено %s, але для цього пристрою немає збірки" % _latest_version, false, false)
		return
	for asset in release_data.get("assets", []):
		if asset is Dictionary and str(asset.get("name", "")) == asset_name:
			_download_url = str(asset.get("browser_download_url", ""))
			_expected_digest = str(asset.get("digest", ""))
			break
	if _download_url.is_empty():
		_set_status("Знайдено %s, але файл %s ще не завантажено" % [_latest_version, asset_name], true, false)
		return
	_download_latest(asset_name)

func _download_latest(asset_name: String) -> void:
	var updates_dir := ProjectSettings.globalize_path("user://updates")
	var make_dir_error := DirAccess.make_dir_recursive_absolute(updates_dir)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		_set_status("Не вдалося створити теку для оновлення", true, false)
		return
	_download_path = "user://updates/" + asset_name
	var global_download_path := ProjectSettings.globalize_path(_download_path)
	if FileAccess.file_exists(_download_path):
		DirAccess.remove_absolute(global_download_path)
	_download_request = HTTPRequest.new()
	_download_request.timeout = 0.0
	_download_request.max_redirects = 8
	_download_request.request_completed.connect(_on_download_completed)
	_download_request.download_file = global_download_path
	add_child(_download_request)
	_set_status("Завантажую Notebook Arena %s з GitHub…" % _latest_version, false, false)
	var error := _download_request.request(_download_url)
	if error != OK:
		_download_request.queue_free()
		_download_request = null
		_set_status("Не вдалося почати завантаження оновлення", true, false)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if is_instance_valid(_download_request):
		_download_request.queue_free()
	_download_request = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not FileAccess.file_exists(_download_path):
		_set_status("Не вдалося завантажити оновлення з GitHub", true, false)
		return
	var downloaded_file := FileAccess.open(_download_path, FileAccess.READ)
	var downloaded_size := downloaded_file.get_length() if downloaded_file != null else 0
	if downloaded_file != null:
		downloaded_file.close()
	if downloaded_size < 1_000_000:
		_set_status("Файл оновлення неповний — видалив його", true, false)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_download_path))
		return
	if not _verify_digest(_download_path, _expected_digest):
		_set_status("Контрольна сума оновлення не збігається — файл видалено", true, false)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_download_path))
		return
	if OS.has_feature("windows"):
		_apply_windows_update()
	elif OS.has_feature("android"):
		can_install = true
		_set_status("APK %s завантажено · відкриваю встановлення…" % _latest_version, false, true)
		open_downloaded_update()

func _apply_windows_update() -> void:
	var downloaded_exe := ProjectSettings.globalize_path(_download_path)
	var running_exe := OS.get_executable_path()
	var script_path := ProjectSettings.globalize_path("user://updates/apply-update.ps1")
	var script_lines := PackedStringArray([
		"$ErrorActionPreference = 'Stop'",
		"$gamePid = %d" % OS.get_process_id(),
		"$source = %s" % _powershell_quote(downloaded_exe),
		"$target = %s" % _powershell_quote(running_exe),
		"while (Get-Process -Id $gamePid -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 350 }",
		"try { Copy-Item -LiteralPath $source -Destination $target -Force; Start-Process -FilePath $target; Remove-Item -LiteralPath $source -Force } catch { Start-Process -FilePath $source }"
	])
	var file := FileAccess.open("user://updates/apply-update.ps1", FileAccess.WRITE)
	if file == null:
		_set_status("Оновлення завантажене, але не вдалося підготувати перезапуск", false, false)
		return
	file.store_string("\n".join(script_lines))
	file.close()
	var process_id := OS.create_process("powershell.exe", PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_path]), false)
	if process_id < 0:
		_set_status("Оновлення збережено: " + downloaded_exe, false, false)
		return
	_set_status("Notebook Arena оновлюється до %s і перезапуститься" % _latest_version, false, false)
	get_tree().quit()

func _refresh_browser_build() -> void:
	_set_status("Браузерна гра оновлюється до %s…" % _latest_version, false, false)
	var js_version := JSON.stringify(_latest_version)
	JavaScriptBridge.eval("const u = new URL(window.location.href); u.searchParams.set('v', %s); window.location.replace(u.toString());" % js_version, true)

func _verify_digest(path: String, digest: String) -> bool:
	if not digest.begins_with("sha256:"):
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var hasher := HashingContext.new()
	if hasher.start(HashingContext.HASH_SHA256) != OK:
		file.close()
		return false
	while not file.eof_reached():
		var chunk := file.get_buffer(65536)
		if chunk.is_empty():
			break
		hasher.update(chunk)
	file.close()
	return "sha256:" + hasher.finish().hex_encode() == digest.to_lower()

func _is_newer_version(candidate: String, installed: String) -> bool:
	var candidate_parts := _numeric_version_parts(candidate)
	var installed_parts := _numeric_version_parts(installed)
	if candidate_parts.is_empty() or installed_parts.is_empty():
		return candidate != installed
	var part_count := maxi(candidate_parts.size(), installed_parts.size())
	for index in range(part_count):
		var candidate_part: int = candidate_parts[index] if index < candidate_parts.size() else 0
		var installed_part: int = installed_parts[index] if index < installed_parts.size() else 0
		if candidate_part != installed_part:
			return candidate_part > installed_part
	return false

func _numeric_version_parts(version: String) -> Array[int]:
	var result: Array[int] = []
	for part in version.split("."):
		var digits := ""
		for character in part:
			if character >= "0" and character <= "9":
				digits += character
			else:
				break
		if digits.is_empty():
			return []
		result.append(int(digits))
	return result

func _powershell_quote(value: String) -> String:
	return "'" + value.replace("'", "''") + "'"

func _set_status(message: String, retry: bool, install: bool) -> void:
	status_message = message
	can_retry = retry
	can_install = install
	status_changed.emit(message, retry, install)
