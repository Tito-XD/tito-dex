export function AppHeader() {
  return (
    <header className="app-header">
      <div className="app-header__brand">
        <svg className="app-header__paw" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <ellipse cx="12" cy="17" rx="5" ry="4" />
          <circle cx="7" cy="10" r="2.5" />
          <circle cx="12" cy="7" r="2.5" />
          <circle cx="17" cy="10" r="2.5" />
        </svg>
        <h1 className="app-header__title">TitoDex</h1>
      </div>
      <span className="app-header__status" aria-label="SoulSilver journey active">
        HGSS
      </span>
    </header>
  );
}
