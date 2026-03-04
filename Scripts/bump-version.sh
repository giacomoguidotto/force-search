#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# Get latest semver tag, default to v0.0.0
LATEST_TAG=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n1)
if [[ -z "$LATEST_TAG" ]]; then
  LATEST_TAG="v0.0.0"
  RANGE="HEAD"
else
  RANGE="${LATEST_TAG}..HEAD"
fi

echo "Latest tag: $LATEST_TAG"

# Parse current version
IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST_TAG#v}"

# Scan commits since last tag
BUMP=""
while IFS= read -r msg; do
  if [[ "$msg" =~ ^feat!: ]] || [[ "$msg" =~ ^[a-z]+\(.*\)!: ]] || [[ "$msg" =~ BREAKING\ CHANGE ]]; then
    BUMP="major"
    break
  elif [[ "$msg" =~ ^feat: ]] || [[ "$msg" =~ ^feat\(.*\): ]]; then
    if [[ "$BUMP" != "minor" ]]; then
      BUMP="minor"
    fi
  elif [[ "$msg" =~ ^fix: ]] || [[ "$msg" =~ ^fix\(.*\): ]]; then
    if [[ -z "$BUMP" ]]; then
      BUMP="patch"
    fi
  fi
done < <(git log "$RANGE" --pretty=format:"%s")

if [[ -z "$BUMP" ]]; then
  echo "No bump-worthy commits since $LATEST_TAG. Nothing to do."
  exit 0
fi

# Compute new version
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "Bump: $BUMP → v${NEW_VERSION}"

if $DRY_RUN; then
  echo "(dry run — no tag created)"
  exit 0
fi

git tag -a "v${NEW_VERSION}" -m "v${NEW_VERSION}"
echo "Tagged v${NEW_VERSION}"
