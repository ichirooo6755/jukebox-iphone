import {
  api,
  artworkSrc,
  ensureParticipant,
  getBaseURL,
  getNickname,
  isOnboarded,
  setBaseURL,
  setNickname,
  setOnboarded,
} from './api.js';
import { connect, onEvent } from './ws.js';

const state = {
  nowPlaying: null,
  queue: [],
  elapsed: 0,
  isPlaying: false,
  skipVote: { votes: 0, required: 2, voters: [] },
  searchType: 'tracks',
  useUnifiedSearch: true,
};

const els = {
  connection: document.getElementById('connection-status'),
  npArtwork: document.getElementById('np-artwork'),
  npPlaceholder: document.getElementById('np-artwork-placeholder'),
  npTitle: document.getElementById('np-title'),
  npArtist: document.getElementById('np-artist'),
  npService: document.getElementById('np-service'),
  npProgress: document.getElementById('np-progress'),
  npElapsed: document.getElementById('np-elapsed'),
  npDuration: document.getElementById('np-duration'),
  togglePlayback: document.getElementById('toggle-playback'),
  skipTrack: document.getElementById('skip-track'),
  voteSkip: document.getElementById('vote-skip'),
  skipVotes: document.getElementById('skip-votes'),
  skipRequired: document.getElementById('skip-required'),
  searchInput: document.getElementById('search-input'),
  searchService: document.getElementById('search-service'),
  searchResults: document.getElementById('search-results'),
  searchTypeSegments: document.getElementById('search-type-segments'),
  queueList: document.getElementById('queue-list'),
  nickname: document.getElementById('nickname'),
  hostUrl: document.getElementById('host-url'),
  accountStatus: document.getElementById('account-status'),
  authStatusList: document.getElementById('auth-status-list'),
  onboarding: document.getElementById('onboarding'),
  onboardingName: document.getElementById('onboarding-name'),
  onboardingJoin: document.getElementById('onboarding-join'),
  toast: document.getElementById('toast'),
};

let toastTimer = null;

function formatTime(sec) {
  const s = Math.max(0, Math.floor(sec || 0));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

function serviceLabel(service) {
  return ({ apple_music: 'Apple Music', spotify: 'Spotify', youtube: 'YouTube' })[service] || service;
}

function kindLabel(kind) {
  return ({ track: '曲', playlist: 'プレイリスト', artist: 'アーティスト' })[kind] || '';
}

function showToast(message) {
  els.toast.textContent = message;
  els.toast.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    els.toast.hidden = true;
  }, 2200);
}

function artworkMarkup(item, size = 56) {
  const src = artworkSrc(item);
  if (!src) {
    return `<div class="artwork placeholder" style="width:${size}px;height:${size}px;font-size:1.5rem">♪</div>`;
  }
  return `<img src="${escapeHtml(src)}" alt="" loading="lazy" width="${size}" height="${size}" onerror="this.replaceWith(Object.assign(document.createElement('div'),{className:'artwork placeholder',style:'width:${size}px;height:${size}px;font-size:1.5rem',textContent:'♪'}))">`;
}

function applyState(payload) {
  const prevId = state.nowPlaying?.music_id;
  state.nowPlaying = payload.current;
  state.queue = payload.queue || [];
  state.elapsed = payload.elapsed || 0;
  state.isPlaying = payload.is_playing;
  state.skipVote = payload.skip_vote || { votes: 0, required: 2, voters: [] };
  renderNowPlaying(prevId !== state.nowPlaying?.music_id);
  renderQueue();
}

