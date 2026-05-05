class PublicProfileModel {
  final String id;
  final String username;
  final String avatarUrl;
  final String role;
  final String? bio;
  final String? faculty;
  final String? cvlacUrl;
  final String? websiteUrl;
  final int followers;
  final int totalLikes;
  final int totalViews;
  final int totalVideos;
  final bool isFollowing;

  const PublicProfileModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.role,
    this.bio,
    this.faculty,
    this.cvlacUrl,
    this.websiteUrl,
    this.followers = 0,
    this.totalLikes = 0,
    this.totalViews = 0,
    this.totalVideos = 0,
    this.isFollowing = false,
  });

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    return PublicProfileModel(
      id: (json['user_id'] ?? json['id'] ?? '').toString(),
      username: json['username'] ?? 'Sin nombre',
      avatarUrl: json['avatar_url'] ?? '',
      role: json['role'] ?? 'estudiante',
      bio: json['bio'],
      faculty: json['faculty'],
      cvlacUrl: json['cvlac_url'],
      websiteUrl: json['website_url'],
      followers: json['followers'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      totalVideos: json['total_videos'] ?? 0,
      isFollowing: json['is_following'] ?? false,
    );
  }

  PublicProfileModel copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? role,
    String? bio,
    String? faculty,
    String? cvlacUrl,
    String? websiteUrl,
    int? followers,
    int? totalLikes,
    int? totalViews,
    int? totalVideos,
    bool? isFollowing,
  }) {
    return PublicProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      faculty: faculty ?? this.faculty,
      cvlacUrl: cvlacUrl ?? this.cvlacUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      followers: followers ?? this.followers,
      totalLikes: totalLikes ?? this.totalLikes,
      totalViews: totalViews ?? this.totalViews,
      totalVideos: totalVideos ?? this.totalVideos,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
