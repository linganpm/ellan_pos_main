# Cubit Integration Guide

This package is a pure Dart package. Keep `flutter_bloc` and widget-layer state in the UI application, and keep this package focused on the `Store` API.

Recommended layering in the UI app:

- `Store` owns persistence, auth, products, orders, customers, and sync.
- `Cubit` owns screen state and calls `Store` methods.
- Widgets only talk to the `Cubit`.

## Add UI Dependency

In the Flutter UI app, add:

```yaml
dependencies:
  flutter_bloc: ^9.0.0
  pos_orders_offline:
    path: ../pos-dart-packages
```

## Auth Cubit Example

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/pos_orders_offline.dart';

class AuthState {
  final bool loading;
  final bool loggedIn;
  final String? error;
  final StoreSession? session;

  const AuthState({
    this.loading = false,
    this.loggedIn = false,
    this.error,
    this.session,
  });

  AuthState copyWith({
    bool? loading,
    bool? loggedIn,
    String? error,
    StoreSession? session,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      loggedIn: loggedIn ?? this.loggedIn,
      error: error,
      session: session ?? this.session,
    );
  }
}

class AuthCubit extends Cubit<AuthState> {
  final Store store;

  AuthCubit(this.store) : super(const AuthState());

  Future<void> restoreSession() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final session = await store.auth.currentSession();
      emit(
        state.copyWith(
          loading: false,
          loggedIn: session != null,
          session: session,
        ),
      );
    } on StoreSessionExpiredException catch (error) {
      emit(state.copyWith(loading: false, loggedIn: false, error: error.toString()));
    } on StoreAuthException catch (error) {
      emit(state.copyWith(loading: false, loggedIn: false, error: error.toString()));
    }
  }

  Future<void> login(String email, String password) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final session = await store.auth.login(
        StoreLoginRequest(email: email, password: password),
      );
      if (session == null) {
        emit(state.copyWith(loading: false, loggedIn: false, error: 'Invalid credentials'));
        return;
      }
      emit(state.copyWith(loading: false, loggedIn: true, session: session));
    } on StoreAuthException catch (error) {
      emit(state.copyWith(loading: false, loggedIn: false, error: error.toString()));
    }
  }

  Future<void> logout() async {
    await store.auth.logout();
    emit(const AuthState());
  }
}
```

## Orders Cubit Example

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/pos_orders_offline.dart';

class OrdersState {
  final bool loading;
  final List<StoreOrderSummary> orders;
  final String? error;

  const OrdersState({
    this.loading = false,
    this.orders = const [],
    this.error,
  });

  OrdersState copyWith({
    bool? loading,
    List<StoreOrderSummary>? orders,
    String? error,
  }) {
    return OrdersState(
      loading: loading ?? this.loading,
      orders: orders ?? this.orders,
      error: error,
    );
  }
}

class OrdersCubit extends Cubit<OrdersState> {
  final Store store;

  OrdersCubit(this.store) : super(const OrdersState());

  Future<void> loadOrders() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final orders = await store.orders.listSummaries(store.scope);
      emit(state.copyWith(loading: false, orders: orders));
    } on StoreSessionExpiredException catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    } on StoreAuthException catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }

  Future<void> createOrder() async {
    try {
      await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          restaurantName: store.storeName,
          customerName: 'Walk-in Customer',
          mobile: '+1000000000',
          statusName: 'Pending',
          total: 65,
          serviceInstance: store.serviceInstanceId,
          createdBy: 'orders-cubit',
          createdOn: DateTime.now().toIso8601String(),
          paymentStatus: 'Unpaid',
          orderType: 'Takeaway',
        ),
      );
      await loadOrders();
    } on StoreAuthorizationException catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }
}
```

## Products Cubit Example

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/pos_orders_offline.dart';

class ProductsState {
  final bool loading;
  final List<String> productNames;
  final String? error;

  const ProductsState({
    this.loading = false,
    this.productNames = const [],
    this.error,
  });

