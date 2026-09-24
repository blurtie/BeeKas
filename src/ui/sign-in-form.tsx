import type { FormEvent } from "react";
import { Button, Field, FormMessage, describedBy, inputClass } from "@/ui/form-controls";

export type SignInText = {
  title: string;
  intro: string;
  emailLabel: string;
  emailPlaceholder: string;
  sendCode: string;
  sending: string;
  codeTitle: string;
  codeSentTo: string;
  codeLabel: string;
  verify: string;
  verifying: string;
  resend: string;
  changeEmail: string;
};

type Props = {
  text: SignInText;
  step: "email" | "code";
  email: string;
  code: string;
  codeLength: number;
  pending: boolean;
  error?: string;
  info?: string;
  onEmailChange: (v: string) => void;
  onCodeChange: (v: string) => void;
  onSubmitEmail: () => void;
  onSubmitCode: () => void;
  onResend: () => void;
  onChangeEmail: () => void;
};

const submit = (fn: () => void) => (e: FormEvent) => {
  e.preventDefault();
  fn();
};

export function SignInForm(p: Props) {
  const { text } = p;
  if (p.step === "email") {
    return (
      <section className="flex flex-col gap-4">
        <h1 className="text-lg font-semibold text-ink">{text.title}</h1>
        <p className="text-sm text-muted">{text.intro}</p>
        <form onSubmit={submit(p.onSubmitEmail)} noValidate className="flex flex-col gap-4">
          <Field id="email" label={text.emailLabel} required error={p.error}>
            <input
              id="email"
              type="email"
              inputMode="email"
              autoComplete="email"
              autoCapitalize="none"
              spellCheck={false}
              required
              placeholder={text.emailPlaceholder}
              value={p.email}
              onChange={(e) => p.onEmailChange(e.target.value)}
              aria-invalid={p.error ? true : undefined}
              aria-describedby={describedBy("email", undefined, p.error)}
              className={inputClass}
            />
          </Field>
          <Button type="submit" disabled={p.pending}>
            {p.pending ? text.sending : text.sendCode}
          </Button>
        </form>
      </section>
    );
  }

  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-lg font-semibold text-ink">{text.codeTitle}</h1>
      <p className="text-sm text-muted">
        {text.codeSentTo} <span className="font-bold break-all text-ink">{p.email}</span>
      </p>
      {p.info && <FormMessage tone="info">{p.info}</FormMessage>}
      <form onSubmit={submit(p.onSubmitCode)} noValidate className="flex flex-col gap-4">
        <Field id="otp" label={text.codeLabel} error={p.error}>
          <div className="relative w-fit rounded-[10px] ring-offset-4 focus-within:ring-2 focus-within:ring-primary">
            <input
              id="otp"
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]*"
              maxLength={p.codeLength}
              required
              value={p.code}
              onChange={(e) => p.onCodeChange(e.target.value.replace(/\D/g, ""))}
              aria-invalid={p.error ? true : undefined}
              aria-describedby={describedBy("otp", undefined, p.error)}
              className="absolute inset-0 size-full cursor-text opacity-0"
            />
            {/* Figma OTP boxes (8:304); one real input on top keeps paste and autofill working. */}
            <div aria-hidden className="flex gap-2">
              {Array.from({ length: p.codeLength }, (_, i) => (
                <span key={i} className={`flex size-11 items-center justify-center rounded-[10px] border text-lg font-semibold text-ink ${
                  i === Math.min(p.code.length, p.codeLength - 1) ? "border-accent" : "border-accent/50"
                }`}>{p.code[i] ?? ""}</span>
              ))}
            </div>
          </div>
        </Field>
        <Button type="submit" disabled={p.pending}>
          {p.pending ? text.verifying : text.verify}
        </Button>
        <Button type="button" variant="secondary" disabled={p.pending} onClick={p.onResend}>
          {text.resend}
        </Button>
        <Button type="button" variant="secondary" disabled={p.pending} onClick={p.onChangeEmail}>
          {text.changeEmail}
        </Button>
      </form>
    </section>
  );
}
