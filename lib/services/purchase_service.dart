import 'package:get/get.dart';

abstract class IPurchaseService {
  Future<bool> purchaseRemoveAds();
  bool get removeAdsPurchased;
}

class NoOpPurchaseService extends GetxService implements IPurchaseService {
  @override
  bool get removeAdsPurchased => false;

  @override
  Future<bool> purchaseRemoveAds() async => false;
}
