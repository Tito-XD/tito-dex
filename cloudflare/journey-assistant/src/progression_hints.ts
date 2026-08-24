import data from '../../../data/journey/progression_hints.json';

export type Requirement = {
  type: 'badge' | 'key_item' | 'milestone';
  id: string;
  labelZh: string;
  reliability: 'save_verified' | 'not_currently_parsed';
};

export type ProgressionHint = {
  id: string;
  games: string[];
  generation: number;
  locations: string[];
  locationAliases: string[];
  destinationAliases: string[];
  subject: {
    type: 'overworld_blocker' | 'story_blocker' | 'reference_topic';
    id: string;
    aliases: string[];
  };
  requirements: Requirement[];
  steps: { instructionZh: string }[];
  overviewZh: string;
  sources: { title: string; url: string; accessedAt: string }[];
};

export const progressionHints = data.entries as ProgressionHint[];
