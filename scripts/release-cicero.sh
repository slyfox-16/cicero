#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 0.1.5"
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Error: version must look like 0.1.5 or 0.1.5-rc.1"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "Error: not inside a git repository."
  exit 1
fi
cd "$REPO_ROOT"

if [[ ! -f ".github/workflows/publish-cicero.yml" ]]; then
  echo "Error: expected workflow .github/workflows/publish-cicero.yml not found."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree is not clean. Commit or stash changes first."
  exit 1
fi

TAG="cicero-bundle-v${VERSION}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Error: local tag $TAG already exists."
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "HEAD" ]]; then
  echo "Error: detached HEAD. Switch to a branch first."
  exit 1
fi

echo "Bumping @slyfox-16/cicero to $VERSION..."
npm version "$VERSION" --no-git-tag-version --workspace packages/cicero

echo "Building bundle manifest..."
npm run build --prefix packages/cicero

echo "Committing release..."
git add packages/cicero/package.json packages/cicero/dist/manifest.json
git commit -m "release(cicero): v${VERSION}"

echo "Tagging and pushing..."
git tag "$TAG"
git push origin "$BRANCH"
git push origin "$TAG"

echo "Release triggered."
echo "Track publish status in GitHub Actions for tag: $TAG"
