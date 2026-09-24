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
        <h1 className="text-2xl font-semibold text-ink">{text.title}</h1>
        <p className="text-muted">{text.intro}</p>
        <form onSubmit={submit(p.onSubmitEmail)} noValidate className="flex flex-col gap-4">
          <Field id="email" label={text.emailLabel} error={p.error}>
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
      <h1 className="text-2xl font-semibold text-ink">{text.codeTitle}</h1>
      <p className="text-muted">
        {text.codeSentTo} <span className="font-medium break-all text-ink">{p.email}</span>
      </p>
      {p.info && <FormMessage tone="info">{p.info}</FormMessage>}
      <form onSubmit={submit(p.onSubmitCode)} noValidate className="flex flex-col gap-4">
        <Field id="otp" label={text.codeLabel} error={p.error}>
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
            className={`${inputClass} text-center text-2xl tracking-[0.5em]`}
          />
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
