import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/excel_service.dart';
import '../services/exchange_service.dart';
import '../services/circular_exchange_service.dart';
import '../services/chain_exchange_service.dart';

/// ExcelService Provider
final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});

/// ExchangeService Provider (1:1 교체)
final exchangeServiceProvider = Provider<ExchangeService>((ref) {
  return ExchangeService();
});

/// CircularExchangeService Provider (순환 교체)
final circularExchangeServiceProvider = Provider<CircularExchangeService>((ref) {
  return CircularExchangeService();
});

/// ChainExchangeService Provider (연쇄 교체)
final chainExchangeServiceProvider = Provider<ChainExchangeService>((ref) {
  return ChainExchangeService();
});