function renderNowPlaying(trackChanged = false) {
  const current = state.nowPlaying;
  const card = document.querySelector('.now-playing-card');
  if (trackChanged && card) {
    card.classList.remove('track-change');
    void card.offsetWidth;
    card.classList.add('track-change');
  }

  els.togglePlayback.textContent = state.isPlaying ? '⏸' : '▶';
  els.togglePlayback.setAttribute('aria-label', state.isPlaying ? '一時停止' : '再生');

  if (!current) {
    els.npTitle.textContent = '再生待ち';
    els.npArtist.textContent = 'キューに曲を追加するか、再生ボタンを押してください';
    els.npService.textContent = '—';
    els.npArtwork.hidden = true;
    els.npPlaceholder.hidden = false;
    els.npProgress.style.width = '0%';
    els.npElapsed.textContent = '0:00';
    els.npDuration.textContent = '0:00';
    els.voteSkip.hidden = true;
    return;
  }

  els.voteSkip.hidden = false;
  els.skipVotes.textContent = state.skipVote.votes;
  els.skipRequired.textContent = state.skipVote.required;
  const nick = getNickname();
  els.voteSkip.disabled = state.skipVote.voters?.includes(nick);

  els.npTitle.textContent = current.title;
  els.npArtist.textContent = current.artist;
  els.npService.textContent = serviceLabel(current.service);
  els.npDuration.textContent = formatTime(current.duration);

  const artwork = artworkSrc(current);
  if (artwork) {
    els.npArtwork.src = artwork;
    els.npArtwork.hidden = false;
    els.npPlaceholder.hidden = true;
  } else {
    els.npArtwork.hidden = true;
    els.npPlaceholder.hidden = false;
  }

  const progress = current.duration > 0 ? Math.min(100, (state.elapsed / current.duration) * 100) : 0;
  els.npProgress.style.width = `${progress}%`;
  els.npElapsed.textContent = formatTime(state.elapsed);
}

function renderQueue() {
  els.queueList.innerHTML = '';
  if (!state.queue.length) {
    els.queueList.innerHTML = '<li class="empty">キューは空です</li>';
    return;
  }

  state.queue.forEach((item) => {
    const li = document.createElement('li');
    li.className = 'queue-item';
    li.draggable = true;
    li.dataset.id = item.id;
    li.innerHTML = `
      <span class="drag-handle">≡</span>
      ${artworkMarkup(item)}
      <div class="meta">
        <h3>${escapeHtml(item.title)}</h3>
        <p>${escapeHtml(item.artist)} · ${serviceLabel(item.service)} · ${escapeHtml(item.added_by)}</p>
      </div>
      <button class="btn icon remove" aria-label="削除">×</button>
    `;

    li.querySelector('.remove').addEventListener('click', async () => {
      await api.removeFromQueue(item.id);
      showToast('キューから削除しました');
    });

    li.addEventListener('dragstart', () => li.classList.add('dragging'));
    li.addEventListener('dragend', () => li.classList.remove('dragging'));
    li.addEventListener('dragover', (e) => e.preventDefault());
    li.addEventListener('drop', async (e) => {
      e.preventDefault();
      const dragging = document.querySelector('.queue-item.dragging');
      if (!dragging || dragging === li) return;
      const items = [...els.queueList.querySelectorAll('.queue-item')];
      const from = items.indexOf(dragging);
      const to = items.indexOf(li);
      if (from < 0 || to < 0) return;
      const order = state.queue.map((q) => q.id);
      const [moved] = order.splice(from, 1);
      order.splice(to, 0, moved);
      await api.reorderQueue(order);
    });

    els.queueList.appendChild(li);
  });
}

function updateSearchMode() {
  const service = els.searchService.value;
  state.useUnifiedSearch = service === 'apple_music';
  els.searchTypeSegments.hidden = state.useUnifiedSearch;
  if (state.useUnifiedSearch) {
    els.searchInput.placeholder = '曲・アーティスト・プレイリストを検索';
  } else {
    els.searchInput.placeholder = state.searchType === 'playlists'
      ? 'プレイリストを検索'
      : '曲を検索';
  }
}

async function addSearchResult(item) {
  const addedBy = getNickname() || await ensureParticipant();

  if (item.kind === 'playlist') {
    const added = await api.importPlaylist(item.service, item.id, addedBy, 50);
    showToast(`プレイリストを追加しました（${added.length}曲）`);
    return;
  }

  if (item.kind === 'artist') {
    const added = await api.importArtist(item.service, item.id, addedBy, 5);
    showToast(`アーティストの曲を追加しました（${added.length}曲）`);
    return;
  }

  await api.addToQueue({
    title: item.title,
    artist: item.subtitle || item.artist,
    artwork_url: item.artwork_url,
    service: item.service,
    music_id: item.music_id,
    duration: item.duration || 0,
    added_by: addedBy,
  });
  showToast(`「${item.title}」をキューに追加しました`);
}

