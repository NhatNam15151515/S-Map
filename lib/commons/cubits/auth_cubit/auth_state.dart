import 'package:equatable/equatable.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/models/models.dart';

class AuthState extends Equatable {
  final AuthStateType type;
  final User? loggedInProfile;
  final bool isDone;
  final String? errorMessage;

  const AuthState({
    this.type = AuthStateType.initial,
    this.loggedInProfile,
    this.isDone = false,
    this.errorMessage,
  });

  bool get isAuthenticated => type == AuthStateType.authenticated;
  bool get isUnAuthenticated => type == AuthStateType.unAuthenticated;
  bool get isInitial => type == AuthStateType.initial;
  bool get isOnboarding => type == AuthStateType.onboarding;
  bool get isLoading => type == AuthStateType.loading;
  bool get isError => errorMessage != null;

  AuthState copyWith({
    AuthStateType? type,
    User? loggedInProfile,
    bool? isDone,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      type: type ?? this.type,
      loggedInProfile: loggedInProfile ?? this.loggedInProfile,
      isDone: isDone ?? this.isDone,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [type, loggedInProfile, isDone, errorMessage];
}

