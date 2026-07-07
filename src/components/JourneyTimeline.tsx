import type { JourneyTimelineEntry } from '../features/journey/journeyTypes';
import { StickerCard } from './StickerCard';

type JourneyTimelineProps = {
  entries: JourneyTimelineEntry[];
  nextReminder?: string;
};

export function JourneyTimeline({ entries, nextReminder }: JourneyTimelineProps) {
  return (
    <StickerCard className="journey-timeline">
      <h3 className="journey-timeline__title">Recent Journey</h3>
      <ol className="journey-timeline__list">
        {entries.map((entry) => (
          <li key={entry.id} className="journey-timeline__item">
            <span className="journey-timeline__dot" aria-hidden="true" />
            <div>
              <p className="journey-timeline__text">{entry.text}</p>
              {entry.at && <span className="journey-timeline__when">{entry.at}</span>}
            </div>
          </li>
        ))}
      </ol>
      {nextReminder && (
        <p className="journey-timeline__reminder">
          <span aria-hidden="true">★</span> Next: {nextReminder}
        </p>
      )}
    </StickerCard>
  );
}
