import { ScreenLayout } from '../../components/layout/ScreenLayout';
import { StickerCard } from '../../components/StickerCard';
import { useJourney } from '../../features/journey/JourneyProvider';
import { isNativePlatform } from '../../platform/capacitor';

export function SettingsPage() {
  const journey = useJourney();

  return (
    <ScreenLayout title="Settings">
      <StickerCard>
        <div className="settings-list">
          <div className="settings-list__row">
            <span>Trainer</span>
            <strong>{journey.trainerName}</strong>
          </div>
          <div className="settings-list__row">
            <span>Current game</span>
            <strong>{journey.game}</strong>
          </div>
          <div className="settings-list__row">
            <span>Platform</span>
            <strong>{isNativePlatform() ? 'Android' : 'Web preview'}</strong>
          </div>
        </div>
      </StickerCard>
      <StickerCard variant="sky">
        <p className="screen-note">
          Settings are a Phase 2 skeleton placeholder. Local persistence, save import, and cloud backup
          arrive in later phases.
        </p>
      </StickerCard>
    </ScreenLayout>
  );
}
