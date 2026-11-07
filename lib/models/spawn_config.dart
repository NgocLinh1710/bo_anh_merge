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
    'collection_1': SpawnConfig(),
    'collection_2': SpawnConfig(lowWeight: 0.60, middleWeight: 0.30),
    'collection_3': SpawnConfig(lowWeight: 0.55, middleWeight: 0.30),
    'collection_4': SpawnConfig(lowWeight: 0.55, middleWeight: 0.30),
    'collection_5': SpawnConfig(closerSpawnChance: 0.60),
    'collection_6': SpawnConfig(
      closerSpawnChance: 1,
      lowWeight: 0.45,
      middleWeight: 0.35,
    ),
  };
}
