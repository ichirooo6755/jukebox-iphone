import {
  api,
  artworkSrc,
  configureRemoteJoin,
  discoverHosts,
  ensureParticipant,
  getBaseURL,
  getJoinCode,
  getNickname,
  getPreferredService,
  getRelayOrigin,
  getServiceProfile,
  isOnboarded,
  isRemoteMode,
  isServiceConnected,
  saveServiceProfiles,
  setBaseURL,
  setNickname,
  setOnboarded,
  setPreferredService,
  setServiceConnected,
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
  playbackMode: 'single_track',
  playlistLanes: [],
  lastRouletteParticipant: null,
  sessionStartedAt: null,
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
  playlistGraph: document.getElementById('playlist-graph'),
  playlistUrlInput: document.getElementById('playlist-url-input'),
  playlistUrlImport: document.getElementById('playlist-url-import'),
  myPlaylistsBtn: document.getElementById('my-playlists'),
  queueList: document.getElementById('queue-list'),
  nickname: document.getElementById('nickname'),
  hostUrl: document.getElementById('host-url'),
  discoverHostsBtn: document.getElementById('discover-hosts'),
  discoveredHosts: document.getElementById('discovered-hosts'),
  syncMetrics: document.getElementById('sync-metrics'),
  accountStatus: document.getElementById('account-status'),
  accountMode: document.getElementById('account-mode'),
  remoteJoinCode: document.getElementById('remote-join-code'),
  authStatusList: document.getElementById('auth-status-list'),
  onboarding: document.getElementById('onboarding'),
  onboardingName: document.getElementById('onboarding-name'),
  onboardingJoin: document.getElementById('onboarding-join'),
  toast: document.getElementById('toast'),
  keyboardBar: document.getElementById('keyboard-bar'),
  keyboardDone: document.getElementById('keyboard-done'),
  webVersion: document.getElementById('web-version'),
  serviceConnect: document.getElementById('service-connect'),
  serviceConnectButtons: document.getElementById('service-connect-buttons'),
  serviceConnectApple: document.getElementById('service-connect-apple'),
};

let toastTimer = null;
let statePollTimer = null;
let elapsedTimer = null;
let lastServerElapsed = 0;
let lastElapsedSync = 0;

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

function setPlaybackIcon(playing) {
  const playIcon = els.togglePlayback.querySelector('.icon-play');
  const pauseIcon = els.togglePlayback.querySelector('.icon-pause');
  if (playIcon) playIcon.hidden = playing;
  if (pauseIcon) pauseIcon.hidden = !playing;
  els.togglePlayback.setAttribute('aria-label', playing ? '一時停止' : '再生');
}

function syncElapsedFromServer(elapsed) {
  state.elapsed = elapsed || 0;
  lastServerElapsed = state.elapsed;
  lastElapsedSync = Date.now();
}

async function refreshStateFromServer() {
  const payload = await api.state();
  applyState(payload);
  return payload;
}

function startStatePolling() {
  if (statePollTimer) return;
  statePollTimer = setInterval(async () => {
    try {
      await refreshStateFromServer();
    } catch (_) {
      // ignore transient errors
    }
  }, 1000);
}

function startElapsedTicker() {
  if (elapsedTimer) return;
  elapsedTimer = setInterval(() => {
    if (!state.isPlaying || !state.nowPlaying) return;
    const drift = (Date.now() - lastElapsedSync) / 1000;
    state.elapsed = lastServerElapsed + drift;
    renderNowPlaying(false);
  }, 250);
}

function setupViewportInsets() {
  const update = () => {
    const vv = window.visualViewport;
    if (!vv) {
      document.documentElement.style.setProperty('--keyboard-inset', '0px');
      return;
    }
    const inset = Math.max(0, window.innerHeight - vv.height - vv.offsetTop);
    document.documentElement.style.setProperty('--keyboard-inset', `${inset}px`);
    if (els.keyboardBar) {
      const focused = document.activeElement;
      const editing = focused instanceof HTMLInputElement || focused instanceof HTMLTextAreaElement || focused instanceof HTMLSelectElement;
      els.keyboardBar.hidden = !(inset > 0 && editing);
    }
  };
  window.visualViewport?.addEventListener('resize', update);
  window.visualViewport?.addEventListener('scroll', update);
  update();
}

