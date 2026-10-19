import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const SalesApp());

// ============================================================
//  HẰNG SỐ & TIỆN ÍCH
// ============================================================
const int kShippingFee = 30000;
const int kFreeShipThreshold = 500000;
const List<String> kCategories = ['Tất cả', 'Thời trang', 'Giày dép', 'Điện tử', 'Phụ kiện'];
const List<String> kPayments = ['Thanh toán khi nhận hàng (COD)', 'Chuyển khoản ngân hàng', 'Ví điện tử'];

String formatMoney(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$bufđ';
}

String _two(int n) => n.toString().padLeft(2, '0');
String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// Bỏ dấu tiếng Việt để tìm kiếm thông minh ("ao khoac" vẫn ra "Áo Khoác")
String normalize(String input) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  var out = input.toLowerCase();
  groups.forEach((base, chars) {
    for (final c in chars.split('')) {
      out = out.replaceAll(c, base);
    }
  });
  return out;
}

// ============================================================
//  MODEL
// ============================================================
class Product {
  final String id;
  final String title;
  final int price;
  final int oldPrice;
  final String imageUrl;
  final String description;
  final String category;
  final double rating;
  final int reviews;
  int stock;
  int sold;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.oldPrice,
    required this.imageUrl,
    required this.description,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.stock,
    required this.sold,
  });

  int get discountPercent => oldPrice > price ? (((oldPrice - price) * 100) / oldPrice).round() : 0;
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class Coupon {
  final String code;
  final String description;
  final int percent;
  final int fixed;
  final int minSubtotal;
  final bool freeShip;
  const Coupon({
    required this.code,
    required this.description,
    this.percent = 0,
    this.fixed = 0,
    this.minSubtotal = 0,
    this.freeShip = false,
  });
}

const List<Coupon> kCoupons = [
  Coupon(code: 'SALE10', description: 'Giảm 10% tổng đơn hàng', percent: 10),
  Coupon(code: 'GIAM50K', description: 'Giảm 50.000đ cho đơn từ 300.000đ', fixed: 50000, minSubtotal: 300000),
  Coupon(code: 'FREESHIP', description: 'Miễn phí vận chuyển', freeShip: true),
];

class OrderInfo {
  final String name, phone, address, note, payment;
  const OrderInfo({
    required this.name,
    required this.phone,
    required this.address,
    required this.note,
    required this.payment,
  });
}

enum OrderStatus { processing, shipping, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.processing => 'Đang xử lý',
        OrderStatus.shipping => 'Đang giao hàng',
        OrderStatus.delivered => 'Đã giao',
        OrderStatus.cancelled => 'Đã hủy',
      };
  Color get color => switch (this) {
        OrderStatus.processing => Colors.orange,
        OrderStatus.shipping => Colors.blue,
        OrderStatus.delivered => Colors.green,
        OrderStatus.cancelled => Colors.red,
      };
  IconData get icon => switch (this) {
        OrderStatus.processing => Icons.hourglass_top,
        OrderStatus.shipping => Icons.local_shipping_outlined,
        OrderStatus.delivered => Icons.check_circle_outline,
        OrderStatus.cancelled => Icons.cancel_outlined,
      };
}

class Order {
  final String id;
  final List<CartItem> items;
  final int subtotal, discount, shipping, total;
  final DateTime createdAt;
  final OrderInfo info;
  bool cancelled = false;

  Order({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.total,
    required this.createdAt,
    required this.info,
  });

  /// Trạng thái giả lập theo thời gian để demo (2 phút -> giao, 5 phút -> đã giao)
  OrderStatus get status {
    if (cancelled) return OrderStatus.cancelled;
    final m = DateTime.now().difference(createdAt).inMinutes;
    if (m < 2) return OrderStatus.processing;
    if (m < 5) return OrderStatus.shipping;
    return OrderStatus.delivered;
  }
}

enum SortOption { featured, priceAsc, priceDesc, rating, discount, bestSeller }

extension SortOptionX on SortOption {
  String get label => switch (this) {
        SortOption.featured => 'Nổi bật',
        SortOption.priceAsc => 'Giá tăng dần',
        SortOption.priceDesc => 'Giá giảm dần',
        SortOption.rating => 'Đánh giá cao',
        SortOption.discount => 'Giảm giá nhiều',
        SortOption.bestSeller => 'Bán chạy',
      };
}

