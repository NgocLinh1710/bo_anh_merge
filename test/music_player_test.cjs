const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

test('volume defaults to 30%, updates live, and survives a new page session including zero', async () => {
  const storage = new Map();
  const app = setup({ storage });
  await Promise.resolve();
  app.events.ready();
  assert.deepEqual(app.volumes, [30]);
  const control = app.elements.get('music-volume');
  for (const value of ['65', '100', '0']) {
    control.value = value;
    control.listeners.input();
    assert.equal(app.volumes.at(-1), Number(value));
    assert.equal(app.elements.get('music-volume-value').textContent, `${value}%`);
    assert.equal(control.attributes['aria-valuetext'], `${value}%`);
    const reopened = setup({ storage });
    await Promise.resolve();
    reopened.events.ready();
    assert.deepEqual(reopened.volumes, [Number(value)]);
  }
});

test('volume changed before readiness is applied on readiness without starting playback on adjustment', async () => {
  const app = setup();
  const control = app.elements.get('music-volume');
  control.value = '45';
  control.listeners.input();
  assert.deepEqual(app.volumes, []);
  await Promise.resolve();
  app.events.ready();
  assert.deepEqual(app.volumes, [45]);
  app.events.play();
  await app.click();
  const stoppedCalls = app.calls.length;
  control.value = '20';
  control.listeners.input();
  app.gesture('pointerdown', { composedPath: () => [control] });
  assert.equal(app.calls.length, stoppedCalls);
  assert.equal(app.volumes.at(-1), 20);
});

test('invalid saved volume and unavailable storage keep working with the default', async () => {
  for (const value of ['', 'invalid', '-1', '101', 'Infinity']) {
    const app = setup({ storage: new Map([['music-volume', value]]) });
    await Promise.resolve();
    app.events.ready();
    assert.deepEqual(app.volumes, [30]);
  }
  const app = setup({ storageBlocked: true });
  await Promise.resolve();
  app.events.ready();
  const control = app.elements.get('music-volume');
  control.value = '75';
  assert.doesNotThrow(() => control.listeners.input());
  assert.deepEqual(app.volumes, [30, 75]);
});

function setup({ apiAvailable = true, storage = new Map(), storageBlocked = false } = {}) {
  const elements = new Map();
  const element = () => ({
    hidden: false, checked: true, children: [], listeners: {}, attributes: {},
    addEventListener(name, fn) { this.listeners[name] = fn; },
    setAttribute(name, value) { this.attributes[name] = value; },
    replaceChildren(...children) { this.children = children; },
    appendChild(child) { this.children.push(child); },
    remove() {},
  });
  for (const id of ['music-toggle', 'music-panel', 'music-player', 'music-status', 'music-repeat', 'music-volume', 'music-volume-value']) {
    elements.set(id, element());
  }
  elements.get('music-panel').hidden = true;
  const events = {};
  const calls = [];
  const volumes = [];
  let index = 0;
  const widget = {
    setVolume(value) { volumes.push(value); },
    bind(name, fn) { events[name] = fn; },
    getSounds(fn) { fn(Array(15).fill({})); },
    getCurrentSoundIndex(fn) { fn(index); },
    skip(value) { calls.push(['skip', value]); },
    play() { calls.push(['play']); },
    pause() { calls.push(['pause']); },
  };
  const Widget = () => widget;
  Widget.Events = { READY: 'ready', ERROR: 'error', FINISH: 'finish', PLAY: 'play', PAUSE: 'pause' };
  const head = element();
  const gestures = {};
  const localStorage = {
    getItem(key) {
      if (storageBlocked) throw new Error('Storage blocked');
      return storage.has(key) ? storage.get(key) : null;
    },
    setItem(key, value) {
      if (storageBlocked) throw new Error('Storage blocked');
      storage.set(key, value);
    },
  };
  const context = {
    document: { getElementById: (id) => elements.get(id), createElement: element, head,
      addEventListener(name, fn) { gestures[name] = fn; } },
    window: apiAvailable ? { SC: { Widget }, localStorage } : { localStorage },
    URLSearchParams, setTimeout: () => 1, clearTimeout() {},
  };
  vm.runInNewContext(fs.readFileSync('web/music.js', 'utf8'), context);
  return { elements, events, calls, volumes, head, setIndex(value) { index = value; },
    gesture(type, overrides = {}) {
      gestures[type]({ type, isTrusted: true, composedPath: () => [], ...overrides });
    },
    click: () => elements.get('music-toggle').listeners.click() };
}

