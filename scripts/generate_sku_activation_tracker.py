#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""Generate a per-SKU activation tracker CSV from the repo manifest."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


CHECKLIST_COLUMNS = [
    "ci_build_status",
    "ci_sbom_status",
    "ci_vuln_scan_status",
    "ci_image_sign_status",
    "ci_image_push_status",
    "ci_manifest_seal_status",
    "ci_cloud_run_deploy_status",
    "ci_gateway_deploy_status",
    "ci_smoke_test_status",
    "runtime_verified_at",
    "runtime_verified_by",
    "runtime_verification_notes",
]


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Generate a CSV tracker for manifest-listed SKUs."
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=repo_root / "dist" / "command_core" / "manifest.json",
        help="Path to the canonical manifest JSON.",
    )
    parser.add_argument(
        "--products-root",
        type=Path,
        default=repo_root / "products",
        help="Directory containing per-product product.json files.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=repo_root / "reports" / "sku_activation_tracker.csv",
        help="Output CSV path.",
    )
    return parser.parse_args()


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def extract_manifest_slugs(manifest: dict[str, Any]) -> list[str]:
    products = manifest.get("products", [])
    if not isinstance(products, list):
        raise ValueError("Manifest field 'products' must be a list.")

    slugs: list[str] = []
    for product in products:
        if isinstance(product, str):
            slugs.append(product)
            continue
        if isinstance(product, dict):
            slug = product.get("slug") or product.get("product") or product.get("name")
            if slug:
                slugs.append(str(slug))
                continue
        raise ValueError(f"Unsupported manifest product entry: {product!r}")
    return slugs


def infer_family(slug: str, sku: str) -> str:
    if sku.startswith("DOM-OS-") or slug.startswith("dominion-os-"):
        return "dominion-os"
    if sku.startswith("DOM-CC-") or slug.startswith("dominion-cloud-computer"):
        return "dominion-cloud-computer"
    return slug


def infer_known_runtime(product: dict[str, Any]) -> str:
    deployment = product.get("deployment", {})
    if isinstance(deployment, dict):
        platform = deployment.get("platform")
        if platform:
            return str(platform)
    return ""


def build_rows(manifest_path: Path, products_root: Path) -> list[dict[str, str]]:
    manifest = load_json(manifest_path)
    slugs = extract_manifest_slugs(manifest)

    rows: list[dict[str, str]] = []
    for slug in slugs:
        product_path = products_root / slug / "product.json"
        if not product_path.exists():
            raise FileNotFoundError(
                f"Manifest-listed product '{slug}' is missing metadata at {product_path}"
            )

        product = load_json(product_path)
        sku = str(product.get("sku", ""))
        row = {
            "sku": sku,
            "name": str(product.get("name", "")),
            "family": infer_family(slug, sku),
            "manifest_status": "listed_in_manifest",
            "known_runtime": infer_known_runtime(product),
        }
        row.update({column: "" for column in CHECKLIST_COLUMNS})
        rows.append(row)

    return rows


def write_csv(rows: list[dict[str, str]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "sku",
        "name",
        "family",
        "manifest_status",
        "known_runtime",
        *CHECKLIST_COLUMNS,
    ]
    with out_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()
    rows = build_rows(args.manifest, args.products_root)
    write_csv(rows, args.out)
    print(f"Wrote {len(rows)} rows to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