// ============================================================
//  DỮ LIỆU MẪU
// ============================================================
List<Product> buildProducts() => [
      Product(
        id: '1', title: 'Áo Khoác Bomber Thời Trang', price: 350000, oldPrice: 500000,
        imageUrl: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=500',
        description: 'Áo khoác bomber chất liệu cao cấp, giữ ấm tốt, thiết kế trẻ trung phù hợp cho cả nam và nữ.',
        category: 'Thời trang', rating: 4.6, reviews: 128, stock: 25, sold: 320,
      ),
      Product(
        id: '2', title: 'Giày Sneaker Thể Thao', price: 650000, oldPrice: 900000,
        imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500',
        description: 'Giày sneaker êm chân, độ bám tốt, thích hợp chạy bộ, đi chơi và tập gym.',
        category: 'Giày dép', rating: 4.8, reviews: 342, stock: 12, sold: 870,
      ),
      Product(
        id: '3', title: 'Đồng Hồ Thông Minh Smartwatch', price: 1200000, oldPrice: 1800000,
        imageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500',
        description: 'Đồng hồ theo dõi sức khỏe, đo nhịp tim, nhận thông báo tin nhắn và cuộc gọi thông minh.',
        category: 'Điện tử', rating: 4.5, reviews: 210, stock: 8, sold: 540,
      ),
      Product(
        id: '4', title: 'Tai Nghe Bluetooth Chống Ồn', price: 450000, oldPrice: 700000,
        imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500',
        description: 'Tai nghe chụp tai âm thanh sống động, công nghệ lọc tiếng ồn cực tốt.',
        category: 'Điện tử', rating: 4.7, reviews: 415, stock: 30, sold: 1200,
      ),
      Product(
        id: '5', title: 'Giày Chạy Bộ Siêu Nhẹ', price: 790000, oldPrice: 990000,
        imageUrl: 'https://images.unsplash.com/photo-1491553895911-0055eca6402d?w=500',
        description: 'Đế đệm khí, trọng lượng nhẹ, thoáng khí - lựa chọn lý tưởng cho dân chạy bộ.',
        category: 'Giày dép', rating: 4.4, reviews: 96, stock: 0, sold: 260,
      ),
      Product(
        id: '6', title: 'Kính Mát Phân Cực Unisex', price: 220000, oldPrice: 320000,
        imageUrl: 'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=500',
        description: 'Tròng kính phân cực chống tia UV400, gọng nhẹ bền đẹp.',
        category: 'Phụ kiện', rating: 4.3, reviews: 77, stock: 40, sold: 410,
      ),
      Product(
        id: '7', title: 'Áo Thun Cotton Basic', price: 120000, oldPrice: 180000,
        imageUrl: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500',
        description: 'Vải cotton 100% thấm hút mồ hôi, form regular dễ phối đồ.',
        category: 'Thời trang', rating: 4.2, reviews: 560, stock: 100, sold: 2300,
      ),
      Product(
        id: '8', title: 'Laptop Mỏng Nhẹ 14 inch', price: 12900000, oldPrice: 15900000,
        imageUrl: 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=500',
        description: 'Màn hình 14 inch Full HD, RAM 16GB, SSD 512GB, pin dùng cả ngày.',
        category: 'Điện tử', rating: 4.9, reviews: 64, stock: 5, sold: 90,
      ),
      Product(
        id: '9', title: 'Túi Xách Da Thời Trang', price: 480000, oldPrice: 650000,
        imageUrl: 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=500',
        description: 'Da tổng hợp cao cấp, nhiều ngăn tiện dụng, kiểu dáng sang trọng.',
        category: 'Phụ kiện', rating: 4.5, reviews: 143, stock: 18, sold: 380,
      ),
      Product(
        id: '10', title: 'Loa Bluetooth Mini Chống Nước', price: 390000, oldPrice: 590000,
        imageUrl: 'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=500',
        description: 'Âm bass mạnh, chống nước IPX7, pin 12 giờ, nhỏ gọn mang theo mọi nơi.',
        category: 'Điện tử', rating: 4.6, reviews: 188, stock: 22, sold: 690,
      ),
    ];

// ============================================================
//  TRẠNG THÁI TOÀN ỨNG DỤNG (không cần thư viện ngoài)
// ============================================================
class AppState extends ChangeNotifier {
  final List<Product> products = buildProducts();
  final List<CartItem> cart = [];
  final Set<String> favorites = {};
  final List<String> recentIds = [];
  final List<String> searchHistory = [];
  final List<Order> orders = [];
  ThemeMode themeMode = ThemeMode.light;
  String? couponCode;

