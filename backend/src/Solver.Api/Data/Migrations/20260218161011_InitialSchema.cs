using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Solver.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "app_data_migrations",
                columns: table => new
                {
                    name = table.Column<string>(type: "text", nullable: false),
                    applied_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_app_data_migrations", x => x.name);
                });

            migrationBuilder.CreateTable(
                name: "asset_price_cache",
                columns: table => new
                {
                    symbol = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    exchange = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    price = table.Column<decimal>(type: "numeric(18,8)", precision: 18, scale: 8, nullable: false),
                    previous_close = table.Column<decimal>(type: "numeric(18,8)", precision: 18, scale: 8, nullable: true),
                    change_percent = table.Column<decimal>(type: "numeric(8,4)", precision: 8, scale: 4, nullable: true),
                    currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false, defaultValue: "USD"),
                    fetched_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_asset_price_cache", x => x.symbol);
                });

            migrationBuilder.CreateTable(
                name: "budget_plan_months",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    year = table.Column<int>(type: "integer", nullable: false),
                    month = table.Column<int>(type: "integer", nullable: false),
                    forecast_disposable_income = table.Column<decimal>(type: "numeric", nullable: false),
                    use_gross_income_base = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_budget_plan_months", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "category_groups",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    type = table.Column<string>(type: "text", nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_category_groups", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "portfolio_holdings",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    symbol = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    exchange = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    asset_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "stock"),
                    quantity = table.Column<decimal>(type: "numeric(18,8)", precision: 18, scale: 8, nullable: false),
                    average_buy_price = table.Column<decimal>(type: "numeric(18,8)", precision: 18, scale: 8, nullable: true),
                    buy_date = table.Column<DateOnly>(type: "date", nullable: true),
                    currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false, defaultValue: "USD"),
                    notes = table.Column<string>(type: "text", nullable: true),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_portfolio_holdings", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "saving_goals",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    goal_type = table.Column<string>(type: "text", nullable: false),
                    target_amount = table.Column<decimal>(type: "numeric", nullable: false),
                    target_date = table.Column<DateOnly>(type: "date", nullable: false),
                    initial_amount = table.Column<decimal>(type: "numeric", nullable: false),
                    monthly_contribution = table.Column<decimal>(type: "numeric", nullable: false),
                    auto_contribution_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    auto_contribution_start_date = table.Column<DateOnly>(type: "date", nullable: true),
                    priority = table.Column<int>(type: "integer", nullable: false),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_saving_goals", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "watchlist_items",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    symbol = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    exchange = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    asset_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "stock"),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_watchlist_items", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "accounts",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    type = table.Column<string>(type: "text", nullable: false),
                    group = table.Column<string>(type: "text", nullable: false),
                    group_id = table.Column<Guid>(type: "uuid", nullable: true),
                    is_fixed = table.Column<bool>(type: "boolean", nullable: false),
                    budget = table.Column<decimal>(type: "numeric", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_accounts", x => x.id);
                    table.ForeignKey(
                        name: "FK_accounts_category_groups_group_id",
                        column: x => x.group_id,
                        principalTable: "category_groups",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "budget_plan_group_allocations",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    plan_month_id = table.Column<Guid>(type: "uuid", nullable: false),
                    group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    input_mode = table.Column<string>(type: "text", nullable: false),
                    planned_percent = table.Column<decimal>(type: "numeric", nullable: false),
                    planned_amount = table.Column<decimal>(type: "numeric", nullable: false),
                    priority = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_budget_plan_group_allocations", x => x.id);
                    table.ForeignKey(
                        name: "FK_budget_plan_group_allocations_budget_plan_months_plan_month~",
                        column: x => x.plan_month_id,
                        principalTable: "budget_plan_months",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_budget_plan_group_allocations_category_groups_group_id",
                        column: x => x.group_id,
                        principalTable: "category_groups",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "saving_goal_entries",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    goal_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    entry_date = table.Column<DateOnly>(type: "date", nullable: false),
                    amount = table.Column<decimal>(type: "numeric", nullable: false),
                    note = table.Column<string>(type: "text", nullable: true),
                    is_auto = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_saving_goal_entries", x => x.id);
                    table.ForeignKey(
                        name: "FK_saving_goal_entries_saving_goals_goal_id",
                        column: x => x.goal_id,
                        principalTable: "saving_goals",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "category_preferences",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    is_archived = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_category_preferences", x => new { x.account_id, x.user_id });
                    table.ForeignKey(
                        name: "FK_category_preferences_accounts_account_id",
                        column: x => x.account_id,
                        principalTable: "accounts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "transactions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    date = table.Column<DateOnly>(type: "date", nullable: false),
                    amount = table.Column<decimal>(type: "numeric", nullable: false),
                    note = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "text", nullable: false),
                    is_auto = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_transactions", x => x.id);
                    table.ForeignKey(
                        name: "FK_transactions_accounts_account_id",
                        column: x => x.account_id,
                        principalTable: "accounts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_accounts_group_id",
                table: "accounts",
                column: "group_id");

            migrationBuilder.CreateIndex(
                name: "IX_accounts_user_id",
                table: "accounts",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_accounts_user_id_group_id",
                table: "accounts",
                columns: new[] { "user_id", "group_id" });

            migrationBuilder.CreateIndex(
                name: "IX_asset_price_cache_fetched_at",
                table: "asset_price_cache",
                column: "fetched_at");

            migrationBuilder.CreateIndex(
                name: "IX_budget_plan_group_allocations_group_id",
                table: "budget_plan_group_allocations",
                column: "group_id");

            migrationBuilder.CreateIndex(
                name: "IX_budget_plan_group_allocations_plan_month_id_group_id",
                table: "budget_plan_group_allocations",
                columns: new[] { "plan_month_id", "group_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_budget_plan_group_allocations_user_id",
                table: "budget_plan_group_allocations",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_budget_plan_months_user_id",
                table: "budget_plan_months",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_budget_plan_months_user_id_year_month",
                table: "budget_plan_months",
                columns: new[] { "user_id", "year", "month" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_category_groups_user_id",
                table: "category_groups",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_category_preferences_user_id",
                table: "category_preferences",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_portfolio_holdings_user_id",
                table: "portfolio_holdings",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_portfolio_holdings_user_id_symbol",
                table: "portfolio_holdings",
                columns: new[] { "user_id", "symbol" });

            migrationBuilder.CreateIndex(
                name: "IX_saving_goal_entries_goal_id",
                table: "saving_goal_entries",
                column: "goal_id");

            migrationBuilder.CreateIndex(
                name: "IX_saving_goal_entries_user_id",
                table: "saving_goal_entries",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_saving_goal_entries_user_id_entry_date",
                table: "saving_goal_entries",
                columns: new[] { "user_id", "entry_date" });

            migrationBuilder.CreateIndex(
                name: "IX_saving_goals_user_id",
                table: "saving_goals",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_saving_goals_user_id_priority",
                table: "saving_goals",
                columns: new[] { "user_id", "priority" });

            migrationBuilder.CreateIndex(
                name: "IX_transactions_account_id",
                table: "transactions",
                column: "account_id");

            migrationBuilder.CreateIndex(
                name: "IX_transactions_user_id",
                table: "transactions",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_transactions_user_id_date",
                table: "transactions",
                columns: new[] { "user_id", "date" });

            migrationBuilder.CreateIndex(
                name: "IX_watchlist_items_user_id",
                table: "watchlist_items",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_watchlist_items_user_id_symbol",
                table: "watchlist_items",
                columns: new[] { "user_id", "symbol" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "app_data_migrations");

            migrationBuilder.DropTable(
                name: "asset_price_cache");

            migrationBuilder.DropTable(
                name: "budget_plan_group_allocations");

            migrationBuilder.DropTable(
                name: "category_preferences");

            migrationBuilder.DropTable(
                name: "portfolio_holdings");

            migrationBuilder.DropTable(
                name: "saving_goal_entries");

            migrationBuilder.DropTable(
                name: "transactions");

            migrationBuilder.DropTable(
                name: "watchlist_items");

            migrationBuilder.DropTable(
                name: "budget_plan_months");

            migrationBuilder.DropTable(
                name: "saving_goals");

            migrationBuilder.DropTable(
                name: "accounts");

            migrationBuilder.DropTable(
                name: "category_groups");
        }
    }
}
