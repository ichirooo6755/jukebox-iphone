import { getBaseURL, isRemoteMode } from './api.js';

let socket = null;
let reconnectTimer = null;
const listeners = new Set();

export function onEvent(handler) {
  listeners.add(handler);
  return () => listeners.delete(handler);
}

function emit(event) {
  listeners.forEach((fn) => fn(event));
}

export function connect() {
  disconnect();

  if (isRemoteMode()) {
    emit({ type: 'connection', online: true });
    return;
  }

  const wsURL = getBaseURL().replace(/^http/, 'ws') + '/ws';
  socket = new WebSocket(wsURL);

  socket.onopen = () => emit({ type: 'connection', online: true });
  socket.onclose = () => {
    emit({ type: 'connection', online: false });
    scheduleReconnect();
  };
  socket.onerror = () => socket.close();
  socket.onmessage = (msg) => {
    try {
      const data = JSON.parse(msg.data);
      emit(data);
    } catch (_) {}
  };
}

export function disconnect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  if (socket) {
    socket.onclose = null;
    socket.close();
    socket = null;
  }
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connect();
  }, 2000);
}