function setupKeyboardBar() {
  const focusable = 'input, select, textarea';
  document.addEventListener('focusin', (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    if (!target.matches(focusable)) return;
    if (els.keyboardBar) els.keyboardBar.hidden = false;
    setTimeout(() => {
      target.scrollIntoView({ block: 'center', behavior: 'smooth' });
    }, 120);
  });
  document.addEventListener('focusout', () => {
    setTimeout(() => {
      const active = document.activeElement;
      const editing = active instanceof HTMLInputElement || active instanceof HTMLTextAreaElement || active instanceof HTMLSelectElement;
      if (!editing && els.keyboardBar) els.keyboardBar.hidden = true;
    }, 80);
  });
  els.keyboardDone?.addEventListener('click', () => {
    document.activeElement?.blur();
    if (els.keyboardBar) els.keyboardBar.hidden = true;
  });
}

function detectBrowserMode() {
  const standalone = window.matchMedia('(display-mode: standalone)').matches
    || window.navigator.standalone === true;
  document.body.classList.toggle('browser-mode', !standalone);
}

async function loadWebVersion() {
  if (!els.webVersion) return;
  try {
    const res = await fetch('/version.txt', { cache: 'no-store' });
    if (res.ok) {
      const text = (await res.text()).trim();
      els.webVersion.textContent = `Web UI: ${text}`;
    }
  } catch {
    els.webVersion.textContent = 'Web UI: unknown';
  }
}

function setupKeyboardDismiss() {
  document.getElementById('views')?.addEventListener('pointerdown', (event) => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    if (target.closest('input, select, textarea, button, a, label')) return;
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
  });
}

function setupArtworkFallback() {
  els.npArtwork.addEventListener('error', () => {
    els.npArtwork.hidden = true;
    els.npPlaceholder.hidden = false;
  });
}

function applyState(payload) {
  const prevId = state.nowPlaying?.music_id;
  state.nowPlaying = payload.current;
  state.queue = payload.queue || [];
  syncElapsedFromServer(payload.elapsed || 0);
  state.isPlaying = payload.is_playing;
  state.skipVote = payload.skip_vote || { votes: 0, required: 2, voters: [] };
  state.playbackMode = payload.playback_mode || 'single_track';
  state.playlistLanes = payload.playlist_lanes || [];
  state.lastRouletteParticipant = payload.last_roulette_participant || null;
  state.sessionStartedAt = payload.session_started_at || null;
  syncPlaybackModeUI();
  renderPlaylistGraph();
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

  setPlaybackIcon(state.isPlaying);

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
    els.npArtwork.removeAttribute('src');
    els.npArtwork.hidden = true;
    els.npPlaceholder.hidden = false;
  }

  const progress = current.duration > 0 ? Math.min(100, (state.elapsed / current.duration) * 100) : 0;
  els.npProgress.style.width = `${progress}%`;
  els.npElapsed.textContent = formatTime(state.elapsed);
}