  ProductsState copyWith({
    bool? loading,
    List<String>? productNames,
    String? error,
  }) {
    return ProductsState(
      loading: loading ?? this.loading,
      productNames: productNames ?? this.productNames,
      error: error,
    );
  }
}

class ProductsCubit extends Cubit<ProductsState> {
  final Store store;

  ProductsCubit(this.store) : super(const ProductsState());

  Future<void> loadProducts() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final names = await store.products.listNames(store.scope);
      emit(state.copyWith(loading: false, productNames: names));
    } on StoreAuthException catch (error) {
      emit(state.copyWith(loading: false, error: error.toString()));
    }
  }
}
```

## Sync Cubit Example

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/pos_orders_offline.dart';

class SyncState {
  final bool running;
  final List<StoreSyncAttemptRecord> history;
  final Map<String, StoreSyncProgressUpdate> progressByTable;
  final String? error;

  const SyncState({
    this.running = false,
    this.history = const [],
    this.progressByTable = const {},
    this.error,
  });

  SyncState copyWith({
    bool? running,
    List<StoreSyncAttemptRecord>? history,
    Map<String, StoreSyncProgressUpdate>? progressByTable,
    String? error,
  }) {
    return SyncState(
      running: running ?? this.running,
      history: history ?? this.history,
      progressByTable: progressByTable ?? this.progressByTable,
      error: error,
    );
  }
}

class SyncCubit extends Cubit<SyncState> {
  final Store store;

  SyncCubit(this.store) : super(const SyncState());

  Future<void> runNow() async {
    emit(state.copyWith(running: true, error: null, progressByTable: const {}));
    try {
      await store.sync.runAll(
        store.scope,
        exportBatchSize: 500,
        onProgress: (update) {
          final progress = Map<String, StoreSyncProgressUpdate>.from(state.progressByTable);
          progress['${update.entity}:${update.direction}'] = update;
          emit(state.copyWith(running: true, progressByTable: progress, error: null));
        },
      );
      final history = await store.sync.history(store.scope, limit: 20);
      emit(state.copyWith(running: false, history: history, error: null));
    } catch (error) {
      emit(state.copyWith(running: false, error: error.toString()));
    }
  }
}
```

This gives the widget layer enough information to render one progress row per table, for example `orders:export`, `products:import`, or `credits:export`.

## App Bootstrap Example

```dart
final config = await StoreConfig.loadForEnvironment(StoreEnvironment.development);
final metadata = config.defaultStore;

final store = await Store.createAndInit(
  orgId: metadata.orgId,
  orgName: metadata.orgName,
  orgCode: metadata.orgCode,
  storeId: metadata.storeId,
  serviceInstanceId: metadata.serviceInstanceId,
  storeName: metadata.storeName,
  logo: metadata.logo,
  uniqueId: metadata.uniqueId,
  contactEmail: metadata.contactEmail,
  phone: metadata.phone,
  contactPerson: metadata.contactPerson,
  status: metadata.status,
  serviceVariantType: metadata.serviceVariantType,
  orderJson: config.assetPaths.orders,
  productJson: config.assetPaths.products,
  customerJson: config.assetPaths.customers,
  config: config,
);

final authCubit = AuthCubit(store);
final ordersCubit = OrdersCubit(store);
final productsCubit = ProductsCubit(store);
final syncCubit = SyncCubit(store);
```

## Widget Usage Sketch

```dart
BlocBuilder<AuthCubit, AuthState>(
  builder: (context, state) {
    if (state.loading) {
      return const CircularProgressIndicator();
    }
    if (!state.loggedIn) {
      return LoginForm(
        onSubmit: (email, password) {
          context.read<AuthCubit>().login(email, password);
        },
      );
    }
    return OrdersScreen();
  },
)
```

## Recommended Split

- `AuthCubit`: login, logout, restore session, current customer.
- `OrdersCubit`: order list, order details, create/update order.
- `ProductsCubit`: categories, product names, product variants.
- `CustomersCubit`: customer search and pagination.
- `SyncCubit`: manual sync, auto-sync toggle, sync history.

The important rule is still the same: keep all data access behind a single `Store` instance and do not bypass it from the UI layer.