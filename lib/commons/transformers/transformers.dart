import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:rxdart/rxdart.dart';

// Re-export standard bloc_concurrency transformers (concurrent, sequential, restartable, droppable)
export 'package:bloc_concurrency/bloc_concurrency.dart';

/// Event transformer kết hợp [debounceTime] và [restartable].
///
/// Hoãn xử lý sự kiện cho đến khi không có sự kiện mới trong khoảng [duration],
/// đồng thời hủy tác vụ bất đồng bộ trước đó nếu có sự kiện mới vượt qua debounce.
/// Rất hữu ích cho các tác vụ tìm kiếm theo viewport, gõ phím, hoặc pan/zoom bản đồ.
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) {
    return restartable<E>()(events.debounceTime(duration), mapper);
  };
}

/// Event transformer kết hợp [debounceTime] và [droppable].
///
/// Bỏ qua các sự kiện mới nếu tác vụ hiện tại đang chạy sau khi debounce.
EventTransformer<E> debounceDroppable<E>(Duration duration) {
  return (events, mapper) {
    return droppable<E>()(events.debounceTime(duration), mapper);
  };
}

/// Event transformer kết hợp [debounceTime] và [sequential].
///
/// Xử lý tuần tự các sự kiện sau khi debounce.
EventTransformer<E> debounceSequential<E>(Duration duration) {
  return (events, mapper) {
    return sequential<E>()(events.debounceTime(duration), mapper);
  };
}

/// Event transformer [debounceTime] thuần túy.
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) {
    return events.debounceTime(duration).flatMap(mapper);
  };
}

/// Event transformer kết hợp [throttleTime] và [restartable].
///
/// Cho phép sự kiện đầu tiên kích hoạt ngay lập tức (leading: true) và chặn các sự kiện
/// tiếp theo trong khoảng [duration], đồng thời hủy tác vụ trước nếu có sự kiện mới.
/// Rất hữu ích cho luồng Reroute (tính lại đường khi chệch tuyến) hoặc GPS tracking.
EventTransformer<E> throttleRestartable<E>(
  Duration duration, {
  bool leading = true,
  bool trailing = false,
}) {
  return (events, mapper) {
    return restartable<E>()(
      events.throttleTime(duration, leading: leading, trailing: trailing),
      mapper,
    );
  };
}

/// Event transformer kết hợp [throttleTime] và [droppable].
///
/// Bỏ qua sự kiện tiếp theo trong khoảng [duration] hoặc khi tác vụ trước đang thực thi.
EventTransformer<E> throttleDroppable<E>(
  Duration duration, {
  bool leading = true,
  bool trailing = false,
}) {
  return (events, mapper) {
    return droppable<E>()(
      events.throttleTime(duration, leading: leading, trailing: trailing),
      mapper,
    );
  };
}

/// Event transformer kết hợp [throttleTime] và [sequential].
///
/// Xử lý tuần tự các sự kiện sau khi đã được throttle theo [duration].
EventTransformer<E> throttleSequential<E>(
  Duration duration, {
  bool leading = true,
  bool trailing = false,
}) {
  return (events, mapper) {
    return sequential<E>()(
      events.throttleTime(duration, leading: leading, trailing: trailing),
      mapper,
    );
  };
}

/// Event transformer [throttleTime] thuần túy.
EventTransformer<E> throttle<E>(
  Duration duration, {
  bool leading = true,
  bool trailing = false,
}) {
  return (events, mapper) {
    return events
        .throttleTime(duration, leading: leading, trailing: trailing)
        .flatMap(mapper);
  };
}

/// Event transformer lọc các sự kiện trùng lặp liên tiếp [distinct].
EventTransformer<E> distinctEvent<E>() {
  return (events, mapper) {
    return events.distinct().flatMap(mapper);
  };
}
