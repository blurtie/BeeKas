import type { ButtonHTMLAttributes, ReactNode } from "react";

export const inputClass =
  "min-h-11 w-full border-0 border-b border-border bg-transparent px-0 text-base text-ink placeholder:text-muted outline-none focus-visible:border-b-2 focus-visible:border-primary disabled:opacity-60";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" };

export function Button({ variant = "primary", className = "", ...props }: ButtonProps) {
  const look =
    variant === "primary"
      ? "rounded-full bg-honey font-bold text-ink"
      : "rounded-xl font-semibold text-primary";
  return (
    <button
      {...props}
      className={`min-h-11 w-full px-4 text-base outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-60 ${look} ${className}`}
    />
  );
}

type FieldProps = { id: string; label: string; required?: boolean; hint?: string; error?: string; children: ReactNode };

export function Field({ id, label, required, hint, error, children }: FieldProps) {
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={id} className="text-sm font-medium text-muted">
        {label}
        {required && <span aria-hidden className="text-danger">*</span>}
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
