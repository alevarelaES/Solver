-- Widen varchar columns in portfolio/watchlist tables that were too narrow
-- for real-world exchange names (e.g. "NASDAQ Global Select Market")

ALTER TABLE portfolio_holdings
  ALTER COLUMN symbol     TYPE varchar(30),
  ALTER COLUMN exchange   TYPE varchar(100);

ALTER TABLE watchlist_items
  ALTER COLUMN symbol     TYPE varchar(30),
  ALTER COLUMN exchange   TYPE varchar(100);

ALTER TABLE asset_price_cache
  ALTER COLUMN symbol     TYPE varchar(30);
