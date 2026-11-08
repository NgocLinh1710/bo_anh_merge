const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function setup({ delayedFetch = false, failFirst = false } = {}) {
  const listeners = new Map();
  const contexts = [], sources = [], requests = [], warnings = [];
  const windowEvents = new Map();
  let gesture = false, pendingFetch, attempts = 0;
  class AudioContext {
    constructor() {
      this.state = 'suspended';
      this.sampleRate = 44100;
      this.destination = {};
      this.resumeCount = 0;
      contexts.push(this);
    }
    resume() {
      assert.equal(gesture, true, 'Safari unlock must occur directly in the trusted gesture');
      this.resumeCount++;
      this.state = 'running';
      return Promise.resolve();
    }
    suspend() { this.state = 'suspended'; return Promise.resolve(); }
    createBuffer() { return { silent: true }; }
    createBufferSource() {
      const source = {
        connect() {}, disconnect() {},
        start() { this.started = true; },
        stop() { this.stopped = true; },
      };
      sources.push(source);
      return source;
    }
    async decodeAudioData() { return { decoded: true }; }
  }
  const response = { ok: true, arrayBuffer: async () => new ArrayBuffer(1) };
  const audioSession = { type: 'auto' };
  const window = { AudioContext, navigator: { audioSession },
    addEventListener(name, fn) { windowEvents.set(name, fn); } };
  const document = {
    hidden: false,
    baseURI: 'https://example.test/game/',
    addEventListener(name, fn, options) {
      if (options) assert.equal(options.capture, true);
      listeners.set(name, fn);
    },
  };
  vm.runInNewContext(fs.readFileSync('web/sound-effects.js', 'utf8'), {
    window, document,
    URL, AbortController, setTimeout, clearTimeout,
    console: { warn: (...args) => warnings.push(args) },
    fetch: async (url) => {
      requests.push(String(url));
      if (failFirst && attempts++ === 0) return { ok: false, status: 404 };
      if (delayedFetch) await new Promise(resolve => { pendingFetch = resolve; });
      return response;
    },
  });
  return {
    audio: window.gameSoundEffects, audioSession, contexts, sources, requests, warnings,
    visibility(hidden) { document.hidden = hidden; listeners.get('visibilitychange')(); },
    pagehide() { windowEvents.get('pagehide')(); },
    finishFetch() { pendingFetch(); },
    gesture(type = 'touchend', overrides = {}) {
      gesture = true;
      try { listeners.get(type)({ type, isTrusted: true, ...overrides }); }
      finally { gesture = false; }
    },
  };
}

test('hiding game stops effects and releases secret priority; next gesture resumes context', async () => {
  const app = setup();
  app.gesture();
  let completed = 0;
  app.audio.setOnComplete(() => completed++);
  await app.audio.play('sounds/sound_secret/Sound 1.mp3');
  const source = app.sources.at(-1);
  app.visibility(true);
  assert.equal(source.stopped, true);
  assert.equal(source.onended, null);
  assert.equal(completed, 1);
  assert.equal(app.contexts[0].state, 'suspended');
  const requests = app.requests.length;
  await assert.rejects(app.audio.play('sounds/sound_normal/a.mp3'), /page is hidden/);
  assert.equal(app.requests.length, requests);
  app.visibility(false);
  app.gesture();
  await app.audio.play('sounds/sound_normal/a.mp3');
  assert.equal(app.sources.at(-1).started, true);
});

test('unlocks synchronously on touchend, then plays async rewards and secret through one context', async () => {
  const app = setup();
  app.gesture('touchend', { isTrusted: false });
  assert.equal(app.contexts.length, 0);
  app.gesture();
  assert.equal(app.contexts[0].resumeCount, 1);
  assert.equal(app.audioSession.type, 'playback');
  let completed = 0;
  app.audio.setOnComplete(() => completed++);
  // No gesture is active when reward processing eventually finishes.
  await Promise.resolve();
  await app.audio.play('sounds/sound_normal/a.mp3');
  const normal = app.sources.at(-1);
  assert.equal(normal.buffer.decoded, true);
  assert.equal(normal.loop, false);
  normal.onended();
  assert.equal(completed, 1);
  await app.audio.play('sounds/sound_secret/Sound 1.mp3');
  assert.equal(app.contexts.length, 1);
  assert.equal(app.sources.at(-1).started, true);
  assert.equal(app.requests[1], 'https://example.test/game/assets/assets/sounds/sound_secret/Sound%25201.mp3');
});

test('stop during download cancels late playback and completion callbacks', async () => {
  const app = setup({ delayedFetch: true });
  app.gesture();
  const playing = app.audio.play('sounds/sound_secret/Sound 2.mp3');
  app.audio.stop();
  app.finishFetch();
  await playing;
  assert.equal(app.sources.filter(source => source.buffer?.decoded).length, 0);
});

test('a fresh gesture resumes an interrupted Safari context', async () => {
  const app = setup();
  app.gesture();
  app.contexts[0].state = 'interrupted';
  app.gesture('click');
  await app.audio.play('sounds/sound_normal/a.mp3');
  assert.equal(app.contexts[0].resumeCount, 2);
  assert.equal(app.sources.at(-1).started, true);
});

test('failed downloads can retry and decoded buffers are reused', async () => {
  const app = setup({ failFirst: true });
  app.gesture();
  await assert.rejects(app.audio.play('sounds/sound_normal/a.mp3'), /HTTP 404/);
  await app.audio.play('sounds/sound_normal/a.mp3');
  await app.audio.play('sounds/sound_normal/a.mp3');
  assert.equal(app.requests.length, 2);
  assert.equal(app.warnings.length, 1);
});

test('synthetic input never unlocks audio and blocked playback remains recoverable', async () => {
  const app = setup();
  app.gesture('keydown', { key: 'a' });
  assert.equal(app.contexts.length, 0);
  await assert.rejects(app.audio.play('sounds/sound_normal/a.mp3'), /fresh user gesture/);
  app.gesture('keydown', { key: 'Enter' });
  await app.audio.play('sounds/sound_normal/a.mp3');
  assert.equal(app.sources.at(-1).started, true);
});
