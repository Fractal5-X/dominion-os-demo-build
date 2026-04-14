#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""
PHI Chief AI - Token Detection and Protection System
Monitors for unauthorized token usage and potential compromises
"""

import os
import re
import time
from datetime import datetime
from typing import Dict, List

import requests


class AITokenDetector:
    def __init__(self):
        self.authorized_users = {
            "Fractal5-Solutions",
            "authorized-user-1",  # Add actual authorized users
        }
        self.token_patterns = [
            r"ghp_[A-Za-z0-9_]{36}",
            r"github_pat_[A-Za-z0-9_]{82}",
            r"AIza[0-9A-Za-z-_]{35}",
            r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
            r"xoxb-[0-9]{10,12}-[0-9]{10,12}-[A-Za-z0-9]{24}",
            r"sk-[A-Za-z0-9]{48}",
        ]
        self.github_api_url = os.getenv("GITHUB_API_URL", "https://api.github.com").rstrip("/")
        self.github_timeout_seconds = float(os.getenv("GITHUB_TIMEOUT_SECONDS", "15"))
        self.github_min_interval_seconds = float(
            os.getenv("GITHUB_GOVERNOR_MIN_INTERVAL_SECONDS", "2.0")
        )
        self._last_github_request_at = 0.0

    def _governed_github_get(self, path: str, headers: Dict[str, str]) -> requests.Response:
        """Issue a paced GitHub request with retry/backoff."""
        url = f"{self.github_api_url}{path}"
        attempts = 3
        last_error = None

        for attempt in range(1, attempts + 1):
            elapsed = time.monotonic() - self._last_github_request_at
            if elapsed < self.github_min_interval_seconds:
                time.sleep(self.github_min_interval_seconds - elapsed)

            response = requests.get(
                url,
                headers=headers,
                timeout=self.github_timeout_seconds,
            )
            self._last_github_request_at = time.monotonic()

            if response.status_code in (429,):
                retry_after = int(response.headers.get("Retry-After", "5"))
                time.sleep(max(retry_after, 1))
                last_error = RuntimeError(f"GitHub API throttled request to {path}")
                continue

            if response.status_code == 403 and response.headers.get("X-RateLimit-Remaining") == "0":
                reset_at = int(response.headers.get("X-RateLimit-Reset", "0") or "0")
                sleep_for = max(reset_at - int(time.time()), 1)
                time.sleep(min(sleep_for, 60))
                last_error = RuntimeError(f"GitHub API rate limit exhausted for {path}")
                continue

            if response.status_code >= 500:
                time.sleep(attempt)
                last_error = RuntimeError(
                    f"GitHub API server error {response.status_code} for {path}"
                )
                continue

            return response

        if last_error is not None:
            raise last_error
        raise RuntimeError(f"GitHub API request failed for {path}")

    def scan_repository(self, repo_path: str) -> List[Dict]:
        """Scan repository for potential token exposures"""
        findings = []

        for root, dirs, files in os.walk(repo_path):
            # Skip .git and other irrelevant directories
            dirs[:] = [
                d
                for d in dirs
                if not d.startswith(".") and d not in ["node_modules", "__pycache__"]
            ]

            for file in files:
                if file.endswith((".py", ".sh", ".md", ".json", ".yaml", ".yml")):
                    filepath = os.path.join(root, file)
                    try:
                        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                            content = f.read()
                            lines = content.split("\n")

                            for line_num, line in enumerate(lines, 1):
                                for pattern in self.token_patterns:
                                    matches = re.findall(pattern, line)
                                    if matches:
                                        findings.append(
                                            {
                                                "file": filepath,
                                                "line": line_num,
                                                "pattern": pattern,
                                                "matches": matches,
                                                "severity": "HIGH",
                                            }
                                        )
                    except Exception as e:
                        print(f"Error scanning {filepath}: {e}")

        return findings

    def check_github_activity(self, token: str) -> Dict:
        """Check recent GitHub activity for suspicious patterns"""
        try:
            headers = {
                "Authorization": f"token {token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            }
            response = self._governed_github_get("/user", headers=headers)

            if response.status_code == 401:
                return {"status": "INVALID_TOKEN", "message": "Token is invalid or expired"}

            user_data = response.json()
            username = user_data.get("login", "unknown")

            if username not in self.authorized_users:
                return {
                    "status": "UNAUTHORIZED_USER",
                    "user": username,
                    "message": f"Token used by unauthorized user: {username}",
                }

            # Check recent activity
            activity_response = self._governed_github_get(
                f"/users/{username}/events", headers=headers
            )

            if activity_response.status_code == 200:
                events = activity_response.json()
                suspicious_activity = []

                for event in events[:10]:  # Check last 10 events
                    if event.get("type") == "PushEvent":
                        repo = event.get("repo", {}).get("name", "")
                        if "dominion-os" in repo.lower():
                            suspicious_activity.append(
                                {
                                    "type": "PUSH_TO_SENSITIVE_REPO",
                                    "repo": repo,
                                    "time": event.get("created_at"),
                                }
                            )

                return {
                    "status": "OK",
                    "user": username,
                    "suspicious_activity": suspicious_activity,
                }

        except Exception as e:
            return {"status": "ERROR", "message": str(e)}

    def generate_security_report(self, findings: List[Dict], activity_check: Dict) -> str:
        """Generate comprehensive security report"""
        report = []
        report.append("# PHI Chief AI Security Report")
        report.append(f"Generated: {datetime.now().isoformat()}")
        report.append("")

        # Token findings
        if findings:
            report.append("## 🚨 Token Exposure Findings")
            for finding in findings:
                report.append(f"- **{finding['severity']}**: {finding['file']}:{finding['line']}")
                report.append(f"  Pattern: {finding['pattern']}")
                report.append(f"  Matches: {', '.join(finding['matches'])}")
            report.append("")
        else:
            report.append("## ✅ No Token Exposures Found")
            report.append("")

        # Activity check
        report.append("## 🔍 GitHub Activity Analysis")
        if activity_check["status"] == "OK":
            report.append(f"✅ Token valid for authorized user: {activity_check['user']}")
            if activity_check.get("suspicious_activity"):
                report.append("⚠️  Suspicious activity detected:")
                for activity in activity_check["suspicious_activity"]:
                    report.append(
                        f"  - {activity['type']} in {activity['repo']} at {activity['time']}"
                    )
        else:
            message = activity_check.get("message", "No activity message provided")
            report.append(f"❌ {activity_check.get('status', 'UNKNOWN')}: {message}")

        return "\n".join(report)


def main():
    detector = AITokenDetector()

    # Scan current repository
    print("🔍 Scanning repository for token exposures...")
    findings = detector.scan_repository(".")

    # Check token activity if token is provided
    token = os.getenv("GITHUB_TOKEN")
    activity_check = {"status": "NO_TOKEN_PROVIDED"}

    if token:
        print("🔍 Checking GitHub activity...")
        activity_check = detector.check_github_activity(token)

    # Generate report
    report = detector.generate_security_report(findings, activity_check)

    # Save report
    with open("security_report.md", "w") as f:
        f.write(report)

    print("📋 Security report saved to security_report.md")

    # Alert if critical issues found
    if findings or (
        activity_check.get("status") not in ["OK", "NO_TOKEN_PROVIDED"]
        and "error" in activity_check.get("message", "").lower()
    ):
        print("🚨 SECURITY ALERT: Issues detected!")
        return 1

    print("✅ Security check passed")
    return 0


if __name__ == "__main__":
    exit(main())
