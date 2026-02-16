# Phase 3 — Temps réel, graphiques & polish

## Objectif
Ajouter le streaming de prix via WebSocket, les graphiques d'historique, et les finitions UX.

## Prérequis
- Phase 2 terminée (page portfolio fonctionnelle avec refresh manuel)

## 1. WebSocket Twelve Data (streaming de prix)

### Comment ça marche
Twelve Data fournit un WebSocket qui push les prix en continu :
- **Free tier** : 1 symbole simultané en streaming
- **Plan Basic (29$/mois)** : 8 symboles simultanés
- Protocole : `wss://ws.twelvedata.com/v1/quotes/price?apikey=xxx`

### Stratégie pour le free tier
Avec 1 seul symbole en streaming gratuit, on ne peut pas tout streamer. Approche hybride :

```
Priorité 1 : Le symbole actuellement consulté par l'user → WebSocket live
Priorité 2 : Les autres symboles → refresh polling toutes les 5 min (cache REST)
```

Quand l'utilisateur clique sur une position ou un item de watchlist → le backend bascule le WebSocket sur ce symbole.

### Backend — `Services/TwelveDataWebSocketService.cs`

```csharp
// Service singleton qui maintient UNE connexion WebSocket
public class TwelveDataWebSocketService : IHostedService, IDisposable
{
    private ClientWebSocket? _ws;
    private string? _currentSymbol;
    private readonly TwelveDataConfig _config;
    private readonly IServiceScopeFactory _scopeFactory;

    // Event pour notifier les clients connectés
    public event Action<string, decimal>? OnPriceUpdate;

    public async Task SubscribeToSymbol(string symbol)
    {
        if (_currentSymbol == symbol) return;

        // Unsubscribe ancien
        if (_currentSymbol != null)
            await SendMessage(new { action = "unsubscribe", params = new { symbols = _currentSymbol } });

        // Subscribe nouveau
        await SendMessage(new { action = "subscribe", params = new { symbols = symbol } });
        _currentSymbol = symbol;
    }

    // Boucle de lecture WebSocket → met à jour le cache + notifie les listeners
    private async Task ReadLoop(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var message = await ReceiveMessage();
            if (message.Event == "price")
            {
                // Mettre à jour le cache DB
                using var scope = _scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<SolverDbContext>();
                // ... upsert asset_price_cache

                // Notifier les clients SSE/WebSocket côté app
                OnPriceUpdate?.Invoke(message.Symbol, message.Price);
            }
        }
    }
}
```

### Backend → Frontend : Server-Sent Events (SSE)

Pour pousser les prix du backend vers le frontend Flutter, utiliser SSE (plus simple que WebSocket côté .NET minimal API) :

```csharp
// Endpoints/MarketEndpoints.cs
app.MapGet("/api/market/stream/{symbol}", async (
    string symbol,
    HttpContext context,
    TwelveDataWebSocketService wsService) =>
{
    context.Response.ContentType = "text/event-stream";
    context.Response.Headers.CacheControl = "no-cache";

    // Dire au service WS de suivre ce symbole
    await wsService.SubscribeToSymbol(symbol);

    // Écouter les mises à jour
    var tcs = new TaskCompletionSource();
    void handler(string sym, decimal price)
    {
        if (sym == symbol)
        {
            var data = JsonSerializer.Serialize(new { symbol = sym, price });
            context.Response.WriteAsync($"data: {data}\n\n");
            context.Response.Body.FlushAsync();
        }
    }

    wsService.OnPriceUpdate += handler;
    context.RequestAborted.Register(() => {
        wsService.OnPriceUpdate -= handler;
        tcs.SetResult();
    });

    await tcs.Task;
});
```

### Frontend — écouter le stream SSE

```dart
// providers/price_stream_provider.dart
final selectedSymbolProvider = StateProvider<String?>((ref) => null);

final priceStreamProvider = StreamProvider.autoDispose<PriceUpdate>((ref) async* {
  final symbol = ref.watch(selectedSymbolProvider);
  if (symbol == null) return;

  final client = ref.read(apiClientProvider);
  final baseUrl = client.options.baseUrl;
  final token = /* get JWT token */;

  final request = http.Request('GET', Uri.parse('$baseUrl/api/market/stream/$symbol'));
  request.headers['Authorization'] = 'Bearer $token';

  final response = await http.Client().send(request);

  await for (final chunk in response.stream.transform(utf8.decoder)) {
    if (chunk.startsWith('data: ')) {
      final json = jsonDecode(chunk.substring(6));
      yield PriceUpdate.fromJson(json);
    }
  }
});
```

