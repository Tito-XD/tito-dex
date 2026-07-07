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
          <span className="continue-card__star continue-card__star--1">★</span>
          <span className="continue-card__star continue-card__star--2">★</span>
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
      {journey.party.length > 0 && (
        <div className="continue-card__party" aria-label="Party preview">
          {journey.party.map((member) => (
            <span key={member.species} className="continue-card__party-chip">
              {member.nickname ?? member.species}
            </span>
          ))}
        </div>
      )}
      <button type="button" className="continue-card__cta">
        Continue
      </button>
    </StickerCard>
  );
}
