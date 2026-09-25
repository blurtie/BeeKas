import Link from "next/link";
import { inputClass } from "@/ui/form-controls";

type Option = { readonly code: string; readonly name: string };

type Props = {
  values: { q?: string; type?: string; category?: string; campus?: string };
  types: readonly Option[];
  categories: readonly Option[];
  campuses: readonly Option[];
  maxSearch: number;
  showClear: boolean;
  text: {
    searchLabel: string;
    searchPlaceholder: string;
    type: string;
    category: string;
    campus: string;
    any: string;
    apply: string;
    clear: string;
  };
};

// Plain GET form: search and filters live in the URL, no client JS needed.
export function CatalogFilters({ values, types, categories, campuses, maxSearch, showClear, text }: Props) {
  const select = (name: string, label: string, options: readonly Option[], value?: string) => (
    <label className="flex flex-col gap-1 text-sm font-medium text-muted">
      {label}
      <select name={name} defaultValue={value ?? ""} className={inputClass}>
        <option value="">{text.any}</option>
        {options.map((o) => (
          <option key={o.code} value={o.code}>{o.name}</option>
        ))}
      </select>
    </label>
  );
  return (
    <form method="get" role="search" className="flex flex-col gap-3">
      <label className="flex flex-col gap-1 text-sm font-medium text-muted">
        {text.searchLabel}
        <input type="search" name="q" defaultValue={values.q ?? ""} maxLength={maxSearch}
          placeholder={text.searchPlaceholder} className={inputClass} />
      </label>
      <div className="grid grid-cols-3 gap-2">
        {select("type", text.type, types, values.type)}
        {select("category", text.category, categories, values.category)}
        {select("campus", text.campus, campuses, values.campus)}
      </div>
      <div className="flex gap-2">
        <button type="submit"
          className="min-h-11 flex-1 rounded-full bg-honey px-4 font-bold text-ink outline-none focus-visible:ring-2 focus-visible:ring-primary">
          {text.apply}
        </button>
        {showClear && (
          <Link href="/catalog"
            className="flex min-h-11 items-center rounded-xl px-4 font-semibold text-primary outline-none focus-visible:ring-2 focus-visible:ring-primary">
            {text.clear}
          </Link>
        )}
      </div>
    </form>
  );
}