test('attempts autoplay, reports actual playback and pauses/resumes without reloading', async () => {
  const app = setup();
  const player = app.elements.get('music-player');
  assert.equal(player.children.length, 1);
  assert.equal(new URL(player.children[0].src).searchParams.get('auto_play'), 'true');
  await Promise.resolve();
  app.events.ready();
  assert.deepEqual(app.calls, [['play']]);
  assert.equal(app.elements.get('music-toggle').attributes['aria-pressed'], 'false');
  // Autoplay can be blocked: a user click retries, without claiming success.
  await app.click();
  assert.deepEqual(app.calls.at(-1), ['play']);
  app.events.play();
  assert.equal(app.elements.get('music-toggle').textContent, '🔊');
  const iframe = player.children[0];
  await app.click();
  assert.deepEqual(app.calls.at(-1), ['pause']);
  assert.equal(app.elements.get('music-toggle').attributes['aria-pressed'], 'false');
  await app.click();
  assert.deepEqual(app.calls.at(-1), ['play']);
  assert.equal(player.children[0], iframe);
});

test('wraps only the last of 15 tracks, respects repeat setting and stop', async () => {
  const app = setup();
  await Promise.resolve();
  app.events.finish();
  assert.equal(app.calls.length, 0);
  app.setIndex(14);
  app.events.finish();
  assert.deepEqual(app.calls, [['skip', 0], ['play']]);
  app.elements.get('music-repeat').checked = false;
  app.events.finish();
  assert.equal(app.calls.length, 2);
  app.elements.get('music-repeat').checked = true;
  app.events.play();
  await app.click();
  const stoppedCalls = app.calls.length;
  app.events.finish();
  assert.equal(app.calls.length, stoppedCalls);
});

test('shows recoverable error and allows stop when external API fails', async () => {
  const app = setup({ apiAvailable: false });
  app.head.children[0].onerror();
  await Promise.resolve();
  await Promise.resolve();
  assert.match(app.elements.get('music-status').textContent, /Chưa tải được/);
  // Retry creates a new script and player instead of leaving a dead control.
  const retry = app.click();
  assert.equal(app.head.children.length, 2);
  await app.click();
  assert.equal(app.elements.get('music-player').children.length, 0);
  app.head.children[1].onerror();
  await retry;
});

test('turning off while API loads cancels autoplay and ignores late callbacks', async () => {
  const app = setup({ apiAvailable: false });
  await app.click();
  assert.equal(app.elements.get('music-player').children.length, 0);
  app.head.children[0].onerror();
  await Promise.resolve();
  await Promise.resolve();
  assert.match(app.elements.get('music-status').textContent, /đang tắt/);
});

test('blocked autoplay retries on game interaction but not synthetic events or speaker presses', async () => {
  const app = setup();
  await Promise.resolve();
  app.events.ready();
  app.gesture('pointerdown', { isTrusted: false });
  app.gesture('keydown', { key: 'a' });
  app.gesture('pointerdown', { composedPath: () => [app.elements.get('music-toggle')] });
  assert.equal(app.calls.length, 1);
  app.gesture('pointerdown');
  assert.equal(app.calls.length, 2);
  app.gesture('keydown', { key: 'Enter' });
  assert.equal(app.calls.length, 3);
  app.events.play();
  app.gesture('pointerdown');
  assert.equal(app.calls.length, 3);
});

test('interactions never turn music back on after the user turns it off', async () => {
  const app = setup();
  await Promise.resolve();
  app.events.ready();
  app.events.play();
  await app.click();
  const stoppedCalls = app.calls.length;
  app.gesture('pointerdown');
  app.gesture('keydown', { key: ' ' });
  assert.equal(app.calls.length, stoppedCalls);
  assert.equal(app.elements.get('music-toggle').attributes['aria-pressed'], 'false');
});
