# Phase 0 — Schéma de base de données

## Objectif
Créer les tables nécessaires au suivi de portefeuille boursier.

## Nouvelles tables

### 1. `portfolio_holdings`

Position d'un utilisateur sur un actif (action, ETF, crypto).

```sql
CREATE TABLE IF NOT EXISTS portfolio_holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    symbol VARCHAR(20) NOT NULL,          -- ex: "AAPL", "BTC/USD", "MC.PAR"
    exchange VARCHAR(20),                  -- ex: "NASDAQ", "EPA", "crypto"
    name VARCHAR(255),                     -- ex: "Apple Inc.", "Bitcoin"
    asset_type VARCHAR(20) NOT NULL DEFAULT 'stock',  -- stock, etf, crypto, forex
    quantity DECIMAL(18, 8) NOT NULL,      -- 8 décimales pour crypto
    average_buy_price DECIMAL(18, 8),      -- prix moyen d'achat (optionnel)
    buy_date DATE,                         -- date d'achat initiale (optionnel)
    currency VARCHAR(3) DEFAULT 'USD',     -- devise de l'actif
    notes TEXT,                            -- note libre de l'utilisateur
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_holdings_asset_type CHECK (asset_type IN ('stock', 'etf', 'crypto', 'forex')),
    CONSTRAINT chk_holdings_quantity CHECK (quantity > 0)
);

-- Index
CREATE INDEX idx_holdings_user_id ON portfolio_holdings(user_id);
CREATE INDEX idx_holdings_user_symbol ON portfolio_holdings(user_id, symbol);
CREATE UNIQUE INDEX idx_holdings_user_symbol_unique ON portfolio_holdings(user_id, symbol) WHERE NOT is_archived;
```

**Notes de design :**
- `UNIQUE(user_id, symbol) WHERE NOT is_archived` → un user ne peut avoir qu'une seule position active par symbole. S'il veut re-investir, il met à jour la quantité.
- `quantity` en DECIMAL(18,8) pour supporter les fractions de crypto (0.00045 BTC).
- `average_buy_price` est optionnel : l'user peut juste vouloir tracker sans historique d'achat.
- `exchange` permet de désambiguïser les symboles identiques sur différentes bourses.

### 2. `watchlist_items`

Symboles surveillés par l'utilisateur (sans position).

```sql
CREATE TABLE IF NOT EXISTS watchlist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    exchange VARCHAR(20),
    name VARCHAR(255),
    asset_type VARCHAR(20) NOT NULL DEFAULT 'stock',
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_watchlist_asset_type CHECK (asset_type IN ('stock', 'etf', 'crypto', 'forex'))
);

-- Index
CREATE INDEX idx_watchlist_user_id ON watchlist_items(user_id);
CREATE UNIQUE INDEX idx_watchlist_user_symbol ON watchlist_items(user_id, symbol);
```

