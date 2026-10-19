import http from "http";
import { parse } from "url";
import next from "next";
import { WebSocketServer, WebSocket } from "ws";
import { loadEnv } from "./lib/loadEnv";
import { verifyToken } from "./lib/auth";
import UserWorkout from "./models/UserWorkout";

loadEnv();

const dev = process.env.NODE_ENV !== "production";
const port = Number(process.env.PORT || 3000);

const app = next({ dev });
const handle = app.getRequestHandler();

const channels = new Map<string, Set<WebSocket>>();
const connState = new WeakMap<
  WebSocket,
  { userId?: string; username?: string; status?: string }
>();
const DEFAULT_CHANNELS = ["presence", "feed_update", "live_cheer"];

interface WsMessage {
  type?: string;
  channel?: string;
  token?: string;
  status?: string;
  data?: unknown;
}

function subscribe(ws: WebSocket, channel: string): void {
  if (!channel) return;
  if (!channels.has(channel)) channels.set(channel, new Set());
  channels.get(channel)!.add(ws);
}

function unsubscribe(ws: WebSocket, channel: string): void {
  const set = channels.get(channel);
  if (!set) return;
  set.delete(ws);
  if (set.size === 0) channels.delete(channel);
}

function publish(channel: string, message: unknown, exclude?: WebSocket): void {
  const set = channels.get(channel);
  if (!set) return;
  const payload = JSON.stringify(message);
  for (const client of set) {
    if (client === exclude) continue;
    if (client.readyState === WebSocket.OPEN) client.send(payload);
  }
}

function sendError(ws: WebSocket, message: string): void {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: "error", error: message }));
  }
}

function sendActiveUsersTo(ws: WebSocket): void {
  const presenceSet = channels.get("presence");
  if (!presenceSet) return;
  const seen = new Set<string>();
  for (const client of presenceSet) {
    if (client === ws) continue;
    if (client.readyState !== WebSocket.OPEN) continue;
    const state = connState.get(client);
    if (!state?.userId || seen.has(state.userId)) continue;
    seen.add(state.userId);
    ws.send(
      JSON.stringify({
        type: "presence",
        user_id: state.userId,
        username: state.username ?? null,
        status: state.status === "training" ? "training" : "online",
        at: new Date().toISOString(),
      })
    );
  }
}

function resolveUser(
  ws: WebSocket,
  msg: WsMessage
): { userId: string; username?: string } | undefined {
  const state = connState.get(ws);
  if (state?.userId) {
    return { userId: state.userId, username: state.username };
  }
  if (!msg.token) return undefined;
  try {
    const payload = verifyToken(msg.token);
    return { userId: payload.userId, username: payload.username };
  } catch {
    return undefined;
  }
}

async function handleMessage(ws: WebSocket, raw: string): Promise<void> {
  let msg: WsMessage;
  try {
    msg = JSON.parse(raw) as WsMessage;
  } catch {
    sendError(ws, "Invalid JSON payload");
    return;
  }

  switch (msg.type) {
    case "subscribe":
      subscribe(ws, msg.channel ?? "");
      break;
    case "unsubscribe":
      unsubscribe(ws, msg.channel ?? "");
      break;
    case "presence": {
      const user = resolveUser(ws, msg);
      if (!user) {
        sendError(ws, "Unauthorized: presence requires a valid JWT");
        break;
      }
      const status = msg.status === "training" ? "training" : "online";
      connState.set(ws, {
        userId: user.userId,
        username: user.username,
        status,
      });
      sendActiveUsersTo(ws);
      publish(
        "presence",
        {
          type: "presence",
          user_id: user.userId,
          username: user.username ?? null,
          status,
          at: new Date().toISOString(),
        },
        ws
      );
      break;
    }
    case "feed_update": {
      const state = connState.get(ws);
      publish("feed_update", {
        type: "feed_update",
        data: msg.data ?? {},
        from: state?.userId ?? null,
        from_username: state?.username ?? null,
        at: new Date().toISOString(),
      });
      break;
    }
    case "live_cheer": {
      const state = connState.get(ws);
      const data = (msg.data ?? {}) as Record<string, unknown>;
      if (
        typeof data.workout_id === "string" &&
        typeof data.reaction_type === "string" &&
        ["fire", "bicep", "dumbbell"].includes(data.reaction_type)
      ) {
        try {
          const updated = await UserWorkout.findByIdAndUpdate(
            data.workout_id as string,
            { $inc: { [`reactions.${data.reaction_type}`]: 1 } },
            { new: true }
          ).exec();
          if (updated) {
            (data as Record<string, unknown>).reactions =
              (updated as unknown as { reactions: unknown }).reactions;
          }
        } catch {
          // ignore DB errors, still broadcast cheer
        }
      }
      publish("live_cheer", {
        type: "live_cheer",
        data,
        from: state?.userId ?? null,
        from_username: state?.username ?? null,
        at: new Date().toISOString(),
      });
      break;
    }
    default:
      sendError(ws, `Unknown event type: ${msg.type ?? "(empty)"}`);
  }
}

async function main(): Promise<void> {
  await app.prepare();

  const server = http.createServer((req, res) => {
    const { pathname } = parse(req.url ?? "", true);
    const isApi = pathname?.startsWith("/api/") ?? false;

    if (isApi) {
      res.setHeader("Access-Control-Allow-Origin", "*");
      res.setHeader(
        "Access-Control-Allow-Methods",
        "GET, POST, PUT, PATCH, DELETE, OPTIONS"
      );
      res.setHeader(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization"
      );

      if (req.method === "OPTIONS") {
        res.writeHead(204);
        res.end();
        return;
      }
    }

    handle(req, res, parse(req.url ?? "", true));
  });

  const wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", (req, socket, head) => {
    const { pathname } = parse(req.url ?? "", true);
    if (pathname === "/ws") {
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit("connection", ws, req);
      });
    } else {
      socket.destroy();
    }
  });

  wss.on("connection", (ws, req) => {
    const query = parse(req.url ?? "", true).query;
    const token = typeof query.token === "string" ? query.token : undefined;
    let userId: string | undefined;
    let username: string | undefined;
    if (token) {
      try {
        const payload = verifyToken(token);
        userId = payload.userId;
        username = payload.username;
      } catch {
        userId = undefined;
        username = undefined;
      }
    }
    connState.set(ws, { userId, username, status: "online" });
    for (const channel of DEFAULT_CHANNELS) subscribe(ws, channel);
    if (userId) {
      sendActiveUsersTo(ws);
    }

    ws.on("message", (data) => {
      const raw = Buffer.isBuffer(data)
        ? data.toString()
        : Array.isArray(data)
          ? Buffer.concat(data).toString()
          : Buffer.from(data).toString();
      void handleMessage(ws, raw);
    });

    ws.on("close", () => {
      for (const channel of DEFAULT_CHANNELS) unsubscribe(ws, channel);
      connState.delete(ws);
    });

    ws.send(
      JSON.stringify({
        type: "connected",
        user_id: userId ?? null,
        channels: DEFAULT_CHANNELS,
      })
    );
  });

  server.listen(port, "0.0.0.0", () => {
    console.log(`> Elite Training server ready on http://localhost:${port}`);
    console.log(`> WebSocket server listening on /ws`);
  });
}

main().catch((err) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});