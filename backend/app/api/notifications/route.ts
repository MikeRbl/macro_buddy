import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { authUser } from "@/lib/requestAuth";
import Notification from "@/models/Notification";

/** GET /api/notifications → mis últimos avisos y cuántos no he leído. */
export async function GET(req: NextRequest) {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  await connectDB();
  const [items, unread] = await Promise.all([
    Notification.find({ user_id: user.userId }).sort({ createdAt: -1 }).limit(30).lean().exec(),
    Notification.countDocuments({ user_id: user.userId, read_at: null }).exec(),
  ]);
  return NextResponse.json({
    unread,
    items: items.map((n) => ({
      id: n._id.toString(),
      type: n.type,
      title: n.title,
      body: n.body ?? null,
      details: n.details ?? [],
      programId: n.program_id?.toString() ?? null,
      read: !!n.read_at,
      at: n.createdAt?.toISOString() ?? null,
    })),
  });
}

/** POST /api/notifications → marca todos mis avisos como leídos. */
export async function POST(req: NextRequest) {
  const user = authUser(req);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  await connectDB();
  await Notification.updateMany(
    { user_id: user.userId, read_at: null },
    { $set: { read_at: new Date() } }
  ).exec();
  return NextResponse.json({ unread: 0 });
}
