import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement>;

const baseProps: IconProps = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2.2,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
};

export function PawIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <ellipse cx="12" cy="17" rx="4.5" ry="3.5" fill="currentColor" stroke="none" />
      <circle cx="7.5" cy="10.5" r="2.2" fill="currentColor" stroke="none" />
      <circle cx="12" cy="8" r="2.2" fill="currentColor" stroke="none" />
      <circle cx="16.5" cy="10.5" r="2.2" fill="currentColor" stroke="none" />
    </svg>
  );
}

export function HomeIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1z" />
    </svg>
  );
}

export function TeamIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <circle cx="8" cy="8" r="3" />
      <circle cx="16" cy="8" r="3" />
      <path d="M4 20v-1a4 4 0 0 1 4-4h0" />
      <path d="M20 20v-1a4 4 0 0 0-4-4h0" />
    </svg>
  );
}

export function JourneyIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <path d="M6 4h12v16H6z" />
      <path d="M9 8h6M9 12h6M9 16h4" />
    </svg>
  );
}

export function DexIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <circle cx="12" cy="12" r="8" />
      <path d="M12 4v16" />
      <path d="M4 12h16" />
      <circle cx="12" cy="12" r="2.5" fill="currentColor" stroke="none" />
    </svg>
  );
}

export function SearchIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <circle cx="11" cy="11" r="6" />
      <path d="m16.5 16.5 4 4" />
    </svg>
  );
}

export function SettingsIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v2M12 20v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M2 12h2M20 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4" />
    </svg>
  );
}

export function BadgeIcon(props: IconProps) {
  return (
    <svg {...baseProps} {...props}>
      <path d="M12 2l2.2 4.5 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5L4.8 7.2l5-.7z" />
    </svg>
  );
}
