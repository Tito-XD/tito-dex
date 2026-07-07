import type { CurrentJourney } from '../features/journey/journeyTypes';
import { StickerCard } from './StickerCard';

type ContinueJourneyCardProps = {
  journey: CurrentJourney;
};

export function ContinueJourneyCard({ journey }: ContinueJourneyCardProps) {
  return (
    <StickerCard variant="deep" className="continue-card">
      <div className="continue-card__header">
        <span className="continue-card__eyebrow">Continue Journey</span>
        <h2 className="continue-card__location">{journey.location}</h2>
      </div>
      <div className="continue-card__illustration" aria-hidden="true">
        <div className="continue-card__city">
          <span className="continue-card__tower" />
          <span className="continue-card__buildings" />
        </div>
      </div>
      <div className="continue-card__meta">
        <div>
          <span className="continue-card__meta-label">Game</span>
          <strong>{journey.game}</strong>
        </div>
        <div>
          <span className="continue-card__meta-label">Play Time</span>
          <strong>{journey.playTime}</strong>
        </div>
        <div>
          <span className="continue-card__meta-label">Badges</span>
          <strong>
            {journey.badges}/{journey.maxBadges}
          </strong>
        </div>
      </div>
      <button type="button" className="continue-card__cta">
        Continue
      </button>
    </StickerCard>
  );
}
