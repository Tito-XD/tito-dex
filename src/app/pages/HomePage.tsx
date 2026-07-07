import { AppHeader } from '../../components/AppHeader';
import { CompanionSticker } from '../../components/CompanionSticker';
import { ContinueJourneyCard } from '../../components/ContinueJourneyCard';
import { JourneyTimeline } from '../../components/JourneyTimeline';
import { PartySummary } from '../../components/PartySummary';
import { QuickWidget } from '../../components/QuickWidget';
import { TrainerCard } from '../../components/TrainerCard';
import { getCurrentJourney } from '../../features/journey/journeyStore';

export function HomePage() {
  const journey = getCurrentJourney();

  return (
    <div className="screen-page">
      <AppHeader />
      <div className="home-grid">
        <div className="home-grid__primary">
          <TrainerCard journey={journey} />
          <ContinueJourneyCard journey={journey} />
        </div>
        <div className="home-grid__secondary">
          <PartySummary party={journey.party} />
          <JourneyTimeline entries={journey.timeline} nextReminder={journey.nextReminder} />
          <CompanionSticker name={journey.companion} message="Goldenrod looks lively today!" />
        </div>
        <div className="home-grid__dashboard-row quick-widgets">
          <QuickWidget to="/team" label="Team" icon="⚔" />
          <QuickWidget to="/journey" label="Journey" icon="📖" />
          <QuickWidget to="/dex" label="Dex" icon="◉" />
          <QuickWidget to="/search" label="Search" icon="🔍" />
        </div>
      </div>
    </div>
  );
}
