type Props = { message: string };

export function OfflineBanner({ message }: Props) {
  return (
    <div role="status" aria-live="polite"
      className="sticky top-0 z-10 w-full border-b border-border bg-honey px-4 py-2 text-center text-sm text-ink">
      {message}
    </div>
  );
}