**Notes de design :**
- Table séparée de `holdings` car le cycle de vie est différent (pas de quantité, pas de prix d'achat).
- `sort_order` pour que l'user puisse ordonner sa watchlist.

### 3. `asset_price_cache`

Cache serveur des prix — **partagé entre tous les utilisateurs**.

```sql
CREATE TABLE IF NOT EXISTS asset_price_cache (
    symbol VARCHAR(20) NOT NULL,
    exchange VARCHAR(20),
    price DECIMAL(18, 8) NOT NULL,
    previous_close DECIMAL(18, 8),        -- clôture veille (pour calcul variation)
    change_percent DECIMAL(8, 4),          -- variation % du jour
    currency VARCHAR(3) DEFAULT 'USD',
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (symbol)
);

-- Index pour nettoyage des prix périmés
CREATE INDEX idx_price_cache_fetched ON asset_price_cache(fetched_at);
```

**Notes de design :**
- Pas de `user_id` : le prix d'Apple est le même pour tout le monde.
- `PRIMARY KEY (symbol)` : un seul enregistrement par symbole, écrasé à chaque refresh.
- `fetched_at` permet au backend de savoir si le cache est frais (< 5 min) ou périmé.
- `previous_close` + `change_percent` pour afficher "+2.3% aujourd'hui" sans appel API supplémentaire.

## Modèles EF Core à créer

### PortfolioHolding.cs
```csharp
namespace Solver.Api.Models;

public class PortfolioHolding
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Symbol { get; set; } = "";
    public string? Exchange { get; set; }
    public string? Name { get; set; }
    public string AssetType { get; set; } = "stock";
    public decimal Quantity { get; set; }
    public decimal? AverageBuyPrice { get; set; }
    public DateOnly? BuyDate { get; set; }
    public string Currency { get; set; } = "USD";
    public string? Notes { get; set; }
    public bool IsArchived { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
```

### WatchlistItem.cs
```csharp
namespace Solver.Api.Models;

public class WatchlistItem
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Symbol { get; set; } = "";
    public string? Exchange { get; set; }
    public string? Name { get; set; }
    public string AssetType { get; set; } = "stock";
    public int SortOrder { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

### AssetPriceCache.cs
```csharp
namespace Solver.Api.Models;

public class AssetPriceCache
{
    public string Symbol { get; set; } = "";
    public string? Exchange { get; set; }
    public decimal Price { get; set; }
    public decimal? PreviousClose { get; set; }
    public decimal? ChangePercent { get; set; }
    public string Currency { get; set; } = "USD";
    public DateTime FetchedAt { get; set; } = DateTime.UtcNow;
}
```

## DbContext — ajouts

```csharp
// Dans SolverDbContext.cs, ajouter :
public DbSet<PortfolioHolding> PortfolioHoldings => Set<PortfolioHolding>();
public DbSet<WatchlistItem> WatchlistItems => Set<WatchlistItem>();
public DbSet<AssetPriceCache> AssetPriceCache => Set<AssetPriceCache>();
```

Configuration Fluent API dans `OnModelCreating` :
```csharp
// PortfolioHolding
modelBuilder.Entity<PortfolioHolding>(e =>
{
    e.ToTable("portfolio_holdings");
    e.HasKey(x => x.Id);
    e.Property(x => x.Symbol).HasMaxLength(20).IsRequired();
    e.Property(x => x.Exchange).HasMaxLength(20);
    e.Property(x => x.AssetType).HasMaxLength(20).HasDefaultValue("stock");
    e.Property(x => x.Quantity).HasPrecision(18, 8);
    e.Property(x => x.AverageBuyPrice).HasPrecision(18, 8);
    e.Property(x => x.Currency).HasMaxLength(3).HasDefaultValue("USD");
    e.HasIndex(x => x.UserId);
    e.HasIndex(x => new { x.UserId, x.Symbol });
});

// WatchlistItem
modelBuilder.Entity<WatchlistItem>(e =>
{
    e.ToTable("watchlist_items");
    e.HasKey(x => x.Id);
    e.Property(x => x.Symbol).HasMaxLength(20).IsRequired();
    e.Property(x => x.Exchange).HasMaxLength(20);
    e.Property(x => x.AssetType).HasMaxLength(20).HasDefaultValue("stock");
    e.HasIndex(x => x.UserId);
    e.HasIndex(x => new { x.UserId, x.Symbol }).IsUnique();
});

// AssetPriceCache
modelBuilder.Entity<AssetPriceCache>(e =>
{
    e.ToTable("asset_price_cache");
    e.HasKey(x => x.Symbol);
    e.Property(x => x.Symbol).HasMaxLength(20);
    e.Property(x => x.Exchange).HasMaxLength(20);
    e.Property(x => x.Price).HasPrecision(18, 8);
    e.Property(x => x.PreviousClose).HasPrecision(18, 8);
    e.Property(x => x.ChangePercent).HasPrecision(8, 4);
    e.Property(x => x.Currency).HasMaxLength(3).HasDefaultValue("USD");
    e.HasIndex(x => x.FetchedAt);
});
```

## RLS (Row Level Security) — Supabase

```sql
-- Holdings : chaque user ne voit que ses positions
ALTER TABLE portfolio_holdings ENABLE ROW LEVEL SECURITY;
CREATE POLICY holdings_user_isolation ON portfolio_holdings
    FOR ALL USING (auth.uid() = user_id);

-- Watchlist : chaque user ne voit que sa watchlist
ALTER TABLE watchlist_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY watchlist_user_isolation ON watchlist_items
    FOR ALL USING (auth.uid() = user_id);

-- Price cache : lecture publique (pas de données sensibles)
ALTER TABLE asset_price_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY price_cache_read_all ON asset_price_cache
    FOR SELECT USING (true);
-- Écriture réservée au service role (backend)
CREATE POLICY price_cache_write_service ON asset_price_cache
    FOR ALL USING (auth.role() = 'service_role');
```

## Checklist Phase 0

- [ ] Créer la migration SQL (via `apply_migration` ou fichier SQL)
- [ ] Ajouter les 3 modèles C# dans `Models/`
- [ ] Mettre à jour `SolverDbContext.cs` avec les DbSets + configuration
- [ ] Appliquer les policies RLS sur Supabase
- [ ] Tester : créer un holding et un watchlist item manuellement en SQL
