// Headless Edge/CDP smoke test for the TigerBay web build.
// Usage: node tool/web_smoke_test.mjs <url>
// Exits non-zero if the app fails to boot, logs uncaught errors, or if
// Stripe.js did not load.

const EDGE =
  process.env.EDGE_PATH ||
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';

const url = process.argv[2] || 'http://127.0.0.1:8099/';
const port = 9333;

const { spawn } = await import('node:child_process');
const { mkdtempSync, writeFileSync } = await import('node:fs');
const { tmpdir } = await import('node:os');
const { join } = await import('node:path');

const userDataDir = mkdtempSync(join(tmpdir(), 'tb-cdp-'));

const edge = spawn(EDGE, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${userDataDir}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-gpu',
  '--window-size=1280,900',
  'about:blank',
]);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getWsUrl() {
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`);
      const json = await res.json();
      if (json.webSocketDebuggerUrl) return json.webSocketDebuggerUrl;
    } catch {
      /* not up yet */
    }
    await sleep(250);
  }
  throw new Error('Edge did not expose a debugging endpoint');
}

const wsUrl = await getWsUrl();
const { WebSocket } = await import('node:worker_threads').then(() => ({
  WebSocket: globalThis.WebSocket,
}));

const ws = new WebSocket(wsUrl);
await new Promise((res, rej) => {
  ws.addEventListener('open', res, { once: true });
  ws.addEventListener('error', rej, { once: true });
});

let nextId = 1;
const pending = new Map();
const events = [];

ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
  } else if (msg.method) {
    events.push(msg);
  }
});

function send(method, params = {}, sessionId) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params, sessionId }));
  });
}

// Attach to a fresh tab with a flat session.
const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', {
  targetId,
  flatten: true,
});

const s = (method, params) => send(method, params, sessionId);

const consoleErrors = [];
const exceptions = [];
const failedRequests = [];
const responses = [];

ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.method === 'Runtime.consoleAPICalled') {
    const text = (msg.params.args || [])
      .map((a) => a.value ?? a.description ?? '')
      .join(' ');
    if (msg.params.type === 'error' || msg.params.type === 'warning') {
      consoleErrors.push(`[${msg.params.type}] ${text}`);
    }
  } else if (msg.method === 'Runtime.exceptionThrown') {
    const d = msg.params.exceptionDetails;
    exceptions.push(d.exception?.description || d.text);
  } else if (msg.method === 'Network.loadingFailed') {
    failedRequests.push(`${msg.params.type} ${msg.params.errorText}`);
  } else if (msg.method === 'Network.responseReceived') {
    responses.push(`${msg.params.response.status} ${msg.params.response.url}`);
  }
});

await s('Runtime.enable');
await s('Page.enable');
await s('Network.enable');
await s('Log.enable');

const logs = [];
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.method === 'Log.entryAdded') {
    logs.push(`[${msg.params.entry.level}] ${msg.params.entry.text}`);
  }
});

await s('Page.navigate', { url });
// The boot splash has its own 15s dismissal timeout, so allow well past that
// before probing, otherwise we can only ever observe the splash.
await sleep(28000);

async function evaluate(expression) {
  const r = await s('Runtime.evaluate', {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  return r.result?.value;
}

const probe = await evaluate(`(() => {
  // CanvasKit renders inside shadow roots, so a flat querySelector finds
  // nothing. Walk every node, piercing shadow boundaries.
  let canvases = 0, views = 0, scenes = 0;
  const tags = new Set();
  const walk = (root) => {
    for (const el of root.querySelectorAll('*')) {
      const tag = el.tagName ? el.tagName.toLowerCase() : '';
      tags.add(tag);
      if (tag === 'canvas' || tag === 'flt-canvas') canvases++;
      if (tag.includes('flutter') || tag.includes('flt-') || tag === 'glass-pane') views++;
      if (el.shadowRoot) walk(el.shadowRoot);
    }
  };
  walk(document);
  return {
    title: document.title,
    hash: location.hash,
    views, canvases, scenes,
    tags: [...tags].sort().join(','),
    stripeType: typeof window.Stripe,
    stripeVersion: (window.Stripe && window.Stripe.VERSION) || null,
    bodyChildren: document.body.children.length,
    text: (document.body.innerText || '').slice(0, 400),
  };
})()`);

const shot = await s('Page.captureScreenshot', { format: 'png' });
const shotPath = join(tmpdir(), 'tb-web-smoke.png');
writeFileSync(shotPath, Buffer.from(shot.data, 'base64'));

console.log('--- PROBE ---');
console.log(JSON.stringify(probe, null, 2));
console.log('--- CONSOLE ERRORS/WARNINGS (' + consoleErrors.length + ') ---');
consoleErrors.slice(0, 25).forEach((l) => console.log(l));
console.log('--- UNCAUGHT EXCEPTIONS (' + exceptions.length + ') ---');
exceptions.slice(0, 15).forEach((l) => console.log(l));
console.log('--- LOG ENTRIES (' + logs.length + ') ---');
logs.slice(0, 25).forEach((l) => console.log(l));
console.log('--- FAILED REQUESTS (' + failedRequests.length + ') ---');
failedRequests.slice(0, 15).forEach((l) => console.log(l));
console.log('--- RESPONSES (' + responses.length + ') ---');
responses
  .filter((r) => !/js\.stripe\.com|m\.stripe\.network|q\.stripe|fonts\.g/.test(r))
  .slice(0, 30)
  .forEach((l) => console.log(l));
console.log('--- SCREENSHOT: ' + shotPath);

const booted = probe.views > 0 || probe.canvases > 0;
const stripeLoaded = probe.stripeType !== 'undefined';
const fatal = exceptions.filter((e) =>
  /Unsupported operation|UnsupportedError|Platform\._operatingSystem|StripeException/i.test(
    e,
  ),
);

console.log('--- VERDICT ---');
console.log('booted:', booted);
console.log('stripeJsLoaded:', stripeLoaded);
console.log('fatalExceptions:', fatal.length);
console.log('renderedText:', JSON.stringify(probe.text));

ws.close();
edge.kill();

const ok = booted && fatal.length === 0;
process.exit(ok ? 0 : 1);
