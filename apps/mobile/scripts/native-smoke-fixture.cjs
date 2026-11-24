const http = require('node:http');
const { WebSocketServer } = require('ws');
const token = 'native_smoke=ok';
const authenticated = request => request.headers.cookie?.includes(token);
const server = http.createServer((request, response) => {
  if (request.url === '/api/auth/status') {
    response.setHeader('Content-Type', 'application/json');
    return response.end(JSON.stringify({ enabled: true, authenticated: Boolean(authenticated(request)) }));
  }
  if (request.method !== 'POST' || request.url !== '/api/auth/login') {
    response.writeHead(404);
    return response.end();
  }
  let data = '';
  request.on('data', chunk => { data += chunk; });
  request.on('end', () => {
    const { username, password } = JSON.parse(data);
    const accepted = username === 'nativefixture' && password === 'correctpassword';
    response.writeHead(accepted ? 200 : 401, accepted ? { 'Set-Cookie': token + '; Path=/; HttpOnly' } : {});
    response.end();
  });
});
const sockets = new WebSocketServer({ noServer: true });
server.on('upgrade', (request, socket, head) => {
  if (!authenticated(request)) {
    socket.end('HTTP/1.1 401 Unauthorized\r\n\r\n');
    return;
  }
  sockets.handleUpgrade(request, socket, head, ws => sockets.emit('connection', ws));
});
let interrupted = false;
function send(ws, turnId, seq, type, content) {
  if (ws.readyState !== 1) return;
  ws.send(JSON.stringify({
    protocol_version: '2.0', type, turn_id: turnId, session_id: 'native-smoke-session',
    seq, timestamp: Date.now(), ...(content === undefined ? {} : { content }),
  }));
}
sockets.on('connection', ws => {
  ws.on('message', message => {
    const command = JSON.parse(message);
    if (command.type === 'resume_from' && command.turn_id === 'native-turn-2' && command.seq === 1 && interrupted) {
      console.log('second turn resumed after sequence 1');
      send(ws, 'native-turn-2', 2, 'content', 'resumed correctly.');
      send(ws, 'native-turn-2', 3, 'done');
    }
    if (command.type !== 'start_turn') return;
    if (command.content === 'First turn') {
      send(ws, 'native-turn-1', 1, 'content', 'First reply ');
      setTimeout(() => {
        send(ws, 'native-turn-1', 2, 'content', 'streamed correctly.');
        send(ws, 'native-turn-1', 3, 'done');
      }, 650);
    }
    if (command.content === 'Second turn' && command.session_id === 'native-smoke-session' && !interrupted) {
      send(ws, 'native-turn-2', 1, 'content', 'Second reply ');
      setTimeout(() => {
        interrupted = true;
        ws.close(1012, 'verification reconnect');
      }, 650);
    }
  });
});
server.listen(18001, '127.0.0.1');
