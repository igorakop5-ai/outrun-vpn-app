import 'package:Outrun VPN/Outrun VPNcore/Outrun VPN_core_service_provider.dart';
import 'package:Outrun VPN/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reset_tunnel_notifier.g.dart';

@riverpod
class ResetTunnelNotifier extends _$ResetTunnelNotifier with AppLogger {
  @override
  Future<void> build() async {}

  Future<void> run() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(Outrun VPNCoreServiceProvider).resetTunnel().getOrElse((err) {
        loggy.warning("error resetting tunnel", err);
        throw err;
      }).run(),
    );
  }
}
