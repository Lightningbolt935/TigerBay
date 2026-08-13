import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tigerbay_app/data/models/merchandise_item.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Merchandise Provider
// ──────────────────────────────────────────────────────────
// Official catalogue of TigerBay branded merchandise items. Each entry
// has both a cash [price] and a [requiredStrips] token equivalent so
// members can choose their preferred payment method in the UI.
// ──────────────────────────────────────────────────────────

/// Immutable catalogue of all available merchandise items.
/// Returns a fixed list of 4 production-grade premium TigerBay products.
final merchandiseProvider = Provider<List<MerchandiseItem>>((ref) {
  return const [
    // ── 1. TigerBay Premium Noir Hoodie ─────────────────────────────────
    MerchandiseItem(
      id: 'merch-hoodie-noir-001',
      name: 'TigerBay Premium Noir Hoodie',
      description: 'Heavyweight 450gsm organic cotton featuring the signature '
          'red embroidered tiger crest.',
      price: 85.00,
      requiredStrips: 850,
      imageUrl: 'assets/images/merch_hoodie.png',
    ),

    // ── 2. Signature Gold Edge Tumbler ──────────────────────────────────
    MerchandiseItem(
      id: 'merch-tumbler-gold-002',
      name: 'Signature Gold Edge Tumbler',
      description: 'Matte black double-walled insulated stainless steel flask '
          'finished with brushed gold trim.',
      price: 35.00,
      requiredStrips: 350,
      imageUrl: 'assets/images/merch_tumbler.png',
    ),

    // ── 3. International Club Cap ────────────────────────────────────────
    MerchandiseItem(
      id: 'merch-cap-club-003',
      name: 'International Club Cap',
      description: 'Adjustable premium vintage strapback cap with minimalist '
          'tonal line stitching.',
      price: 28.00,
      requiredStrips: 280,
      imageUrl: 'assets/images/merch_cap.png',
    ),

    // ── 4. Luxury Membership Leather Cardholder ──────────────────────────
    MerchandiseItem(
      id: 'merch-wallet-leather-004',
      name: 'Luxury Membership Leather Cardholder',
      description: 'Saffiano leather wallet debossed with the TigerBay crest, '
          'featuring RFID shielding.',
      price: 50.00,
      requiredStrips: 500,
      imageUrl: 'assets/images/merch_wallet.png',
    ),
  ];
});
