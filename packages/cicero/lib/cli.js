const fs = require('fs');
const os = require('os');
const path = require('path');
const readline = require('readline/promises');

const DEFAULT_OLLAMA_BASE_URL = 'http://saturn:11434';
const DEFAULT_TEMPERATURE = 0.15;
const DEFAULT_TOP_P = 0.9;
const DEFAULT_NUM_PREDICT = 512;
const REQUEST_TIMEOUT_MS = 30000;

function readBundleConfig() {
  const configPath = path.resolve(__dirname, '..', 'configuration.yaml');
  const personalityPath = path.resolve(__dirname, '..', 'personality.txt');
  const configRaw = fs.readFileSync(configPath, 'utf8');
  const personality = fs.readFileSync(personalityPath, 'utf8');
  const modelId = extractLocalModelId(configRaw);
  if (!modelId) {
    throw new Error('Missing backends.local.model_id in configuration.yaml');
  }
  return { modelId, personality };
}

function extractLocalModelId(yamlText) {
  const lines = yamlText.split(/\r?\n/);
  let inBackends = false;
  let inLocal = false;

  for (const line of lines) {
    if (!inBackends && /^backends:\s*$/.test(line)) {
      inBackends = true;
      continue;
    }

    if (inBackends && /^  [a-zA-Z0-9_-]+:\s*$/.test(line) && !/^  local:\s*$/.test(line)) {
      inLocal = false;
    }

    if (inBackends && /^  local:\s*$/.test(line)) {
      inLocal = true;
      continue;
    }

    if (inBackends && !/^ /.test(line) && line.trim() !== '') {
      inBackends = false;
      inLocal = false;
    }

    if (inBackends && inLocal) {
      const match = line.match(/^\s{4}model_id:\s*["']?([^"']+)["']?\s*$/);
      if (match) {
        return match[1];
      }
    }
  }

  return null;
}

function normalizeBaseUrl(url) {
  return url.replace(/\/+$/, '');
}

async function requestJson(url, options) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    const text = await response.text();
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${text}`);
    }
    return text ? JSON.parse(text) : {};
  } finally {
    clearTimeout(timeout);
  }
}

async function verifyOllama(baseUrl, modelId) {
  try {
    await requestJson(`${baseUrl}/api/tags`, { method: 'GET' });
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    console.error(`Unable to reach Ollama at ${baseUrl}.`);
    console.error(`Reason: ${reason}`);
    console.error('');
    console.error('Actionable steps:');
    console.error('1. Install Ollama: https://ollama.com/download');
    console.error('2. Start Ollama: run `ollama serve` (or start the system service).');
    console.error(`3. Pull the model: \`ollama pull ${modelId}\`.`);
    console.error('4. If needed, set OLLAMA_BASE_URL to your Ollama host.');
    process.exit(1);
  }
}

function logMetadata(entry) {
  const logDir = path.join(os.homedir(), '.cicero', 'logs');
  fs.mkdirSync(logDir, { recursive: true });
  const day = new Date().toISOString().slice(0, 10);
  const logPath = path.join(logDir, `${day}.log`);
  fs.appendFileSync(logPath, `${JSON.stringify(entry)}\n`, 'utf8');
}

function buildMessages(personality, history, userInput) {
  const limitedHistory = history.slice(-8);
  return [
    { role: 'system', content: personality },
    ...limitedHistory,
    { role: 'user', content: userInput }
  ];
}

async function chatWithOllama(baseUrl, modelId, messages) {
  return requestJson(`${baseUrl}/api/chat`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      model: modelId,
      messages,
      stream: false,
      options: {
        temperature: DEFAULT_TEMPERATURE,
        top_p: DEFAULT_TOP_P,
        num_predict: DEFAULT_NUM_PREDICT
      }
    })
  });
}

async function startRepl() {
  const { modelId, personality } = readBundleConfig();
  const baseUrl = normalizeBaseUrl(process.env.OLLAMA_BASE_URL || DEFAULT_OLLAMA_BASE_URL);
  await verifyOllama(baseUrl, modelId);

  console.log(`Cicero ready. backend=ollama model=${modelId}`);
  console.log(`Using OLLAMA_BASE_URL=${baseUrl}`);
  console.log('Type `exit` to quit.');

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  const history = [];

  try {
    for (;;) {
      const line = await rl.question('cicero> ');
      const input = line.trim();
      if (!input) {
        continue;
      }
      if (input === 'exit') {
        break;
      }

      const started = Date.now();
      try {
        const messages = buildMessages(personality, history, input);
        const result = await chatWithOllama(baseUrl, modelId, messages);
        const output = result?.message?.content?.trim() || '';
        console.log(output);

        history.push({ role: 'user', content: input });
        history.push({ role: 'assistant', content: output });

        const logEntry = {
          timestamp: new Date().toISOString(),
          backend: 'ollama',
          model_id: modelId,
          latency_ms: Date.now() - started
        };
        if (typeof result?.prompt_eval_count === 'number') {
          logEntry.prompt_tokens = result.prompt_eval_count;
        }
        if (typeof result?.eval_count === 'number') {
          logEntry.completion_tokens = result.eval_count;
        }
        logMetadata(logEntry);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`Request failed: ${message}`);
      }
    }
  } finally {
    rl.close();
  }
}

async function run(args) {
  const [command] = args;
  if (command === 'start') {
    await startRepl();
    return;
  }

  console.log('Usage: cicero start');
  process.exit(command ? 1 : 0);
}

module.exports = { run };
