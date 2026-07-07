import { Link } from 'react-router-dom';
import { PawIcon, SettingsIcon } from './icons/Icons';
import { BadgePill } from './primitives/BadgePill';

export function AppHeader() {
  return (
    <header className="app-header">
      <div className="app-header__brand">
        <PawIcon className="app-header__paw" aria-hidden="true" />
        <h1 className="app-header__title">TitoDex</h1>
      </div>
      <div className="app-header__actions">
        <BadgePill tone="yellow">HGSS</BadgePill>
        <Link to="/settings" className="app-header__settings" aria-label="Settings">
          <SettingsIcon width={20} height={20} />
        </Link>
      </div>
    </header>
  );
}
