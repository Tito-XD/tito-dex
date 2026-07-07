import type { CurrentJourney } from '../features/journey/journeyTypes';

export const mockJourney: CurrentJourney = {
  game: 'SoulSilver',
  trainerName: 'Tito',
  location: 'Goldenrod City',
  badges: 3,
  maxBadges: 8,
  playTime: '18:42',
  companion: 'Riolu',
  nextReminder: 'Visit the Radio Tower when ready',
  party: [
    { species: 'Quilava', level: 24, nickname: 'Quilava' },
    { species: 'Riolu', level: 18, nickname: 'Riolu' },
    { species: 'Flaaffy', level: 21 },
    { species: 'Togepi', level: 15 },
  ],
  timeline: [
    { id: 't1', text: 'Reached Goldenrod City', at: 'Day 4' },
    { id: 't2', text: 'Won Hive Badge', at: 'Day 3' },
    { id: 't3', text: 'Added Riolu as companion', at: 'Day 2' },
  ],
};
