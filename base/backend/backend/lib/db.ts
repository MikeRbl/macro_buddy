import mongoose from "mongoose";

declare global {
  var __mongooseConnection: Promise<typeof mongoose> | undefined;
}

export async function connectDB(): Promise<typeof mongoose> {
  const MONGODB_URI = process.env.MONGODB_URI;
  if (!MONGODB_URI) {
    throw new Error("MONGODB_URI is not defined in the environment");
  }
  if (global.__mongooseConnection) {
    return global.__mongooseConnection;
  }
  global.__mongooseConnection = mongoose.connect(MONGODB_URI, {
    serverSelectionTimeoutMS: 10000,
  });
  return global.__mongooseConnection;
}