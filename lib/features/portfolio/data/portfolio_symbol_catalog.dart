const symbolSearchHintSymbols = <String>['AAPL', 'TSLA', 'MSFT'];

const knownLogoDomains = <String, String>{
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

const knownCryptoAliases = <String, String>{
  'BTCUSD': 'BTC',
  'BTCUSDT': 'BTC',
  'ETHUSD': 'ETH',
  'ETHUSDT': 'ETH',
  'SOLUSD': 'SOL',
  'SOLUSDT': 'SOL',
  'BNBUSD': 'BNB',
  'BNBUSDT': 'BNB',
  'XRPUSD': 'XRP',
  'XRPUSDT': 'XRP',
};

String? resolveCoinSymbol(String rawSymbol) {
  if (rawSymbol.contains('/')) return rawSymbol.split('/').first;
  if (rawSymbol.startsWith('X:')) return rawSymbol.substring(2);
  return knownCryptoAliases[rawSymbol];
}
