import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';

class AssetLogo extends StatelessWidget {
  final String symbol;
  final String assetType;
  final String? logoUrl;
  final double size;
  final double borderRadius;

  const AssetLogo({
    super.key,
    required this.symbol,
    this.assetType = 'stock',
    this.logoUrl,
    this.size = 32,
    this.borderRadius = 999,
  });

  @override
  Widget build(BuildContext context) {
    final urls = _resolveLogoUrls();
    final fallback = _FallbackBadge(
      symbol: symbol,
      assetType: assetType,
      size: size,
      borderRadius: borderRadius,
    );

    if (urls.isEmpty) return fallback;

    return _ResilientNetworkLogo(
      urls: urls,
      size: size,
      borderRadius: borderRadius,
      fallback: fallback,
    );
  }

  List<String> _resolveLogoUrls() {
    final urls = <String>[];

    if ((logoUrl ?? '').trim().isNotEmpty) {
      urls.add(logoUrl!.trim());
    }

    final normalized = symbol.trim().toUpperCase();
    if (normalized.isEmpty) return urls;

    final base = normalized
        .split('/')
        .first
        .split('.')
        .first
        .replaceAll('X:', '');

    final coin = _coinFromSymbol(normalized);
    final isCrypto = assetType.toLowerCase() == 'crypto' || coin != null;
    if (isCrypto) {
      final token = (coin ?? base).toLowerCase();
      urls.add('https://assets.coincap.io/assets/icons/$token@2x.png');
      urls.add(
        'https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/32/color/$token.png',
      );
      return urls;
    }

    if (base.isEmpty) return urls;

    final domain = _knownDomains[base];
    if (domain != null) {
      urls.add('https://logo.clearbit.com/$domain');
    }
    urls.add('https://images.financialmodelingprep.com/symbol/$base.png');
    urls.add(
      'https://static2.finnhub.io/file/publicdatany/finnhubimage/stock_logo/$base.png',
    );

    return urls;
  }

  String? _coinFromSymbol(String raw) {
    if (raw.contains('/')) return raw.split('/').first;
    if (raw.startsWith('X:')) return raw.substring(2);
    return switch (raw) {
      'BTCUSD' || 'BTCUSDT' => 'BTC',
      'ETHUSD' || 'ETHUSDT' => 'ETH',
      'SOLUSD' || 'SOLUSDT' => 'SOL',
      'BNBUSD' || 'BNBUSDT' => 'BNB',
      'XRPUSD' || 'XRPUSDT' => 'XRP',
      _ => null,
    };
  }
}

class _ResilientNetworkLogo extends StatefulWidget {
  final List<String> urls;
  final double size;
  final double borderRadius;
  final Widget fallback;

  const _ResilientNetworkLogo({
    required this.urls,
    required this.size,
    required this.borderRadius,
    required this.fallback,
  });

  @override
  State<_ResilientNetworkLogo> createState() => _ResilientNetworkLogoState();
}

class _ResilientNetworkLogoState extends State<_ResilientNetworkLogo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) return widget.fallback;
    final url = widget.urls[_index];

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => widget.fallback,
        errorWidget: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index++);
          });
          return widget.fallback;
        },
      ),
    );
  }
}

const Map<String, String> _knownDomains = {
  'AAPL': 'apple.com',
  'MSFT': 'microsoft.com',
  'NVDA': 'nvidia.com',
  'AMZN': 'amazon.com',
  'TSLA': 'tesla.com',
  'META': 'meta.com',
  'GOOGL': 'google.com',
  'NFLX': 'netflix.com',
  'INTC': 'intel.com',
  'AMD': 'amd.com',
  'WMT': 'walmart.com',
  'DIS': 'disney.com',
  'PYPL': 'paypal.com',
  'UBER': 'uber.com',
  'CRM': 'salesforce.com',
  'JPM': 'jpmorganchase.com',
  'V': 'visa.com',
  'JNJ': 'jnj.com',
};

class _FallbackBadge extends StatelessWidget {
  final String symbol;
  final String assetType;
  final double size;
  final double borderRadius;

  const _FallbackBadge({
    required this.symbol,
    required this.assetType,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final clean = symbol.trim().toUpperCase();
    final seed = clean.isEmpty ? 1 : clean.codeUnits.fold(0, (a, b) => a + b);
    final hue = (seed * 37) % 360;
    final base = HSVColor.fromAHSV(1, hue.toDouble(), 0.7, 0.7).toColor();
    final bg = Color.alphaBlend(
      base.withValues(alpha: 0.2),
      AppColors.primary.withValues(alpha: 0.08),
    );
    final text = clean.contains('/')
        ? clean.split('/').first
        : clean.split('.').first;
    final label = text.isEmpty
        ? '?'
        : text.length <= 3
        ? text
        : text.substring(0, math.min(3, text.length));

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: base.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: size * 0.28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimaryLight,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
