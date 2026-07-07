import type { PartyMember } from '../features/journey/journeyTypes';
import { StickerCard } from './StickerCard';

type PartySummaryProps = {
  party: PartyMember[];
};

export function PartySummary({ party }: PartySummaryProps) {
  return (
    <StickerCard className="party-summary">
      <h3 className="party-summary__title">Current Party</h3>
      <ul className="party-summary__list">
        {party.map((member) => (
          <li key={member.species} className="party-chip">
            <span className="party-chip__ball" aria-hidden="true">
              ◉
            </span>
            <span className="party-chip__name">{member.nickname ?? member.species}</span>
            {member.level != null && <span className="party-chip__level">Lv.{member.level}</span>}
          </li>
        ))}
      </ul>
    </StickerCard>
  );
}
