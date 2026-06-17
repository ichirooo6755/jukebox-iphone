const STORAGE_HOST = 'jukebox_host_url';
const STORAGE_NICKNAME = 'jukebox_nickname';
const STORAGE_ONBOARDED = 'jukebox_onboarded';

let baseURL = localStorage.getItem(STORAGE_HOST) || window.location.origin;

export function getBaseURL() {
  return baseURL.replace(/\/$/, '');
}

export function setBaseURL(url) {
  baseURL = url.replace(/\/$/, '');
  localStorage.setItem(STORAGE_HOST, baseURL);
}

export function getNickname() {
  return localStorage.getItem(STORAGE_NICKNAME) || '';
}

export function setNickname(name) {
  localStorage.setItem(STORAGE_NICKNAME, name);
}

export function isOnboarded() {
  return localStorage.getItem(STORAGE_ONBOARDED) === '1' || Boolean(getNickname());
}

export function setOnboarded() {
  localStorage.setItem(STORAGE_ONBOARDED, '1');
}

export function normalizeArtworkURL(url) {
  if (!url) return '';
  const value = url
    .replace(/\{w\}/g, '300')
    .replace(/\{h\}/g, '300')
    .replace(/%7Bw%7D/gi, '300')
    .replace(/%7Bh%7D/gi, '300')
    .replace(/^http:\/\//i, 'https://');
  return value.startsWith('https://') ? value : '';
}

export function artworkSrc(itemOrUrl, maybeItem = null) {
  const item = typeof itemOrUrl === 'object' && itemOrUrl !== null ? itemOrUrl : maybeItem;
  const url = typeof itemOrUrl === 'string' ? itemOrUrl : itemOrUrl?.artwork_url;
  const normalized = normalizeArtworkURL(url);
  if (normalized) {
    return `${getBaseURL()}/api/artwork?url=${encodeURIComponent(normalized)}`;
  }
  if (!item?.service) return '';
  const musicId = item.music_id || item.id;
  if (!musicId) return '';
  const params = new URLSearchParams({
    service: item.service,
    music_id: musicId,
  });
  if (item.title) params.set('title', item.title);
  if (item.artist) params.set('artist', item.artist);
  return `${getBaseURL()}/api/artwork?${params.toString()}`;
}

function withParticipant(path, participant) {
  const name = (participant || '').trim();
  if (!name) return path;
  const joiner = path.includes('?') ? '&' : '?';
  return `${path}${joiner}participant=${encodeURIComponent(name)}`;
}

async function request(path, options = {}) {
  const res = await fetch(`${getBaseURL()}${path}`, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || res.statusText);
  }
  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  status: () => request('/api/status'),
  state: () => request('/api/state'),
  queue: () => request('/api/queue'),
  addToQueue: (item) => request('/api/queue', { method: 'POST', body: JSON.stringify(item) }),
  removeFromQueue: (id) => request(`/api/queue/${id}`, { method: 'DELETE' }),
  reorderQueue: (order) => request('/api/queue/reorder', { method: 'PUT', body: JSON.stringify({ order }) }),
  search: (q, service, participant = getNickname()) =>
    request(withParticipant(`/api/search?q=${encodeURIComponent(q)}&service=${service}`, participant)),
  unifiedSearch: (q, service, participant = getNickname()) =>
    request(withParticipant(`/api/search/unified?q=${encodeURIComponent(q)}&service=${service}`, participant)),
  playlists: (q, service, participant = getNickname()) =>
    request(withParticipant(`/api/playlists?q=${encodeURIComponent(q)}&service=${service}`, participant)),
  importPlaylist: (service, playlistID, addedBy, limit = 50) => request('/api/playlists/import', {
    method: 'POST',
    body: JSON.stringify({ service, playlist_id: playlistID, added_by: addedBy, limit }),
  }),
  importArtist: (service, artistID, addedBy, limit = 5) => request('/api/artists/import', {
    method: 'POST',
    body: JSON.stringify({ service, artist_id: artistID, added_by: addedBy, limit }),
  }),
  authStatus: (participant = getNickname()) => request(withParticipant('/api/auth/status', participant)),
  registerUser: (nickname) => request('/api/users', { method: 'POST', body: JSON.stringify({ nickname }) }),
  voteSkip: (nickname) => request('/api/playback/vote-skip', { method: 'POST', body: JSON.stringify({ nickname }) }),
  togglePlayback: () => request('/api/playback/toggle', { method: 'POST' }),
  skipTrack: () => request('/api/playback/skip', { method: 'POST' }),
};

export async function ensureParticipant() {
  if (getNickname()) {
    setOnboarded();
    return getNickname();
  }
  const user = await api.registerUser('');
  setNickname(user.nickname);
  setOnboarded();
  return user.nickname;
}