function renderQueue() {
  els.queueList.innerHTML = '';
  const rows = [];
  if (state.nowPlaying) {
    rows.push({ item: state.nowPlaying, playing: true, queueId: null });
  }
  state.queue.forEach((item) => {
    if (state.nowPlaying && item.music_id === state.nowPlaying.music_id && item.title === state.nowPlaying.title) {
      return;
    }
    rows.push({ item, playing: false, queueId: item.id });
  });

  if (!rows.length) {
    els.queueList.innerHTML = '<li class="empty">キューは空です</li>';
    return;
  }

  rows.forEach(({ item, playing, queueId }) => {
    const li = document.createElement('li');
    li.className = `queue-item${playing ? ' playing-now' : ''}`;
    if (queueId != null) {
      li.draggable = true;
      li.dataset.id = queueId;
    }
    li.innerHTML = `
      <span class="drag-handle">${playing ? '♪' : '≡'}</span>
      ${artworkMarkup(item)}
      <div class="meta">
        <h3>${escapeHtml(item.title)}${playing ? ' <span class="kind-badge">再生中</span>' : ''}</h3>
        <p>${escapeHtml(item.artist)} · ${serviceLabel(item.service)} · ${escapeHtml(item.added_by)}</p>
      </div>
      ${playing ? '' : '<button class="btn icon remove" aria-label="削除">×</button>'}
    `;

    if (!playing) {
      li.querySelector('.remove').addEventListener('click', async () => {
        await api.removeFromQueue(queueId);
        await refreshStateFromServer();
        showToast('キューから削除しました');
      });

      li.addEventListener('dragstart', () => li.classList.add('dragging'));
      li.addEventListener('dragend', () => li.classList.remove('dragging'));
      li.addEventListener('dragover', (e) => e.preventDefault());
      li.addEventListener('drop', async (e) => {
        e.preventDefault();
        const dragging = document.querySelector('.queue-item.dragging');
        if (!dragging || dragging === li) return;
        const items = [...els.queueList.querySelectorAll('.queue-item[draggable="true"]')];
        const from = items.indexOf(dragging);
        const to = items.indexOf(li);
        if (from < 0 || to < 0) return;
        const order = state.queue.map((q) => q.id);
        const [moved] = order.splice(from, 1);
        order.splice(to, 0, moved);
        await api.reorderQueue(order);
      });
    }

    els.queueList.appendChild(li);
  });
}

function updateSearchMode() {
  const service = els.searchService.value;
  state.useUnifiedSearch = service === 'apple_music';
  els.searchTypeSegments.hidden = state.useUnifiedSearch;
  if (els.myPlaylistsBtn) {
    els.myPlaylistsBtn.hidden = service === 'apple_music';
  }
  if (state.useUnifiedSearch) {
    els.searchInput.placeholder = '曲・アーティスト・プレイリストを検索';
  } else {
    els.searchInput.placeholder = state.searchType === 'playlists'
      ? 'プレイリストを検索（空欄で自分の一覧）'
      : '曲を検索';
  }
}

function marqueeHTML(text) {
  const safe = escapeHtml(text);
  return `<div class="marquee" data-text="${safe}"><span class="marquee-text">${safe}</span></div>`;
}

function syncPlaybackModeUI() {
  document.querySelectorAll('[data-playback-mode]').forEach((button) => {
    button.classList.toggle('active', button.dataset.playbackMode === state.playbackMode);
  });
  if (els.playlistGraph) {
    els.playlistGraph.hidden = state.playbackMode !== 'playlist_roulette';
  }
}

