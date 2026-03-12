import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pricing_service.dart';

final pricingServiceProvider = Provider<PricingService>((ref) {
  return PricingService(Supabase.instance.client);
});
