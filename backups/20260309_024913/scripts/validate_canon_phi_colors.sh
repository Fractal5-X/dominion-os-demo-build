#!/bin/bash
# Canon Φ v1.0 Color Validation Script
# Validates sealed five monochrome compliance across codebase
# Fractal5 Solutions Inc.
#
# Usage:
#   ./scripts/validate_canon_phi_colors.sh
#   ./scripts/validate_canon_phi_colors.sh --strict  # Exit 1 on violations

set -e

STRICT_MODE=false
if [ "$1" = "--strict" ]; then
    STRICT_MODE=true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎨 Canon Φ v1.0 Color Validation"
echo "   Sealed Five Monochrome System"
echo "   Fractal5 Solutions Inc."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Sealed five monochrome colors (AUTHORIZED ONLY)
SEALED_FIVE=(
    "000000"  # Onyx metallic - Text, icons, logos
    "ffffff"  # Platinum white - Backgrounds
    "f5f5f5"  # Light silver - Elevated surfaces, panels
    "d9d9d9"  # Medium silver - Borders, dividers
    "797979"  # Gunmetal/Bronze - Secondary text, muted accents
)

# Forbidden colors (old purple gradient)
FORBIDDEN=("#667eea" "#764ba2")

echo "▸ Authorized Colors (Sealed Five):"
echo "  • #000000 (Onyx metallic - ink)"
echo "  • #ffffff (Platinum white - bg)"
echo "  • #f5f5f5 (Light silver - panel)"
echo "  • #d9d9d9 (Medium silver - border)"
echo "  • #797979 (Gunmetal/Bronze - muted)"
echo ""

# Step 1: Check for forbidden purple gradient
echo "▸ Checking for forbidden purple gradient..."
PURPLE_FOUND=false

if grep -r "${FORBIDDEN[0]}\|${FORBIDDEN[1]}" \
    --include="*.html" \
    --include="*.css" \
    --include="*.py" \
    --include="*.js" \
    --include="*.ts" \
    --exclude-dir=.venv \
    --exclude-dir=__pycache__ \
    --exclude-dir=node_modules \
    --exclude-dir=.git \
    . 2>/dev/null; then
    PURPLE_FOUND=true
    echo ""
    echo "  ❌ CRITICAL: Old purple gradient detected!"
    echo "     Found: #667eea or #764ba2"
    echo "     These colors are explicitly forbidden."
    echo ""
fi

if [ "$PURPLE_FOUND" = false ]; then
    echo "  ✅ No purple gradient violations"
fi

echo ""

# Step 2: Extract all hex colors from codebase
echo "▸ Scanning codebase for hex colors..."

COLORS=$(grep -rhoE "#[0-9a-fA-F]{6}" \
    --include="*.html" \
    --include="*.css" \
    --include="*.py" \
    --include="*.js" \
    --include="*.ts" \
    --exclude-dir=.venv \
    --exclude-dir=__pycache__ \
    --exclude-dir=node_modules \
    --exclude-dir=.git \
    . 2>/dev/null | sed 's/#//' | tr '[:upper:]' '[:lower:]' | sort -u || echo "")

if [ -z "$COLORS" ]; then
    echo "  ℹ️  No hex colors found"
    echo ""
    echo "✅ Canon Φ v1.0 Compliance: PASSED (no colors to validate)"
    exit 0
fi

TOTAL_COLORS=$(echo "$COLORS" | wc -l)
echo "  Found $TOTAL_COLORS unique hex colors"
echo ""

# Step 3: Validate each color against sealed five
echo "▸ Validating against sealed five..."

COMPLIANT_COLORS=0
NON_COMPLIANT_COLORS=()

for color in $COLORS; do
    IS_SEALED=false

    for sealed in "${SEALED_FIVE[@]}"; do
        if [ "$color" = "$sealed" ]; then
            IS_SEALED=true
            COMPLIANT_COLORS=$((COMPLIANT_COLORS + 1))
            break
        fi
    done

    if [ "$IS_SEALED" = false ]; then
        NON_COMPLIANT_COLORS+=("#$color")
    fi
done

echo "  • Compliant colors: $COMPLIANT_COLORS"
echo "  • Non-compliant colors: ${#NON_COMPLIANT_COLORS[@]}"
echo ""

# Step 4: Report results
if [ ${#NON_COMPLIANT_COLORS[@]} -gt 0 ]; then
    echo "⚠️  Non-Sealed-Five Colors Detected:"
    echo ""

    # Group colors by file for detailed reporting
    for color in "${NON_COMPLIANT_COLORS[@]}"; do
        FILES=$(grep -rl "${color}" \
            --include="*.html" \
            --include="*.css" \
            --include="*.py" \
            --include="*.js" \
            --include="*.ts" \
            --exclude-dir=.venv \
            --exclude-dir=__pycache__ \
            --exclude-dir=node_modules \
            --exclude-dir=.git \
            . 2>/dev/null | head -3)

        echo "  $color"
        for file in $FILES; do
            echo "    └─ $file"
        done
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$PURPLE_FOUND" = true ]; then
        echo "❌ VALIDATION FAILED - Purple gradient violations"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 1
    fi

    if [ "$STRICT_MODE" = true ]; then
        echo "❌ VALIDATION FAILED - Non-compliant colors detected"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "To fix: Replace non-sealed-five colors with:"
        echo "  #000000, #ffffff, #f5f5f5, #d9d9d9, or #797979"
        echo ""
        exit 1
    else
        echo "⚠️  VALIDATION WARNING - Non-compliant colors found"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Consider updating to sealed five monochrome system."
        exit 0
    fi
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Canon Φ v1.0 Compliance: PERFECT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "All colors comply with sealed five monochrome."
    echo ""
    exit 0
fi
