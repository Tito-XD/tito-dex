export type DexEntry = {
  id: number;
  name: string;
  type: string;
  caught: boolean;
  seen: boolean;
};

export const dexMockData: DexEntry[] = [
  { id: 155, name: 'Cyndaquil', type: 'Fire', caught: true, seen: true },
  { id: 156, name: 'Quilava', type: 'Fire', caught: true, seen: true },
  { id: 179, name: 'Mareep', type: 'Electric', caught: true, seen: true },
  { id: 180, name: 'Flaaffy', type: 'Electric', caught: true, seen: true },
  { id: 175, name: 'Togepi', type: 'Fairy', caught: true, seen: true },
  { id: 447, name: 'Riolu', type: 'Fighting', caught: true, seen: true },
  { id: 163, name: 'Hoothoot', type: 'Normal/Flying', caught: false, seen: true },
  { id: 39, name: 'Jigglypuff', type: 'Normal/Fairy', caught: false, seen: true },
  { id: 133, name: 'Eevee', type: 'Normal', caught: false, seen: false },
  { id: 25, name: 'Pikachu', type: 'Electric', caught: false, seen: true },
];
