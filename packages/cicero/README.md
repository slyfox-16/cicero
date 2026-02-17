# @slyfox-16/cicero

Pure bundle package for Cicero artifacts. This package contains:

- `personality.txt`
- `configuration.yaml`
- `dist/manifest.json` (generated)

No runtime code is shipped in this package.

## Install from GitHub Packages

1. Configure npm for the scope and registry.
2. Authenticate with a token via environment variable or `npm login`.

Example `.npmrc` (safe template):

```ini
@slyfox-16:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}
```

Install:

```bash
npm install @slyfox-16/cicero@0.1.0
# or by dist-tag
npm install @slyfox-16/cicero@latest
```

If you prefer login flow:

```bash
npm login --scope=@slyfox-16 --registry=https://npm.pkg.github.com
```

## Build

From repo root:

```bash
npm run build --prefix packages/cicero
```

This generates `packages/cicero/dist/manifest.json` with package version and SHA-256 hashes for:

- `personality.txt`
- `configuration.yaml`

## Publish via GitHub Actions (recommended)

Publishing is automated by `.github/workflows/publish-cicero-bundle.yml`.

- Trigger: push a tag matching `cicero-bundle-v*`
- Auth: uses `GITHUB_TOKEN`
- Required workflow permissions:
  - `contents: read`
  - `packages: write`

## Manual Publish from Laptop (PAT classic)

Use a GitHub Personal Access Token (classic) with:

- `read:packages`
- `write:packages`

Do not commit tokens. Use env vars at publish time:

```bash
export NODE_AUTH_TOKEN=YOUR_PAT_CLASSIC
npm run build --prefix packages/cicero
npm publish --prefix packages/cicero --registry=https://npm.pkg.github.com
```

You can also keep a local untracked `.npmrc` in your home directory with the same placeholder format.
