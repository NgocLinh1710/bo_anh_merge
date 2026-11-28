/// Free-play tuning. Timed games do not use these settings.
class SpawnConfig {
  final double supportChance;
  final double closerSpawnChance;
  final double lowWeight;
  final double middleWeight;

  const SpawnConfig({
    this.supportChance = 0.35,
    this.closerSpawnChance = 0,
    this.lowWeight = 0.50,
    this.middleWeight = 0.35,
  });

  static const collections = <String, SpawnConfig>{
    'collection_1': SpawnConfig(lowWeight: 0.65, middleWeight: 0.30),
    'collection_2': SpawnConfig(
      supportChance: 0.32,
      lowWeight: 0.70,
      middleWeight: 0.25,
    ),
    'collection_3': SpawnConfig(
      supportChance: 0.30,
      lowWeight: 0.70,
      middleWeight: 0.25,
    ),
    'collection_4': SpawnConfig(
      supportChance: 0.28,
      lowWeight: 0.70,
      middleWeight: 0.25,
    ),
    'collection_5': SpawnConfig(
      supportChance: 0.25,
      closerSpawnChance: 0.20,
      lowWeight: 0.65,
      middleWeight: 0.30,
    ),
    'collection_6': SpawnConfig(
      supportChance: 0.22,
      closerSpawnChance: 0.45,
      lowWeight: 0.60,
      middleWeight: 0.30,
    ),
    'collection_7': SpawnConfig(),
    'collection_8': SpawnConfig(),
  };
}
