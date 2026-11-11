import mongoose from "mongoose";
import { Readable } from "node:stream";
import { NextRequest, NextResponse } from "next/server";
import { connectDB } from "@/lib/db";
import { openPhoto, photoInfo } from "@/lib/contributions";
import { authUser, isAdmin } from "@/lib/requestAuth";

/** GET /api/admin/food-photos/:id → la imagen de una contribución. */
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  if (!isAdmin(authUser(req))) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  const { id } = await params;
  if (!mongoose.isValidObjectId(id)) {
    return NextResponse.json({ error: "id inválido" }, { status: 400 });
  }
  await connectDB();
  const info = await photoInfo(id);
  if (!info) return NextResponse.json({ error: "No encontrada" }, { status: 404 });

  const stream = Readable.toWeb(openPhoto(id)) as unknown as ReadableStream<Uint8Array>;
  const contentType =
    (info.metadata as { contentType?: string } | undefined)?.contentType ?? "image/jpeg";
  return new NextResponse(stream, {
    headers: { "Content-Type": contentType, "Cache-Control": "private, max-age=3600" },
  });
}
