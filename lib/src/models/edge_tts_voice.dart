class EdgeTtsVoice {
  const EdgeTtsVoice({
    required this.name,
    required this.shortName,
    required this.gender,
    required this.locale,
    required this.suggestedCodec,
    required this.friendlyName,
    required this.status,
  });

  factory EdgeTtsVoice.fromJson(Map<String, dynamic> json) {
    return EdgeTtsVoice(
      name: json['Name'] as String? ?? '',
      shortName: json['ShortName'] as String? ?? '',
      gender: json['Gender'] as String? ?? '',
      locale: json['Locale'] as String? ?? '',
      suggestedCodec: json['SuggestedCodec'] as String? ?? '',
      friendlyName: json['FriendlyName'] as String? ?? '',
      status: json['Status'] as String? ?? '',
    );
  }

  final String name;
  final String shortName;
  final String gender;
  final String locale;
  final String suggestedCodec;
  final String friendlyName;
  final String status;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'Name': name,
      'ShortName': shortName,
      'Gender': gender,
      'Locale': locale,
      'SuggestedCodec': suggestedCodec,
      'FriendlyName': friendlyName,
      'Status': status,
    };
  }
}
