from __future__ import annotations

import re
import sys
from pathlib import Path


def replace_preserving_newlines(path: Path, pattern: str, replacement: str) -> None:
	original = path.read_bytes().decode("utf-8")
	newline = "\r\n" if "\r\n" in original else "\n"
	normalized = original.replace("\r\n", "\n")
	if not re.search(pattern, normalized, flags=re.MULTILINE):
		raise SystemExit(f"Could not update {path}: version setting not found")
	updated = re.sub(pattern, replacement, normalized, count=1, flags=re.MULTILINE)
	path.write_text(updated.replace("\n", newline), encoding="utf-8", newline="")


def main() -> None:
	version = sys.argv[1].removeprefix("v") if len(sys.argv) > 1 else ""
	if not re.fullmatch(r"\d+\.\d+\.\d+", version):
		raise SystemExit("Expected a release version in MAJOR.MINOR.PATCH form")

	major, minor, patch = (int(part) for part in version.split("."))
	version_code = major * 1_000_000 + minor * 1_000 + patch
	if version_code <= 0 or version_code > 2_100_000_000:
		raise SystemExit("Version is outside the supported Android version-code range")

	project = Path("project.godot")
	replace_preserving_newlines(project, r'^config/version="[^"]+"$', f'config/version="{version}"')

	presets = Path("export_presets.cfg")
	original = presets.read_bytes().decode("utf-8")
	newline = "\r\n" if "\r\n" in original else "\n"
	text = original.replace("\r\n", "\n")
	start = text.find("[preset.2.options]")
	if start < 0:
		raise SystemExit("Android export preset was not found")
	section_end = text.find("\n[", start + 1)
	if section_end < 0:
		section_end = len(text)
	section = text[start:section_end]
	section, code_count = re.subn(r'^version/code=\d+$', f"version/code={version_code}", section, count=1, flags=re.MULTILINE)
	section, name_count = re.subn(r'^version/name="[^"]+"$', f'version/name="{version}"', section, count=1, flags=re.MULTILINE)
	if code_count != 1 or name_count != 1:
		raise SystemExit("Android version settings were not found in the export preset")
	text = text[:start] + section + text[section_end:]
	presets.write_text(text.replace("\n", newline), encoding="utf-8", newline="")


if __name__ == "__main__":
	main()
