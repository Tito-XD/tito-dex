export type ParsedSaveSummary = {
  game: 'SoulSilver' | 'HeartGold';
  trainerName?: string;
  playTime?: string;
  badges?: number;
  location?: string;
  party?: Array<{
    species: string;
    level?: number;
  }>;
  saveHash: string;
  parsedAt: string;
};
