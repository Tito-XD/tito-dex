class DexEntry {
  const DexEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.caught,
    required this.seen,
  });

  final int id;
  final String name;
  final String type;
  final bool caught;
  final bool seen;
}

const dexMockData = <DexEntry>[
  DexEntry(id: 155, name: 'Cyndaquil', type: 'Fire', caught: true, seen: true),
  DexEntry(id: 156, name: 'Quilava', type: 'Fire', caught: true, seen: true),
  DexEntry(id: 179, name: 'Mareep', type: 'Electric', caught: true, seen: true),
  DexEntry(id: 180, name: 'Flaaffy', type: 'Electric', caught: true, seen: true),
  DexEntry(id: 175, name: 'Togepi', type: 'Fairy', caught: true, seen: true),
  DexEntry(id: 447, name: 'Riolu', type: 'Fighting', caught: true, seen: true),
  DexEntry(id: 163, name: 'Hoothoot', type: 'Normal/Flying', caught: false, seen: true),
  DexEntry(id: 39, name: 'Jigglypuff', type: 'Normal/Fairy', caught: false, seen: true),
  DexEntry(id: 133, name: 'Eevee', type: 'Normal', caught: false, seen: false),
  DexEntry(id: 25, name: 'Pikachu', type: 'Electric', caught: false, seen: true),
];
