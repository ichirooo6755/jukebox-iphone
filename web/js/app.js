import { api, getBaseURL, getNickname, setBaseURL, setNickname } from './api.js';
import { connect, onEvent } from './ws.js';

const state = {
  nowPlaying: null,
  queue: [],
  elapsed: 0,
  isPlaying: false,
  skipVote: { votes: 0, required: 2, voters: [] },
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
  voteSkip: document.getElementById('vote-skip'),
  skipVotes: document.getElementById('skip-votes'),
  skipRequired: document.getElementById('skip-required'),
  searchInput: document.getElementById('search-input'),
  searchService: document.getElementById('search-service'),
  searchResults: document.getElementById('search-results'),
  queueList: document.getElementById('queue-list'),
  nickname: document.getElementById('nickname'),
  hostUrl: document.getElementById('host-url'),
  accountStatus: document.getElementById('account-status'),
};

function formatTime(sec) {
  const s = Math.max(0, Math.floor(sec || 0));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

function serviceLabel(service) {
  return ({ apple_music: 'Apple Music', spotify: 'Spotify', youtube: 'YouTube' })[service] || service;
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

  if (!current) {
    els.npTitle.textContent = '再生待ち';
    els.npArtist.textContent = 'キューに曲を追加してください';
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

  if (current.artwork_url) {
    els.npArtwork.src = current.artwork_url;
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

  state.queue.forEach((item, index) => {
    const li = document.createElement('li');
    li.className = 'queue-item';
    li.draggable = true;
    li.dataset.id = item.id;
    li.innerHTML = `
      <span class="drag-handle">≡</span>
      ${item.artwork_url ? `<img src="${item.artwork_url}" alt="">` : '<div class="artwork placeholder" style="width:56px;height:56px;font-size:1.5rem">♪</div>'}
      <div class="meta">
        <h3>${escapeHtml(item.title)}</h3>
        <p>${escapeHtml(item.artist)} · ${serviceLabel(item.service)} · ${escapeHtml(item.added_by)}</p>
      </div>
      <button class="btn icon remove" aria-label="削除">×</button>
    `;

    li.querySelector('.remove').addEventListener('click', async () => {
      await api.removeFromQueue(item.id);
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

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

let searchTimer = null;
async function runSearch() {
  const q = els.searchInput.value.trim();
  if (!q) {
    els.searchResults.innerHTML = '';
    return;
  }
  try {
    const results = await api.search(q, els.searchService.value);
    els.searchResults.innerHTML = '';
    if (!results.length) {
      els.searchResults.innerHTML = '<li class="empty">結果がありません</li>';
      return;
    }
    results.forEach((item) => {
      const li = document.createElement('li');
      li.className = 'result-item';
      li.innerHTML = `
        ${item.artwork_url ? `<img src="${item.artwork_url}" alt="">` : '<div class="artwork placeholder" style="width:56px;height:56px;font-size:1.5rem">♪</div>'}
        <div class="meta">
          <h3>${escapeHtml(item.title)}</h3>
          <p>${escapeHtml(item.artist)} · ${serviceLabel(item.service)}</p>
        </div>
        <button class="btn icon add" aria-label="追加">＋</button>
      `;
      li.querySelector('.add').addEventListener('click', async () => {
        await api.addToQueue({
          title: item.title,
          artist: item.artist,
          artwork_url: item.artwork_url,
          service: item.service,
          music_id: item.music_id,
          duration: item.duration,
          added_by: getNickname(),
        });
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
    if (!name) return;
    setNickname(name);
    try {
      await api.registerUser(name);
      els.accountStatus.textContent = `保存しました: ${name}`;
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
  els.searchInput.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(runSearch, 300);
  });
  els.searchService.addEventListener('change', runSearch);

  els.voteSkip.addEventListener('click', async () => {
    try {
      await api.voteSkip(getNickname());
    } catch (err) {
      console.error(err);
    }
  });
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

async function bootstrap() {
  setupTabs();
  setupAccount();
  setupSearch();
  setupConnection();

  try {
    const initial = await api.state();
    applyState(initial);
    els.connection.textContent = '接続中';
    els.connection.classList.add('online');
    els.connection.classList.remove('offline');
  } catch (_) {
    els.connection.textContent = '未接続';
  }

  connect();
}

bootstrap();
