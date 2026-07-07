import { ScreenLayout } from '../../components/layout/ScreenLayout';
import { StickerCard } from '../../components/StickerCard';
import { dexMockData } from '../../features/dex/dexMockData';
import { useJourney } from '../../features/journey/JourneyProvider';

export function DexPage() {
  const journey = useJourney();
  const caughtCount = dexMockData.filter((e) => e.caught).length;

  return (
    <ScreenLayout title={`Dex — ${journey.game} (${caughtCount}/${dexMockData.length})`}>
      <p className="screen-note screen-note--muted">
        Mock Dex scoped to your current SoulSilver journey — not a full encyclopedia.
      </p>
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
    </ScreenLayout>
  );
}
