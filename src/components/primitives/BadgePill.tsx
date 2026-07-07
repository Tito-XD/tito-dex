import type { ReactNode } from 'react';

type BadgePillProps = {
  children: ReactNode;
  tone?: 'yellow' | 'sky' | 'coral' | 'mint';
};

const toneClass = {
  yellow: 'badge-pill--yellow',
  sky: 'badge-pill--sky',
  coral: 'badge-pill--coral',
  mint: 'badge-pill--mint',
} as const;

export function BadgePill({ children, tone = 'yellow' }: BadgePillProps) {
  return <span className={`badge-pill ${toneClass[tone]}`}>{children}</span>;
}
