import { redirect } from "next/navigation";

/** La web vive en /panel (usuario) y /pro (profesional). */
export default function Home() {
  redirect("/panel");
}
