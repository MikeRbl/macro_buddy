import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import type { ReactNode } from "react";
import { ProShell } from "./session";
import "./pro.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-mono" });

export const metadata: Metadata = {
  title: "Macrobuddy Pro",
  description: "Plataforma para profesionales de Macrobuddy",
};

export default function ProLayout({ children }: { children: ReactNode }) {
  return (
    <div className={`pro ${inter.variable} ${mono.variable}`}>
      <ProShell>{children}</ProShell>
    </div>
  );
}
