class EdgeTtsMetadata {
  const EdgeTtsMetadata({required this.items});

  factory EdgeTtsMetadata.fromJson(Map<String, dynamic> json) {
    final items = (json['Metadata'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(EdgeTtsMetadataItem.fromJson)
        .toList(growable: false);
    return EdgeTtsMetadata(items: items);
  }

  final List<EdgeTtsMetadataItem> items;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'Metadata': items.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class EdgeTtsMetadataItem {
  const EdgeTtsMetadataItem({required this.type, required this.data});

  factory EdgeTtsMetadataItem.fromJson(Map<String, dynamic> json) {
    return EdgeTtsMetadataItem(
      type: json['Type'] as String? ?? '',
      data: EdgeTtsMetadataData.fromJson(
        json['Data'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }

  final String type;
  final EdgeTtsMetadataData data;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'Type': type, 'Data': data.toJson()};
  }
}

class EdgeTtsMetadataData {
  const EdgeTtsMetadataData({
    required this.offset,
    required this.duration,
    this.text,
    required this.raw,
  });

  factory EdgeTtsMetadataData.fromJson(Map<String, dynamic> json) {
    return EdgeTtsMetadataData(
      offset: _asInt(json['Offset']),
      duration: _asInt(json['Duration']),
      text: json['text'] is Map<String, dynamic>
          ? EdgeTtsMetadataText.fromJson(json['text'] as Map<String, dynamic>)
          : null,
      raw: Map<String, dynamic>.from(json),
    );
  }

  final int offset;
  final int duration;
  final EdgeTtsMetadataText? text;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

class EdgeTtsMetadataText {
  const EdgeTtsMetadataText({
    required this.text,
    required this.length,
    this.boundaryType,
  });

  factory EdgeTtsMetadataText.fromJson(Map<String, dynamic> json) {
    return EdgeTtsMetadataText(
      text: json['Text'] as String? ?? '',
      length: _asInt(json['Length']),
      boundaryType: json['BoundaryType'] as String?,
    );
  }

  final String text;
  final int length;
  final String? boundaryType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'Text': text,
      'Length': length,
      if (boundaryType != null) 'BoundaryType': boundaryType,
    };
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
