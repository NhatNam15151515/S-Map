import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/models/models.dart';
import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  final AuthStateType type;

  const AuthState(this.type);

  bool get isAuthenticated => type == AuthStateType.authenticated;

  @override
  List<Object?> get props => [type];
}

class Authenticated extends AuthState {
  final User loggedInProfile;
  const Authenticated(this.loggedInProfile) : super(AuthStateType.authenticated);

  @override
  List<Object?> get props => [type, loggedInProfile.username, loggedInProfile.id];
}

class UnAuthenticated extends AuthState {
  const UnAuthenticated() : super(AuthStateType.unAuthenticated);
}

class InitialAuth extends AuthState {
  const InitialAuth() : super(AuthStateType.initial);
}

class LoadingAuth extends AuthState {
  final bool isDone;
  const LoadingAuth({this.isDone = false}) : super(AuthStateType.loading);

  @override
  List<Object?> get props => [type, isDone];
}

