import Link from "next/link";
import { FormMessage } from "@/ui/form-controls";

type Row = { label: string; value: string | null };

type Props = {
  title: string;
  rows: readonly Row[];
  notSet: string;
  incompleteMessage?: string;
  editHref: string;
  editLabel: string;
  signOutAction: string;
  signOutLabel: string;
};

const buttonBase =
  "flex min-h-11 w-full items-center justify-center rounded-xl px-4 text-base font-semibold outline-none focus-visible:ring-2 focus-visible:ring-primary";

export function ProfileSummary(p: Props) {
  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold text-ink">{p.title}</h1>
      {p.incompleteMessage && <FormMessage tone="info">{p.incompleteMessage}</FormMessage>}
      <dl className="divide-y divide-border rounded-2xl border border-border bg-surface">
        {p.rows.map(({ label, value }) => (
          <div key={label} className="flex flex-col gap-0.5 px-4 py-3">
            <dt className="text-sm text-muted">{label}</dt>
            <dd className={`break-all ${value ? "text-ink" : "text-muted"}`}>{value ?? p.notSet}</dd>
          </div>
        ))}
      </dl>
      <Link href={p.editHref} className={`${buttonBase} bg-honey text-ink`}>
        {p.editLabel}
      </Link>
      <form action={p.signOutAction} method="post">
        <button type="submit" className={`${buttonBase} border border-border bg-surface text-primary`}>
          {p.signOutLabel}
        </button>
      </form>
    </section>
  );
}
