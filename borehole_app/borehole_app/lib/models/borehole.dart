class Borehole {
  final int? id;
  final int siteId;
  final String name;
  final String xyPosition;
  final double mAOD;

  Borehole({
    this.id,
    required this.siteId,
    required this.name,
    required this.xyPosition,
    required this.mAOD,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteId': siteId,
      'boreholeName': name,
      'xyPosition': xyPosition,
      'mAOD': mAOD,
    };
  }

  factory Borehole.fromMap(Map<String, dynamic> map) {
    return Borehole(
      id: map['id'],
      siteId: map['siteId'],
      name: map['boreholeName'],
      xyPosition: map['xyPosition'],
      mAOD: map['mAOD'],
    );
  }
}
