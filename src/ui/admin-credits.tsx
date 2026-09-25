import { Button, Field, FormMessage, inputClass } from "@/ui/form-controls";

type Member = { id: string; email: string; nickname: string | null; credits: number };

type Props = {
  title: string;
  q: string;
  members: readonly Member[] | null;
  message?: { tone: "error" | "info"; text: string };
  action: (formData: FormData) => Promise<void>;
  text: {
    searchLabel: string;
    search: string;
    noResults: string;
    deltaLabel: string;
    noteLabel: string;
    apply: string;
    count: (n: number) => string;
  };
};

export function AdminCredits({ title, q, members, message, action, text }: Props) {
  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold text-ink">{title}</h1>
      {message && <FormMessage tone={message.tone}>{message.text}</FormMessage>}
      <form method="get" className="flex flex-col gap-3">
        <Field id="q" label={text.searchLabel}>
          <input id="q" name="q" defaultValue={q} minLength={2} required className={inputClass} />
        </Field>
        <Button type="submit" variant="secondary">
          {text.search}
        </Button>
      </form>
      {members?.length === 0 && <p className="text-muted">{text.noResults}</p>}
      {members?.map((m) => (
        <form key={m.id} action={action} className="flex flex-col gap-3 rounded-2xl border border-border bg-surface p-4">
          <div>
            <p className="font-semibold text-ink">{m.nickname ?? m.email}</p>
            <p className="break-all text-sm text-muted">{m.email}</p>
            <p className="text-sm text-ink">{text.count(m.credits)}</p>
          </div>
          <input type="hidden" name="target" value={m.id} />
          <input type="hidden" name="q" value={q} />
          <Field id={`delta-${m.id}`} label={text.deltaLabel} required>
            <input id={`delta-${m.id}`} name="delta" type="number" step={1} required className={inputClass} />
          </Field>
          <Field id={`note-${m.id}`} label={text.noteLabel} required>
            <input id={`note-${m.id}`} name="note" maxLength={200} required className={inputClass} />
          </Field>
          <Button type="submit">{text.apply}</Button>
        </form>
      ))}
    </section>
  );
}
