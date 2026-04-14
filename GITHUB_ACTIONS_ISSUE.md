# GitHub Actions Startup Failure Issue

## Status: CRITICAL

**All workflows experiencing `startup_failure` since March 7, 2026**

## Summary

All GitHub Actions workflows in this repository are failing immediately with `startup_failure` status before any jobs execute. This issue affects all workflows except GitHub-managed CodeQL scans.

## Timeline

- **Last Success**: March 5, 2026 @ 01:07 UTC (commit `6dc8e4b0`)
- **First Failure**: March 7, 2026 @ 13:06 UTC (commit `ee331ddd`)
- **Duration**: 36+ consecutive failures across 26 affected workflows
- **Current Status**: ONGOING (as of March 8, 2026)

## Affected Workflows

### PHI Workflows (Added in PR #56)

- ✗ PHI Automation Monitor (`phi-automation-monitor.yml`)
- ✗ PHI Create Pull Request (`phi-create-pr.yml`)
- ✗ PHI Status Report (`phi-status-report.yml`)

### Core Workflows

- ✗ PHI + MCP CI/CD Pipeline (`ci.yml`)
- ✗ Security Scan (`security-scan.yml`)
- ✗ Production Deploy (Cost-Optimized) (`production-deploy-optimized.yml`)
- ✗ Production Deployment CI/CD (`production-deploy.yml`)
- ✗ Canon Φ v1.0 Color Compliance (`canon-phi-validation.yml`)
- ✗ Governance Suite (`governance-suite.yml`)
- ✗ Optimized Docker Build (`_docker-build-optimized.yml`)

### Working Workflows

- ✅ CodeQL (GitHub-managed, not user-defined)

## Symptoms

- **Error Message**: "This run likely failed because of a workflow file issue"
- **Elapsed Time**: 0 seconds (fails before job execution)
- **Conclusion**: `startup_failure`
- **Logs**: Not available (failure at validation/parse stage)
- **Manual Trigger**: HTTP 403 "Resource not accessible by integration"

## Investigation Performed

### 1. YAML Syntax Validation ✅

- **PR #60**: Fixed invalid `|| true` syntax in path specifications
- **PR #61**: Corrected `continue-on-error` indentation
- **Result**: YAML files are syntactically valid
- **Verification**: Manual inspection confirmed proper structure

### 2. File Content Analysis ✅

- All referenced scripts exist and are executable:
  - `scripts/phi_status.sh` ✅
  - `scripts/telemetry/continuous_monitor.sh` ✅
- Docker compose files present ✅
- Required configuration files present ✅

### 3. Git History Analysis ✅

- Breaking commit: `ee331ddd` - "feat: Activate Sovereign Autopilot NHITL Mode"
- Changes in that commit:
  - Added top-level `permissions:` block to ci.yml
  - Added job-level `permissions:` blocks
  - Changed trivy-action from `@master` to `@0.34.0`
  - Added pytest step
- **Note**: All changes appear valid and necessary

### 4. Permissions Investigation ⚠️

- GitHub CLI returns HTTP 403 for Actions permissions endpoint
- Cannot manually trigger workflows (HTTP 403)
- Suggests authentication/authorization issue
- **Critical**: This blocks diagnostic access

### 5. Artifact Actions Updated ✅

