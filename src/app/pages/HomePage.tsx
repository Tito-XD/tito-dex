import { useJourney } from '../../features/journey/JourneyProvider';
import { ScreenLayout } from '../../components/layout/ScreenLayout';
import { CompanionSticker } from '../../components/CompanionSticker';
import { ContinueJourneyCard } from '../../components/ContinueJourneyCard';
import { JourneyTimeline } from '../../components/JourneyTimeline';
import { PartySummary } from '../../components/PartySummary';
import { QuickWidget } from '../../components/QuickWidget';
import { TrainerCard } from '../../components/TrainerCard';
import { LauncherWidgets } from '../../components/LauncherWidgets';
import { DexIcon, JourneyIcon, SearchIcon, TeamIcon } from '../../components/icons/Icons';

export function HomePage() {
  const journey = useJourney();

  return (
    <ScreenLayout>
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
          <QuickWidget to="/team" label="Team" icon={<TeamIcon width={28} height={28} />} />
          <QuickWidget to="/journey" label="Journey" icon={<JourneyIcon width={28} height={28} />} />
          <QuickWidget to="/dex" label="Dex" icon={<DexIcon width={28} height={28} />} />
          <QuickWidget to="/search" label="Search" icon={<SearchIcon width={28} height={28} />} />
        </div>
        <div className="home-grid__widgets-row">
          <LauncherWidgets />
        </div>
      </div>
    </ScreenLayout>
  );
}
