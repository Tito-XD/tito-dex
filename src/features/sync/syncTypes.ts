export type SyncMetadata = {
  game: string;
  playTime?: string;
  badges?: number;
  location?: string;
  saveHash: string;
  updatedAt: string;
};

export type SyncStatus = 'idle' | 'syncing' | 'error' | 'synced';
