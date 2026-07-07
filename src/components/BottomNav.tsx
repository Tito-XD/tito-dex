import { NavLink } from 'react-router-dom';
import { DexIcon, HomeIcon, JourneyIcon, SearchIcon, TeamIcon } from './icons/Icons';

const navItems = [
  { to: '/', label: 'Home', Icon: HomeIcon },
  { to: '/team', label: 'Team', Icon: TeamIcon },
  { to: '/journey', label: 'Journey', Icon: JourneyIcon },
  { to: '/dex', label: 'Dex', Icon: DexIcon },
  { to: '/search', label: 'Search', Icon: SearchIcon },
] as const;

export function BottomNav() {
  return (
    <nav className="bottom-nav" aria-label="Main navigation">
      {navItems.map(({ to, label, Icon }) => (
        <NavLink
          key={to}
          to={to}
          end={to === '/'}
          className={({ isActive }) =>
            `bottom-nav__link${isActive ? ' bottom-nav__link--active' : ''}`
          }
        >
          <Icon className="bottom-nav__icon" width={22} height={22} aria-hidden="true" />
          {label}
        </NavLink>
      ))}
    </nav>
  );
}
