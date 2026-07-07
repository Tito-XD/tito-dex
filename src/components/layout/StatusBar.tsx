export function StatusBar() {
  return (
    <div className="status-bar" aria-hidden="true">
      <span className="status-bar__time">18:42</span>
      <span className="status-bar__label">SoulSilver</span>
      <span className="status-bar__icons">
        <span className="status-bar__dot" />
        <span className="status-bar__dot" />
        <span className="status-bar__battery" />
      </span>
    </div>
  );
}
