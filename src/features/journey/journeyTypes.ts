export type GameId = 'SoulSilver' | 'HeartGold';

export type PartyMember = {
  species: string;
  level?: number;
  nickname?: string;
};

export type JourneyTimelineEntry = {
  id: string;
  text: string;
  at?: string;
};

export type CurrentJourney = {
  game: GameId;
  trainerName: string;
  location: string;
  badges: number;
  maxBadges: number;
  playTime: string;
  party: PartyMember[];
  timeline: JourneyTimelineEntry[];
  companion: string;
  nextReminder?: string;
};
