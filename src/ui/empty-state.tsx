type Props = { title: string; message: string };

export function EmptyState({ title, message }: Props) {
  return (
    <section>
      <h1 className="mb-6 text-2xl font-semibold text-ink">{title}</h1>
      <div className="rounded-2xl border border-border bg-surface p-8 text-center text-muted">
        {message}
      </div>
    </section>
  );
}