let searchTimer = null;
async function runSearch() {
  const q = els.searchInput.value.trim();
  if (!q) {
    els.searchResults.innerHTML = '';
    return;
  }
  try {
    let results;
    if (state.useUnifiedSearch) {
      results = await api.unifiedSearch(q, els.searchService.value);
    } else {
      results = state.searchType === 'playlists'
        ? await api.playlists(q, els.searchService.value)
        : await api.search(q, els.searchService.value);
      results = results.map((row) => ({
        ...row,
        kind: state.searchType === 'playlists' ? 'playlist' : 'track',
        subtitle: row.artist || row.owner,
        id: row.music_id || row.id,
      }));
    }

    els.searchResults.innerHTML = '';
    if (!results.length) {
      els.searchResults.innerHTML = '<li class="empty">結果がありません</li>';
      return;
    }

    results.forEach((item) => {
      const li = document.createElement('li');
      li.className = 'result-item';
      const badge = item.kind && item.kind !== 'track' ? `<span class="kind-badge">${kindLabel(item.kind)}</span>` : '';
      const actionLabel = item.kind === 'playlist' ? '↧' : item.kind === 'artist' ? '↧' : '＋';
      li.innerHTML = `
        ${artworkMarkup(item)}
        <div class="meta">
          <h3>${escapeHtml(item.title)} ${badge}</h3>
          <p>${escapeHtml(item.subtitle || item.artist || item.owner)} · ${serviceLabel(item.service)}${item.track_count ? ` · ${item.track_count}曲` : ''}</p>
        </div>
        <button class="btn icon add" aria-label="追加">${actionLabel}</button>
      `;
      li.querySelector('.add').addEventListener('click', async () => {
        try {
          await addSearchResult(item);
        } catch (err) {
          showToast(`追加に失敗: ${err.message}`);
        }
      });
      els.searchResults.appendChild(li);
    });
  } catch (err) {
    els.searchResults.innerHTML = `<li class="empty">検索エラー: ${escapeHtml(err.message)}</li>`;
  }
}

function setupTabs() {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((t) => t.classList.remove('active'));
      document.querySelectorAll('.view').forEach((v) => v.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(`view-${tab.dataset.tab}`).classList.add('active');
    });
  });
}

function setupAccount() {
  els.nickname.value = getNickname();
  els.hostUrl.value = getBaseURL();

  document.getElementById('save-nickname').addEventListener('click', async () => {
    const name = els.nickname.value.trim();
    try {
      const user = await api.registerUser(name);
      setNickname(user.nickname);
      els.nickname.value = user.nickname;
      els.accountStatus.textContent = `保存しました: ${user.nickname}`;
      await refreshAuthStatus();
    } catch (err) {
      els.accountStatus.textContent = err.message;
    }
  });

  document.getElementById('connect-host').addEventListener('click', async () => {
    const url = els.hostUrl.value.trim();
    if (!url) return;
    setBaseURL(url);
    connect();
    try {
      await api.state();
      els.accountStatus.textContent = '接続しました';
    } catch (err) {
      els.accountStatus.textContent = `接続失敗: ${err.message}`;
    }
  });

}

function setupSearch() {
  document.querySelectorAll('[data-search-type]').forEach((button) => {
    button.addEventListener('click', () => {
      document.querySelectorAll('[data-search-type]').forEach((b) => b.classList.remove('active'));
      button.classList.add('active');
      state.searchType = button.dataset.searchType;
      updateSearchMode();
      runSearch();
    });
  });

  els.searchInput.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(runSearch, 300);
  });
  els.searchService.addEventListener('change', () => {
    updateSearchMode();
    runSearch();
  });

  els.togglePlayback.addEventListener('click', async () => {
    try {
      await api.togglePlayback();
    } catch (err) {
      showToast(`再生エラー: ${err.message}`);
    }
  });

  els.skipTrack.addEventListener('click', async () => {
    try {
      await api.skipTrack();
    } catch (err) {
      showToast(`スキップエラー: ${err.message}`);
    }
  });

  els.voteSkip.addEventListener('click', async () => {
    try {
      await api.voteSkip(getNickname());
    } catch (err) {
      console.error(err);
    }
  });

  updateSearchMode();
}

function cleanQueryParams(...keys) {
  const url = new URL(window.location.href);
  keys.forEach((key) => url.searchParams.delete(key));
  const next = `${url.pathname}${url.search}${url.hash}`;
  window.history.replaceState({}, '', next);
}

function finishOnboarding({ toastMessage } = {}) {
  setOnboarded();
  setBaseURL(getBaseURL());
  hideOnboardingOverlay();
  if (toastMessage) showToast(toastMessage);
}

function hideOnboardingOverlay() {
  if (!els.onboarding) return;
  els.onboarding.hidden = true;
  els.onboarding.setAttribute('aria-hidden', 'true');
}

function showOnboardingOverlay() {
  if (!els.onboarding) return;
  els.onboarding.hidden = false;
  els.onboarding.removeAttribute('aria-hidden');
}

