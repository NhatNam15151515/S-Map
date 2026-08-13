enum ViewMode { standard, detail, goToFullScreen }

enum VideoSourceType { fileData, url }

enum AuthStateType {
  authenticated,
  unAuthenticated,
  initial,
  loading,
}

enum NotificationType {
  system(1),
  general(2),
  ;

  final int id;

  const NotificationType(this.id);
}

enum UserAddressType {
  init(0),
  defaultAddress(1);

  final int id;

  const UserAddressType(this.id);
}

enum UserRoleType {
  superAdmin(1),
  admin(2),
  user(3);

  final int id;

  const UserRoleType(this.id);
}
