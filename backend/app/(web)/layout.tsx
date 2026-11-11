import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import type { ReactNode } from "react";
import { WebShell } from "./session";
import "./web.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-mono" });

export const metadata: Metadata = {
  title: "Macrobuddy",
  description: "Tu panel de Macrobuddy y la plataforma para profesionales",
};

export default function WebLayout({ children }: { children: ReactNode }) {
  return (
    <div className={`pro ${inter.variable} ${mono.variable}`}>
      <WebShell>{children}</WebShell>
    </div>
  );
}
