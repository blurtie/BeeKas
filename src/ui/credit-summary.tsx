type Entry = { id: number; delta: number; label: string; note: string | null; date: string };

type Props = {
  title: string;
  count: string;
  rule: string;
  historyTitle: string;
  historyEmpty: string;
  entries: readonly Entry[];
};

export function CreditSummary(p: Props) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-xl font-semibold text-ink">{p.title}</h2>
      <p className="rounded-2xl border border-border bg-surface px-4 py-3 text-lg font-semibold text-ink">{p.count}</p>
      <p className="text-sm text-muted">{p.rule}</p>
      <h3 className="font-semibold text-ink">{p.historyTitle}</h3>
      {p.entries.length === 0 ? (
        <p className="text-muted">{p.historyEmpty}</p>
      ) : (
        <ul className="divide-y divide-border rounded-2xl border border-border bg-surface">
          {p.entries.map((e) => (
            <li key={e.id} className="flex items-start justify-between gap-3 px-4 py-3">
              <div className="min-w-0">
                <p className="text-ink">{e.label}</p>
                {e.note && <p className="break-words text-sm text-muted">{e.note}</p>}
                <p className="text-sm text-muted">{e.date}</p>
              </div>
              <span className={`font-semibold ${e.delta > 0 ? "text-ink" : "text-primary"}`}>
                {e.delta > 0 ? `+${e.delta}` : e.delta}
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
