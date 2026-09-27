import 'dart:async';

class SearchDebouncer {
  Timer? _timer;
  String _lastQuery = '';

  void onQueryChanged(String query, void Function(String query) callback) {
    _lastQuery = query;
    _timer?.cancel();
    callback(query);
    if (query.trim().length <= 1) return;

    final delay = query.trim().length <= 3
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 300);
    _timer = Timer(delay, () {
      if (_lastQuery == query) callback(query);
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
