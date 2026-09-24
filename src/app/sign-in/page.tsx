import type { Metadata } from "next";
import { copy } from "@/config/copy";
import { safeNextPath } from "@/lib/domain/safe-redirect";
import { SignInFlow } from "./sign-in-flow";

export const metadata: Metadata = { title: copy.auth.signIn.title };

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);

export default async function SignInPage({ searchParams }: PageProps<"/sign-in">) {
  const params = await searchParams;
  const next = safeNextPath(first(params.next));
  const initialError = first(params.error) === "link_failed" ? "link_failed" : undefined;
  return <SignInFlow next={next} initialError={initialError} />;
}
