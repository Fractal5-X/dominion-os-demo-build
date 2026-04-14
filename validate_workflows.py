#!/usr/bin/env python3
import sys

import yaml

workflows = [".github/workflows/continuous-polish.yml", ".github/workflows/heartbeat-commit.yml"]

all_valid = True
for workflow in workflows:
    try:
        with open(workflow, "r") as f:
            yaml.safe_load(f)
        print(f"✅ {workflow}: Valid YAML")
    except Exception as e:
        print(f"❌ {workflow}: {e}")
        all_valid = False

if all_valid:
    print("\n✅ All workflow files have valid YAML syntax")
    sys.exit(0)
else:
    print("\n❌ Some workflow files have YAML syntax errors")
    sys.exit(1)
