import Link from "next/link";

export function Brand({ size = "md" }: { size?: "sm" | "md" }) {
  const isSm = size === "sm";
  return (
    <Link
      href="/"
      className="inline-flex items-center gap-2 font-semibold tracking-tight"
    >
      <span
        className={`grid place-items-center rounded-lg bg-gradient-to-br from-indigo-500 to-fuchsia-500 text-white shadow-lg shadow-indigo-500/20 ${
          isSm ? "h-7 w-7 text-sm" : "h-9 w-9 text-base"
        }`}
        aria-hidden
      >
        Z
      </span>
      <span className={isSm ? "text-base" : "text-lg"}>
        ZAXEL <span className="text-muted font-normal">Learning</span>
      </span>
    </Link>
  );
}
