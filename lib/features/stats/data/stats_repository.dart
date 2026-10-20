import 'package:fpdart/fpdart.dart';
import 'package:outrun_vpn/core/utils/exception_handler.dart';
import 'package:outrun_vpn/features/stats/model/stats_failure.dart';
import 'package:outrun_vpn/Outrun VPNcore/generated/v2/hcore/hcore.pb.dart';
import 'package:outrun_vpn/Outrun VPNcore/Outrun VPN_core_service.dart';
import 'package:outrun_vpn/utils/custom_loggers.dart';

abstract interface class StatsRepository {
  Stream<Either<StatsFailure, SystemInfo>> watchStats();
}

class StatsRepositoryImpl with ExceptionHandler, InfraLogger implements StatsRepository {
  StatsRepositoryImpl({required this.singbox});

  final Outrun VPNCoreService singbox;

  @override
  Stream<Either<StatsFailure, SystemInfo>> watchStats() {
    return singbox.watchStats().handleExceptions(StatsUnexpectedFailure.new);
  }
}
