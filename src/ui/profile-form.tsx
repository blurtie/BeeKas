import { Button, Field, FormMessage, describedBy, inputClass } from "@/ui/form-controls";

type Option = { readonly code: string; readonly name: string };
type Group = { readonly school: string; readonly majors: readonly Option[] };

export type ProfileFormText = {
  title: string;
  intro: string;
  save: string;
  saving: string;
  listComingSoon: string;
  fields: {
    email: string;
    userType: string;
    nickname: string;
    whatsapp: string;
    whatsappHint: string;
    campus: string;
    campusPlaceholder: string;
    major: string;
    majorPlaceholder: string;
    majorOther: string;
    binusian: string;
    binusianPlaceholder: string;
    binusianHint: string;
  };
};

type Values = { nickname: string; whatsapp: string; campus: string; major: string; binusian: string };
type Errors = Partial<Record<keyof Values, string>>;

type Props = {
  text: ProfileFormText;
  action: (formData: FormData) => void;
  pending: boolean;
  email: string;
  userTypeLabel: string;
  isStudent: boolean;
  values: Values;
  errors: Errors;
  formError?: string;
  next: string;
  campuses: readonly Option[];
  majorGroups: readonly Group[];
  otherMajor: string;
  binusians: readonly string[];
  nicknameMax: number;
};

function ReadOnly({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-sm font-medium text-ink">{label}</span>
      <span className="min-h-11 rounded-xl border border-border bg-background px-3 py-2.5 break-all text-muted">
        {value}
      </span>
    </div>
  );
}

export function ProfileForm(p: Props) {
  const { fields } = p.text;
  const e = p.errors;
  const noCampuses = p.campuses.length === 0;
  const noMajors = p.majorGroups.length === 0;
  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold text-ink">{p.text.title}</h1>
      <p className="text-muted">{p.text.intro}</p>
      {p.formError && <FormMessage tone="error">{p.formError}</FormMessage>}
      <form action={p.action} noValidate className="flex flex-col gap-4">
        <input type="hidden" name="next" value={p.next} />
        <ReadOnly label={fields.email} value={p.email} />
        <ReadOnly label={fields.userType} value={p.userTypeLabel} />

        <Field id="nickname" label={fields.nickname} error={e.nickname}>
          <input id="nickname" name="nickname" type="text" autoComplete="nickname" required
            maxLength={p.nicknameMax} defaultValue={p.values.nickname}
            aria-invalid={e.nickname ? true : undefined}
            aria-describedby={describedBy("nickname", undefined, e.nickname)} className={inputClass} />
        </Field>

        <Field id="whatsapp" label={fields.whatsapp} hint={fields.whatsappHint} error={e.whatsapp}>
          <input id="whatsapp" name="whatsapp" type="tel" inputMode="tel" autoComplete="tel" required
            defaultValue={p.values.whatsapp}
            aria-invalid={e.whatsapp ? true : undefined}
            aria-describedby={describedBy("whatsapp", fields.whatsappHint, e.whatsapp)} className={inputClass} />
        </Field>

        <Field id="campus" label={fields.campus} hint={noCampuses ? p.text.listComingSoon : undefined} error={e.campus}>
          <select id="campus" name="campus" required defaultValue={p.values.campus}
            aria-invalid={e.campus ? true : undefined}
            aria-describedby={describedBy("campus", noCampuses ? p.text.listComingSoon : undefined, e.campus)}
            className={inputClass}>
            <option value="">{fields.campusPlaceholder}</option>
            {p.campuses.map((c) => (
              <option key={c.code} value={c.code}>{c.name}</option>
            ))}
          </select>
        </Field>

        {p.isStudent && (
          <>
            <Field id="major" label={fields.major} hint={noMajors ? p.text.listComingSoon : undefined} error={e.major}>
              <select id="major" name="major" defaultValue={p.values.major}
                aria-invalid={e.major ? true : undefined}
                aria-describedby={describedBy("major", noMajors ? p.text.listComingSoon : undefined, e.major)}
                className={inputClass}>
                <option value="">{fields.majorPlaceholder}</option>
                {p.majorGroups.map((g) => (
                  <optgroup key={g.school} label={g.school}>
                    {g.majors.map((m) => (
                      <option key={m.code} value={m.code}>{m.name}</option>
                    ))}
                  </optgroup>
                ))}
                <option value={p.otherMajor}>{fields.majorOther}</option>
              </select>
            </Field>

            <Field id="binusian" label={fields.binusian} hint={fields.binusianHint} error={e.binusian}>
              <select id="binusian" name="binusian" required defaultValue={p.values.binusian}
                aria-invalid={e.binusian ? true : undefined}
                aria-describedby={describedBy("binusian", fields.binusianHint, e.binusian)}
                className={inputClass}>
                <option value="">{fields.binusianPlaceholder}</option>
                {p.binusians.map((b) => (
                  <option key={b} value={b}>{b}</option>
                ))}
              </select>
            </Field>
          </>
        )}

        <Button type="submit" disabled={p.pending}>
          {p.pending ? p.text.saving : p.text.save}
        </Button>
      </form>
    </section>
  );
}