function setupOnboarding() {
  const params = new URLSearchParams(window.location.search);
  const hostParam = params.get('host');
  if (hostParam) {
    setBaseURL(hostParam);
  } else if (!localStorage.getItem('jukebox_host_url')) {
    setBaseURL(window.location.origin);
  }

  const authService = params.get('auth');
  const authOk = params.get('ok') === '1';
  cleanQueryParams('onboard', 'auth', 'ok', 'join', 'tab');

  if (authService) {
    setOnboarded();
    hideOnboardingOverlay();
    showToast(
      authOk
        ? `${serviceLabel(authService)} にログインしました`
        : `${serviceLabel(authService)} のログインに失敗しました`
    );
    activateTab('account');
    return;
  }

  if (isOnboarded()) {
    hideOnboardingOverlay();
    return;
  }

  showOnboardingOverlay();
  if (getNickname()) {
    els.onboardingName.value = getNickname();
  }

  const join = async () => {
    if (els.onboardingJoin?.disabled) return;
    if (els.onboardingJoin) {
      els.onboardingJoin.disabled = true;
      els.onboardingJoin.textContent = '参加中...';
    }
    const name = els.onboardingName?.value.trim() ?? '';
    try {
      const user = await api.registerUser(name);
      setNickname(user.nickname);
      finishOnboarding({ toastMessage: `ようこそ、${user.nickname} さん` });
    } catch (err) {
      showToast(err.message || '参加に失敗しました');
      if (els.onboardingJoin) {
        els.onboardingJoin.disabled = false;
        els.onboardingJoin.textContent = '参加する';
      }
    }
  };

  els.onboardingJoin?.addEventListener('click', join);
  els.onboardingName?.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') join();
  });
}
function activateTab(tabName) {
  const target = document.querySelector(`.tab[data-tab="${tabName}"]`);
  target?.click();
}

function authLoginURL(loginURL) {
  const url = new URL(loginURL, getBaseURL());
  url.searchParams.set('return', 'account');
  return url.href;
}

function renderAuthAction(status) {
  if (status.is_authenticated) {
    return '<span class="auth-pill ok">OK</span>';
  }
  if (status.service === 'apple_music') {
    return '<span class="auth-pill warn">ホスト共有</span>';
  }
  if (!status.login_url) {
    return '<span class="auth-pill warn">要設定</span>';
  }
  return `<a class="btn auth-login" href="${escapeHtml(authLoginURL(status.login_url))}" target="_self">ログイン</a>`;
}

async function refreshAuthStatus() {
  if (!els.authStatusList) return;
  try {
    await ensureParticipant();
    const statuses = await api.authStatus();
    els.authStatusList.innerHTML = '';
    statuses.forEach((status) => {
      const row = document.createElement('div');
      row.className = 'auth-status-row';
      row.innerHTML = `
        <div>
          <strong>${serviceLabel(status.service)}</strong>
          <p>${escapeHtml(status.message)}</p>
        </div>
        ${renderAuthAction(status)}
      `;
      els.authStatusList.appendChild(row);
    });
  } catch (err) {
    els.authStatusList.innerHTML = `<p class="muted">認証状態を取得できません: ${escapeHtml(err.message)}</p>`;
  }
}

function setupConnection() {
  onEvent((event) => {
    if (event.type === 'connection') {
      els.connection.textContent = event.online ? '接続中' : '再接続中...';
      els.connection.classList.toggle('online', event.online);
      els.connection.classList.toggle('offline', !event.online);
      return;
    }
    if (event.type === 'state') {
      applyState(event.payload);
    }
    if (event.type === 'queue_updated') {
      state.queue = event.payload;
      renderQueue();
    }
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function bootstrap() {
  setupTabs();
  setupAccount();
  setupSearch();
  setupConnection();
  setupOnboarding();

  const params = new URLSearchParams(window.location.search);
  const tab = params.get('tab') || (params.get('auth') ? 'account' : null);
  if (tab) {
    activateTab(tab);
    cleanQueryParams('tab');
  }

  try {
    const initial = await api.state();
    applyState(initial);
    els.connection.textContent = '接続中';
    els.connection.classList.add('online');
    els.connection.classList.remove('offline');
  } catch (_) {
    els.connection.textContent = '未接続';
  }

  if (isOnboarded()) {
    try {
      await ensureParticipant();
      await refreshAuthStatus();
    } catch (_) {
      // ignore
    }
  }

  connect();
}

bootstrap();