  Product byId(String id) => products.firstWhere((p) => p.id == id);

  // ---------- Giao diện ----------
  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ---------- Yêu thích ----------
  void toggleFavorite(Product p) {
    favorites.contains(p.id) ? favorites.remove(p.id) : favorites.add(p.id);
    notifyListeners();
  }

  // ---------- Đã xem & lịch sử tìm kiếm ----------
  void markViewed(Product p) {
    recentIds.remove(p.id);
    recentIds.insert(0, p.id);
    if (recentIds.length > 8) recentIds.removeLast();
    notifyListeners();
  }

  void addSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    searchHistory.remove(t);
    searchHistory.insert(0, t);
    if (searchHistory.length > 6) searchHistory.removeLast();
    notifyListeners();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    notifyListeners();
  }

  // ---------- Giỏ hàng ----------
  int get cartCount => cart.fold(0, (s, i) => s + i.quantity);
  int get subtotal => cart.fold(0, (s, i) => s + i.product.price * i.quantity);

  /// Trả về false nếu đã đạt giới hạn tồn kho.
  bool addToCart(Product p, {int qty = 1}) {
    final idx = cart.indexWhere((i) => i.product.id == p.id);
    final current = idx >= 0 ? cart[idx].quantity : 0;
    if (current + qty > p.stock) {
      if (current >= p.stock) return false;
      qty = p.stock - current;
    }
    if (idx >= 0) {
      cart[idx].quantity += qty;
    } else {
      cart.add(CartItem(product: p, quantity: qty));
    }
    notifyListeners();
    return true;
  }

  bool changeQty(CartItem item, int delta) {
    final next = item.quantity + delta;
    if (next > item.product.stock) return false;
    if (next <= 0) {
      cart.remove(item);
    } else {
      item.quantity = next;
    }
    notifyListeners();
    return true;
  }

  void removeFromCart(CartItem item) {
    cart.remove(item);
    notifyListeners();
  }

  void restoreToCart(CartItem item, int index) {
    cart.insert(index.clamp(0, cart.length), item);
    notifyListeners();
  }

  // ---------- Mã giảm giá ----------
  Coupon? get coupon {
    for (final c in kCoupons) {
      if (c.code == couponCode) return c;
    }
    return null;
  }

  bool get couponValid => coupon != null && subtotal >= coupon!.minSubtotal;

  int get discount {
    final c = coupon;
    if (c == null || subtotal < c.minSubtotal) return 0;
    return ((subtotal * c.percent) / 100).round() + c.fixed;
  }

  int get shipping {
    if (cart.isEmpty) return 0;
    if (subtotal >= kFreeShipThreshold) return 0;
    if (couponValid && coupon!.freeShip) return 0;
    return kShippingFee;
  }

  int get total => (subtotal - discount + shipping).clamp(0, 1 << 40);

  /// Trả về thông báo lỗi, hoặc null nếu áp dụng thành công.
  String? applyCoupon(String raw) {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) return 'Vui lòng nhập mã giảm giá';
    final found = kCoupons.where((c) => c.code == code);
    if (found.isEmpty) return 'Mã giảm giá không hợp lệ';
    final c = found.first;
    if (subtotal < c.minSubtotal) return 'Đơn hàng tối thiểu ${formatMoney(c.minSubtotal)} để dùng mã này';
    couponCode = c.code;
    notifyListeners();
    return null;
  }

  void removeCoupon() {
    couponCode = null;
    notifyListeners();
  }

  // ---------- Đặt hàng ----------
  Order placeOrder(OrderInfo info) {
    final items = cart.map((i) => CartItem(product: i.product, quantity: i.quantity)).toList();
    final order = Order(
      id: 'DH${DateTime.now().millisecondsSinceEpoch % 1000000}',
      items: items,
      subtotal: subtotal,
      discount: discount,
      shipping: shipping,
      total: total,
      createdAt: DateTime.now(),
      info: info,
    );
    for (final i in items) {
      i.product.stock -= i.quantity;
      i.product.sold += i.quantity;
    }
    orders.insert(0, order);
    cart.clear();
    couponCode = null;
    notifyListeners();
    return order;
  }

  void cancelOrder(Order o) {
    if (o.status != OrderStatus.processing) return;
    o.cancelled = true;
    for (final i in o.items) {
      i.product.stock += i.quantity;
      i.product.sold -= i.quantity;
    }
    notifyListeners();
  }

  // ---------- Gợi ý thông minh ----------
  bool get hasSignal => favorites.isNotEmpty || recentIds.isNotEmpty || cart.isNotEmpty;

  /// Chấm điểm danh mục dựa trên yêu thích, giỏ hàng, đã xem rồi gợi ý sản phẩm phù hợp.
  List<Product> recommendations({Product? basis, int limit = 6}) {
    final score = <String, double>{};
    void add(String cat, double w) => score[cat] = (score[cat] ?? 0) + w;
    for (final id in favorites) {
      add(byId(id).category, 3);
    }
    for (final i in cart) {
      add(i.product.category, 2);
    }
    for (final id in recentIds) {
      add(byId(id).category, 1);
    }
    if (basis != null) add(basis.category, 5);

    final exclude = <String>{...cart.map((i) => i.product.id), if (basis != null) basis.id};
    final candidates = products.where((p) => !exclude.contains(p.id) && p.stock > 0).toList();
    double rank(Product p) => (score[p.category] ?? 0) * 10 + p.rating + p.discountPercent / 100;
    candidates.sort((a, b) => rank(b).compareTo(rank(a)));
    return candidates.take(limit).toList();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  /// Lắng nghe thay đổi (rebuild khi state đổi)
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Chỉ đọc, không rebuild
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

// ============================================================
//  APP
// ============================================================
class SalesApp extends StatefulWidget {
  const SalesApp({super.key});

  @override
  State<SalesApp> createState() => _SalesAppState();
}

class _SalesAppState extends State<SalesApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: Builder(builder: (context) {
        final s = AppScope.of(context);
        return MaterialApp(
          title: 'SuperShop',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          home: const SalesHomePage(),
        );
      }),
    );
  }
}

