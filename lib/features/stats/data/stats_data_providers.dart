import 'package:outrun_vpn/features/stats/data/stats_repository.dart';
import 'package:outrun_vpn/Outrun VPNcore/Outrun VPN_core_service_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_data_providers.g.dart';

@Riverpod(keepAlive: true)
StatsRepository statsRepository(Ref ref) {
  return StatsRepositoryImpl(singbox: ref.watch(Outrun VPNCoreServiceProvider));
}
