import { useMemo, useState } from 'react';
import { AppHeader } from '../../components/AppHeader';
import { StickerCard } from '../../components/StickerCard';
import { dexMockData } from '../../features/dex/dexMockData';
import { getCurrentJourney } from '../../features/journey/journeyStore';

export function SearchPage() {
  const journey = getCurrentJourney();
  const [query, setQuery] = useState('');

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return dexMockData.filter(
      (entry) =>
        entry.name.toLowerCase().includes(q) ||
        entry.type.toLowerCase().includes(q) ||
        String(entry.id).includes(q),
    );
  }, [query]);

  return (
    <div className="screen-page">
      <AppHeader />
      <h2 className="screen-page__title">Search — {journey.game} context</h2>
      <input
        className="search-input"
        type="search"
        placeholder="Search Pokémon in current journey..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        aria-label="Search Pokémon"
      />
      {query && results.length === 0 && (
        <StickerCard>
          <p style={{ margin: 0 }}>No matches in the current mock Dex data.</p>
        </StickerCard>
      )}
      {results.length > 0 && (
        <div className="dex-grid">
          {results.map((entry) => (
            <StickerCard key={entry.id} className="dex-card">
              <div className="dex-card__number">#{String(entry.id).padStart(3, '0')}</div>
              <div className="dex-card__name">{entry.name}</div>
              <div className="dex-card__type">{entry.type}</div>
            </StickerCard>
          ))}
        </div>
      )}
    </div>
  );
}
