const STORAGE_HOST = 'jukebox_host_url';
const STORAGE_NICKNAME = 'jukebox_nickname';

let baseURL = localStorage.getItem(STORAGE_HOST) || window.location.origin;

export function getBaseURL() {
  return baseURL.replace(/\/$/, '');
}

export function setBaseURL(url) {
  baseURL = url.replace(/\/$/, '');
  localStorage.setItem(STORAGE_HOST, baseURL);
}

export function getNickname() {
  return localStorage.getItem(STORAGE_NICKNAME) || 'Guest';
}

export function setNickname(name) {
  localStorage.setItem(STORAGE_NICKNAME, name);
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
  search: (q, service) => request(`/api/search?q=${encodeURIComponent(q)}&service=${service}`),
  registerUser: (nickname) => request('/api/users', { method: 'POST', body: JSON.stringify({ nickname }) }),
  voteSkip: (nickname) => request('/api/playback/vote-skip', { method: 'POST', body: JSON.stringify({ nickname }) }),
};
