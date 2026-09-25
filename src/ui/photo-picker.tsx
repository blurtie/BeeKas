import type { ChangeEvent } from "react";
import { FormMessage } from "@/ui/form-controls";

type Props = {
  label: string;
  cameraLabel: string;
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
      <div className="grid grid-cols-2 gap-2">
        {/* capture opens the camera directly; the second input opens the gallery/file picker. */}
        <PickButton label={p.cameraLabel} busy={p.busy} onChange={p.onChange} capture="environment" />
        <PickButton label={p.chooseLabel} busy={p.busy} onChange={p.onChange} />
      </div>
      <p className="text-sm text-muted">{p.warning}</p>
      {p.status && <FormMessage tone={p.status.tone}>{p.status.text}</FormMessage>}
    </div>
  );
}

type PickProps = Pick<Props, "busy" | "onChange"> & { label: string; capture?: "environment" };

function PickButton({ label, busy, onChange, capture }: PickProps) {
  return (
    <label
      className={`flex min-h-11 cursor-pointer items-center justify-center rounded-xl border border-border bg-surface px-3 text-center font-semibold text-primary focus-within:ring-2 focus-within:ring-primary ${
        busy ? "pointer-events-none opacity-60" : ""
      }`}
    >
      {label}
      <input type="file" accept="image/*" capture={capture} className="sr-only" disabled={busy} onChange={onChange} />
    </label>
  );
}
