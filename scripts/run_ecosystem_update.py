#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""
Run a full ecosystem refresh/rebuild/verification cycle and publish a final status bundle.
"""

from __future__ import annotations

import csv
import json
import subprocess
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = ROOT.parents[1]
COMMAND_CENTER_ROOT = WORKSPACE_ROOT / "github" / "dominion-command-center"
DATA_DIR = ROOT / "data"
REPORTS_DIR = ROOT / "reports"
TELEMETRY_DIR = ROOT / "telemetry"
BACKUPS_DIR = ROOT / "backups"
ERICA_EMAIL = "sacredselfworkshops@gmail.com"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def refresh_apollo(run_id: str) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    started = utc_now()
    start_time = time.time()
    source = "apollo"
    input_path = DATA_DIR / "apollo_crm" / "accounts_raw.json"
    output_path = DATA_DIR / "apollo_crm" / "crm_accounts.json"
    csv_path = DATA_DIR / "apollo_crm" / "crm_accounts.csv"
    warnings: List[str] = []

    raw_data = read_json(input_path, {})
    if isinstance(raw_data, dict):
        organizations = raw_data.get("organizations", [])
    elif isinstance(raw_data, list):
        organizations = raw_data
    else:
        organizations = []
        warnings.append("Input payload is not a dict/list; treated as empty.")

    accounts: List[Dict[str, Any]] = []
    for index, org in enumerate(organizations, start=1):
        if not isinstance(org, dict):
            warnings.append(f"Skipped non-object organization at index {index - 1}.")
            continue

        if "account_id" in org and "account_name" in org:
            account = {
                "account_id": str(org.get("account_id", "") or f"apollo_{index:04d}"),
                "account_name": str(org.get("account_name", "")),
                "domain": str(org.get("domain", "")),
                "apollo_score": _safe_int(org.get("apollo_score", 0)),
                "industry": str(org.get("industry", "")),
                "headcount": _safe_int(org.get("headcount", 0)),
                "revenue_range": str(org.get("revenue_range", "")),
                "city": str(org.get("city", "")),
                "state": str(org.get("state", "")),
                "country": str(org.get("country", "")),
                "linkedin_url": str(org.get("linkedin_url", "")),
                "twitter_url": str(org.get("twitter_url", "")),
                "facebook_url": str(org.get("facebook_url", "")),
                "phone": str(org.get("phone", "")),
                "founded_year": org.get("founded_year", ""),
                "description": str(org.get("description", "")),
            }
        else:
            account = {
                "account_id": str(org.get("id", "") or f"apollo_{index:04d}"),
                "account_name": str(org.get("name", "")),
                "domain": str(org.get("primary_domain", "")),
                "apollo_score": _safe_int(org.get("account_score", 0)),
                "industry": str(org.get("industry", "")),
                "headcount": _safe_int(org.get("employee_count", 0)),
                "revenue_range": str(org.get("revenue_range", "")),
                "city": str(org.get("city", "")),
                "state": str(org.get("state", "")),
                "country": str(org.get("country", "")),
                "linkedin_url": str(org.get("linkedin_url", "")),
                "twitter_url": str(org.get("twitter_url", "")),
                "facebook_url": str(org.get("facebook_url", "")),
                "phone": str(org.get("phone", "")),
                "founded_year": org.get("founded_year", ""),
                "description": str(org.get("short_description", "")),
            }

        account["last_updated"] = utc_now()
        account["data_source"] = "apollo_api_snapshot"
        accounts.append(account)

    write_json(output_path, accounts)

    fieldnames = [
        "account_id",
        "account_name",
        "domain",
        "apollo_score",
        "industry",
        "headcount",
        "revenue_range",
        "city",
        "state",
        "country",
        "linkedin_url",
        "twitter_url",
        "facebook_url",
        "phone",
        "founded_year",
        "description",
        "last_updated",
        "data_source",
    ]
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in accounts:
            writer.writerow(row)

    ended = utc_now()
    telemetry = {
        "source": source,
        "run_id": run_id,
        "started_at_utc": started,
        "ended_at_utc": ended,
        "duration_ms": int((time.time() - start_time) * 1000),
        "status": "success",
        "input_file": str(input_path),
        "output_file": str(output_path),
        "records_in": len(organizations),
        "records_out": len(accounts),
        "warnings": warnings,
    }

    return telemetry, accounts


def refresh_gmail(run_id: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    started = utc_now()
    start_time = time.time()
    source = "gmail"
    path = DATA_DIR / "gmail_contacts" / "contacts.json"
    warnings: List[str] = []

    payload = read_json(path, {})
    if not isinstance(payload, dict):
        warnings.append("Input payload is not an object; reset to empty object.")
        payload = {}

    normalized: Dict[str, Any] = {}
    for key, value in payload.items():
        if not isinstance(value, dict):
            warnings.append(f"Skipped non-object contact payload for key '{key}'.")
            continue

        email = str(value.get("email") or key or "").strip().lower()
        if not email:
            warnings.append(f"Skipped empty email contact for key '{key}'.")
            continue

        normalized[email] = {
            "name": str(value.get("name", "")).strip(),
            "email": email,
            "interaction_count": _safe_int(value.get("interaction_count", 0)),
            "last_contact": str(value.get("last_contact", "")).strip(),
            "first_contact": str(value.get("first_contact", "")).strip(),
            "threads": [str(thread) for thread in value.get("threads", []) if str(thread).strip()],
        }

    ordered = {key: normalized[key] for key in sorted(normalized)}
    write_json(path, ordered)

    telemetry = {
        "source": source,
        "run_id": run_id,
        "started_at_utc": started,
        "ended_at_utc": utc_now(),
        "duration_ms": int((time.time() - start_time) * 1000),
        "status": "success",
        "input_file": str(path),
        "output_file": str(path),
        "records_in": len(payload),
        "records_out": len(ordered),
        "warnings": warnings,
    }

    return telemetry, ordered


def refresh_google_drive(run_id: str) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    started = utc_now()
    start_time = time.time()
    source = "google_drive"
    path = DATA_DIR / "google_drive" / "documents.json"
    warnings: List[str] = []

    payload = read_json(path, [])
    if not isinstance(payload, list):
        warnings.append("Input payload is not an array; reset to empty list.")
        payload = []

    documents: List[Dict[str, Any]] = []
    for index, item in enumerate(payload):
        if not isinstance(item, dict):
            warnings.append(f"Skipped non-object document at index {index}.")
            continue

        shared = item.get("shared_with", [])
        if not isinstance(shared, list):
            shared = []

        owners = item.get("owners", [])
        if not isinstance(owners, list):
            owners = []

        document = {
            "id": str(item.get("id", "")).strip(),
            "name": str(item.get("name", "")).strip(),
            "mime_type": str(item.get("mime_type") or item.get("mimeType") or "").strip(),
            "size": _safe_int(item.get("size", 0)),
            "created_time": str(item.get("created_time") or item.get("createdTime") or "").strip(),
            "modified_time": str(item.get("modified_time") or item.get("modifiedTime") or "").strip(),
            "owners": [str(owner).strip().lower() for owner in owners if str(owner).strip()],
            "shared_with": [str(email).strip().lower() for email in shared if str(email).strip()],
            "web_view_link": str(item.get("web_view_link") or item.get("webViewLink") or "").strip(),
            "description": str(item.get("description", "")).strip(),
        }
        documents.append(document)

    write_json(path, documents)

    telemetry = {
        "source": source,
        "run_id": run_id,
        "started_at_utc": started,
        "ended_at_utc": utc_now(),
        "duration_ms": int((time.time() - start_time) * 1000),
        "status": "success",
        "input_file": str(path),
        "output_file": str(path),
        "records_in": len(payload),
        "records_out": len(documents),
        "warnings": warnings,
    }

    return telemetry, documents


def refresh_dropbox(run_id: str) -> Tuple[Dict[str, Any], List[Dict[str, Any]]]:
    started = utc_now()
    start_time = time.time()
    source = "dropbox"
    path = DATA_DIR / "dropbox_drive" / "files.json"
    warnings: List[str] = []

    payload = read_json(path, [])
    if not isinstance(payload, list):
        warnings.append("Input payload is not an array; reset to empty list.")
        payload = []

    files: List[Dict[str, Any]] = []
    for index, item in enumerate(payload):
        if not isinstance(item, dict):
            warnings.append(f"Skipped non-object file entry at index {index}.")
            continue

        shared = item.get("shared_with", [])
        if not isinstance(shared, list):
            shared = []

        file_entry = {
            "id": str(item.get("id", "")).strip(),
            "name": str(item.get("name", "")).strip(),
            "path": str(item.get("path") or item.get("path_display") or "").strip(),
            "size": _safe_int(item.get("size", 0)),
            "server_modified": str(item.get("server_modified", "")).strip(),
            "client_modified": str(item.get("client_modified", "")).strip(),
            "rev": str(item.get("rev", "")).strip(),
            "content_hash": str(item.get("content_hash", "")).strip(),
            "shared_with": [str(email).strip().lower() for email in shared if str(email).strip()],
        }
        files.append(file_entry)

    write_json(path, files)

    telemetry = {
        "source": source,
        "run_id": run_id,
        "started_at_utc": started,
        "ended_at_utc": utc_now(),
        "duration_ms": int((time.time() - start_time) * 1000),
        "status": "success",
        "input_file": str(path),
        "output_file": str(path),
        "records_in": len(payload),
        "records_out": len(files),
        "warnings": warnings,
    }

    return telemetry, files


def run_unifier(run_id: str) -> Dict[str, Any]:
    command = [sys.executable, str(ROOT / "scripts" / "create_unified_relationships.py")]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)

    log_file = TELEMETRY_DIR / f"erica_unifier_{run_id}.log"
    combined = []
    combined.append(f"timestamp_utc={utc_now()}")
    combined.append("command=" + " ".join(command))
    combined.append("return_code=" + str(result.returncode))
    combined.append("stdout=")
    combined.append(result.stdout.rstrip())
    combined.append("stderr=")
    combined.append(result.stderr.rstrip())
    write_text(log_file, "\n".join(combined).strip() + "\n")

    success_token = "Created unified database with"
    success = result.returncode == 0 and success_token in result.stdout

    return {
        "status": "success" if success else "failed",
        "command": command,
        "return_code": result.returncode,
        "log_file": str(log_file),
        "stdout_tail": result.stdout.strip().splitlines()[-3:] if result.stdout.strip() else [],
        "stderr_tail": result.stderr.strip().splitlines()[-3:] if result.stderr.strip() else [],
        "success_token": success_token,
        "success_token_present": success_token in result.stdout,
    }


def evaluate_quality_gates(
    run_id: str,
    source_results: Dict[str, Dict[str, Any]],
    contacts: Dict[str, Any],
) -> Dict[str, Any]:
    unified_path = DATA_DIR / "unified_relationships.json"
    analysis_path = REPORTS_DIR / "relationship_analysis.json"
    relationships = read_json(unified_path, [])
    analysis = read_json(analysis_path, {})

    schema_violations: List[Dict[str, Any]] = []
    required_fields = [
        "entity_id",
        "entity_name",
        "email",
        "relationship_score",
        "interaction_count",
        "data_sources",
    ]

    normalized_emails: List[str] = []
    empty_email_rows: List[int] = []
    source_presence = Counter()

    for index, row in enumerate(relationships):
        if not isinstance(row, dict):
            schema_violations.append({"index": index, "issue": "Relationship row is not an object."})
            continue

        for field in required_fields:
            if field not in row:
                schema_violations.append({"index": index, "issue": f"Missing required field: {field}"})

        email = str(row.get("email", "")).strip().lower()
        if not email:
            empty_email_rows.append(index)
        else:
            normalized_emails.append(email)

        if not isinstance(row.get("data_sources", []), list):
            schema_violations.append({"index": index, "issue": "data_sources must be an array."})
            continue

        for source in row.get("data_sources", []):
            source_presence[str(source)] += 1

    duplicate_emails = [email for email, count in Counter(normalized_emails).items() if count > 1]

    ingestion_coverage = {
        source: {
            "status": details.get("status"),
            "records_out": details.get("records_out", 0),
            "covered": details.get("status") == "success" and details.get("records_out", 0) > 0,
        }
        for source, details in source_results.items()
    }
    source_coverage_ok = all(item["covered"] for item in ingestion_coverage.values())

    key_contacts = sorted({email.lower() for email in contacts.keys()} | {ERICA_EMAIL})
    unified_set = set(normalized_emails)
    missing_key_contacts = [email for email in key_contacts if email not in unified_set]
    key_contacts_ok = len(missing_key_contacts) == 0

    report_schema_ok = isinstance(analysis, dict) and isinstance(analysis.get("summary"), dict)
    schema_ok = len(schema_violations) == 0 and report_schema_ok
    duplicates_ok = len(duplicate_emails) == 0
    empty_email_ok = len(empty_email_rows) == 0

    quality = {
        "run_id": run_id,
        "generated_at_utc": utc_now(),
        "files": {
            "unified_relationships": str(unified_path),
            "relationship_analysis": str(analysis_path),
        },
        "gates": {
            "schema_validity": {
                "pass": schema_ok,
                "report_schema_ok": report_schema_ok,
                "violations": schema_violations,
            },
            "duplicate_detection": {
                "pass": duplicates_ok,
                "duplicate_emails": duplicate_emails,
            },
            "empty_email_rejection": {
                "pass": empty_email_ok,
                "empty_email_rows": empty_email_rows,
            },
            "source_coverage": {
                "pass": source_coverage_ok,
                "ingestion_coverage": ingestion_coverage,
                "unified_source_presence": dict(source_presence),
            },
            "key_contact_presence": {
                "pass": key_contacts_ok,
                "required_contacts": key_contacts,
                "missing_contacts": missing_key_contacts,
                "erica_present": ERICA_EMAIL in unified_set,
            },
        },
    }

    quality["overall_pass"] = all(gate["pass"] for gate in quality["gates"].values())

    quality_file = TELEMETRY_DIR / f"quality_gates_{run_id}.json"
    write_json(quality_file, quality)
    quality["quality_file"] = str(quality_file)

    return quality


def _parse_json_text(text: str) -> Any:
    content = text.strip()
    if not content:
        return {}
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        first = content.find("{")
        last = content.rfind("}")
        if first >= 0 and last > first:
            return json.loads(content[first : last + 1])
        raise


def run_phi_health_checks(run_id: str) -> Dict[str, Any]:
    results: Dict[str, Any] = {}

    status_script = COMMAND_CENTER_ROOT / "phi_sovereign_status.ps1"
    status_command = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(status_script),
        "-OutputFormat",
        "json",
    ]
    status_run = subprocess.run(status_command, text=True, capture_output=True)
    status_log = TELEMETRY_DIR / f"phi_status_check_{run_id}.log"
    write_text(
        status_log,
        "\n".join(
            [
                f"timestamp_utc={utc_now()}",
                "command=" + " ".join(status_command),
                "return_code=" + str(status_run.returncode),
                "stdout=",
                status_run.stdout.rstrip(),
                "stderr=",
                status_run.stderr.rstrip(),
            ]
        ).strip()
        + "\n",
    )

    status_payload: Dict[str, Any] = {}
    status_parse_error = None
    try:
        status_payload = _parse_json_text(status_run.stdout)
    except json.JSONDecodeError as exc:
        status_parse_error = str(exc)

    status_json_file = TELEMETRY_DIR / f"phi_status_{run_id}.json"
    write_json(status_json_file, status_payload)

    chief_script = WORKSPACE_ROOT / "start-phi-chief-of-staff.ps1"
    chief_command = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(chief_script),
        "-Tenant",
        "fractal5",
        "-Overlay",
        "business",
        "-SkipHarvest",
        "-DeepAudit",
        "-IncludeDemoBuild",
    ]
    chief_run = subprocess.run(chief_command, text=True, capture_output=True)
    chief_log = TELEMETRY_DIR / f"phi_chief_bundle_{run_id}.log"
    write_text(
        chief_log,
        "\n".join(
            [
                f"timestamp_utc={utc_now()}",
                "command=" + " ".join(chief_command),
                "return_code=" + str(chief_run.returncode),
                "stdout=",
                chief_run.stdout.rstrip(),
                "stderr=",
                chief_run.stderr.rstrip(),
            ]
        ).strip()
        + "\n",
    )

    chief_payload: Dict[str, Any] = {}
    chief_parse_error = None
    try:
        chief_payload = _parse_json_text(chief_run.stdout)
    except json.JSONDecodeError as exc:
        chief_parse_error = str(exc)

    chief_json_file = TELEMETRY_DIR / f"phi_chief_bundle_{run_id}.json"
    if chief_payload:
        write_json(chief_json_file, chief_payload)
    else:
        fallback_summary = WORKSPACE_ROOT / ".run" / "phi-chief-of-staff-last.json"
        chief_payload = read_json(fallback_summary, {})
        write_json(chief_json_file, chief_payload)

    doctor_ok = bool(chief_payload.get("doctor", {}).get("ok"))

    results["phi_status"] = {
        "command": status_command,
        "return_code": status_run.returncode,
        "parse_error": status_parse_error,
        "payload_file": str(status_json_file),
        "log_file": str(status_log),
        "overall": status_payload.get("overall"),
        "runtime_ok": all(
            bool(check.get("ok")) for check in status_payload.get("runtime", {}).values()
        )
        if isinstance(status_payload.get("runtime"), dict)
        else False,
    }

    results["chief_bundle"] = {
        "command": chief_command,
        "return_code": chief_run.returncode,
        "parse_error": chief_parse_error,
        "payload_file": str(chief_json_file),
        "log_file": str(chief_log),
        "summary_file": str(WORKSPACE_ROOT / ".run" / "phi-chief-of-staff-last.json"),
        "doctor_ok": doctor_ok,
        "doctor_summary": chief_payload.get("doctor", {}).get("summary"),
    }

    return results


def build_relationship_confirmations(
    relationships: List[Dict[str, Any]],
    source_results: Dict[str, Dict[str, Any]],
    unifier: Dict[str, Any],
    phi_health: Dict[str, Any],
    source_log_files: Dict[str, str],
) -> List[Dict[str, Any]]:
    doctor_ok = bool(phi_health["chief_bundle"].get("doctor_ok"))
    unifier_ok = unifier.get("status") == "success"

    confirmations: List[Dict[str, Any]] = []
    for row in relationships:
        if not isinstance(row, dict):
            continue

        row_sources = [str(source) for source in row.get("data_sources", [])]
        source_checks = {
            source: bool(source_results.get(source, {}).get("status") == "success")
            for source in row_sources
        }
        telemetry_confirmed = unifier_ok and doctor_ok and all(source_checks.values())

        confirmations.append(
            {
                "entity_name": row.get("entity_name", ""),
                "email": row.get("email", ""),
                "relationship_score": row.get("relationship_score", 0),
                "interaction_count": row.get("interaction_count", 0),
                "data_sources": row_sources,
                "last_updated": row.get("last_updated"),
                "telemetry_confirmed": telemetry_confirmed,
                "telemetry_evidence": {
                    "source_refresh_logs": {source: source_log_files.get(source) for source in row_sources},
                    "unifier_log": unifier.get("log_file"),
                    "phi_status_file": phi_health["phi_status"].get("payload_file"),
                    "phi_chief_bundle_file": phi_health["chief_bundle"].get("payload_file"),
                },
            }
        )

    return confirmations


def latest_baseline_snapshot() -> str:
    candidates = sorted(BACKUPS_DIR.glob("ecosystem_baseline_20260319_*"))
    if not candidates:
        return ""
    return str(candidates[-1])


def publish_final_bundle(
    run_id: str,
    source_results: Dict[str, Dict[str, Any]],
    source_log_files: Dict[str, str],
    unifier: Dict[str, Any],
    quality: Dict[str, Any],
    phi_health: Dict[str, Any],
) -> Path:
    unified = read_json(DATA_DIR / "unified_relationships.json", [])
    report = read_json(REPORTS_DIR / "relationship_analysis.json", {})

    confirmations = build_relationship_confirmations(
        relationships=unified,
        source_results=source_results,
        unifier=unifier,
        phi_health=phi_health,
        source_log_files=source_log_files,
    )

    all_sources_ok = all(item.get("status") == "success" for item in source_results.values())
    unifier_ok = unifier.get("status") == "success"
    quality_ok = bool(quality.get("overall_pass"))
    doctor_ok = bool(phi_health["chief_bundle"].get("doctor_ok"))
    per_relationship_ok = all(item.get("telemetry_confirmed") for item in confirmations)

    dod = {
        "all_source_refreshes_succeed_with_telemetry": all_sources_ok,
        "unified_relationships_regenerated_and_quality_passed": unifier_ok and quality_ok,
        "chief_of_staff_health_green_doctor_ok": doctor_ok,
        "final_bundle_confirms_telemetry_for_all_relationships": per_relationship_ok,
    }

    status = "confirmed" if all(dod.values()) else "degraded"

    summary = report.get("summary", {}) if isinstance(report, dict) else {}
    source_breakdown = report.get("source_breakdown", {}) if isinstance(report, dict) else {}

    final_payload = {
        "generated_at_utc": utc_now(),
        "run_id": run_id,
        "request": "ecosystem refresh/rebuild/verification + chief health confirmation",
        "status": status,
        "baseline_snapshot": {
            "snapshot_date": "2026-03-19",
            "backup_dir": latest_baseline_snapshot(),
            "artifacts": [
                "data/gmail_contacts/contacts.json",
                "data/unified_relationships.json",
                "reports/relationship_analysis.json",
                "telemetry/erica_final_status_20260319_060119.json",
            ],
        },
        "source_refresh": {
            "sources": source_results,
            "telemetry_logs": source_log_files,
        },
        "telemetry_confirmation": {
            "latest_unifier_log": unifier.get("log_file"),
            "unifier_log_contains_success": bool(unifier.get("success_token_present")),
            "unified_relationships_file": str(DATA_DIR / "unified_relationships.json"),
            "relationship_analysis_file": str(REPORTS_DIR / "relationship_analysis.json"),
            "quality_gates_file": quality.get("quality_file"),
        },
        "quality_gates": quality,
        "phi_chief": {
            "summary_file": phi_health["chief_bundle"].get("summary_file"),
            "doctor_ok": doctor_ok,
            "doctor_summary": phi_health["chief_bundle"].get("doctor_summary"),
            "phi_status_file": phi_health["phi_status"].get("payload_file"),
            "chief_bundle_file": phi_health["chief_bundle"].get("payload_file"),
            "evidence_logs": {
                "phi_status_log": phi_health["phi_status"].get("log_file"),
                "chief_bundle_log": phi_health["chief_bundle"].get("log_file"),
            },
        },
        "ecosystem_summary": {
            "total_relationships": summary.get("total_relationships", len(unified)),
            "active_contacts": summary.get("active_contacts", 0),
            "high_value_relationships": summary.get("high_value_relationships", 0),
            "source_breakdown": source_breakdown,
        },
        "lessons_learned": [
            "Snapshot-first execution prevents accidental data loss when relationship transforms change.",
            "Per-source telemetry logs make ingestion failures immediately attributable and auditable.",
            "Quality gates catch subtle trust breaks (duplicates, empty emails, key-contact drift) before downstream use.",
            "Chief-of-staff doctor/status evidence should be attached to every ecosystem release bundle.",
        ],
        "relationship_confirmations": confirmations,
        "operationalization": {
            "timezone": "America/Vancouver",
            "cadence": {
                "source_sync": "Every 4 hours at minute 05",
                "unified_rebuild": "Every 4 hours at minute 20",
                "quality_and_bundle_verification": "Every 4 hours at minute 35",
                "chief_health_bundle": "Daily at 06:15",
            },
            "alert_thresholds": {
                "source_ingestion_failure": {
                    "critical": "Any source refresh status != success in a run",
                    "warning": "Source refresh duration > 15 minutes",
                },
                "relationship_count_anomaly": {
                    "warning": "Absolute change > 10% vs trailing 7-run median",
                    "critical": "Absolute change > 25% vs trailing 7-run median",
                },
                "data_quality": {
                    "critical": "Any duplicate emails OR any empty-email rows",
                    "critical_key_contact": "Any missing key contact (including Erica)",
                },
            },
        },
        "definition_of_done": {
            "checks": dod,
            "all_passed": all(dod.values()),
        },
    }

    final_file = TELEMETRY_DIR / f"erica_final_status_{run_id}.json"
    write_json(final_file, final_payload)
    return final_file


def main() -> int:
    TELEMETRY_DIR.mkdir(parents=True, exist_ok=True)
    run_id = run_stamp()

    source_results: Dict[str, Dict[str, Any]] = {}
    source_log_files: Dict[str, str] = {}

    apollo_meta, _apollo_accounts = refresh_apollo(run_id)
    gmail_meta, gmail_contacts = refresh_gmail(run_id)
    drive_meta, _drive_docs = refresh_google_drive(run_id)
    dropbox_meta, _dropbox_files = refresh_dropbox(run_id)

    for meta in [apollo_meta, gmail_meta, drive_meta, dropbox_meta]:
        source = str(meta["source"])
        source_results[source] = meta
        log_path = TELEMETRY_DIR / f"source_refresh_{source}_{run_id}.json"
        write_json(log_path, meta)
        source_log_files[source] = str(log_path)

    run_manifest = {
        "run_id": run_id,
        "generated_at_utc": utc_now(),
        "sources": source_results,
    }
    write_json(TELEMETRY_DIR / f"source_refresh_run_{run_id}.json", run_manifest)

    unifier = run_unifier(run_id)
    quality = evaluate_quality_gates(run_id=run_id, source_results=source_results, contacts=gmail_contacts)
    phi_health = run_phi_health_checks(run_id)

    final_bundle = publish_final_bundle(
        run_id=run_id,
        source_results=source_results,
        source_log_files=source_log_files,
        unifier=unifier,
        quality=quality,
        phi_health=phi_health,
    )

    summary = {
        "run_id": run_id,
        "final_bundle": str(final_bundle),
        "quality_pass": quality.get("overall_pass"),
        "doctor_ok": phi_health["chief_bundle"].get("doctor_ok"),
        "all_source_refreshes_success": all(meta.get("status") == "success" for meta in source_results.values()),
    }
    print(json.dumps(summary, indent=2))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
