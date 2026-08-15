import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:rxdart/rxdart.dart';

// Re-export standard bloc_concurrency transformers
export 'package:bloc_concurrency/bloc_concurrency.dart';

/// Event transformer kết hợp debounce và restartable
/// Hữu ích cho các luồng gõ phím hoặc pan/zoom bản đồ liên tục
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) {
    return restartable<E>()(events.debounceTime(duration), mapper);
  };
}

/// Event transformer debounce thuần túy
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) {
    return events.debounceTime(duration).flatMap(mapper);
  };
}
