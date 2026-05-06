class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int bannedUsers;
  final int totalVideos;
  final int publishedVideos;
  final int removedVideos;
  final int totalComments;
  final int totalLikes;
  final int recentSignups;
  final List<RoleCount> topRoles;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.bannedUsers,
    required this.totalVideos,
    required this.publishedVideos,
    required this.removedVideos,
    required this.totalComments,
    required this.totalLikes,
    required this.recentSignups,
    required this.topRoles,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['total_users'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      bannedUsers: json['banned_users'] ?? 0,
      totalVideos: json['total_videos'] ?? 0,
      publishedVideos: json['published_videos'] ?? 0,
      removedVideos: json['removed_videos'] ?? 0,
      totalComments: json['total_comments'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
      recentSignups: json['recent_signups'] ?? 0,
      topRoles: (json['top_roles'] as List<dynamic>?)
              ?.map((e) => RoleCount.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class RoleCount {
  final String roleCode;
  final String roleName;
  final int count;

  RoleCount({
    required this.roleCode,
    required this.roleName,
    required this.count,
  });

  factory RoleCount.fromJson(Map<String, dynamic> json) {
    return RoleCount(
      roleCode: json['role_code'] ?? '',
      roleName: json['role_name'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class AdminUser {
  final int id;
  final String email;
  final String name;
  final String lastName;
  final String? avatarUrl;
  final String roleCode;
  final String roleName;
  final int accessLevel;
  final String statusCode;
  final String statusName;
  final String createdAt;
  final String? lastLogin;
  final int videosCount;
  final int commentsCount;

  AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.lastName,
    this.avatarUrl,
    required this.roleCode,
    required this.roleName,
    required this.accessLevel,
    required this.statusCode,
    required this.statusName,
    required this.createdAt,
    this.lastLogin,
    required this.videosCount,
    required this.commentsCount,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatarUrl: json['avatar_url'],
      roleCode: json['role_code'] ?? '',
      roleName: json['role_name'] ?? '',
      accessLevel: json['access_level'] ?? 0,
      statusCode: json['status_code'] ?? '',
      statusName: json['status_name'] ?? '',
      createdAt: json['created_at'] ?? '',
      lastLogin: json['last_login'],
      videosCount: json['videos_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
    );
  }
}

class AdminVideo {
  final int id;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int authorId;
  final String authorName;
  final String authorEmail;
  final String statusCode;
  final String statusName;
  final int likesCount;
  final int commentsCount;
  final String createdAt;

  AdminVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.authorId,
    required this.authorName,
    required this.authorEmail,
    required this.statusCode,
    required this.statusName,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
  });

  factory AdminVideo.fromJson(Map<String, dynamic> json) {
    return AdminVideo(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['video_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      authorId: json['author_id'] ?? 0,
      authorName: json['author_name'] ?? '',
      authorEmail: json['author_email'] ?? '',
      statusCode: json['status_code'] ?? '',
      statusName: json['status_name'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class AdminReport {
  final int reportId;
  final int commentId;
  final String motivo;
  final String estado;
  final DateTime fechaCreacion;
  final String commentText;
  final String authorName;
  final String reporterName;

  AdminReport({
    required this.reportId,
    required this.commentId,
    required this.motivo,
    required this.estado,
    required this.fechaCreacion,
    required this.commentText,
    required this.authorName,
    required this.reporterName,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    return AdminReport(
      reportId: json['report_id'] ?? 0,
      commentId: json['comment_id'] ?? 0,
      motivo: json['motivo'] ?? '',
      estado: json['estado'] ?? '',
      fechaCreacion: json['fecha_creacion'] != null ? DateTime.parse(json['fecha_creacion']) : DateTime.now(),
      commentText: json['comment_text'] ?? '',
      authorName: json['author_name'] ?? '',
      reporterName: json['reporter_name'] ?? '',
    );
  }
}

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    var pagination = json['pagination'] ?? {};
    var dataList = json['data'] as List<dynamic>? ?? [];
    return PaginatedResponse<T>(
      data: dataList.map((item) => fromJsonT(item as Map<String, dynamic>)).toList(),
      total: pagination['total'] ?? 0,
      page: pagination['page'] ?? 1,
      pageSize: pagination['page_size'] ?? 20,
      totalPages: pagination['total_pages'] ?? 1,
    );
  }
}
