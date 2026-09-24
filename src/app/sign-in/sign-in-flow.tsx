"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { copy } from "@/config/copy";
import { authErrorKey } from "@/lib/domain/auth-errors";
import { campusEmailSchema } from "@/lib/domain/campus-email";
import { OTP_LENGTH, otpCodeSchema } from "@/lib/domain/otp";
import { createClient } from "@/lib/supabase/client";
import { SignInForm } from "@/ui/sign-in-form";

type ErrorKey = keyof typeof copy.auth.errors;
const isErrorKey = (k: unknown): k is ErrorKey => typeof k === "string" && k in copy.auth.errors;

type Props = { next: string };

export function SignInFlow({ next }: Props) {
  const router = useRouter();
  const [step, setStep] = useState<"email" | "code">("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<ErrorKey>();
  const [info, setInfo] = useState<string>();

  async function sendCode(address: string) {
    const { error: err } = await createClient().auth.signInWithOtp({
      email: address,
      // Code-only sign-in: the email templates contain only {{ .Token }} (D-14).
      options: { shouldCreateUser: true },
    });
    return err ? authErrorKey(err) : null;
  }

  async function onSubmitEmail() {
    // Validate before calling Supabase so users see the friendly domain message.
    const parsed = campusEmailSchema.safeParse(email);
    if (!parsed.success) {
      const msg = parsed.error.issues[0]?.message;
      setError(isErrorKey(msg) ? msg : "invalid_email");
      return;
    }
    setPending(true);
    setError(undefined);
    const failure = await sendCode(parsed.data);
    setPending(false);
    if (failure) {
      setError(failure);
      return;
    }
    setEmail(parsed.data);
    setCode("");
    setInfo(undefined);
    setStep("code");
  }

  async function onSubmitCode() {
    const parsed = otpCodeSchema.safeParse(code);
    if (!parsed.success) {
      setError("invalid_otp");
      return;
    }
    setPending(true);
    setError(undefined);
    const { error: err } = await createClient().auth.verifyOtp({ email, token: parsed.data, type: "email" });
    if (err) {
      setPending(false);
      setError(authErrorKey(err));
      return;
    }
    router.replace(next);
    router.refresh();
  }

  async function onResend() {
    setPending(true);
    setError(undefined);
    setInfo(undefined);
    const failure = await sendCode(email);
    setPending(false);
    if (failure) setError(failure);
    else setInfo(copy.auth.signIn.codeResent);
  }

  return (
    <SignInForm
      text={copy.auth.signIn}
      step={step}
      email={email}
      code={code}
      codeLength={OTP_LENGTH}
      pending={pending}
      error={error ? copy.auth.errors[error] : undefined}
      info={info}
      onEmailChange={(v) => {
        setEmail(v);
        setError(undefined);
      }}
      onCodeChange={(v) => {
        setCode(v);
        setError(undefined);
      }}
      onSubmitEmail={onSubmitEmail}
      onSubmitCode={onSubmitCode}
      onResend={onResend}
      onChangeEmail={() => {
        setStep("email");
        setCode("");
        setError(undefined);
        setInfo(undefined);
      }}
    />
  );
}
