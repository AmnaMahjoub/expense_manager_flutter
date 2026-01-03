class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  // Convertir depuis Firestore
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Créer depuis Firebase Auth User
  factory AppUser.fromFirebaseUser(
    String uid, 
    String email, {
    String? displayName,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
  }

  // Copier avec modifications
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}