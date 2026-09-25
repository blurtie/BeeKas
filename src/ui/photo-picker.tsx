import type { ChangeEvent } from "react";
import { FormMessage } from "@/ui/form-controls";

type Props = {
  label: string;
  chooseLabel: string;
  warning: string;
  previewUrl: string | null;
  previewAlt: string;
  busy: boolean;
  status?: { tone: "error" | "info"; text: string };
  onChange: (e: ChangeEvent<HTMLInputElement>) => void;
};

export function PhotoPicker(p: Props) {
  return (
    <div className="flex flex-col gap-2">
      <span className="text-sm font-medium text-muted">{p.label}</span>
      {p.previewUrl && (
        // eslint-disable-next-line @next/next/no-img-element -- local blob preview, not optimizable
        <img src={p.previewUrl} alt={p.previewAlt} className="aspect-square w-full rounded-2xl object-cover" />
      )}
      <label
        className={`flex min-h-11 cursor-pointer items-center justify-center rounded-xl border border-border bg-surface px-4 font-semibold text-primary focus-within:ring-2 focus-within:ring-primary ${
          p.busy ? "pointer-events-none opacity-60" : ""
        }`}
      >
        {p.chooseLabel}
        <input type="file" accept="image/*" className="sr-only" disabled={p.busy} onChange={p.onChange} />
      </label>
      <p className="text-sm text-muted">{p.warning}</p>
      {p.status && <FormMessage tone={p.status.tone}>{p.status.text}</FormMessage>}
    </div>
  );
}
