# Fix GitHub Actions - Admin Instructions

## Issue

All GitHub Actions workflows are failing with `startup_failure` and HTTP 403 errors. The GitHub CLI token doesn't have admin permissions to modify repository settings programmatically.

## Required: Web UI Access

**You need to access the repository settings via the GitHub web interface.**

---

## Step-by-Step Fix

### 1. Enable Actions Permissions

1. Go to: <https://github.com/Fractal5-Solutions/dominion-os-demo-build/settings/actions>
2. Under **"Actions permissions"**:
   - Select: **"Allow all actions and reusable workflows"**
   - Or select: **"Allow Fractal5-Solutions, and select non-Fractal5-Solutions, actions and reusable workflows"**
3. Click **"Save"**

### 2. Configure Workflow Permissions

1. Scroll down to **"Workflow permissions"** on the same page
2. Select: **"Read and write permissions"**
3. Check: **"Allow GitHub Actions to create and approve pull requests"**
4. Click **"Save"**

### 3. Verify Actions Minutes/Quota

1. Go to: <https://github.com/organizations/Fractal5-Solutions/settings/billing>
2. Check **"Actions & Packages"** tab
3. Verify there are available minutes or no quota issues
4. If needed, add billing or increase quota

### 4. Review Branch Protection (Optional)

1. Go to: <https://github.com/Fractal5-Solutions/dominion-os-demo-build/settings/branches>
2. Click **"Edit"** on the `main` branch protection
3. Temporarily disable **"Require status checks to pass before merging"** if needed
4. Can re-enable after Actions are working

---

## Verification After Fix

Run these commands to verify Actions are working:

```bash
# Test workflow trigger
gh workflow run test-minimal.yml

# Check if it runs
gh run list --limit 5

# View the run
gh run view --log
```

---

## Alternative: Personal Access Token

If the current GitHub CLI token lacks admin rights, authenticate with a PAT:

1. Create a PAT with `repo` and `admin:repo_hook` scopes:
   - <https://github.com/settings/tokens/new>
2. Authenticate:

   ```bash
   gh auth login --with-token < token.txt
   ```

3. Retry the fix commands

---

## Status

- ✅ All YAML syntax fixes applied
- ✅ Deprecated actions updated
- ✅ Diagnostic workflows created
- ⚠️ **BLOCKED**: Need admin access to enable Actions
- 🎯 **NEXT**: Complete steps 1-2 above via web UI

## Questions?

See: [GITHUB_ACTIONS_ISSUE.md](./GITHUB_ACTIONS_ISSUE.md) for detailed root cause analysis.
