class UserModel {
  final String userId;
  final String name;
  final String userCode;
  final String position;
  final String? profileImage;
  final bool isOnline;
  final int height;
  final int weight;
  final int age;
  final String preferredFoot;
  final int matches;
  final int goals;
  final int assists;
  final int wins;
  final List<Map<String, dynamic>> availabilities;
  final double? distance;
  final double rating;
  final int ratingCount;
  final String? availabilityStartTime;
  final String? availabilityEndTime;
  final Map<String, dynamic>? availabilityLocation;

  UserModel({
    required this.userId,
    required this.name,
    required this.userCode,
    required this.position,
    this.profileImage,
    this.isOnline = false,
    this.height = 0,
    this.weight = 0,
    this.age = 0,
    this.preferredFoot = '',
    this.matches = 0,
    this.goals = 0,
    this.assists = 0,
    this.wins = 0,
    this.availabilities = const [],
    this.distance,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.availabilityStartTime,
    this.availabilityEndTime,
    this.availabilityLocation,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'userCode': userCode,
      'position': position,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'height': height,
      'weight': weight,
      'age': age,
      'preferredFoot': preferredFoot,
      'matches': matches,
      'goals': goals,
      'assists': assists,
      'wins': wins,
      'availabilities': availabilities,
      'distance': distance,
      'rating': rating,
      'ratingCount': ratingCount,
      'availabilityStartTime': availabilityStartTime,
      'availabilityEndTime': availabilityEndTime,
      'availabilityLocation': availabilityLocation,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      userCode: map['userCode'] ?? '',
      position: map['position'] ?? '',
      profileImage: map['profileImage'],
      isOnline: map['isOnline'] ?? false,
      height: int.tryParse(map['height']?.toString() ?? '0') ?? 0,
      weight: int.tryParse(map['weight']?.toString() ?? '0') ?? 0,
      age: int.tryParse(map['age']?.toString() ?? '0') ?? 0,
      preferredFoot: map['preferredFoot'] ?? '',
      matches: int.tryParse(map['matches']?.toString() ?? '0') ?? 0,
      goals: int.tryParse(map['goals']?.toString() ?? '0') ?? 0,
      assists: int.tryParse(map['assists']?.toString() ?? '0') ?? 0,
      wins: int.tryParse(map['wins']?.toString() ?? '0') ?? 0,
      availabilities:
          List<Map<String, dynamic>>.from(map['availabilities'] ?? []),
      distance: map['distance']?.toDouble(),
      rating: (map['rating'] ?? 0.0).toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
      availabilityStartTime: map['availabilityStartTime'],
      availabilityEndTime: map['availabilityEndTime'],
      availabilityLocation: map['availabilityLocation'],
    );
  }
}
