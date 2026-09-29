from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> None:
	if len(sys.argv) != 3 or not re.fullmatch(r"\d+\.\d+\.\d+", sys.argv[2]):
		raise SystemExit("Usage: stamp_web_version.py WEB_EXPORT_DIR MAJOR.MINOR.PATCH")

	web_dir = Path(sys.argv[1])
	version = sys.argv[2]
	base_name = f"index-{version}"
	asset_suffixes = [
		".js",
		".pck",
		".wasm",
		".audio.worklet.js",
		".audio.position.worklet.js",
	]
	versioned_asset_pattern = re.compile(r"^index-\d+\.\d+\.\d+(?:\.audio\.position\.worklet\.js|\.audio\.worklet\.js|\.js|\.pck|\.wasm)$")
	for old_asset in web_dir.iterdir():
		if versioned_asset_pattern.fullmatch(old_asset.name):
			old_asset.unlink()
	for suffix in asset_suffixes:
		source = web_dir / f"index{suffix}"
		target = web_dir / f"{base_name}{suffix}"
		if not source.is_file():
			raise SystemExit(f"Expected Godot Web asset was not exported: {source}")
		source.replace(target)

	html_path = web_dir / "index.html"
	html = html_path.read_text(encoding="utf-8")
	replacements = {
		'src="index.js"': f'src="{base_name}.js"',
		'"executable":"index"': f'"executable":"{base_name}"',
		'"index.pck":': f'"{base_name}.pck":',
		'"index.wasm":': f'"{base_name}.wasm":',
	}
	for old, new in replacements.items():
		if old not in html:
			raise SystemExit(f"Godot Web template no longer contains {old}")
		html = html.replace(old, new, 1)
	html_path.write_text(html, encoding="utf-8", newline="")


if __name__ == "__main__":
	main()
