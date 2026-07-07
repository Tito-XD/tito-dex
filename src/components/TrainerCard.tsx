import type { CurrentJourney } from '../features/journey/journeyTypes';
import { StickerCard } from './StickerCard';

type TrainerCardProps = {
  journey: CurrentJourney;
};

export function TrainerCard({ journey }: TrainerCardProps) {
  const badgeDots = Array.from({ length: journey.maxBadges }, (_, i) => i < journey.badges);

  return (
    <StickerCard className="trainer-card">
      <div className="trainer-card__inner">
        <div className="trainer-card__avatar" aria-hidden="true">
          <span className="trainer-card__companion">🐾</span>
        </div>
        <div className="trainer-card__body">
          <p className="trainer-card__label">Trainer Card</p>
          <h2 className="trainer-card__name">{journey.trainerName}</h2>
          <p className="trainer-card__game">{journey.game}</p>
          <p className="trainer-card__companion-name">Companion: {journey.companion}</p>
          <div className="trainer-card__badges" aria-label={`${journey.badges} of ${journey.maxBadges} badges`}>
            {badgeDots.map((earned, index) => (
              <span
                key={index}
                className={`trainer-card__badge ${earned ? 'trainer-card__badge--earned' : ''}`}
              />
            ))}
          </div>
        </div>
      </div>
    </StickerCard>
  );
}
