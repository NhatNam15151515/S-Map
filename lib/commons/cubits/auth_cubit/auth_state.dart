import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/models/user.dart';
import 'package:equatable/equatable.dart';

abstract class AuthState {
  final AuthStateType type;

  AuthState(this.type);

  bool get isAuthenticated => type == AuthStateType.authenticated;
}

// ignore: deprecated_member_use
class Authenticated extends AuthState with EquatableMixin {
  final User loggedInProfile;
  Authenticated(this.loggedInProfile) : super(AuthStateType.authenticated);

  @override
  List<Object?> get props => [loggedInProfile.username];
}

class UnAuthenticated extends AuthState {
  UnAuthenticated() : super(AuthStateType.unAuthenticated);
}

class InitialAuth extends AuthState {
  InitialAuth() : super(AuthStateType.initial);
}
class LoadingAuth extends AuthState {
  final bool isDone;
  LoadingAuth({this.isDone=false}) : super(AuthStateType.loading);
}
