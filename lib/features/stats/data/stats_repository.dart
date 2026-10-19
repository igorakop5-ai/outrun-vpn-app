import 'package:fpdart/fpdart.dart';
import 'package:Outrun VPN/core/utils/exception_handler.dart';
import 'package:Outrun VPN/features/stats/model/stats_failure.dart';
import 'package:Outrun VPN/Outrun VPNcore/generated/v2/hcore/hcore.pb.dart';
import 'package:Outrun VPN/Outrun VPNcore/Outrun VPN_core_service.dart';
import 'package:Outrun VPN/utils/custom_loggers.dart';

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
