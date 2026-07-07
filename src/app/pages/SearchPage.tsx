import { useMemo, useState } from 'react';
import { ScreenLayout } from '../../components/layout/ScreenLayout';
import { StickerCard } from '../../components/StickerCard';
import { dexMockData } from '../../features/dex/dexMockData';
import { useJourney } from '../../features/journey/JourneyProvider';

export function SearchPage() {
  const journey = useJourney();
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
    <ScreenLayout title={`Search — ${journey.game}`}>
      <input
        className="search-input"
        type="search"
        placeholder="Search Pokémon in current journey..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        aria-label="Search Pokémon"
      />
      {!query && (
        <StickerCard>
          <p className="screen-note">Search mock Dex entries from your current journey context.</p>
        </StickerCard>
      )}
      {query && results.length === 0 && (
        <StickerCard>
          <p className="screen-note">No matches in the current mock Dex data.</p>
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
    </ScreenLayout>
  );
}
