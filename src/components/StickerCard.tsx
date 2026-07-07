import type { CSSProperties, ReactNode } from 'react';

type StickerCardProps = {
  children: ReactNode;
  className?: string;
  variant?: 'cream' | 'deep' | 'sky';
  style?: CSSProperties;
};

const variantClass: Record<NonNullable<StickerCardProps['variant']>, string> = {
  cream: 'sticker-card--cream',
  deep: 'sticker-card--deep',
  sky: 'sticker-card--sky',
};

export function StickerCard({
  children,
  className = '',
  variant = 'cream',
  style,
}: StickerCardProps) {
  return (
    <article className={`sticker-card ${variantClass[variant]} ${className}`.trim()} style={style}>
      {children}
    </article>
  );
}