function renderPlaylistGraph() {
  if (!els.playlistGraph) return;
  if (state.playbackMode !== 'playlist_roulette') {
    els.playlistGraph.innerHTML = '';
    return;
  }

  const lanes = state.playlistLanes || [];
  if (!lanes.length) {
    els.playlistGraph.innerHTML = '<p class="muted graph-empty">Search からプレイリストを追加すると、ここに参加者ごとのレーンが表示されます。</p>';
    return;
  }

  const winner = state.lastRouletteParticipant;
  const sessionStart = state.sessionStartedAt
    ? new Date(state.sessionStartedAt).getTime()
    : Math.min(...lanes.map((lane) => new Date(lane.joined_at).getTime()));
  const sorted = [...lanes].sort((a, b) => new Date(a.joined_at) - new Date(b.joined_at));

  els.playlistGraph.innerHTML = `
    <div class="graph-header">
      <h3>プレイリストルーレット</h3>
      <p class="muted">次の曲は ${lanes.filter((lane) => lane.position < lane.tracks.length).length} 人中からランダム抽選</p>
    </div>
    <div class="graph-trunk" aria-hidden="true"></div>
    <div class="graph-lanes">
      ${sorted.map((lane) => {
        const joinedAt = new Date(lane.joined_at).getTime();
        const isBranch = joinedAt - sessionStart > 3000;
        const active = lane.position < lane.tracks.length;
        const current = lane.tracks[lane.position];
        const avatar = lane.avatar_url
          ? `<img class="lane-avatar" src="${escapeHtml(lane.avatar_url)}" alt="">`
          : `<span class="lane-avatar placeholder">${escapeHtml((lane.display_name || lane.participant || '?').slice(0, 1))}</span>`;
        return `
          <div class="graph-lane ${active ? 'active' : 'done'} ${isBranch ? 'branch' : 'trunk'} ${winner === lane.participant ? 'winner' : ''}" style="--lane-color:${lane.color}">
            ${isBranch ? '<div class="graph-merge"><span>途中参加</span></div>' : ''}
            <div class="lane-head">
              ${avatar}
              <div class="lane-meta">
                <strong>${escapeHtml(lane.display_name || lane.participant)}</strong>
                ${marqueeHTML(lane.playlist_title)}
              </div>
            </div>
            <div class="lane-rail">
              ${lane.tracks.map((track, index) => `
                <div class="lane-node ${index < lane.position ? 'played' : ''} ${index === lane.position ? 'current' : ''}">
                  <span class="lane-dot"></span>
                  ${index === lane.position && current ? marqueeHTML(track.title) : `<span class="lane-track">${escapeHtml(track.title)}</span>`}
                </div>
              `).join('')}
            </div>
            <p class="lane-progress">${lane.position}/${lane.tracks.length}</p>
          </div>
        `;
      }).join('')}
    </div>
  `;

  els.playlistGraph.querySelectorAll('.marquee').forEach((node) => {
    const text = node.querySelector('.marquee-text');
    if (text && text.scrollWidth > node.clientWidth + 4) {
      node.classList.add('scroll');
    }
  });
}

function setupPlaybackMode() {
  document.querySelectorAll('[data-playback-mode]').forEach((button) => {
    button.addEventListener('click', async () => {
      const mode = button.dataset.playbackMode;
      if (mode === state.playbackMode) return;
      try {
        const next = await api.setPlaybackMode(mode);
        state.playbackMode = next.mode;
        state.playlistLanes = next.lanes || [];
        state.lastRouletteParticipant = next.last_roulette_participant || null;
        syncPlaybackModeUI();
        renderPlaylistGraph();
        showToast(mode === 'playlist_roulette' ? 'プレイリスト選択モード' : '一曲ずつモード');
      } catch (err) {
        showToast(`モード変更に失敗: ${err.message}`);
      }
    });
  });
}

async function addSearchResult(item) {
  const addedBy = getNickname() || await ensureParticipant();
  const profile = getServiceProfile(item.service);

  if (item.kind === 'playlist') {
    if (state.playbackMode === 'playlist_roulette') {
      await api.addPlaylistLane({
        service: item.service,
        playlist_id: item.id,
        added_by: addedBy,
        limit: 50,
        display_name: profile?.displayName,
        avatar_url: profile?.avatarURL,
        playlist_title: item.title,
        playlist_artwork_url: item.artwork_url,
      });
      showToast(`「${item.title}」をルーレットに参加しました`);
      return;
    }
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
  await refreshStateFromServer();
  const queued = state.queue?.length > 0;
  if (queued && !state.isPlaying) {
    showToast(`「${item.title}」をキューに追加（再生を開始できませんでした）`);
  } else {
    showToast(`「${item.title}」をキューに追加しました`);
  }
}

let searchTimer = null;
async function runSearch() {
  const q = els.searchInput.value.trim();
  const service = els.searchService.value;
  if (!q && !(state.searchType === 'playlists' && service !== 'apple_music')) {
    els.searchResults.innerHTML = '';
    return;
  }
  try {
    let results;
    if (state.useUnifiedSearch) {
      results = await api.unifiedSearch(q, service);
    } else if (state.searchType === 'playlists' && !q) {
      results = await api.myPlaylists(service);
      results = results.map((row) => ({
        ...row,
        kind: 'playlist',
        subtitle: row.owner,
        id: row.id,
      }));
    } else {
      results = state.searchType === 'playlists'
        ? await api.playlists(q, service)
        : await api.search(q, service);
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
      document.activeElement?.blur();
      document.querySelectorAll('.tab').forEach((t) => t.classList.remove('active'));
      document.querySelectorAll('.view').forEach((v) => v.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(`view-${tab.dataset.tab}`).classList.add('active');
      if (tab.dataset.tab === 'account') {
        refreshSyncMetrics();
        loadWebVersion();
      }
    });
  });
}

