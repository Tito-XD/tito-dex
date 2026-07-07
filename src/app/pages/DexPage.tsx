import { AppHeader } from '../../components/AppHeader';
import { StickerCard } from '../../components/StickerCard';
import { dexMockData } from '../../features/dex/dexMockData';
import { getCurrentJourney } from '../../features/journey/journeyStore';

export function DexPage() {
  const journey = getCurrentJourney();
  const caughtCount = dexMockData.filter((e) => e.caught).length;

  return (
    <div className="screen-page">
      <AppHeader />
      <h2 className="screen-page__title">
        Dex — {journey.game} ({caughtCount}/{dexMockData.length} caught)
      </h2>
      <div className="dex-grid">
        {dexMockData.map((entry) => (
          <StickerCard
            key={entry.id}
            className={`dex-card${entry.caught ? ' dex-card--caught' : ''}`}
          >
            <div className="dex-card__number">#{String(entry.id).padStart(3, '0')}</div>
            <div className="dex-card__name">{entry.name}</div>
            <div className="dex-card__type">{entry.type}</div>
            <div className="dex-card__status">
              {entry.caught ? 'Caught' : entry.seen ? 'Seen' : 'Unknown'}
            </div>
          </StickerCard>
        ))}
      </div>
    </div>
  );
}
