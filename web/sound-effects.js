(() => {
  'use strict';
  // One context survives file changes. Unlock it synchronously in a trusted
  // gesture, before Flutter's async storage/network work loses that gesture.
  let context, activeSource, onComplete;
  let generation = 0;
  let pageActive = !document.hidden;
  const buffers = new Map();

  function getContext() {
    if (!context || context.state === 'closed') {
      // Safari can silence Web Audio via the Ring/Silent switch even while
      // HTML media (SoundCloud) remains audible. Opt into playback if supported.
      try {
        if (window.navigator?.audioSession) window.navigator.audioSession.type = 'playback';
      } catch (error) {
        console.warn('Audio session configuration unavailable', error);
      }
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) throw new Error('Web Audio is unavailable');
      context = new AudioContext();
      buffers.clear();
    }
    return context;
  }

  function unlock(event) {
    if (!pageActive || document.hidden) return;
    if (!event.isTrusted) return;
    if (event.type === 'keydown' && !['Enter', ' '].includes(event.key)) return;
    try {
      const audio = getContext();
      if (audio.state === 'running') return;
      // Call resume here, not after a fetch, timer, or Promise callback.
      audio.resume().catch((error) => console.warn('Sound unlock failed', error));
      const silent = audio.createBufferSource();
      silent.buffer = audio.createBuffer(1, 1, audio.sampleRate);
      silent.connect(audio.destination);
      silent.onended = () => silent.disconnect();
      silent.start(0);
    } catch (error) {
      console.warn('Sound unlock failed', error);
    }
  }

  for (const name of ['touchend', 'pointerdown', 'pointerup', 'click', 'keydown']) {
    document.addEventListener(name, unlock, { capture: true, passive: true });
  }

  function leavePage() {
    pageActive = false;
    stop();
    // Release Dart's secret reservation when an effect is interrupted.
    if (onComplete) onComplete();
    if (context && context.state === 'running') {
      context.suspend().catch((error) => console.warn('Sound suspension failed', error));
    }
  }
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) leavePage();
    else pageActive = true;
  });
  window.addEventListener('pagehide', leavePage);
  window.addEventListener('pageshow', () => { pageActive = !document.hidden; });

  function stop() {
    ++generation;
    if (activeSource) {
      const source = activeSource;
      activeSource = null;
      source.onended = null;
      source.stop();
      source.disconnect();
    }
  }

  async function loadBuffer(path, audio) {
    if (!buffers.has(path)) {
      const request = (async () => {
        // Flutter bundles assets/<manifest-key>; manifest keys already start
        // with assets/. Dart passes paths with that first prefix removed.
        // Flutter writes encoded filenames ("Sound%201.mp3") to the bundle;
        // encode again for HTTP so the server decodes to that literal filename.
        const encodedPath = path.split('/').map((part) =>
          encodeURIComponent(encodeURIComponent(part))).join('/');
        const url = new URL(`assets/assets/${encodedPath}`, document.baseURI);
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 15000);
        try {
          const response = await fetch(url, { signal: controller.signal });
          if (!response.ok) throw new Error(`Sound HTTP ${response.status}: ${path}`);
          return await audio.decodeAudioData(await response.arrayBuffer());
        } finally {
          clearTimeout(timeout);
        }
      })();
      buffers.set(path, request);
      request.catch(() => { if (buffers.get(path) === request) buffers.delete(path); });
    }
    return buffers.get(path);
  }

  async function play(path) {
    // Reject pending Dart requests so a queued secret releases its reservation.
    if (!pageActive || document.hidden) throw new Error('Game page is hidden');
    if (!/^sounds\/(sound_normal|sound_secret)\/[^/\\]+\.mp3$/i.test(path)) {
      throw new Error('Invalid sound path');
    }
    stop();
    const current = generation;
    try {
      const audio = getContext();
      const buffer = await loadBuffer(path, audio);
      if (current !== generation) return;
      // Once unlocked, normal/secret may start after async reward processing.
      // Retry on subsequent real gestures after backgrounding the browser.
      if (audio.state !== 'running') {
        throw new Error('Sound needs a fresh user gesture');
      }
      const source = audio.createBufferSource();
      source.buffer = buffer;
      source.loop = false;
      source.connect(audio.destination);
      source.onended = () => {
        source.disconnect();
        if (activeSource !== source) return;
        activeSource = null;
        if (onComplete) onComplete();
      };
      activeSource = source;
      source.start(0);
    } catch (error) {
      console.warn('Sound effect could not play', error);
      throw error;
    }
  }

  window.gameSoundEffects = {
    play, stop,
    setOnComplete(callback) { onComplete = callback; },
  };
})();
