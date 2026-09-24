import type { ButtonHTMLAttributes, ReactNode } from "react";

export const inputClass =
  "min-h-11 w-full rounded-xl border border-border bg-surface px-3 text-base text-ink outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-60";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" };

export function Button({ variant = "primary", className = "", ...props }: ButtonProps) {
  const look =
    variant === "primary"
      ? "bg-honey text-ink"
      : "border border-border bg-surface text-primary";
  return (
    <button
      {...props}
      className={`min-h-11 w-full rounded-xl px-4 text-base font-semibold outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-60 ${look} ${className}`}
    />
  );
}

type FieldProps = { id: string; label: string; hint?: string; error?: string; children: ReactNode };

export function Field({ id, label, hint, error, children }: FieldProps) {
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={id} className="text-sm font-medium text-ink">
        {label}
      </label>
      {children}
      {hint && (
        <p id={`${id}-hint`} className="text-sm text-muted">
          {hint}
        </p>
      )}
      {error && (
        <p id={`${id}-error`} role="alert" className="text-sm font-medium text-primary">
          {error}
        </p>
      )}
    </div>
  );
}

export function describedBy(id: string, hint?: string, error?: string) {
  const ids = [hint && `${id}-hint`, error && `${id}-error`].filter(Boolean);
  return ids.length ? ids.join(" ") : undefined;
}

export function FormMessage({ tone, children }: { tone: "error" | "info"; children: ReactNode }) {
  return (
    <p
      role={tone === "error" ? "alert" : "status"}
      className={`rounded-xl border border-border px-3 py-2 text-sm ${
        tone === "error" ? "bg-surface font-medium text-primary" : "bg-honey text-ink"
      }`}
    >
      {children}
    </p>
  );
}
