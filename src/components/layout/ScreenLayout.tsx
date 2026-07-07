import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { AppHeader } from '../AppHeader';
import { SettingsIcon } from '../icons/Icons';

type ScreenLayoutProps = {
  children: ReactNode;
  title?: string;
  showHeader?: boolean;
  showSettings?: boolean;
};

export function ScreenLayout({
  children,
  title,
  showHeader = true,
  showSettings = false,
}: ScreenLayoutProps) {
  return (
    <div className="screen-page">
      {showHeader && <AppHeader />}
      {(title || showSettings) && (
        <div className="screen-page__heading">
          {title && <h2 className="screen-page__title">{title}</h2>}
          {showSettings && (
            <Link to="/settings" className="screen-page__settings" aria-label="Settings">
              <SettingsIcon width={22} height={22} />
            </Link>
          )}
        </div>
      )}
      {children}
    </div>
  );
}
