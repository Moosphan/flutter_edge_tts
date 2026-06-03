class EdgeTtsProsody {
  const EdgeTtsProsody({
    this.rate = '1.0',
    this.pitch = '+0Hz',
    this.volume = '100',
  });

  final String rate;
  final String pitch;
  final String volume;

  EdgeTtsProsody copyWith({String? rate, String? pitch, String? volume}) {
    return EdgeTtsProsody(
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
    );
  }
}
