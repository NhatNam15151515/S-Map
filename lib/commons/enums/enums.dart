enum AuthStateType {
  authenticated,
  unAuthenticated,
  initial,
  loading,
  onboarding,
}

enum NotificationType {
  system(1),
  general(2),
  ;

  final int id;

  const NotificationType(this.id);
}

