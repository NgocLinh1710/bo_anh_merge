(() => {
  'use strict';
  // Use only music licensed for this game. The speaker controls the widget.
  const playlistUrl = 'https://soundcloud.com/s-ng-mai-nguy-n-906756930/sets/14-casper';
  const toggle = document.getElementById('music-toggle');
  const container = document.getElementById('music-player');
  const status = document.getElementById('music-status');
  const repeat = document.getElementById('music-repeat');
  let widget, apiPromise, readyTimeout;
  let generation = 0;
  let ready = false, playing = false, enabled = true, failed = false;
  let awaitingAutoplay = true;

  // Browsers may block sound on initial load. Retry within a real interaction
  // in the game, without intercepting that interaction or undoing user mute.
  function tryAutoplayFromGesture(event) {
    if (!event.isTrusted || !awaitingAutoplay || !enabled || !ready || failed || playing) return;
    if (event.composedPath().includes(toggle)) return;
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
