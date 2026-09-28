import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_bank.dart';

class KenyaBanksNotifier extends AutoDisposeAsyncNotifier<List<SafariTapBank>> {
  @override
  Future<List<SafariTapBank>> build() {
    return ref.read(safariTapPayApiProvider).listBanks();
  }
}

final kenyaBanksProvider =
    AutoDisposeAsyncNotifierProvider<KenyaBanksNotifier, List<SafariTapBank>>(
  KenyaBanksNotifier.new,
);
