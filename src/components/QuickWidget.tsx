import { Link } from 'react-router-dom';

type QuickWidgetProps = {
  to: string;
  label: string;
  icon: string;
};

export function QuickWidget({ to, label, icon }: QuickWidgetProps) {
  return (
    <Link to={to} className="quick-widget">
      <span className="quick-widget__icon" aria-hidden="true">
        {icon}
      </span>
      <span className="quick-widget__label">{label}</span>
    </Link>
  );
}
