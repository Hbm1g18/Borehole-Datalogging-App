class Site {
  final int? id;
  final String name;
  final String location;
  final bool isPostgres; 

  Site({
    this.id,
    required this.name,
    required this.location,
    this.isPostgres = false,  
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'isPostgres': isPostgres ? 1 : 0, 
    };
  }

  factory Site.fromMap(Map<String, dynamic> map) {
    return Site(
      id: map['id'],
      name: map['name'],
      location: map['location'],
      isPostgres: map['isPostgres'] == 1,
    );
  }
}
