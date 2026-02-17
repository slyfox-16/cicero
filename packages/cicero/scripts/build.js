const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

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

function run() {
  const pkg = JSON.parse(readUtf8(packageJsonPath));
  const personality = readUtf8(personalityPath);
  const configuration = readUtf8(configurationPath);

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

  fs.mkdirSync(distDir, { recursive: true });
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  console.log(`Generated ${manifestPath}`);
}

run();