## 2. Graphiques d'historique

### Librairie recommandée : `fl_chart`
Déjà largement utilisée dans l'écosystème Flutter, légère et personnalisable.

```yaml
# pubspec.yaml
dependencies:
  fl_chart: ^0.69.0
```

### Widget : `widgets/price_chart.dart`

```dart
class PriceChart extends ConsumerWidget {
  final String symbol;
  final String interval; // "1day", "1week", "1month"

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(priceHistoryProvider((symbol: symbol, interval: interval)));

    return history.when(
      loading: () => const ShimmerPlaceholder(),
      error: (err, _) => Text('Erreur'),
      data: (points) => AppPanel(
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: points.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), e.value.close)
                  ).toList(),
                  isCurved: true,
                  color: points.last.close >= points.first.close
                      ? AppTokens.success
                      : AppTokens.error,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: (points.last.close >= points.first.close
                        ? AppTokens.success
                        : AppTokens.error).withOpacity(0.1),
                  ),
                ),
              ],
              titlesData: FlTitlesData(show: false),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}
```

### Provider historique
```dart
final priceHistoryProvider = FutureProvider.autoDispose
    .family<List<TimeSeriesPoint>, ({String symbol, String interval})>(
  (ref, params) async {
    final client = ref.read(apiClientProvider);
    final response = await client.get(
      '/api/market/history/${params.symbol}',
      queryParameters: {'interval': params.interval, 'days': 30},
    );
    return (response.data['values'] as List)
        .map((e) => TimeSeriesPoint.fromJson(e))
        .toList();
  },
);
```

### Périodes disponibles (boutons)
```
[ 1S ] [ 1M ] [ 3M ] [ 6M ] [ 1A ] [ MAX ]
```

Mapping vers l'API :
| Bouton | interval | outputsize |
|--------|----------|-----------|
| 1S | 1h | 40 (5 jours × 8h) |
| 1M | 1day | 22 |
| 3M | 1day | 66 |
| 6M | 1day | 132 |
| 1A | 1week | 52 |
| MAX | 1month | 120 |

## 3. Vue détail d'un actif

Quand l'utilisateur tape sur une position ou un item watchlist, ouvrir une vue détail enrichie avec les données Finnhub :

```
┌──────────────────────────────┐
│ ← Retour     AAPL            │
│  [logo]  Apple Inc.          │
│  Technology · NASDAQ · US    │  ← Finnhub profil
├──────────────────────────────┤
│                              │
│  $178.50   +$2.30  (+1.3%)   │  ← prix live (SSE / Twelve Data)
│  Market cap: $2.89T          │  ← Finnhub
│                              │
│  ┌────────────────────────┐  │
│  │   Graphique historique │  │
│  │   (fl_chart)           │  │
│  └────────────────────────┘  │
│  [ 1S ] [ 1M ] [ 3M ] [1A]  │
│                              │
├──────────────────────────────┤
│ Ma position                  │
│ 10 actions × $150.00 moy    │
│ Valeur: $1,785   +19.0%     │
│ Investi: $1,500              │
│ Gain: +$285                  │
├──────────────────────────────┤
│ Analystes         Finnhub    │
│ ████████████░░░░             │
│ 12 Strong Buy · 24 Buy      │
│ 7 Hold · 1 Sell             │
├──────────────────────────────┤
│ Actualités        Finnhub    │
│ ┌────────────────────────┐   │
│ │ Apple Reports Record   │   │
│ │ Q1 Revenue · Reuters   │   │
│ │ il y a 2h              │   │
│ ├────────────────────────┤   │
│ │ iPhone 18 Leaks Show...│   │
│ │ Bloomberg · il y a 5h  │   │
│ └────────────────────────┘   │
├──────────────────────────────┤
│ [ Modifier ] [ Supprimer ]   │
└──────────────────────────────┘
```

Implémentation : soit un `showModalBottomSheet` (mobile), soit un panneau latéral (desktop).

### Providers pour la vue détail
```dart
// Profil entreprise — cache longue durée côté backend (1h)
final companyProfileProvider = FutureProvider.autoDispose
    .family<CompanyProfile?, String>((ref, symbol) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/api/market/profile/$symbol');
  return CompanyProfile.fromJson(response.data);
});

// News récentes
final companyNewsProvider = FutureProvider.autoDispose
    .family<List<CompanyNews>, String>((ref, symbol) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/api/market/news/$symbol');
  return (response.data['news'] as List)
      .map((e) => CompanyNews.fromJson(e)).toList();
});

// Recommandations analystes
final analystRecoProvider = FutureProvider.autoDispose
    .family<List<AnalystRecommendation>, String>((ref, symbol) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/api/market/recommendations/$symbol');
  return (response.data['recommendations'] as List)
      .map((e) => AnalystRecommendation.fromJson(e)).toList();
});
```

