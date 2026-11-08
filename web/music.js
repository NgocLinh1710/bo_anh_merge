(() => {
  'use strict';
  // Use only music licensed for this game. The speaker controls the widget.
  const playlistUrl = 'https://soundcloud.com/s-ng-mai-nguy-n-906756930/sets/14-casper';
  const toggle = document.getElementById('music-toggle');
  const container = document.getElementById('music-player');
  const status = document.getElementById('music-status');
  const repeat = document.getElementById('music-repeat');
  const volumeControl = document.getElementById('music-volume');
  const volumeValue = document.getElementById('music-volume-value');
  const volumeKey = 'music-volume';
  let volume = 30;
  try {
    const saved = window.localStorage.getItem(volumeKey);
    const parsed = Number(saved);
    if (saved !== null && saved.trim() !== '' && Number.isFinite(parsed) && parsed >= 0 && parsed <= 100) {
      volume = Math.round(parsed);
    }
  } catch (_) { /* Storage may be unavailable; keep the default volume. */ }
  function updateVolume() {
    volumeControl.value = String(volume);
    volumeControl.setAttribute('aria-valuetext', `${volume}%`);
    volumeValue.textContent = `${volume}%`;
  }
  updateVolume();
  volumeControl.addEventListener('input', () => {
    const value = Number(volumeControl.value);
    if (!Number.isFinite(value)) return;
    volume = Math.max(0, Math.min(100, Math.round(value)));
    updateVolume();
    if (widget && ready && !failed) widget.setVolume(volume);
    try { window.localStorage.setItem(volumeKey, String(volume)); }
    catch (_) { /* Volume still works when storage is blocked. */ }
  });
  let widget, apiPromise, readyTimeout;
  let generation = 0;
  let ready = false, playing = false, enabled = true, failed = false;
  let awaitingAutoplay = true;
  let pageActive = !document.hidden;

  function stopForBackground() {
    pageActive = false;
    enabled = playing = awaitingAutoplay = false;
    // pause is a cross-frame message and may arrive too late during suspension.
    // Destroy the iframe as well so it cannot retain background media playback.
    if (widget) {
      try { widget.pause(); } catch (_) { /* Still remove an unresponsive frame. */ }
    }
    ++generation;
    clearTimeout(readyTimeout);
    widget = null;
    ready = true;
    failed = false;
    container.replaceChildren();
    const session = window.navigator?.mediaSession;
    if (session) {
      try { session.playbackState = 'none'; session.metadata = null; } catch (_) {}
      for (const action of ['play', 'pause', 'stop', 'seekbackward', 'seekforward', 'seekto', 'previoustrack', 'nexttrack']) {
        try { session.setActionHandler(action, null); } catch (_) {}
      }
      try { session.setPositionState(); } catch (_) {}
    }
    updateSpeaker();
    status.textContent = 'Nhạc đã dừng khi rời game · Bấm loa để bật lại.';
  }

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stopForBackground();
    else pageActive = true; // Returning does not restart music without consent.
  });
  window.addEventListener('pagehide', stopForBackground);
  window.addEventListener('pageshow', () => { pageActive = !document.hidden; });

  // Browsers may block sound on initial load. Retry within a real interaction
  // in the game, without intercepting that interaction or undoing user mute.
  function tryAutoplayFromGesture(event) {
    if (!pageActive || document.hidden || !event.isTrusted || !awaitingAutoplay || !enabled || !ready || failed || playing) return;
    if (event.composedPath().includes(toggle) || event.composedPath().includes(volumeControl)) return;
    if (event.type === 'keydown' && event.key !== 'Enter' && event.key !== ' ') return;
    widget.play();
  }
  document.addEventListener('pointerdown', tryAutoplayFromGesture, { capture: true, passive: true });
  document.addEventListener('keydown', tryAutoplayFromGesture, { capture: true });

  function updateSpeaker() {
    const label = playing || (enabled && !ready && !failed) ? 'Tắt nhạc' : 'Bật nhạc';
    toggle.textContent = playing ? '🔊' : '🔇';
    toggle.setAttribute('aria-label', label);
    toggle.setAttribute('title', label);
    toggle.setAttribute('aria-pressed', String(playing));
  }

  function loadApi() {
    if (window.SC && window.SC.Widget) return Promise.resolve(window.SC);
    if (apiPromise) return apiPromise;
    apiPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://w.soundcloud.com/player/api.js';
      const fail = () => {
        script.remove(); apiPromise = null;
        reject(new Error('Could not load SoundCloud'));
      };
      script.onload = () => {
        if (window.SC && window.SC.Widget) resolve(window.SC);
        else fail();
      };
      script.onerror = fail;
      document.head.appendChild(script);
    });
    return apiPromise;
  }

  async function initialize() {
    if (!pageActive || document.hidden) { stopForBackground(); return; }
    const current = ++generation;
    clearTimeout(readyTimeout);
    widget = null;
    ready = playing = failed = false;
    updateSpeaker();
    status.textContent = 'Đang tải nhạc…';
    const iframe = document.createElement('iframe');
    const params = new URLSearchParams({
      url: playlistUrl, auto_play: 'true', show_user: 'true',
      show_artwork: 'true', show_playcount: 'true', color: '#83ad59',
    });
    iframe.title = 'Playlist 14 Casper trên SoundCloud';
    iframe.allow = 'autoplay';
    iframe.src = `https://w.soundcloud.com/player/?${params}`;
    container.replaceChildren(iframe);
    const showError = () => {
      if (current !== generation) return;
      clearTimeout(readyTimeout);
      failed = true;
      playing = false;
      updateSpeaker();
      status.textContent = 'Chưa tải được nhạc. Bấm loa để thử lại hoặc mở trên SoundCloud.';
    };
    readyTimeout = setTimeout(showError, 20000);
    try {
      const SC = await loadApi();
      if (current !== generation) return;
      widget = SC.Widget(iframe);
      widget.bind(SC.Widget.Events.READY, () => {
        if (current !== generation) return;
        clearTimeout(readyTimeout);
        ready = true;
        failed = false;
        widget.setVolume(volume);
        status.textContent = enabled
          ? 'Nếu chưa nghe thấy nhạc, bấm nút loa để bật.'
          : 'Nhạc đang tắt.';
        updateSpeaker();
        if (enabled) widget.play();
        else widget.pause();
      });
      widget.bind(SC.Widget.Events.PLAY, () => {
        if (current !== generation) return;
        if (!enabled) { widget.pause(); return; }
        playing = true;
        awaitingAutoplay = false;
        failed = false;
        updateSpeaker();
        status.textContent = 'Đang phát nhạc · Bấm loa để tắt.';
      });
      widget.bind(SC.Widget.Events.PAUSE, () => {
        if (current !== generation) return;
        playing = false;
        updateSpeaker();
        status.textContent = 'Nhạc đang dừng · Bấm loa để bật lại.';
      });
      widget.bind(SC.Widget.Events.ERROR, showError);
      widget.bind(SC.Widget.Events.FINISH, () => {
        if (current !== generation || !enabled || !repeat.checked) return;
        widget.getSounds((sounds) => {
          if (current !== generation || !enabled || !repeat.checked || !sounds.length) return;
          widget.getCurrentSoundIndex((index) => {
            if (current === generation && enabled && repeat.checked && index === sounds.length - 1) {
              widget.skip(0);
              widget.play();
            }
          });
        });
      });
    } catch (_) { showError(); }
  }

  toggle.addEventListener('click', () => {
    if (!pageActive || document.hidden) return;
    awaitingAutoplay = false;
    if (failed) { enabled = true; return initialize(); }
    if (playing || (enabled && !ready)) {
      enabled = false;
      playing = false;
      if (widget) widget.pause();
      else {
        // Stop even when the external API has not loaded yet.
        ++generation;
        clearTimeout(readyTimeout);
        container.replaceChildren();
        ready = true;
      }
      status.textContent = 'Nhạc đang tắt.';
    } else {
      enabled = true;
      if (!widget) return initialize();
      widget.play();
      status.textContent = 'Đang bật nhạc…';
    }
    updateSpeaker();
  });
  initialize();
})();
