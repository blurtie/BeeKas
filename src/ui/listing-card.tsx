import Link from "next/link";

export type ListingCardData = {
  href: string;
  imageUrl: string;
  title: string;
  price: string;
  campus: string;
  badge?: string;
};

export function ListingCard({ href, imageUrl, title, price, campus, badge }: ListingCardData) {
  return (
    <Link
      href={href}
      className="flex flex-col overflow-hidden rounded-2xl border border-border bg-surface outline-none focus-visible:ring-2 focus-visible:ring-primary"
    >
      <div className="relative">
        {/* eslint-disable-next-line @next/next/no-img-element -- Supabase public URL, already resized to 1024 px */}
        <img src={imageUrl} alt="" loading="lazy" className="aspect-square w-full object-cover" />
        {badge && (
          <span className="absolute left-2 top-2 rounded-full bg-honey px-2 py-0.5 text-xs font-semibold text-ink">
            {badge}
          </span>
        )}
      </div>
      <div className="flex flex-col gap-0.5 p-3">
        <p className="font-bold text-ink">{price}</p>
        <p className="line-clamp-2 text-sm text-ink">{title}</p>
        <p className="text-xs text-muted">{campus}</p>
      </div>
    </Link>
  );
}
