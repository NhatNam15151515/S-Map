---
name: bloc-pattern
description: |
  Quy tắc và pattern cho BLoC/Cubit state management trong dự án S-Map Flutter.
  Bao gồm GenericCubit, BaseChangeCubit, emit guard, và cấu trúc file chuẩn.
  Trigger khi: tạo cubit mới, refactor state management, fix emit-after-close,
  tạo feature screen mới cần state.
---

# BLoC/Cubit Pattern Skill — S-Map

## Nguyên tắc cốt lõi

1. **Cubit-only**: Dự án S-Map KHÔNG dùng Bloc event-based. Chỉ dùng Cubit.
2. **Pattern có sẵn**: Luôn tái sử dụng `GenericCubit<T>`, `GenericNonNullCubit<T>`, hoặc `BaseChangeCubit<T>`.
3. **Emit guard**: Mọi cubit custom PHẢI override `emit()` với guard `if(isClosed) return;`.

---

## Khi nào dùng pattern nào?

| Tình huống | Pattern | Ví dụ |
|-----------|---------|-------|
| Gọi API, trả về data nullable | `GenericCubit<T>` | Load profile, load list |
| Gọi API, data luôn non-null | `GenericNonNullCubit<T>` | Load config bắt buộc |
| State UI đơn giản (toggle, selection) | `BaseChangeCubit<T>` | Tab selection, filter toggle |
| State phức tạp, nhiều field | Custom Cubit với state riêng | `AuthCubit`, `AppCubit` |

---

## GenericCubit Pattern

### Tạo mới
```dart
// Trong widget initState() hoặc bloc provider
final myCubit = GenericCubit<MyModel>(() => myRepos.getData());
myCubit.getData(); // Trigger API call
```

### Lắng nghe trong widget
```dart
// Cách 1: BlocBuilder (trong build method)
myCubit.blocBuilder(
  builder: (context, state) {
    switch (state.type) {
      case GenericStateType.loading:
        return LoadingWidget();
      case GenericStateType.succeed:
        return DataWidget(data: state.value!);
      case GenericStateType.error:
        return ErrorWidget(error: state.errorMessage);
      default:
        return SizedBox();
    }
  },
);

// Cách 2: Listen trong initState (side effects)
myCubit.listenToState(
  onStateSuccess: (data) => showSnackBar('Thành công'),
  onStateError: (error) => showSnackBar(error?.statusMessage ?? ''),
  onStateLoading: () => showLoading(),
);
```

### State types
```dart
enum GenericStateType { initial, loading, succeed, error }
```

---

## BaseChangeCubit Pattern

### Dùng cho UI state đơn giản
```dart
// Tạo
final tabCubit = BaseChangeCubit<int>();

// Cập nhật
tabCubit.updateState(1);

// Đọc
tabCubit.state.value; // int?
```

---

## Custom Cubit (State phức tạp)

### Cấu trúc file
```
commons/cubits/<cubit_name>/
├── <cubit_name>.dart           # Cubit class
├── <cubit_name>_state.dart     # State class (EquatableMixin recommended)
└── <cubit_name>_helper.dart    # Extension helpers (optional)
```

### Template
```dart
// === <cubit_name>_state.dart ===
import 'package:equatable/equatable.dart';

enum MyStateType { initial, loading, loaded, error }

class MyState with EquatableMixin {
  final MyStateType type;
  final MyData? data;
  final String? errorMessage;

  const MyState({required this.type, this.data, this.errorMessage});

  MyState copyWith({MyStateType? type, MyData? data, String? errorMessage}) {
    return MyState(
      type: type ?? this.type,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [type, data, errorMessage];
}

// === <cubit_name>.dart ===
import 'package:flutter_bloc/flutter_bloc.dart';
import '<cubit_name>_state.dart';

class MyCubit extends Cubit<MyState> {
  final MyRepos _repos;

  MyCubit(this._repos) : super(const MyState(type: MyStateType.initial));

  Future<void> loadData() async {
    emit(state.copyWith(type: MyStateType.loading));
    try {
      final data = await _repos.getData();
      emit(state.copyWith(type: MyStateType.loaded, data: data));
    } on ErrorResponse catch (e) {
      emit(state.copyWith(type: MyStateType.error, errorMessage: e.statusMessage));
    }
  }

  @override
  void emit(MyState state) {
    if (isClosed) return; // ← BẮT BUỘC
    super.emit(state);
  }
}
```

---

## Cung cấp Cubit cho Widget Tree

### Global cubit (auth, app): Trong app.dart
```dart
MultiBlocProvider(
  providers: [
    BlocProvider.value(value: appCubit),
    BlocProvider.value(value: authCubit),
  ],
  child: ...
);
```

### Local cubit (feature-specific): Trong screen
```dart
class MyScreen extends StatefulWidget {
  static const String path = '/my-screen';

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late final GenericCubit<MyModel> _dataCubit;

  @override
  void initState() {
    super.initState();
    _dataCubit = GenericCubit<MyModel>(() => repos.getData());
    _dataCubit.getData();
  }

  @override
  void dispose() {
    _dataCubit.close(); // ← PHẢI close
    super.dispose();
  }
}
```

---

## Anti-patterns CẤM

| # | Sai | Đúng |
|---|-----|------|
| 1 | Gọi `getData()` trong constructor | Gọi trong `initState()` |
| 2 | Dùng `setState()` cho logic phức tạp | Dùng Cubit |
| 3 | Emit sau khi close | Override `emit()` với guard |
| 4 | Listen stream mà không cancel | Cancel trong `dispose()` |
| 5 | Dùng Bloc event-based | Chỉ dùng Cubit |
| 6 | Đặt cubit shared trong `screens/` | Đặt trong `commons/cubits/` |
| 7 | Tạo state class không EquatableMixin | Dùng EquatableMixin cho custom state |
