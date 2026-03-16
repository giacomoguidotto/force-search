import { cn } from "@/lib/utils";

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: "default" | "outline";
}

export function Badge({
  className,
  variant = "default",
  ...props
}: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-3 py-1 font-medium text-xs",
        variant === "default" &&
          "border border-primary/20 bg-primary/10 text-primary",
        variant === "outline" && "border border-border text-muted-foreground",
        className
      )}
      {...props}
    />
  );
}
