from __future__ import annotations

import re
import sys


def main() -> None:
	versions = [argument.removeprefix("v") for argument in sys.argv[1:]]
	if not versions or any(not re.fullmatch(r"\d+\.\d+\.\d+", version) for version in versions):
		raise SystemExit("Expected one or more base versions in MAJOR.MINOR.PATCH form")
	major, minor, patch = max(tuple(int(part) for part in version.split(".")) for version in versions)
	patch += 1
	if patch > 999:
		patch = 0
		minor += 1
	if minor > 999:
		minor = 0
		major += 1

	version = f"{major}.{minor}.{patch}"
	version_code = major * 1_000_000 + minor * 1_000 + patch
	if version_code <= 0 or version_code > 2_100_000_000:
		raise SystemExit("Next version is outside the supported Android version-code range")
	print(version)


if __name__ == "__main__":
	main()
