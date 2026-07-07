import { useJourney } from '../features/journey/JourneyProvider';
import { StickerCard } from './StickerCard';

/** Glanceable launcher-style widget previews for future Android home-screen widgets. */
export function LauncherWidgets() {
  const journey = useJourney();

  return (
    <div className="launcher-widgets" aria-label="Launcher widget previews">
      <StickerCard className="launcher-widget">
        <span className="launcher-widget__label">Continue</span>
        <strong>{journey.location}</strong>
        <span className="launcher-widget__meta">{journey.playTime}</span>
      </StickerCard>
      <StickerCard className="launcher-widget">
        <span className="launcher-widget__label">Badges</span>
        <strong>
          {journey.badges}/{journey.maxBadges}
        </strong>
      </StickerCard>
      <StickerCard className="launcher-widget">
        <span className="launcher-widget__label">Companion</span>
        <strong>{journey.companion}</strong>
      </StickerCard>
    </div>
  );
}
