import { ScreenLayout } from '../../components/layout/ScreenLayout';
import { JourneyTimeline } from '../../components/JourneyTimeline';
import { StickerCard } from '../../components/StickerCard';
import { useJourney } from '../../features/journey/JourneyProvider';

export function JourneyPage() {
  const journey = useJourney();

  return (
    <ScreenLayout title={`Journey — ${journey.location}`}>
      <JourneyTimeline entries={journey.timeline} nextReminder={journey.nextReminder} />
      <StickerCard>
        <div className="timeline-page__entry">
          <strong>Current location</strong>
          <p className="screen-note screen-note--tight">{journey.location}</p>
        </div>
        <div className="timeline-page__entry">
          <strong>Play time</strong>
          <p className="screen-note screen-note--tight">{journey.playTime}</p>
        </div>
        <div className="timeline-page__entry">
          <strong>Badges</strong>
          <p className="screen-note screen-note--tight">
            {journey.badges} / {journey.maxBadges}
          </p>
        </div>
      </StickerCard>
    </ScreenLayout>
  );
}