### Widget jauge analystes — `analyst_gauge.dart`
Barre horizontale colorée montrant la répartition buy/hold/sell :
```
Strong Buy ████ Buy ████████████ Hold ████ Sell █
    12           24              7         1
```

### Widget news — `news_list.dart`
Liste scrollable de cartes avec :
- Image de l'article (thumbnail)
- Headline + source + timestamp relatif
- Tap → ouvre l'URL dans le navigateur (`url_launcher`)

## 4. Mini sparklines dans les listes

Dans les cartes de positions et la watchlist, afficher un mini graphique 7 jours :

```dart
// widgets/mini_sparkline.dart
class MiniSparkline extends StatelessWidget {
  final List<double> prices; // 7 derniers jours
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isPositive = prices.last >= prices.first;
    return CustomPaint(
      size: Size(width, height),
      painter: SparklinePainter(
        prices: prices,
        color: isPositive ? AppTokens.success : AppTokens.error,
      ),
    );
  }
}
```

Pour alimenter les sparklines sans exploser le quota :
- Appel batch `/api/market/history-batch` qui retourne les 7 derniers jours de chaque symbole du portefeuille
- Cache 1h côté backend (l'historique ne change pas souvent)
- 1 seul appel API pour tout le portefeuille

## 5. Animations et polish

### Variation de prix en live
Quand le prix change via SSE, animer la transition :
```dart
// Animation flash vert/rouge quand le prix change
AnimatedSwitcher(
  duration: Duration(milliseconds: 300),
  child: Text(
    formatPrice(currentPrice),
    key: ValueKey(currentPrice),
    style: TextStyle(
      color: priceUp ? AppTokens.success : AppTokens.error,
    ),
  ),
)
```

### État vide (premier lancement)
```
┌──────────────────────────┐
│                          │
│    📊                    │
│    Votre portefeuille    │
│    est vide              │
│                          │
│    Ajoutez vos premières │
│    positions pour suivre │
│    vos investissements   │
│                          │
│    [+ Ajouter un actif]  │
│                          │
└──────────────────────────┘
```

### Loading states
- Skeleton/shimmer pour les cartes de positions pendant le chargement
- Prix "---" avec indicateur de chargement pendant le fetch initial
- Badge "Données retardées 15 min" discret en bas de page

## 6. Notifications de prix (bonus, optionnel)

Fonctionnalité optionnelle pour plus tard :
- L'user définit une alerte : "AAPL > $200" ou "TSLA < $180"
- Le backend vérifie à chaque refresh de cache
- Envoi d'une notification push via Supabase Edge Functions

> Cette feature peut faire l'objet d'une Phase 4 dédiée si besoin.

## Checklist Phase 3

### Backend — Streaming & batch
- [ ] Créer `TwelveDataWebSocketService.cs` (IHostedService)
- [ ] Ajouter endpoint SSE `/api/market/stream/{symbol}`
- [ ] Ajouter endpoint `/api/market/history-batch` pour sparklines

### Frontend — Graphiques & streaming
- [ ] Ajouter `fl_chart` et `url_launcher` dans pubspec.yaml
- [ ] Créer `price_chart.dart` avec sélection de période
- [ ] Créer `mini_sparkline.dart`
- [ ] Créer `price_stream_provider.dart` (SSE)
- [ ] Intégrer les sparklines dans les cartes positions/watchlist

### Frontend — Vue détail enrichie (Finnhub)
- [ ] Créer `company_profile_header.dart` (logo, secteur, market cap)
- [ ] Créer `analyst_gauge.dart` (barre buy/hold/sell)
- [ ] Créer `news_list.dart` (articles récents avec thumbnail)
- [ ] Créer les providers : `companyProfileProvider`, `companyNewsProvider`, `analystRecoProvider`
- [ ] Assembler la vue détail complète (prix + graphique + profil + analystes + news)

### Frontend — Polish
- [ ] Animations de variation de prix (flash vert/rouge)
- [ ] État vide + loading skeletons
- [ ] Badge "Données retardées 15 min"
- [ ] Tester : ouvrir un actif → prix live + profil + news + analystes
- [ ] Tester : vérifier que le quota n'est pas dépassé
