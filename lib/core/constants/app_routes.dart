/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Route Definitions
/// ═══════════════════════════════════════════════════════════════════════════
class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String registrationVerification = '/registration-verification';
  static const String pendingVerification = '/pending-verification';

  // Paywall Gate
  static const String membershipPaywall = '/membership-paywall';

  // Main tabs
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // Loyalty / Wallet
  static const String loyalty = '/loyalty';
  static const String qrDisplay = '/loyalty/qr';
  static const String transactionHistory = '/loyalty/transactions';
  static const String linkPhysicalCard = '/loyalty/link-card';
  static const String redeem = '/loyalty/redeem';

  // Reward Store
  static const String rewardStore = '/reward-store';

  // Bookings
  static const String myBookings = '/my-bookings';
  static const String booking = '/my-bookings/new';
  static const String bookingConfirm = '/my-bookings/confirm';
  static const String bookingDetail = '/my-bookings/detail';

  // Menu
  static const String menu = '/menu';
  static const String menuItemDetail = '/menu/item';

  // Profile / Settings
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String notificationPrefs = '/profile/notifications';

  // Notifications Inbox
  static const String notifications = '/notifications';
}
