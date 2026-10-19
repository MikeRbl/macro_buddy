import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  async headers() {
    const cors = [
      { key: "Access-Control-Allow-Origin", value: "*" },
      { key: "Access-Control-Allow-Methods", value: "GET, POST, PUT, PATCH, DELETE, OPTIONS" },
      {
        key: "Access-Control-Allow-Headers",
        value: "Content-Type, Authorization",
      },
    ];
    return [
      { source: "/api/:path*", headers: cors },
      { source: "/assets/:path*", headers: cors },
    ];
  },
};

export default nextConfig;
