#!/usr/bin/env python3
"""Update APR Route Recorder's TOC from Blizzard's official version feed."""

from __future__ import annotations

import argparse
import re
import sys
import urllib.error
import urllib.request
from collections.abc import Iterable
from pathlib import Path


VERSION_URL = "https://us.version.battle.net/{product}/versions"
BUILD_PATTERN = re.compile(r"^(\d+)\.(\d+)\.(\d+)\.(\d+)$")
PRODUCT_PATTERN = re.compile(r"^[a-z0-9_]+$")
INTERFACE_PATTERN = re.compile(r"^[1-9]\d{4,}$")
INTERFACE_LINE_PATTERN = re.compile(
    r"^(?P<prefix>## Interface:[ \t]*)(?P<value>[^\r\n]*)(?P<ending>\r?\n|$)",
    re.MULTILINE,
)

LIVE_PRODUCTS = ("wow",)
PTR_PRODUCTS = ("wowt", "wowxptr")
BETA_PRODUCTS = ("wow_beta",)


def get_product_build(product: str, region: str = "us") -> str:
    """Return a validated full build from Blizzard's HTTPS version feed."""
    if not PRODUCT_PATTERN.fullmatch(product):
        raise ValueError(f"Invalid Blizzard product: {product!r}")

    request = urllib.request.Request(
        VERSION_URL.format(product=product),
        headers={"User-Agent": "APR Route Recorder TOC updater"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = response.read().decode("utf-8-sig")

    for line in payload.splitlines():
        if not line or line.startswith("#") or line.startswith("Region!"):
            continue
        columns = line.split("|")
        if len(columns) >= 6 and columns[0].strip().lower() == region.lower():
            build = columns[5].strip()
            if BUILD_PATTERN.fullmatch(build):
                return build
            break

    raise RuntimeError(
        f"No valid build found for Blizzard product {product!r} "
        f"in region {region!r}"
    )


def build_to_interface(build: str) -> int:
    """Convert a full build such as 12.1.0.69587 to Interface 120100."""
    match = BUILD_PATTERN.fullmatch(build)
    if not match:
        raise ValueError(f"Invalid WoW build: {build!r}")

    major, minor, patch, _ = (int(part) for part in match.groups())
    if major == 0 or minor > 99 or patch > 99:
        raise ValueError(f"Build cannot be represented as a TOC Interface: {build!r}")

    interface = int(f"{major}{minor:02d}{patch:02d}")
    validate_interface(interface)
    return interface


def validate_interface(interface: int) -> None:
    """Reject invalid values, especially the zero value produced by the old updater."""
    value = str(interface)
    if interface <= 0 or not INTERFACE_PATTERN.fullmatch(value):
        raise ValueError(f"Invalid TOC Interface value: {value!r}")


def parse_interface_list(value: str) -> set[int]:
    versions: set[int] = set()
    for item in value.split(","):
        item = item.strip()
        if not INTERFACE_PATTERN.fullmatch(item) or int(item) <= 0:
            raise ValueError(f"Invalid value in ## Interface: {item!r}")
        versions.add(int(item))
    if not versions:
        raise ValueError("## Interface must contain at least one version")
    return versions


def update_toc_content(content: str, discovered: Iterable[int]) -> str:
    """Add discovered versions without ever removing supported versions."""
    discovered_versions = set(discovered)
    if not discovered_versions:
        raise ValueError("No Interface versions were discovered")
    for interface in discovered_versions:
        validate_interface(interface)

    matches = list(INTERFACE_LINE_PATTERN.finditer(content))
    if len(matches) != 1:
        raise ValueError(
            f"Expected exactly one ## Interface line, found {len(matches)}"
        )
    match = matches[0]

    merged = parse_interface_list(match.group("value")) | discovered_versions
    value = ", ".join(str(version) for version in sorted(merged))
    replacement = f"{match.group('prefix')}{value}{match.group('ending')}"
    return content[: match.start()] + replacement + content[match.end() :]


def read_text_preserving_newlines(path: Path) -> str:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return handle.read()


def write_text_preserving_newlines(path: Path, content: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(content)


def update_toc(path: Path, products: Iterable[str], region: str = "us") -> bool:
    """Resolve every product before touching the TOC, then update it if needed."""
    builds: dict[str, str] = {}
    interfaces: set[int] = set()
    for product in dict.fromkeys(products):
        build = get_product_build(product, region)
        interface = build_to_interface(build)
        builds[product] = build
        interfaces.add(interface)
        print(f"{product}: {build} -> Interface {interface}")

    original = read_text_preserving_newlines(path)
    updated = update_toc_content(original, interfaces)
    if updated == original:
        print(f"{path}: already up to date")
        return False

    write_text_preserving_newlines(path, updated)
    print(f"{path}: updated from {', '.join(builds)}")
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--toc",
        type=Path,
        default=Path("APR-Recorder.toc"),
        help="TOC file to update",
    )
    parser.add_argument("--region", default="us", help="Blizzard region to select")
    parser.add_argument("--ptr", action="store_true", help="Include Retail PTR products")
    parser.add_argument("--beta", action="store_true", help="Include the Retail beta product")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    products = [*LIVE_PRODUCTS]
    if args.ptr:
        products.extend(PTR_PRODUCTS)
    if args.beta:
        products.extend(BETA_PRODUCTS)

    try:
        update_toc(args.toc, products, args.region)
    except (OSError, UnicodeError, ValueError, RuntimeError, urllib.error.URLError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
