import { ScreenLayout } from '../../components/layout/ScreenLayout';
import { PartySummary } from '../../components/PartySummary';
import { StickerCard } from '../../components/StickerCard';
import { useJourney } from '../../features/journey/JourneyProvider';

export function TeamPage() {
  const journey = useJourney();

  return (
    <ScreenLayout title={`Team — ${journey.game}`}>
      <PartySummary party={journey.party} />
      <StickerCard>
        <p className="screen-note">
          Party management will become editable in Phase 3. For now, this screen mirrors your SoulSilver
          mock party.
        </p>
      </StickerCard>
    </ScreenLayout>
  );
}
