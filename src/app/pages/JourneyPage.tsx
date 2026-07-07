import { AppHeader } from '../../components/AppHeader';
import { JourneyTimeline } from '../../components/JourneyTimeline';
import { StickerCard } from '../../components/StickerCard';
import { getCurrentJourney } from '../../features/journey/journeyStore';

export function JourneyPage() {
  const journey = getCurrentJourney();

  return (
    <div className="screen-page">
      <AppHeader />
      <h2 className="screen-page__title">Journey — {journey.location}</h2>
      <JourneyTimeline entries={journey.timeline} nextReminder={journey.nextReminder} />
      <StickerCard>
        <div className="timeline-page__entry">
          <strong>Current location</strong>
          <p style={{ margin: '4px 0 0' }}>{journey.location}</p>
        </div>
        <div className="timeline-page__entry">
          <strong>Play time</strong>
          <p style={{ margin: '4px 0 0' }}>{journey.playTime}</p>
        </div>
        <div className="timeline-page__entry">
          <strong>Badges</strong>
          <p style={{ margin: '4px 0 0' }}>
            {journey.badges} / {journey.maxBadges}
          </p>
        </div>
      </StickerCard>
    </div>
  );
}
