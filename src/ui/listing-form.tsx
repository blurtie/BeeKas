import type { ReactNode } from "react";
import { Button, Field, FormMessage, describedBy, inputClass } from "@/ui/form-controls";

type Option = { readonly code: string; readonly name: string };
type Values = {
  type: string;
  title: string;
  category: string;
  condition: string;
  description: string;
  price: string;
  campus: string;
  meetup_note: string;
};
type ErrorKey = keyof Values | "agree" | "image_path";

export type ListingFormText = {
  fields: {
    type: string;
    title: string;
    category: string;
    categoryPlaceholder: string;
    condition: string;
    conditionPlaceholder: string;
    description: string;
    price: string;
    priceHint: string;
    campus: string;
    meetupNote: string;
    meetupNoteHint: string;
  };
  statement: string;
  publish: string;
  publishing: string;
};

type Props = {
  text: ListingFormText;
  action: (formData: FormData) => void;
  pending: boolean;
  values: Values;
  errors: Partial<Record<ErrorKey, string>>;
  formError?: string;
  photo: ReactNode;
  types: readonly Option[];
  categories: readonly Option[];
  conditions: readonly Option[];
  campuses: readonly Option[];
  limits: { titleMax: number; descriptionMax: number; meetupNoteMax: number };
  type: string;
  onTypeChange: (type: string) => void;
  agreed: boolean;
  onAgreeChange: (agreed: boolean) => void;
  costNote: string;
  // When set, replaces the Publish button (F4.9); the form stays filled in.
  blockedMessage?: string;
};

const aria = (id: string, error?: string, hint?: string) => ({
  "aria-invalid": error ? true : undefined,
  "aria-describedby": describedBy(id, hint, error),
});

export function ListingForm(p: Props) {
  const f = p.text.fields;
  const e = p.errors;
  const v = p.values;
  return (
    <form action={p.action} noValidate className="flex flex-col gap-4">
      {p.formError && <FormMessage tone="error">{p.formError}</FormMessage>}

      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-sm font-medium text-muted">{f.type}</legend>
        <div className="grid grid-cols-2 gap-2">
          {p.types.map((t) => (
            <label
              key={t.code}
              className={`flex min-h-11 cursor-pointer items-center justify-center rounded-xl border px-3 text-center font-semibold focus-within:ring-2 focus-within:ring-primary ${
                p.type === t.code ? "border-primary bg-honey text-ink" : "border-border bg-surface text-muted"
              }`}
            >
              <input type="radio" name="type" value={t.code} checked={p.type === t.code}
                onChange={() => p.onTypeChange(t.code)} className="sr-only" />
              {t.name}
            </label>
          ))}
        </div>
      </fieldset>

      {p.photo}
      {e.image_path && <FormMessage tone="error">{e.image_path}</FormMessage>}

      <Field id="title" label={f.title} required error={e.title}>
        <input id="title" name="title" required maxLength={p.limits.titleMax} defaultValue={v.title}
          {...aria("title", e.title)} className={inputClass} />
      </Field>

      <Field id="category" label={f.category} required error={e.category}>
        <select id="category" name="category" required defaultValue={v.category} {...aria("category", e.category)}
          className={inputClass}>
          <option value="">{f.categoryPlaceholder}</option>
          {p.categories.map((c) => <option key={c.code} value={c.code}>{c.name}</option>)}
        </select>
      </Field>

      <Field id="condition" label={f.condition} required error={e.condition}>
        <select id="condition" name="condition" required defaultValue={v.condition} {...aria("condition", e.condition)}
          className={inputClass}>
          <option value="">{f.conditionPlaceholder}</option>
          {p.conditions.map((c) => <option key={c.code} value={c.code}>{c.name}</option>)}
        </select>
      </Field>

      {p.type === "sale" && (
        <Field id="price" label={f.price} required hint={f.priceHint} error={e.price}>
          <input id="price" name="price" inputMode="numeric" required defaultValue={v.price}
            {...aria("price", e.price, f.priceHint)} className={inputClass} />
        </Field>
      )}

      <Field id="description" label={f.description} required error={e.description}>
        <textarea id="description" name="description" required rows={4} maxLength={p.limits.descriptionMax}
          defaultValue={v.description} {...aria("description", e.description)} className={`${inputClass} py-2`} />
      </Field>

      <Field id="campus" label={f.campus} required error={e.campus}>
        <select id="campus" name="campus" required defaultValue={v.campus} {...aria("campus", e.campus)}
          className={inputClass}>
          {p.campuses.map((c) => <option key={c.code} value={c.code}>{c.name}</option>)}
        </select>
      </Field>

      <Field id="meetup_note" label={f.meetupNote} hint={f.meetupNoteHint} error={e.meetup_note}>
        <input id="meetup_note" name="meetup_note" maxLength={p.limits.meetupNoteMax} defaultValue={v.meetup_note}
          {...aria("meetup_note", e.meetup_note, f.meetupNoteHint)} className={inputClass} />
      </Field>

      <label className="flex items-start gap-3 text-sm text-ink">
        <input type="checkbox" name="agree" checked={p.agreed} onChange={(ev) => p.onAgreeChange(ev.target.checked)}
          className="mt-1 size-5 shrink-0 accent-primary" {...aria("agree", e.agree)} />
        <span>{p.text.statement}</span>
      </label>
      {e.agree && <p id="agree-error" role="alert" className="text-sm font-medium text-primary">{e.agree}</p>}

      <p className="text-sm text-muted">{p.costNote}</p>
      {p.blockedMessage ? (
        <FormMessage tone="info">{p.blockedMessage}</FormMessage>
      ) : (
        <Button type="submit" disabled={p.pending || !p.agreed}>
          {p.pending ? p.text.publishing : p.text.publish}
        </Button>
      )}
    </form>
  );
}