function setupAccount() {
  els.nickname.value = getNickname();
  els.hostUrl.value = isRemoteMode() ? getRelayOrigin() : getBaseURL();
  if (els.remoteJoinCode) {
    els.remoteJoinCode.value = getJoinCode();
  }
  if (els.accountMode) {
    els.accountMode.textContent = isRemoteMode()
      ? `リモート参加（コード ${getJoinCode()}）`
      : 'ローカル参加';
  }

  document.getElementById('connect-remote')?.addEventListener('click', async () => {
    const origin = els.hostUrl.value.trim();
    const code = els.remoteJoinCode?.value.trim();
    if (!origin || !code) {
      els.accountStatus.textContent = 'リレー URL と参加コードを入力してください';
      return;
    }
    configureRemoteJoin(origin, code);
    connect();
    try {
      await refreshStateFromServer();
      els.accountMode.textContent = `リモート参加（コード ${getJoinCode()}）`;
      els.accountStatus.textContent = 'リモート接続しました';
      await refreshSyncMetrics();
    } catch (err) {
      els.accountStatus.textContent = `リモート接続失敗: ${err.message}`;
    }
  });

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
      await refreshStateFromServer();
      els.accountStatus.textContent = '接続しました';
      await refreshSyncMetrics();
    } catch (err) {
      els.accountStatus.textContent = `接続失敗: ${err.message}`;
    }
  });

  els.discoverHostsBtn?.addEventListener('click', async () => {
    els.discoverHostsBtn.disabled = true;
    els.discoverHostsBtn.textContent = '探索中…';
    try {
      const hosts = await discoverHosts();
      if (!hosts.length) {
        els.accountStatus.textContent = 'ホストが見つかりませんでした。QR または IP を入力してください。';
        els.discoveredHosts.innerHTML = '';
        return;
      }
      els.discoveredHosts.innerHTML = hosts.map((host) => `
        <li>
          <button type="button" class="btn discovered-host" data-url="${escapeHtml(host.url)}">
            ${escapeHtml(host.name)} · ${escapeHtml(host.url)}
          </button>
        </li>
      `).join('');
      els.discoveredHosts.querySelectorAll('.discovered-host').forEach((button) => {
        button.addEventListener('click', async () => {
          els.hostUrl.value = button.dataset.url;
          setBaseURL(button.dataset.url);
          connect();
          try {
            await refreshStateFromServer();
            els.accountStatus.textContent = `${button.dataset.url} に接続しました`;
            await refreshSyncMetrics();
          } catch (err) {
            els.accountStatus.textContent = `接続失敗: ${err.message}`;
          }
        });
      });
      els.accountStatus.textContent = `${hosts.length} 件のホストが見つかりました`;
    } finally {
      els.discoverHostsBtn.disabled = false;
      els.discoverHostsBtn.textContent = 'ホストを探す';
    }
  });

}

