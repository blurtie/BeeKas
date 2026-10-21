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
  static const sellItem = 'assets/images/ikon/listing/jual-barang.png';
  static const donateItem = 'assets/images/ikon/listing/donasi-barang.png';

  /// Daftar-12 tiles, by ListingCategory.code.
  static const categories = {
    'laptop_computer': '$_category/laptop-komputer.png',
    'phone_gadget': '$_category/hp-gadget.png',
    'accessories': '$_category/aksesoris.png',
    'clothing': '$_category/pakaian.png',
    'shoes': '$_category/sepatu.png',
    'bags': '$_category/tas.png',
    'books_stationery': '$_category/buku-alat-tulis.png',
    'campus_supplies': '$_category/perlengkapan-kampus.png',
    'other': '$_category/lainnya.png',
  };
  static const _category = 'assets/images/ikon/kategori';

  /// Beranda shortcuts, by CategoryGroup.name.
  static const groups = {
    'all': '$_group/semua.png',
    'electronics': '$_group/elektronik.png',
    'fashion': '$_group/fashion.png',
    'books': '$_group/buku.png',
    'supplies': '$_group/perlengkapan.png',
  };
  static const _group = 'assets/images/ikon/kategori-beranda';

  static final all = [
    beeWriting,
    selfieExample,
    logo,
    mascot,
    binus,
    community,
    findItems,
    trusted,
    buySell,
    sellItem,
    donateItem,
    ...categories.values,
    ...groups.values,
  ];
}
