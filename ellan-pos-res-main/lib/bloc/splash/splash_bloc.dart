import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_orders_offline/store.dart';
import 'package:pos_orders_offline/store_config.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'splash_event.dart';
import 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc() : super(SplashInitial()) {
    on<SplashStarted>(_onSplashStarted);
  }

  static const String developmentAssetPath =
      'config/store_config.dev.json';
  static const String testAssetPath = 'config/store_config.test.json';
  static const String productionAssetPath =
      'config/store_config.production.json';
  static const String defaultAssetPath = developmentAssetPath;

  StoreConfig? _config;
  // ignore: unused_field
  StoreOrganisation? _organisation;
  // ignore: unused_field
  StoreOrganisationLoginResult? _organisationLogin;
  // ignore: unused_field
  StoreOrganisationBootstrapSyncResult? _bootstrap;
  // ignore: unused_field
  StoreDeviceRegistrationRequest? _deviceRegistration;
  // ignore: unused_field
  Store? _store;

  Future<void> _onSplashStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    emit(SplashLoading());
    if(_config == null){
      print("Config Initialized as fail");
    }else{
      print("Config Initialized as success");
    }

    // Retrieve user login status
    final prefs = await SharedPreferences.getInstance();
    String? userLoggedIn = prefs.getString('userLoggedIn');
    print('User logged in: $userLoggedIn');

    // Simulate initialization delay like fetching config, etc.
    await Future.delayed(const Duration(seconds: 3));
    emit(SplashCompleted());
  }


}
