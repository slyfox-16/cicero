const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

const rootDir = path.resolve(__dirname, '..');
const distDir = path.join(rootDir, 'dist');
const packageJsonPath = path.join(rootDir, 'package.json');
const personalityPath = path.join(rootDir, 'personality.txt');
const configurationPath = path.join(rootDir, 'configuration.yaml');
const manifestPath = path.join(distDir, 'manifest.json');

function sha256(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

function readUtf8(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function getGitSha() {
  if (process.env.GITHUB_SHA) {
    return process.env.GITHUB_SHA;
  }
  try {
    return execSync('git rev-parse --short HEAD', {
      cwd: rootDir,
      stdio: ['ignore', 'pipe', 'ignore']
    })
      .toString('utf8')
      .trim();
  } catch {
    return null;
  }
}

function run() {
  const pkg = JSON.parse(readUtf8(packageJsonPath));
  const personality = readUtf8(personalityPath);
  const configuration = readUtf8(configurationPath);
  const gitSha = getGitSha();

  const manifest = {
    name: pkg.name,
    version: pkg.version,
    generatedAt: new Date().toISOString(),
    files: {
      'personality.txt': {
        sha256: sha256(personality)
      },
      'configuration.yaml': {
        sha256: sha256(configuration)
      }
    }
  };
  if (gitSha) {
    manifest.gitSha = gitSha;
  }

  fs.mkdirSync(distDir, { recursive: true });
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  console.log(`Generated ${manifestPath}`);
}

run();