// ============================================================
//  WIDGET DÙNG CHUNG
// ============================================================
void openProduct(BuildContext context, Product p, String heroTag) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p, heroTag: heroTag)));
}

void openCart(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));

void showSnack(BuildContext context, String msg, {SnackBarAction? action, bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? Colors.red.shade700 : null,
    action: action,
  ));
}

class ProductImage extends StatelessWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  const ProductImage({super.key, required this.url, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (ctx, child, progress) => progress == null
          ? child
          : Container(
              width: width,
              height: height,
              color: bg,
              alignment: Alignment.center,
              child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (ctx, e, st) => Container(
        width: width,
        height: height,
        color: bg,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  const StarRating({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = rating >= i + 1
            ? Icons.star
            : rating >= i + 0.5
                ? Icons.star_half
                : Icons.star_border;
        return Icon(icon, size: size, color: Colors.amber);
      }),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ?trailing,
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final String heroTag;
  const ProductCard({super.key, required this.product, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final fav = s.favorites.contains(product.id);
    final soldOut = product.stock == 0;

    return Material(
      color: cs.surfaceContainerLow,
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openProduct(context, product, heroTag),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: heroTag, child: ProductImage(url: product.imageUrl)),
                  if (soldOut)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const Text('HẾT HÀNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  if (product.discountPercent > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        child: Text('-${product.discountPercent}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => s.toggleFavorite(product),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white,
                        child: Icon(fav ? Icons.favorite : Icons.favorite_border,
                            size: 18, color: fav ? Colors.red : Colors.grey.shade700),
                      ),
                    ),
                  ),
                  if (!soldOut)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          final ok = s.addToCart(product);
                          showSnack(
                            context,
                            ok ? 'Đã thêm "${product.title}" vào giỏ hàng' : 'Đã đạt số lượng tồn kho tối đa',
                            error: !ok,
                            action: ok ? SnackBarAction(label: 'XEM GIỎ', onPressed: () => openCart(context)) : null,
                          );
                        },
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: cs.primary,
                          child: Icon(Icons.add_shopping_cart, size: 16, color: cs.onPrimary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text('${product.rating}', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('Đã bán ${product.sold}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: cs.outline)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(formatMoney(product.price),
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (product.oldPrice > product.price)
                    Text(formatMoney(product.oldPrice),
                        style: TextStyle(color: cs.outline, decoration: TextDecoration.lineThrough, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Danh sách sản phẩm cuộn ngang
class HorizontalProducts extends StatelessWidget {
  final List<Product> products;
  final String tagPrefix;
  const HorizontalProducts({super.key, required this.products, required this.tagPrefix});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 245,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 150,
          child: ProductCard(product: products[i], heroTag: '$tagPrefix${products[i].id}'),
        ),
      ),
    );
  }
}

// ============================================================
//  BANNER TỰ CHẠY
// ============================================================
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final _ctrl = PageController();
  Timer? _timer;
  int _index = 0;

  static const _banners = [
    ('Siêu Sale Mùa Hè ☀️', 'Giảm giá lên đến 50% cho tất cả\ncác mặt hàng thời trang và điện tử.', [Colors.deepPurple, Colors.purpleAccent]),
    ('Miễn Phí Vận Chuyển 🚚', 'Cho đơn hàng từ 500.000đ.\nDùng mã FREESHIP để được ưu đãi thêm.', [Colors.teal, Colors.greenAccent]),
    ('Mã SALE10 🎁', 'Giảm thêm 10% tổng đơn hàng.\nÁp dụng ngay tại giỏ hàng!', [Colors.deepOrange, Colors.amber]),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_ctrl.hasClients) return;
      _ctrl.animateToPage((_index + 1) % _banners.length,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final b = _banners[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: b.$3, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(b.$1, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(b.$2, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _index == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _index == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
//  ĐẾM NGƯỢC FLASH SALE
// ============================================================
class CountdownBadge extends StatefulWidget {
  const CountdownBadge({super.key});

  @override
  State<CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<CountdownBadge> {
  late DateTime _end;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _end = DateTime.now().add(const Duration(hours: 3));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_end.difference(DateTime.now()).isNegative) {
          _end = DateTime.now().add(const Duration(hours: 3));
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _end.difference(DateTime.now());
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    Widget box(int v) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
          child: Text(_two(v), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [box(h), const Text(' : '), box(m), const Text(' : '), box(s)],
    );
  }
}

// ============================================================
//  TRANG CHỦ
// ============================================================
class SalesHomePage extends StatefulWidget {
  const SalesHomePage({super.key});

  @override
  State<SalesHomePage> createState() => _SalesHomePageState();
}

class _SalesHomePageState extends State<SalesHomePage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'Tất cả';
  SortOption _sort = SortOption.featured;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filtered(AppState s) {
    final tokens = normalize(_query).split(' ').where((t) => t.isNotEmpty).toList();
    final list = s.products.where((p) {
      if (_category != 'Tất cả' && p.category != _category) return false;
      final hay = normalize('${p.title} ${p.category} ${p.description}');
      return tokens.every(hay.contains);
    }).toList();

    switch (_sort) {
      case SortOption.featured:
        break;
      case SortOption.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case SortOption.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
      case SortOption.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case SortOption.discount:
        list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      case SortOption.bestSeller:
        list.sort((a, b) => b.sold.compareTo(a.sold));
    }
    return list;
  }

  void _setQuery(String q) => setState(() {
        _query = q;
        _searchCtrl.text = q;
        _searchCtrl.selection = TextSelection.collapsed(offset: q.length);
      });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final isFiltering = _query.trim().isNotEmpty || _category != 'Tất cả';
    final results = _filtered(s);
    final flash = ([...s.products]..sort((a, b) => b.discountPercent.compareTo(a.discountPercent))).take(5).toList();
    final recent = s.recentIds.map(s.byId).toList();
    final recs = s.recommendations();

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.storefront, color: cs.primary, size: 28),
            const SizedBox(width: 8),
            const Text('SuperShop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chế độ sáng/tối',
            icon: Icon(s.themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: s.toggleTheme,
          ),
          IconButton(
            tooltip: 'Đơn hàng',
            icon: Badge.count(
              count: s.orders.length,
              isLabelVisible: s.orders.isNotEmpty,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
          ),
          IconButton(
            tooltip: 'Yêu thích',
            icon: Badge.count(
              count: s.favorites.length,
              isLabelVisible: s.favorites.isNotEmpty,
              child: const Icon(Icons.favorite_border),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          IconButton(
            tooltip: 'Giỏ hàng',
            icon: Badge.count(
              count: s.cartCount,
              isLabelVisible: s.cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => openCart(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ---- Tìm kiếm ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                    onSubmitted: s.addSearch,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm (không cần gõ dấu)...',
                      prefixIcon: Icon(Icons.search, color: cs.primary),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.close), onPressed: () => _setQuery('')),
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (_query.isEmpty && s.searchHistory.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Tìm kiếm gần đây', style: TextStyle(fontSize: 12, color: cs.outline)),
                        const Spacer(),
                        GestureDetector(
                          onTap: s.clearSearchHistory,
                          child: Text('Xóa', style: TextStyle(fontSize: 12, color: cs.primary)),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: s.searchHistory
                          .map((h) => ActionChip(
                                avatar: const Icon(Icons.history, size: 16),
                                label: Text(h),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _setQuery(h),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ---- Banner + Flash Sale (khi không lọc) ----
          if (!isFiltering) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: PromoBanner()),
            SliverToBoxAdapter(
              child: SectionHeader('⚡ Flash Sale', trailing: const CountdownBadge()),
            ),
            SliverToBoxAdapter(child: HorizontalProducts(products: flash, tagPrefix: 'flash_')),
          ],

          // ---- Danh mục ----
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                itemCount: kCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(kCategories[i]),
                  selected: _category == kCategories[i],
                  onSelected: (_) => setState(() => _category = kCategories[i]),
                ),
              ),
            ),
          ),

          // ---- Gợi ý thông minh ----
          if (!isFiltering && s.hasSignal && recs.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('✨ Dành riêng cho bạn')),
            SliverToBoxAdapter(child: HorizontalProducts(products: recs, tagPrefix: 'rec_')),
          ],
          if (!isFiltering && recent.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('🕘 Đã xem gần đây')),
            SliverToBoxAdapter(child: HorizontalProducts(products: recent, tagPrefix: 'recent_')),
          ],

          // ---- Tiêu đề + sắp xếp ----
          SliverToBoxAdapter(
            child: SectionHeader(
              isFiltering ? 'Kết quả (${results.length})' : 'Sản Phẩm Nổi Bật',
              trailing: PopupMenuButton<SortOption>(
                tooltip: 'Sắp xếp',
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => SortOption.values
                    .map((o) => CheckedPopupMenuItem(value: o, checked: o == _sort, child: Text(o.label)))
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 18, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(_sort.label, style: TextStyle(color: cs.primary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),

          // ---- Lưới sản phẩm ----
          if (results.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 56, color: cs.outline),
                    const SizedBox(height: 8),
                    const Text('Không tìm thấy sản phẩm phù hợp'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _setQuery('');
                        _category = 'Tất cả';
                      }),
                      child: const Text('Xóa bộ lọc'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ProductCard(product: results[i], heroTag: 'grid_${results[i].id}'),
                  childCount: results.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
//  CHI TIẾT SẢN PHẨM
// ============================================================
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String heroTag;
  const ProductDetailScreen({super.key, required this.product, required this.heroTag});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;

  // Đánh giá mẫu (dữ liệu giả lập)
  static const _reviews = [
    ('Minh Anh', 5, 'Hàng đẹp, đúng mô tả, giao nhanh. Sẽ ủng hộ tiếp!'),
    ('Quốc Bảo', 4, 'Chất lượng ổn trong tầm giá, đóng gói cẩn thận.'),
    ('Thu Hà', 5, 'Rất hài lòng, shop tư vấn nhiệt tình.'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).markViewed(widget.product);
    });
  }

  void _add(AppState s) {
    final ok = s.addToCart(widget.product, qty: _qty);
    showSnack(context, ok ? 'Đã thêm $_qty sản phẩm vào giỏ hàng' : 'Đã đạt số lượng tồn kho tối đa', error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final p = widget.product;
    final fav = s.favorites.contains(p.id);
    final soldOut = p.stock == 0;
    final related = s.recommendations(basis: p, limit: 5);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Colors.red : null),
            onPressed: () => s.toggleFavorite(p),
          ),
          IconButton(
            icon: Badge.count(
              count: s.cartCount,
              isLabelVisible: s.cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => openCart(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          Hero(tag: widget.heroTag, child: ProductImage(url: p.imageUrl, width: double.infinity, height: 300)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StarRating(rating: p.rating, size: 18),
                    const SizedBox(width: 6),
                    Text('${p.rating} (${p.reviews} đánh giá) • Đã bán ${p.sold}',
                        style: TextStyle(color: cs.outline, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatMoney(p.price),
                        style: TextStyle(color: cs.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    if (p.oldPrice > p.price) ...[
                      Text(formatMoney(p.oldPrice),
                          style: TextStyle(color: cs.outline, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        child: Text('-${p.discountPercent}%',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if (p.oldPrice > p.price)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Bạn tiết kiệm ${formatMoney(p.oldPrice - p.price)}',
                        style: const TextStyle(color: Colors.green, fontSize: 13)),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(soldOut ? Icons.error_outline : Icons.inventory_2_outlined,
                        size: 18, color: soldOut ? Colors.red : (p.stock <= 10 ? Colors.orange : Colors.green)),
                    const SizedBox(width: 6),
                    Text(
                      soldOut
                          ? 'Tạm hết hàng'
                          : p.stock <= 10
                              ? 'Chỉ còn ${p.stock} sản phẩm - sắp hết!'
                              : 'Còn hàng (${p.stock})',
                      style: TextStyle(color: soldOut ? Colors.red : (p.stock <= 10 ? Colors.orange : Colors.green)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!soldOut)
                  Row(
                    children: [
                      const Text('Số lượng', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton.outlined(
                        icon: const Icon(Icons.remove),
                        onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('$_qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton.outlined(
                        icon: const Icon(Icons.add),
                        onPressed: _qty < p.stock ? () => setState(() => _qty++) : null,
                      ),
                    ],
                  ),
                const Divider(height: 32),
                const Text('Mô tả sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(p.description, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.5)),
                const Divider(height: 32),
                const Text('Đánh giá từ khách hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._reviews.map(
                  (r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(r.$1[0])),
                    title: Row(children: [Text(r.$1), const SizedBox(width: 8), StarRating(rating: r.$2.toDouble(), size: 13)]),
                    subtitle: Text(r.$3),
                  ),
                ),
              ],
            ),
          ),
          if (related.isNotEmpty) ...[
            const SectionHeader('Có thể bạn cũng thích'),
            HorizontalProducts(products: related, tagPrefix: 'rel_'),
            const SizedBox(height: 24),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: soldOut ? null : () => _add(s),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Thêm vào giỏ'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: soldOut
                      ? null
                      : () {
                          final ok = s.addToCart(p, qty: _qty);
                          if (!ok) {
                            showSnack(context, 'Đã đạt số lượng tồn kho tối đa', error: true);
                            return;
                          }
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                        },
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Mua Ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  YÊU THÍCH
// ============================================================
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final favs = s.products.where((p) => s.favorites.contains(p.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Yêu thích (${favs.length})')),
      body: favs.isEmpty
          ? const Center(child: Text('Bạn chưa có sản phẩm yêu thích nào'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: favs.length,
              itemBuilder: (_, i) => ProductCard(product: favs[i], heroTag: 'fav_${favs[i].id}'),
            ),
    );
  }
}

// ============================================================
//  GIỎ HÀNG
// ============================================================
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponCtrl = TextEditingController();
  String? _couponError;

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(fontSize: bold ? 17 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final remainFree = kFreeShipThreshold - s.subtotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ Hàng Của Bạn')),
      body: s.cart.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 72, color: cs.outline),
                  const SizedBox(height: 12),
                  const Text('Giỏ hàng trống!', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tiếp tục mua sắm')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // Thanh tiến độ miễn phí vận chuyển
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remainFree <= 0
                            ? '🎉 Bạn được miễn phí vận chuyển!'
                            : 'Mua thêm ${formatMoney(remainFree)} để được miễn phí vận chuyển',
                        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: (s.subtotal / kFreeShipThreshold).clamp(0.0, 1.0), minHeight: 6),
                      ),
                    ],
                  ),
                ),

                // Danh sách sản phẩm (vuốt để xóa)
                ...s.cart.map((item) {
                  return Dismissible(
                    key: ValueKey(item.product.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      final index = s.cart.indexOf(item);
                      s.removeFromCart(item);
                      showSnack(
                        context,
                        'Đã xóa "${item.product.title}"',
                        action: SnackBarAction(label: 'HOÀN TÁC', onPressed: () => s.restoreToCart(item, index)),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProductImage(url: item.product.imageUrl, width: 64, height: 64),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.title,
                                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(formatMoney(item.product.price), style: TextStyle(color: cs.primary)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () => s.changeQty(item, -1),
                                ),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () {
                                    if (!s.changeQty(item, 1)) {
                                      showSnack(context, 'Chỉ còn ${item.product.stock} sản phẩm trong kho', error: true);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Mã giảm giá
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: s.coupon != null && s.couponValid
                      ? ListTile(
                          tileColor: Colors.green.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.local_offer, color: Colors.green),
                          title: Text('Đã áp dụng ${s.coupon!.code}'),
                          subtitle: Text(s.coupon!.description),
                          trailing: IconButton(icon: const Icon(Icons.close), onPressed: s.removeCoupon),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponCtrl,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      labelText: 'Mã giảm giá',
                                      errorText: _couponError,
                                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () {
                                    setState(() => _couponError = s.applyCoupon(_couponCtrl.text));
                                    if (_couponError == null) _couponCtrl.clear();
                                  },
                                  child: const Text('Áp dụng'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: kCoupons
                                  .map((c) => ActionChip(
                                        avatar: const Icon(Icons.local_offer_outlined, size: 16),
                                        label: Text(c.code),
                                        tooltip: c.description,
                                        onPressed: () {
                                          _couponCtrl.text = c.code;
                                          setState(() => _couponError = s.applyCoupon(c.code));
                                        },
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                ),

                // Tổng kết
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Tạm tính', formatMoney(s.subtotal)),
                      if (s.discount > 0) _row('Giảm giá', '-${formatMoney(s.discount)}', color: Colors.green),
                      _row('Phí vận chuyển', s.shipping == 0 ? 'Miễn phí' : formatMoney(s.shipping)),
                      const Divider(),
                      _row('Tổng thanh toán', formatMoney(s.total), bold: true, color: cs.primary),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: s.cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  child: Text('Tiến Hành Đặt Hàng • ${formatMoney(s.total)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
    );
  }
}

// ============================================================
//  THANH TOÁN
// ============================================================
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  int _payment = 0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Future<void> _submit(AppState s) async {
    if (!_formKey.currentState!.validate()) return;
    final order = s.placeOrder(OrderInfo(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      note: _note.text.trim(),
      payment: kPayments[_payment],
    ));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt Hàng Thành Công 🎉'),
        content: Text('Cảm ơn bạn đã mua hàng!\nMã đơn: ${order.id}\nTổng tiền: ${formatMoney(order.total)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Thông Tin Đặt Hàng')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Thông tin nhận hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Họ và tên', Icons.person_outline),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Vui lòng nhập họ tên' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Số điện thoại', Icons.phone_outlined),
              validator: (v) => RegExp(r'^0\d{9}$').hasMatch((v ?? '').trim()) ? null : 'Số điện thoại gồm 10 số, bắt đầu bằng 0',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: _dec('Địa chỉ giao hàng', Icons.location_on_outlined),
              validator: (v) => (v == null || v.trim().length < 8) ? 'Vui lòng nhập địa chỉ đầy đủ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _note, maxLines: 2, decoration: _dec('Ghi chú (tuỳ chọn)', Icons.edit_note)),
            const SizedBox(height: 20),
            const Text('Phương thức thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.generate(kPayments.length, (i) {
              final selected = _payment == i;
              return Card(
                color: selected ? cs.primaryContainer : null,
                child: ListTile(
                  title: Text(kPayments[i]),
                  trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? cs.primary : cs.outline),
                  onTap: () => setState(() => _payment = i),
                ),
              );
            }),
            const SizedBox(height: 20),
            const Text('Đơn hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...s.cart.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text('${i.product.title} × ${i.quantity}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(formatMoney(i.product.price * i.quantity)),
                    ],
                  ),
                )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(formatMoney(s.total), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.primary)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: s.cart.isEmpty ? null : () => _submit(s),
              child: const Text('Xác Nhận Đặt Hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  LỊCH SỬ ĐƠN HÀNG
// ============================================================
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn Hàng Của Tôi')),
      body: s.orders.isEmpty
          ? const Center(child: Text('Bạn chưa có đơn hàng nào'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: s.orders.length,
              itemBuilder: (_, i) {
                final o = s.orders[i];
                final st = o.status;
                return Card(
                  child: ExpansionTile(
                    leading: Icon(st.icon, color: st.color),
                    title: Text('Đơn ${o.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${formatDate(o.createdAt)} • ${st.label}', style: TextStyle(color: st.color, fontSize: 12)),
                    trailing: Text(formatMoney(o.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...o.items.map((it) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(child: Text('${it.product.title} × ${it.quantity}')),
                                Text(formatMoney(it.product.price * it.quantity)),
                              ],
                            ),
                          )),
                      const Divider(),
                      Text('Người nhận: ${o.info.name} - ${o.info.phone}'),
                      Text('Địa chỉ: ${o.info.address}'),
                      Text('Thanh toán: ${o.info.payment}'),
                      if (o.info.note.isNotEmpty) Text('Ghi chú: ${o.info.note}'),
                      const SizedBox(height: 4),
                      Text('Tạm tính ${formatMoney(o.subtotal)} • Giảm ${formatMoney(o.discount)} • Ship ${formatMoney(o.shipping)}',
                          style: const TextStyle(fontSize: 12)),
                      if (st == OrderStatus.processing)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              s.cancelOrder(o);
                              showSnack(context, 'Đã hủy đơn ${o.id}');
                            },
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            label: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}