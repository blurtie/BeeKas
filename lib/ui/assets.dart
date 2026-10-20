/// Image paths under assets/images/, from the Figma export of 20 Oct 2026.
/// test/ui/assets_test.dart loads every path listed in [all].
abstract final class BeeAssets {
  static const beeWriting = 'assets/images/ilustrasi/lebah-menulis.png';
  static const selfieExample = 'assets/images/ilustrasi/selfie-wanita.png';
  static const logo = 'assets/images/logo/beekas-logo.png';
  static const mascot = 'assets/images/logo/beekas-maskot.png';
  static const binus = 'assets/images/logo/binus-university.png';
  static const community = 'assets/images/ilustrasi/onboarding-komunitas.png';
  static const findItems = 'assets/images/ilustrasi/onboarding-cari-barang.png';
  static const trusted = 'assets/images/ilustrasi/onboarding-transaksi.png';
  static const buySell = 'assets/images/ilustrasi/onboarding-jual-beli.png';

  static const all = [
    beeWriting,
    selfieExample,
    logo,
    mascot,
    binus,
    community,
    findItems,
    trusted,
    buySell,
  ];
}