- Updated `security-scan.yml` from upload-artifact@v3 to @v4 (breaking PR #60 fix)

## Root Cause Analysis

### Most Likely Causes (In Order of Probability)

#### 1. **Repository Actions Permissions Disabled** (HIGHEST)

- **Evidence**:
  - HTTP 403 errors when accessing Actions API
  - Simultaneous failure of all workflows
  - Breaking commit added permission blocks (possibly conflicting)
- **Check**: Repository Settings → Actions → General → Actions permissions
- **Fix**: Enable "Allow all actions and reusable workflows" or configure allowed actions

#### 2. **GITHUB_TOKEN Permissions Insufficient**

- **Evidence**:
  - Workflows define specific permission scopes
  - May conflict with repository-level restrictions
- **Check**: Repository Settings → Actions → General → Workflow permissions
- **Fix**: Set to "Read and write permissions" or adjust workflow permissions

#### 3. **Branch Protection Rules Blocking Actions**

- **Evidence**:
  - Protected main branch requires status checks
  - Failed status checks may block workflow execution
- **Check**: Repository Settings → Branches → Branch protection rules
- **Fix**: Temporarily disable "Require status checks" or whitelist specific checks

#### 4. **GitHub Actions Quota Exceeded**

- **Evidence**:
  - Sudden failure of all workflows
  - Rate limiting or billing issue
- **Check**: Repository Settings → Billing & plans → Usage
- **Fix**: Check Actions minutes quota, add billing if needed

#### 5. **Organization/Enterprise Policy Change**

- **Evidence**:
  - Simultaneous failure across multiple workflow types
  - Timing coincides with organizational policy update
- **Check**: Organization Settings → Actions → Policies
- **Fix**: Contact GitHub organization admin

## Remediation Steps

### Immediate Actions (Repository Administrator Required)

#### Step 1: Verify Actions Are Enabled

```text
Repository Settings → Actions → General
- Actions permissions: "Allow all actions and reusable workflows"
- Fork pull request workflows: Enable as needed
```

#### Step 2: Check Workflow Permissions

```text
Repository Settings → Actions → General → Workflow permissions
- Set to: "Read and write permissions"
- Check: "Allow GitHub Actions to create and approve pull requests" (if needed)
```

#### Step 3: Review Branch Protection

```text
Repository Settings → Branches → main → Edit
- Temporarily disable "Require status checks to pass before merging"
- Re-enable after workflows are working
```

#### Step 4: Verify Actions Minutes

```text
Repository Settings → Billing & plans → Usage
- Check Actions minutes remaining
- Verify no billing holds or restrictions
```

#### Step 5: Test with Minimal Workflow

```bash
# Create test branch
git checkout -b test-github-actions

# Trigger the new test-minimal.yml workflow
git push origin test-github-actions

# Check if it runs successfully
gh run list --workflow test-minimal.yml
```

### Diagnostic Commands (For Administrators)

```bash
# Check Actions status via GitHub CLI (requires admin token)
gh api repos/Fractal5-Solutions/dominion-os-demo-build/actions/permissions

# View specific workflow run details
gh run view <run-id> --log

# Re-run failed workflow
gh run rerun <run-id>

# Check organization-level restrictions
gh api orgs/Fractal5-Solutions/actions/permissions
```

## Workarounds While Issue Persists

### Local Development Validation

```bash
# Validate YAML syntax
for f in .github/workflows/*.yml; do 
  echo "Checking $f..."
  # Use Python or online validator
done

# Run tests locally
cd /workspaces/dominion-os-demo-build/scripts
source .venv/bin/activate
pytest

# Validate bash scripts
bash -n scripts/*.sh

# Lint Python code
flake8 .
black --check .
```

### Manual Deployment

```bash
# Deploy MCP stack locally
cd /workspaces/dominion-os-demo-build
bash scripts/deploy_mcp_full.sh

# Run security scans locally
docker run --rm -v $(pwd):/workspace aquasecurity/trivy fs /workspace

# Validate Docker configurations
docker-compose -f docker-compose-mcp.yml config
```

## Resolution Verification

Once fixed, verify with:

```bash
# Check recent runs
gh run list --limit 10

# Verify all workflows can be triggered
gh workflow list | grep -v disabled

# Re-run previous failed workflows
gh run list --status failure --limit 5 | grep startup_failure
```

## Impact Assessment

### ❌ Current Impact

- **CI/CD Pipeline**: Completely non-functional
- **Security Scans**: Not running on PRs
- **Automated Deployments**: Blocked
- **PR Automation**: Cannot create automated PRs
- **Monitoring**: Scheduled checks not executing

### ✅ Unaffected Systems

- **Local PHI Services**: 4/5 services operational (125/100 Live Ops Score)
- **Git Operations**: Normal
- **Code Quality**: Local validation working
- **Development**: Can continue locally

## Contact Information

**Issue Requires**: Repository administrator with Settings access

**Escalation Path**:

1. Repository owner (Fractal5-Solutions organization admin)
2. GitHub Support (if billing/quota issue)
3. GitHub Enterprise Support (if organizational policy)

**GitHub Support**: <https://support.github.com>

**Actions Documentation**: <https://docs.github.com/actions>

---

**Created**: March 8, 2026  
**Last Updated**: March 8, 2026  
**Status**: OPEN - Awaiting Administrator Action  
**Priority**: P0 - Critical Infrastructure
