import { AppHeader } from '../../components/AppHeader';
import { PartySummary } from '../../components/PartySummary';
import { StickerCard } from '../../components/StickerCard';
import { getCurrentJourney } from '../../features/journey/journeyStore';

export function TeamPage() {
  const journey = getCurrentJourney();

  return (
    <div className="screen-page">
      <AppHeader />
      <h2 className="screen-page__title">Team — {journey.game}</h2>
      <PartySummary party={journey.party} />
      <StickerCard>
        <p style={{ margin: 0 }}>
          Party management will become editable in Phase 3. For now, this screen mirrors your SoulSilver
          mock party.
        </p>
      </StickerCard>
    </div>
  );
}