async function refreshSyncMetrics() {
  if (!els.syncMetrics) return;
  try {
    const started = performance.now();
    await api.state();
    const roundTrip = Math.round(performance.now() - started);
    const metrics = await api.metrics();
    const broadcast = metrics.last_broadcast_ms_ago != null
      ? `${Math.round(metrics.last_broadcast_ms_ago)}ms 前`
      : '—';
    els.syncMetrics.textContent =
      `同期: 往復 ${roundTrip}ms · 配信 ${broadcast} · 接続 ${metrics.connected_clients} 人`;
  } catch {
    els.syncMetrics.textContent = '';
  }
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

  els.playlistUrlImport?.addEventListener('click', async () => {
    const url = els.playlistUrlInput?.value.trim();
    if (!url) return;
    try {
      const summary = await api.resolvePlaylistURL(url);
      await addSearchResult({
        kind: 'playlist',
        service: summary.service,
        id: summary.id,
        title: summary.title,
        artwork_url: summary.artwork_url,
        owner: summary.owner,
        track_count: summary.track_count,
      });
      if (els.playlistUrlInput) els.playlistUrlInput.value = '';
    } catch (err) {
      showToast(`URL から追加できません: ${err.message}`);
    }
  });

  els.myPlaylistsBtn?.addEventListener('click', async () => {
    const service = els.searchService.value;
    if (service === 'apple_music') return;
    state.searchType = 'playlists';
    document.querySelectorAll('[data-search-type]').forEach((button) => {
      button.classList.toggle('active', button.dataset.searchType === 'playlists');
    });
    els.searchInput.value = '';
    updateSearchMode();
    await runSearch();
  });

  els.togglePlayback.addEventListener('click', async () => {
    try {
      await api.togglePlayback();
      await refreshStateFromServer();
    } catch (err) {
      showToast(`再生エラー: ${err.message}`);
    }
  });

  els.skipTrack.addEventListener('click', async () => {
    try {
      await api.skipTrack();
      await refreshStateFromServer();
    } catch (err) {
      showToast(`スキップエラー: ${err.message}`);
    }
  });

  els.voteSkip.addEventListener('click', async () => {
    try {
      await api.voteSkip(getNickname());
      await refreshStateFromServer();
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
  if (!isServiceConnected()) {
    showServiceConnectOverlay();
  }
}

function hideServiceConnectOverlay() {
  if (!els.serviceConnect) return;
  els.serviceConnect.hidden = true;
  els.serviceConnect.setAttribute('aria-hidden', 'true');
}

function showServiceConnectOverlay() {
  if (!els.serviceConnect) return;
  els.serviceConnect.hidden = false;
  els.serviceConnect.removeAttribute('aria-hidden');
  renderServiceConnectButtons();
}

async function renderServiceConnectButtons() {
  if (!els.serviceConnectButtons) return;
  els.serviceConnectButtons.innerHTML = '<p class="muted">サービス状態を読み込み中…</p>';
  try {
    await ensureParticipant();
    const statuses = await api.authStatus(undefined, { force: true });
    els.serviceConnectButtons.innerHTML = '';
    statuses
      .filter((status) => status.service === 'spotify' || status.service === 'youtube')
      .forEach((status) => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'btn primary';
        btn.textContent = status.is_authenticated
          ? `${serviceLabel(status.service)} 接続済み（続行）`
          : `${serviceLabel(status.service)} にログイン`;
        btn.addEventListener('click', () => {
          setPreferredService(status.service);
          if (status.is_authenticated) {
            setServiceConnected(true);
            hideServiceConnectOverlay();
            els.searchService.value = status.service;
            updateSearchMode();
            activateTab('search');
            showToast(`${serviceLabel(status.service)} で検索できます`);
            return;
          }
          if (!status.login_url) {
            showToast(status.message || 'ログイン URL を取得できません');
            return;
          }
          window.location.href = authLoginURL(status.login_url, 'connect');
        });
        els.serviceConnectButtons.appendChild(btn);
      });
  } catch (err) {
    els.serviceConnectButtons.innerHTML = `<p class="muted">読み込み失敗: ${escapeHtml(err.message)}</p>`;
  }
}

function setupServiceConnect() {
  els.serviceConnectApple?.addEventListener('click', () => {
    setPreferredService('apple_music');
    setServiceConnected(true);
    hideServiceConnectOverlay();
    els.searchService.value = 'apple_music';
    updateSearchMode();
    activateTab('search');
    showToast('Apple Music（ホストカタログ）で検索できます');
  });
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
  const roomCode = params.get('room');
  if (roomCode) {
    const relayOrigin = params.get('relay') || getRelayOrigin() || window.location.origin;
    configureRemoteJoin(relayOrigin, roomCode);
  } else if (hostParam) {
    setBaseURL(hostParam);
  } else if (!localStorage.getItem('jukebox_host_url')) {
    setBaseURL(window.location.origin);
  }

  const authService = params.get('auth');
  const authOk = params.get('ok') === '1';
  cleanQueryParams('onboard', 'auth', 'ok', 'join', 'tab', 'room', 'relay');

  if (authService) {
    setOnboarded();
    hideOnboardingOverlay();
    hideServiceConnectOverlay();
    if (authOk) {
      setPreferredService(authService);
      setServiceConnected(true);
    }
    showToast(
      authOk
        ? `${serviceLabel(authService)} にログインしました`
        : `${serviceLabel(authService)} のログインに失敗しました`
    );
    if (authOk) {
      els.searchService.value = authService;
      updateSearchMode();
      activateTab('search');
    } else {
      activateTab('account');
    }
    refreshAuthStatus().catch(() => {});
    return;
  }

  if (isOnboarded()) {
    hideOnboardingOverlay();
    if (!isServiceConnected()) {
      showServiceConnectOverlay();
    }
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

function authLoginURL(loginURL, returnTo = 'account') {
  const url = new URL(loginURL, getBaseURL());
  url.searchParams.set('return', returnTo);
  return url.href;
}

function renderAuthAction(status) {
  if (status.is_authenticated) {
    return '<span class="auth-pill ok">OK</span>';
  }
  if (status.service === 'apple_music') {
    return '<span class="auth-pill warn">Guestアプリで許可</span>';
  }
  if (!status.login_url) {
    return '<span class="auth-pill warn">要設定</span>';
  }
  return `<a class="btn auth-login" href="${escapeHtml(authLoginURL(status.login_url))}" target="_self">ログイン</a>`;
}

async function refreshAuthStatus() {
  if (!els.authStatusList) return;
  els.authStatusList.innerHTML = '<p class="muted">サービス状態を読み込み中…</p>';
  try {
    await ensureParticipant();
    const statuses = await api.authStatus(undefined, { force: true });
    saveServiceProfiles(statuses);
    els.authStatusList.innerHTML = '';
    statuses.forEach((status) => {
      const row = document.createElement('div');
      row.className = 'auth-status-row';
      const avatar = status.avatar_url
        ? `<img class="auth-avatar" src="${escapeHtml(status.avatar_url)}" alt="">`
        : '';
      const identity = status.display_name
        ? `<p class="auth-identity">${escapeHtml(status.display_name)}</p>`
        : '';
      row.innerHTML = `
        <div class="auth-status-main">
          ${avatar}
          <div>
            <strong>${serviceLabel(status.service)}</strong>
            ${identity}
            <p>${escapeHtml(status.message)}</p>
          </div>
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
      if (event.online) {
        refreshStateFromServer().catch(() => {});
      }
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
  detectBrowserMode();
  setupTabs();
  setupAccount();
  setupSearch();
  setupPlaybackMode();
  setupConnection();
  setupOnboarding();
  setupServiceConnect();
  setupViewportInsets();
  setupKeyboardBar();
  setupKeyboardDismiss();
  setupArtworkFallback();
  startStatePolling();
  startElapsedTicker();
  loadWebVersion();

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
  await refreshSyncMetrics();

  const preferred = getPreferredService();
  if (preferred) {
    els.searchService.value = preferred;
    updateSearchMode();
  }
}

bootstrap();
