import 'package:get_it/get_it.dart';
import 'package:wordrop/services/action_service.dart';
import 'package:wordrop/repositories/settings_repository.dart';
import 'package:wordrop/repositories/trigger_word_repository.dart';
import 'package:wordrop/repositories/log_repository.dart';

final locator = GetIt.instance;

void setupLocator() {
  // Register Repositories (Lazy Singleton = Created when first requested)
  locator.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  locator.registerLazySingleton<TriggerWordRepository>(
    () => TriggerWordRepository(),
  );
  locator.registerLazySingleton<LogRepository>(() => LogRepository());

  // Register Services
  // ActionService is currently a Singleton factory, but we can register it here too
  // for consistent access via locator<ActionService>().
  // In future, we will remove the factory from ActionService and inject dependencies.
  locator.registerLazySingleton<ActionService>(() => ActionService());
}
