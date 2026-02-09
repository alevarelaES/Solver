# 🎯 SOLVER - Plan d'Implémentation Détaillé

**Version:** 1.0
**Date:** 2026-02-09
**Approche:** Incrémentale et validée par phase

---

## 📋 Principes Directeurs

### Bonnes Pratiques Obligatoires
- ✅ **Commits atomiques** : Un commit = une fonctionnalité complète
- ✅ **Tests avant merge** : Valider chaque endpoint/composant
- ✅ **Code en anglais** : Variables, fonctions, commentaires
- ✅ **UI en français** : Tous les textes utilisateur
- ✅ **Git flow** : Feature branches → main
- ✅ **Validation par phase** : Ne passer à la phase suivante qu'après validation complète
- ✅ **Security First** : Jamais de secrets en dur, toujours .env
- ✅ **Performance** : Lazy loading, pagination, indexation DB

---

## 🏗️ Phase 0 : Configuration Environnement

### 0.1 Configuration Supabase
**Objectif:** Créer et configurer le projet Supabase

#### Actions
1. **Créer le projet Supabase**
   - Aller sur [supabase.com](https://supabase.com)
   - Créer un nouveau projet
   - Nom: `solver-production`
   - Région: Choisir la plus proche (EU Central)
   - Mot de passe DB: Générer et stocker en sécurité

2. **Récupérer les credentials**
   - URL du projet
   - `anon` public key
   - `service_role` secret key (pour backend uniquement)
   - Connection string PostgreSQL

3. **Configurer Row Level Security (RLS)**
   ```sql
   -- Activer RLS sur toutes les tables
   ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
   ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

   -- Policy pour accounts
   CREATE POLICY "Users can only access their own accounts"
   ON accounts FOR ALL
   USING (auth.uid() = user_id);

   -- Policy pour transactions
   CREATE POLICY "Users can only access their own transactions"
   ON transactions FOR ALL
   USING (auth.uid() = user_id);
   ```

4. **Configurer l'authentification**
   - Activer Email/Password provider
   - Configurer les redirect URLs pour Flutter Web
   - Désactiver les confirmations email (dev mode) ou configurer SMTP

#### Checklist de validation
- [ ] Projet Supabase créé et accessible
- [ ] Credentials sauvegardés en sécurité (NOT in git)
- [ ] Connection à la DB PostgreSQL testée
- [ ] RLS activé et testé

---

## 🏗️ Phase 1 : Backend Foundation (.NET)

### 1.1 Initialisation du Projet .NET
**Durée estimée:** 2-3h

#### Actions
1. **Créer la solution**
   ```bash
   dotnet new sln -n Solver
   dotnet new webapi -n Solver.Api -o src/Solver.Api
   dotnet sln add src/Solver.Api
   ```

2. **Structure des dossiers**
   ```
   src/
   ├── Solver.Api/
   │   ├── Models/           # Entities EF Core
   │   ├── DTOs/             # Data Transfer Objects
   │   ├── Services/         # Business logic
   │   ├── Data/             # DbContext
   │   ├── Middleware/       # Auth middleware
   │   └── Endpoints/        # Minimal API endpoints
   ```

3. **Installer les packages NuGet**
   ```bash
   cd src/Solver.Api
   dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
   dotnet add package Microsoft.EntityFrameworkCore.Design
   dotnet add package Supabase.Gotrue
   dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
   ```

4. **Configuration appsettings.json**
   ```json
   {
     "ConnectionStrings": {
       "DefaultConnection": "TO_BE_REPLACED_BY_ENV"
     },
     "Supabase": {
       "Url": "TO_BE_REPLACED_BY_ENV",
       "AnonKey": "TO_BE_REPLACED_BY_ENV"
     }
   }
   ```

5. **Créer .env et .env.example**
   ```env
   # .env.example
   SUPABASE_URL=your_project_url
   SUPABASE_ANON_KEY=your_anon_key
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   DB_CONNECTION_STRING=your_postgres_connection_string
   ```

6. **Ajouter .gitignore**
   ```gitignore
   .env
   appsettings.Development.json
   bin/
   obj/
   ```

#### Checklist de validation
- [ ] Solution créée et compilable (`dotnet build`)
- [ ] Structure de dossiers respectée
- [ ] Packages NuGet installés
- [ ] .env.example créé (sans secrets)
- [ ] .gitignore configuré

---

### 1.2 Modèles de Données (EF Core)
**Durée estimée:** 2h

#### Actions
1. **Créer les entités** (`Models/`)

   **Account.cs**
   ```csharp
   public class Account
   {
       public Guid Id { get; set; }
       public Guid UserId { get; set; }
       public string Name { get; set; } = string.Empty;
       public AccountType Type { get; set; }
       public string Group { get; set; } = string.Empty;
       public bool IsFixed { get; set; }
       public decimal Budget { get; set; }
       public DateTime CreatedAt { get; set; }
   }

   public enum AccountType
   {
       Income,
       Expense
   }
   ```

   **Transaction.cs**
   ```csharp
   public class Transaction
   {
       public Guid Id { get; set; }
       public Guid AccountId { get; set; }
       public Guid UserId { get; set; }
       public DateOnly Date { get; set; }
       public decimal Amount { get; set; }
       public string? Note { get; set; }
       public TransactionStatus Status { get; set; }
       public bool IsAuto { get; set; }
       public DateTime CreatedAt { get; set; }

       // Navigation
       public Account Account { get; set; } = null!;
   }

   public enum TransactionStatus
   {
       Completed,
       Pending
   }
   ```

2. **Créer le DbContext** (`Data/SolverDbContext.cs`)
   ```csharp
   public class SolverDbContext : DbContext
   {
       public SolverDbContext(DbContextOptions<SolverDbContext> options)
           : base(options) { }

       public DbSet<Account> Accounts => Set<Account>();
       public DbSet<Transaction> Transactions => Set<Transaction>();

       protected override void OnModelCreating(ModelBuilder modelBuilder)
       {
           modelBuilder.Entity<Account>(entity =>
           {
               entity.ToTable("accounts");
               entity.HasKey(e => e.Id);
               entity.Property(e => e.Type).HasConversion<string>();
               entity.HasIndex(e => e.UserId);
           });

           modelBuilder.Entity<Transaction>(entity =>
           {
               entity.ToTable("transactions");
               entity.HasKey(e => e.Id);
               entity.Property(e => e.Status).HasConversion<string>();
               entity.HasIndex(e => new { e.UserId, e.Date });
               entity.HasIndex(e => e.AccountId);

               entity.HasOne(e => e.Account)
                   .WithMany()
                   .HasForeignKey(e => e.AccountId);
           });
       }
   }
   ```

3. **Créer et appliquer la migration**
   ```bash
   dotnet ef migrations add InitialCreate
   dotnet ef database update
   ```

#### Bonnes pratiques appliquées
- ✅ Navigation properties pour relations
- ✅ Indexes sur UserId et dates (performance)
- ✅ Enums stockés en string (lisibilité DB)
- ✅ DateOnly pour dates (pas de timezone)
- ✅ Naming snake_case pour tables (convention Postgres)

#### Checklist de validation
- [ ] Modèles créés avec toutes les propriétés
- [ ] DbContext configuré avec indexes
- [ ] Migration créée sans erreur
- [ ] Tables visibles dans Supabase Dashboard
- [ ] RLS policies appliquées

---

### 1.3 Middleware d'Authentification
**Durée estimée:** 3h

#### Actions
1. **Créer le middleware JWT** (`Middleware/SupabaseAuthMiddleware.cs`)
   ```csharp
   public class SupabaseAuthMiddleware
   {
       private readonly RequestDelegate _next;

       public SupabaseAuthMiddleware(RequestDelegate next)
       {
           _next = next;
       }

       public async Task InvokeAsync(HttpContext context)
       {
           var token = context.Request.Headers["Authorization"]
               .FirstOrDefault()?.Split(" ").Last();

           if (!string.IsNullOrEmpty(token))
           {
               try
               {
                   // Validate JWT and extract user_id
                   var userId = ValidateTokenAndExtractUserId(token);
                   context.Items["UserId"] = userId;
               }
               catch
               {
                   context.Response.StatusCode = 401;
                   return;
               }
           }

           await _next(context);
       }
   }
   ```

2. **Configuration Program.cs**
   ```csharp
   var builder = WebApplication.CreateBuilder(args);

   // Load .env file
   DotNetEnv.Env.Load();

   // Configure DB
   builder.Services.AddDbContext<SolverDbContext>(options =>
       options.UseNpgsql(Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")));

   // Configure CORS
   builder.Services.AddCors(options =>
   {
       options.AddDefaultPolicy(policy =>
       {
           policy.WithOrigins("http://localhost:*")
               .AllowAnyHeader()
               .AllowAnyMethod();
       });
   });

   var app = builder.Build();

   app.UseCors();
   app.UseMiddleware<SupabaseAuthMiddleware>();

   app.Run();
   ```

#### Checklist de validation
- [ ] Middleware créé et enregistré
- [ ] Token JWT validé correctement
- [ ] UserId extrait dans context
- [ ] Requêtes non-auth retournent 401
- [ ] CORS configuré pour Flutter Web

---

### 1.4 Endpoints CRUD de Base
**Durée estimée:** 4h

#### Actions
1. **Créer les DTOs** (`DTOs/`)
   ```csharp
   public record AccountDto(
       string Name,
       AccountType Type,
       string Group,
       bool IsFixed,
       decimal Budget
   );

   public record TransactionDto(
       Guid AccountId,
       DateOnly Date,
       decimal Amount,
       string? Note,
       TransactionStatus Status,
       bool IsAuto
   );
   ```

2. **Endpoints Accounts** (`Endpoints/AccountsEndpoints.cs`)
   ```csharp
   public static class AccountsEndpoints
   {
       public static void MapAccountsEndpoints(this WebApplication app)
       {
           var group = app.MapGroup("/api/accounts");

           group.MapGet("/", async (SolverDbContext db, HttpContext ctx) =>
           {
               var userId = GetUserId(ctx);
               return await db.Accounts
                   .Where(a => a.UserId == userId)
                   .ToListAsync();
           });

           group.MapPost("/", async (AccountDto dto, SolverDbContext db, HttpContext ctx) =>
           {
               var userId = GetUserId(ctx);
               var account = new Account
               {
                   Id = Guid.NewGuid(),
                   UserId = userId,
                   Name = dto.Name,
                   Type = dto.Type,
                   Group = dto.Group,
                   IsFixed = dto.IsFixed,
                   Budget = dto.Budget,
                   CreatedAt = DateTime.UtcNow
               };

               db.Accounts.Add(account);
               await db.SaveChangesAsync();

               return Results.Created($"/api/accounts/{account.Id}", account);
           });

           // PUT, DELETE similaires...
       }

       private static Guid GetUserId(HttpContext ctx)
       {
           return (Guid)ctx.Items["UserId"]!;
       }
   }
   ```

3. **Endpoints Transactions** (similaire structure)

#### Bonnes pratiques appliquées
- ✅ Minimal APIs groupés par resource
- ✅ DTOs pour validation input
- ✅ UserId extrait du context (isolation)
- ✅ Guid générés côté serveur
- ✅ Timestamps UTC

#### Checklist de validation
- [ ] GET /api/accounts retourne liste filtrée par user
- [ ] POST /api/accounts crée avec UserId correct
- [ ] Endpoints Transactions fonctionnels
- [ ] Impossible d'accéder aux données d'un autre user
- [ ] Testés avec Postman/Thunder Client

---

## 🎨 Phase 2 : Frontend Foundation (Flutter)

### 2.1 Initialisation Flutter Web
**Durée estimée:** 2h

#### Actions
1. **Créer le projet**
   ```bash
   flutter create solver_app --org com.solver --platforms web,ios,android
   cd solver_app
   ```

2. **Configurer pubspec.yaml**
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     flutter_riverpod: ^2.5.1
     riverpod_annotation: ^2.3.5
     go_router: ^14.0.0
     dio: ^5.4.0
     flutter_localizations:
       sdk: flutter
     intl: ^0.19.0
     url_strategy: ^0.3.0
     google_fonts: ^6.1.0

   dev_dependencies:
     flutter_test:
       sdk: flutter
     flutter_lints: ^4.0.0
     riverpod_generator: ^2.3.9
     build_runner: ^2.4.7
   ```

3. **Structure des dossiers**
   ```
   lib/
   ├── core/
   │   ├── theme/          # Deep Glass theme
   │   ├── router/         # GoRouter config
   │   ├── constants/      # Colors, sizes
   │   └── services/       # API client
   ├── features/
   │   ├── auth/
   │   ├── dashboard/
   │   ├── journal/
   │   ├── schedule/
   │   ├── budget/
   │   └── analysis/
   ├── shared/
   │   └── widgets/        # Composants réutilisables
   └── l10n/               # ARB files
   ```

4. **Installer les dépendances**
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

#### Checklist de validation
- [ ] Projet créé et compilable (`flutter run -d chrome`)
- [ ] Structure de dossiers créée
- [ ] Dependencies installées
- [ ] Build runner exécuté sans erreur

---

### 2.2 Configuration Thème "Deep Glass"
**Durée estimée:** 3h

#### Actions
1. **Créer le thème** (`core/theme/app_theme.dart`)
   ```dart
   class AppTheme {
     static const Color deepBlack = Color(0xFF050505);
     static const Color electricBlue = Color(0xFF3B82F6);
     static const Color neonEmerald = Color(0xFF10B981);
     static const Color softRed = Color(0xFFEF4444);
     static const Color coolPurple = Color(0xFFA855F7);

     static ThemeData get darkTheme => ThemeData(
       brightness: Brightness.dark,
       scaffoldBackgroundColor: deepBlack,
       primaryColor: electricBlue,
       colorScheme: ColorScheme.dark(
         primary: electricBlue,
         secondary: coolPurple,
         error: softRed,
         surface: deepBlack,
       ),
       textTheme: GoogleFonts.plusJakartaSansTextTheme(
         ThemeData.dark().textTheme,
       ),
     );
   }
   ```

2. **Glass Container Widget** (`shared/widgets/glass_container.dart`)
   ```dart
   class GlassContainer extends StatelessWidget {
     final Widget child;
     final double blur;
     final Color? borderColor;

     const GlassContainer({
       required this.child,
       this.blur = 10,
       this.borderColor,
     });

     @override
     Widget build(BuildContext context) {
       return ClipRRect(
         borderRadius: BorderRadius.circular(24),
         child: BackdropFilter(
           filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
           child: Container(
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.05),
               borderRadius: BorderRadius.circular(24),
               border: Border.all(
                 color: borderColor ?? Colors.white.withOpacity(0.1),
                 width: 1,
               ),
             ),
             child: child,
           ),
         ),
       );
     }
   }
   ```

#### Checklist de validation
- [ ] Thème appliqué globalement
- [ ] GlassContainer fonctionnel avec blur
- [ ] Couleurs conformes au spec
- [ ] Police Plus Jakarta Sans chargée

---

### 2.3 Configuration Router & Navigation
**Durée estimée:** 2h

#### Actions
1. **Créer le router** (`core/router/app_router.dart`)
   ```dart
   final goRouterProvider = Provider<GoRouter>((ref) {
     return GoRouter(
       initialLocation: '/dashboard',
       routes: [
         ShellRoute(
           builder: (context, state, child) {
             return AppShell(child: child);
           },
           routes: [
             GoRoute(
               path: '/dashboard',
               builder: (context, state) => const DashboardView(),
             ),
             GoRoute(
               path: '/journal',
               builder: (context, state) => const JournalView(),
             ),
             // Autres routes...
           ],
         ),
       ],
     );
   });
   ```

2. **App Shell responsive** (`shared/widgets/app_shell.dart`)
   ```dart
   class AppShell extends StatelessWidget {
     final Widget child;

     @override
     Widget build(BuildContext context) {
       final isDesktop = MediaQuery.of(context).size.width > 768;

       return Scaffold(
         body: Row(
           children: [
             if (isDesktop) const DesktopSidebar(),
             Expanded(child: child),
           ],
         ),
         bottomNavigationBar: isDesktop ? null : const MobileBottomBar(),
       );
     }
   }
   ```

#### Checklist de validation
- [ ] Navigation fonctionnelle entre vues
- [ ] Sidebar visible sur desktop
- [ ] Bottom bar visible sur mobile
- [ ] URL sans # (url_strategy configuré)

---

### 2.4 Configuration API Client (Dio + Supabase)
**Durée estimée:** 3h

#### Actions
1. **Service API** (`core/services/api_client.dart`)
   ```dart
   @riverpod
   Dio dio(DioRef ref) {
     final dio = Dio(BaseOptions(
       baseUrl: 'http://localhost:5000/api',
       headers: {'Content-Type': 'application/json'},
     ));

     dio.interceptors.add(InterceptorsWrapper(
       onRequest: (options, handler) async {
         // Récupérer token Supabase
         final token = await ref.read(authTokenProvider.future);
         if (token != null) {
           options.headers['Authorization'] = 'Bearer $token';
         }
         handler.next(options);
       },
     ));

     return dio;
   }
   ```

2. **Auth Provider** (`features/auth/providers/auth_provider.dart`)
   ```dart
   @riverpod
   class AuthToken extends _$AuthToken {
     @override
     Future<String?> build() async {
       // TODO: Intégration Supabase Auth
       return null;
     }
   }
   ```

#### Checklist de validation
- [ ] Dio configuré avec baseUrl
- [ ] Interceptor ajoute le token JWT
- [ ] Requêtes testées avec backend local
- [ ] Gestion 401 (token expiré)

---

## 🚀 Phase 3 : Feature Core - Dashboard

### 3.1 Backend - Endpoint Dashboard
**Durée estimée:** 4h

#### Actions
1. **DTO Dashboard** (`DTOs/DashboardDto.cs`)
   ```csharp
   public record DashboardResponse(
       decimal CurrentBalance,
       decimal MonthlyIncome,
       decimal MonthlyExpenses,
       Dictionary<string, GroupData> Groups
   );

   public record GroupData(
       string GroupName,
       List<AccountMonthlyData> Accounts
   );

   public record AccountMonthlyData(
       Guid AccountId,
       string AccountName,
       Dictionary<int, MonthCell> Months // Key = month number (1-12)
   );

   public record MonthCell(
       decimal TotalAmount,
       int PendingCount,
       int CompletedCount
   );
   ```

2. **Service Dashboard** (`Services/DashboardService.cs`)
   ```csharp
   public class DashboardService
   {
       private readonly SolverDbContext _db;

       public async Task<DashboardResponse> GetDashboardDataAsync(Guid userId, int year)
       {
           // Récupérer toutes les transactions de l'année
           var transactions = await _db.Transactions
               .Include(t => t.Account)
               .Where(t => t.UserId == userId && t.Date.Year == year)
               .ToListAsync();

           // Grouper par Account et Month
           var grouped = transactions
               .GroupBy(t => t.Account.Group)
               .ToDictionary(
                   g => g.Key,
                   g => BuildGroupData(g)
               );

           // Calculer KPIs
           var currentBalance = CalculateRealBalance(userId);
           var monthlyIncome = CalculateMonthlyIncome(transactions);
           var monthlyExpenses = CalculateMonthlyExpenses(transactions);

           return new DashboardResponse(
               currentBalance,
               monthlyIncome,
               monthlyExpenses,
               grouped
           );
       }
   }
   ```

3. **Endpoint** (`Endpoints/DashboardEndpoints.cs`)
   ```csharp
   group.MapGet("/", async (
       int year,
       SolverDbContext db,
       HttpContext ctx) =>
   {
       var userId = GetUserId(ctx);
       var service = new DashboardService(db);
       return await service.GetDashboardDataAsync(userId, year);
   });
   ```

#### Bonnes pratiques appliquées
- ✅ Aggregation côté serveur (performance)
- ✅ Service layer pour business logic
- ✅ Include() pour éviter N+1 queries
- ✅ DTO structuré pour frontend

#### Checklist de validation
- [ ] Endpoint retourne JSON structuré
- [ ] Aggregation correcte par mois
- [ ] KPIs calculés correctement
- [ ] Performance <500ms avec 1000 transactions

---

### 3.2 Frontend - Grille Dashboard
**Durée estimée:** 6h

#### Actions
1. **Provider Dashboard** (`features/dashboard/providers/dashboard_provider.dart`)
   ```dart
   @riverpod
   Future<DashboardData> dashboardData(
     DashboardDataRef ref,
     int year,
   ) async {
     final dio = ref.watch(dioProvider);
     final response = await dio.get('/dashboard', queryParameters: {'year': year});
     return DashboardData.fromJson(response.data);
   }
   ```

2. **Widget Grille** (`features/dashboard/widgets/dashboard_grid.dart`)
   ```dart
   class DashboardGrid extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final data = ref.watch(dashboardDataProvider(2026));

       return data.when(
         loading: () => const CircularProgressIndicator(),
         error: (err, stack) => Text('Erreur: $err'),
         data: (dashboard) => SingleChildScrollView(
           scrollDirection: Axis.horizontal,
           child: DataTable(
             columns: _buildMonthColumns(),
             rows: _buildAccountRows(dashboard),
           ),
         ),
       );
     }
   }
   ```

3. **Logique Time-Aware**
   ```dart
   Color _getCellBackground(int month) {
     final now = DateTime.now();
     if (month < now.month) {
       return Colors.white.withOpacity(0.02); // Passé
     } else if (month == now.month) {
       return Colors.white.withOpacity(0.1); // Présent
     } else {
       return Colors.transparent; // Futur
     }
   }

   TextStyle _getCellTextStyle(int month) {
     final now = DateTime.now();
     return TextStyle(
       fontStyle: month > now.month ? FontStyle.italic : FontStyle.normal,
       color: month < now.month
         ? Colors.white.withOpacity(0.5)
         : Colors.white,
     );
   }
   ```

#### Checklist de validation
- [ ] Grille 12 colonnes (mois) affichée
- [ ] Groupes avec sticky headers
- [ ] Couleurs passé/présent/futur correctes
- [ ] Montants en rouge (dépenses) / vert (revenus)
- [ ] Icône horloge pour pending
- [ ] Responsive (scroll horizontal)

---

### 3.3 KPI Cards & Footer
**Durée estimée:** 3h

#### Actions
1. **Widget KPI Card** (`shared/widgets/kpi_card.dart`)
   ```dart
   class KpiCard extends StatelessWidget {
     final String label;
     final String value;
     final Color color;
     final IconData icon;

     @override
     Widget build(BuildContext context) {
       return GlassContainer(
         child: Padding(
           padding: const EdgeInsets.all(24),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Icon(icon, color: color, size: 32),
               const SizedBox(height: 12),
               Text(
                 label,
                 style: TextStyle(
                   color: Colors.white.withOpacity(0.7),
                   fontSize: 14,
                 ),
               ),
               const SizedBox(height: 8),
               Text(
                 value,
                 style: TextStyle(
                   color: color,
                   fontSize: 32,
                   fontWeight: FontWeight.bold,
                   fontFamily: 'RobotoMono', // Monospace
                 ),
               ),
             ],
           ),
         ),
       );
     }
   }
   ```

2. **Header Dashboard**
   ```dart
   Row(
     children: [
       Expanded(
         child: KpiCard(
           label: 'Solde Actuel',
           value: formatCurrency(dashboard.currentBalance),
           color: AppTheme.electricBlue,
           icon: Icons.account_balance_wallet,
         ),
       ),
       // 3 autres KPI cards...
     ],
   )
   ```

3. **Footer Sticky**
   ```dart
   // Utiliser sticky_headers package ou custom implementation
   StickyHeader(
     header: Container(
       color: AppTheme.deepBlack,
       child: Row(
         children: [
           Text('Solde Fin de Mois'),
           ...List.generate(12, (i) =>
             Text(formatCurrency(projectedBalances[i]))
           ),
         ],
       ),
     ),
     content: const SizedBox.shrink(),
   );
   ```

#### Checklist de validation
- [ ] 4 KPI cards affichées en header
- [ ] Footer sticky visible au scroll
- [ ] Montants formatés (CHF, 2 décimales)
- [ ] Police monospace pour chiffres

---

## 🔄 Phase 4 : Moteur de Récurrence

### 4.1 Backend - Batch Endpoint
**Durée estimée:** 4h

#### Actions
1. **DTO Récurrence**
   ```csharp
   public record RecurrenceOptions(
       DateOnly StartDate,
       int DayOfMonth
   );

   public record BatchTransactionRequest(
       TransactionDto Transaction,
       RecurrenceOptions Recurrence
   );
   ```

2. **Service Récurrence** (`Services/RecurrenceService.cs`)
   ```csharp
   public class RecurrenceService
   {
       public List<Transaction> GenerateRecurringTransactions(
           BatchTransactionRequest request,
           Guid userId)
       {
           var transactions = new List<Transaction>();
           var currentMonth = DateTime.UtcNow.Month;

           for (int month = request.Recurrence.StartDate.Month; month <= 12; month++)
           {
               var date = CreateDateForMonth(
                   request.Recurrence.StartDate.Year,
                   month,
                   request.Recurrence.DayOfMonth
               );

               var status = month == currentMonth
                   ? request.Transaction.Status
                   : TransactionStatus.Pending;

               transactions.Add(new Transaction
               {
                   Id = Guid.NewGuid(),
                   AccountId = request.Transaction.AccountId,
                   UserId = userId,
                   Date = date,
                   Amount = request.Transaction.Amount,
                   Note = request.Transaction.Note,
                   Status = status,
                   IsAuto = request.Transaction.IsAuto,
                   CreatedAt = DateTime.UtcNow
               });
           }

           return transactions;
       }

       private DateOnly CreateDateForMonth(int year, int month, int dayOfMonth)
       {
           // Handle Feb 28/29
           var maxDay = DateTime.DaysInMonth(year, month);
           var day = Math.Min(dayOfMonth, maxDay);
           return new DateOnly(year, month, day);
       }
   }
   ```

3. **Endpoint**
   ```csharp
   group.MapPost("/batch", async (
       BatchTransactionRequest request,
       SolverDbContext db,
       HttpContext ctx) =>
   {
       var userId = GetUserId(ctx);
       var service = new RecurrenceService();

       var transactions = service.GenerateRecurringTransactions(request, userId);

       await db.Transactions.AddRangeAsync(transactions);
       await db.SaveChangesAsync();

       return Results.Ok(new { Count = transactions.Count });
   });
   ```

#### Bonnes pratiques appliquées
- ✅ Logique métier isolée dans service
- ✅ Gestion Feb 28/29
- ✅ AddRangeAsync pour performance
- ✅ Status forcé à pending pour mois futurs

#### Checklist de validation
- [ ] Endpoint crée N transactions (N = mois restants)
- [ ] Dates correctes (jour du mois respecté)
- [ ] Status logique (current = user choice, future = pending)
- [ ] Gestion Février (28/29 jours)
- [ ] Transaction atomique (rollback si erreur)

---

### 4.2 Frontend - Modal Transaction
**Durée estimée:** 5h

#### Actions
1. **Widget Modal** (`features/dashboard/widgets/transaction_form.dart`)
   ```dart
   class TransactionFormModal extends ConsumerStatefulWidget {
     @override
     ConsumerState<TransactionFormModal> createState() => _TransactionFormModalState();
   }

   class _TransactionFormModalState extends ConsumerState<TransactionFormModal> {
     final _formKey = GlobalKey<FormState>();
     Guid? selectedAccountId;
     DateTime selectedDate = DateTime.now();
     double amount = 0;
     String note = '';
     bool isAuto = false;
     bool isCompleted = false;
     bool repeatUntilDecember = false;
     int dayOfMonth = 1;

     @override
     Widget build(BuildContext context) {
       return Dialog(
         child: GlassContainer(
           child: Padding(
             padding: const EdgeInsets.all(32),
             child: Form(
               key: _formKey,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   // Account Dropdown
                   DropdownButtonFormField<Guid>(
                     items: _buildAccountItems(),
                     onChanged: (value) => setState(() => selectedAccountId = value),
                     decoration: InputDecoration(labelText: 'Compte'),
                   ),

                   // Date Picker
                   TextFormField(
                     decoration: InputDecoration(labelText: 'Date'),
                     onTap: () => _pickDate(),
                   ),

                   // Amount
                   TextFormField(
                     decoration: InputDecoration(labelText: 'Montant (CHF)'),
                     keyboardType: TextInputType.number,
                     onChanged: (value) => amount = double.tryParse(value) ?? 0,
                   ),

                   // Note
                   TextFormField(
                     decoration: InputDecoration(labelText: 'Note'),
                     onChanged: (value) => note = value,
                   ),

                   // Switches
                   SwitchListTile(
                     title: Text('Prélèvement automatique'),
                     value: isAuto,
                     onChanged: (value) => setState(() => isAuto = value),
                   ),

                   SwitchListTile(
                     title: Text('Déjà payé ?'),
                     value: isCompleted,
                     onChanged: (value) => setState(() => isCompleted = value),
                   ),

                   SwitchListTile(
                     title: Text('Répéter jusqu\'en Décembre'),
                     value: repeatUntilDecember,
                     onChanged: (value) => setState(() => repeatUntilDecember = value),
                   ),

                   if (repeatUntilDecember)
                     TextFormField(
                       decoration: InputDecoration(labelText: 'Jour du mois'),
                       keyboardType: TextInputType.number,
                       initialValue: '1',
                       onChanged: (value) => dayOfMonth = int.tryParse(value) ?? 1,
                     ),

                   // Submit Button
                   ElevatedButton(
                     onPressed: _submit,
                     child: Text('Créer'),
                   ),
                 ],
               ),
             ),
           ),
         ),
       );
     }

     Future<void> _submit() async {
       if (!_formKey.currentState!.validate()) return;

       final endpoint = repeatUntilDecember
         ? '/transactions/batch'
         : '/transactions';

       final payload = repeatUntilDecember
         ? {
             'transaction': _buildTransactionDto(),
             'recurrence': {
               'startDate': selectedDate.toIso8601String(),
               'dayOfMonth': dayOfMonth,
             }
           }
         : _buildTransactionDto();

       try {
         await ref.read(dioProvider).post(endpoint, data: payload);
         Navigator.of(context).pop();
         ref.invalidate(dashboardDataProvider);
       } catch (e) {
         // Show error
       }
     }
   }
   ```

#### Checklist de validation
- [ ] Modal s'ouvre avec bouton "Nouvelle Transaction"
- [ ] Tous les champs fonctionnels
- [ ] Switch "Répéter" affiche champ "Jour du mois"
- [ ] Submit appelle bon endpoint (simple vs batch)
- [ ] Dashboard refresh après création
- [ ] Validation formulaire (montant > 0, etc.)

---

## 📊 Phase 5 : Vues Secondaires

### 5.1 Journal View
**Durée estimée:** 4h

#### Actions
1. **Backend - Endpoint filtré**
   ```csharp
   group.MapGet("/", async (
       Guid? accountId,
       TransactionStatus? status,
       bool showFuture,
       SolverDbContext db,
       HttpContext ctx) =>
   {
       var userId = GetUserId(ctx);
       var query = db.Transactions
           .Include(t => t.Account)
           .Where(t => t.UserId == userId);

       if (accountId.HasValue)
           query = query.Where(t => t.AccountId == accountId.Value);

       if (status.HasValue)
           query = query.Where(t => t.Status == status.Value);

       if (!showFuture)
       {
           var today = DateOnly.FromDateTime(DateTime.UtcNow);
           query = query.Where(t =>
               t.Date <= today ||
               (t.Status == TransactionStatus.Pending && t.Date.Month == today.Month)
           );
       }

       return await query
           .OrderByDescending(t => t.Date)
           .ToListAsync();
   });
   ```

2. **Frontend - List View**
   ```dart
   class JournalView extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final transactions = ref.watch(journalTransactionsProvider);

       return Column(
         children: [
           // Filters
           Row(
             children: [
               DropdownButton(/* Account filter */),
               DropdownButton(/* Status filter */),
               Switch(
                 value: ref.watch(showFutureProvider),
                 onChanged: (value) => ref.read(showFutureProvider.notifier).state = value,
               ),
             ],
           ),

           // Grouped List
           Expanded(
             child: transactions.when(
               data: (data) => ListView.builder(
                 itemCount: data.length,
                 itemBuilder: (context, index) {
                   final transaction = data[index];
                   return TransactionListTile(transaction: transaction);
                 },
               ),
               loading: () => CircularProgressIndicator(),
               error: (err, stack) => Text('Erreur: $err'),
             ),
           ),
         ],
       );
     }
   }
   ```

#### Checklist de validation
- [ ] Filtres fonctionnels (Account, Status)
- [ ] Toggle "Show Future" cache/affiche correctement
- [ ] Groupement par mois
- [ ] Badge statut (vert completed, bouton pending)
- [ ] Modal confirmation sur "Valider"

---

### 5.2 Schedule View (Échéancier)
**Durée estimée:** 3h

#### Actions
1. **Backend - Endpoint upcoming**
   ```csharp
   group.MapGet("/upcoming", async (SolverDbContext db, HttpContext ctx) =>
   {
       var userId = GetUserId(ctx);
       var today = DateOnly.FromDateTime(DateTime.UtcNow);

       return await db.Transactions
           .Include(t => t.Account)
           .Where(t =>
               t.UserId == userId &&
               t.Status == TransactionStatus.Pending &&
               t.Date >= today
           )
           .OrderBy(t => t.Date)
           .ToListAsync();
   });
   ```

2. **Frontend - Split View**
   ```dart
   class ScheduleView extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final upcoming = ref.watch(upcomingTransactionsProvider);

       return upcoming.when(
         data: (transactions) {
           final auto = transactions.where((t) => t.isAuto).toList();
           final manual = transactions.where((t) => !t.isAuto).toList();

           return Row(
             children: [
               Expanded(
                 child: ScheduleColumn(
                   title: 'Prélèvements Auto',
                   icon: Icons.bolt,
                   color: AppTheme.electricBlue,
                   transactions: auto,
                 ),
               ),
               Expanded(
                 child: ScheduleColumn(
                   title: 'Factures Manuelles',
                   icon: Icons.warning_amber,
                   color: Colors.orange,
                   transactions: manual,
                 ),
               ),
             ],
           );
         },
         loading: () => CircularProgressIndicator(),
         error: (err, stack) => Text('Erreur: $err'),
       );
     }
   }
   ```

#### Checklist de validation
- [ ] Split 2 colonnes (auto/manuel)
- [ ] Icônes différenciées
- [ ] Tri par date croissante
- [ ] Widget "Next 7 Days" sur Dashboard

---

### 5.3 Budget View (Planification)
**Durée estimée:** 6h

#### Actions
1. **Backend - Endpoint stats**
   ```csharp
   group.MapGet("/budget-stats", async (SolverDbContext db, HttpContext ctx) =>
   {
       var userId = GetUserId(ctx);
       var currentMonth = DateTime.UtcNow.Month;

       // Calculate average income
       var avgIncome = await db.Transactions
           .Where(t =>
               t.UserId == userId &&
               t.Account.Type == AccountType.Income &&
               t.Status == TransactionStatus.Completed
           )
           .GroupBy(t => t.Date.Month)
           .Select(g => g.Sum(t => t.Amount))
           .AverageAsync();

       // Fixed accounts budgets
       var fixedBudgets = await db.Accounts
           .Where(a => a.UserId == userId && a.IsFixed)
           .SumAsync(a => a.Budget);

       // Real spent per account (current month)
       var spent = await db.Transactions
           .Where(t =>
               t.UserId == userId &&
               t.Date.Month == currentMonth &&
               t.Status == TransactionStatus.Completed
           )
           .GroupBy(t => t.AccountId)
           .Select(g => new {
               AccountId = g.Key,
               TotalSpent = g.Sum(t => t.Amount)
           })
           .ToListAsync();

       return new {
           AverageIncome = avgIncome,
           FixedBudgets = fixedBudgets,
           DisposableIncome = avgIncome - fixedBudgets,
           SpentByAccount = spent
       };
   });
   ```

2. **Frontend - Allocator**
   ```dart
   class BudgetAllocator extends ConsumerStatefulWidget {
     @override
     ConsumerState<BudgetAllocator> createState() => _BudgetAllocatorState();
   }

   class _BudgetAllocatorState extends ConsumerState<BudgetAllocator> {
     Map<String, double> allocations = {};

     @override
     Widget build(BuildContext context) {
       final stats = ref.watch(budgetStatsProvider);

       return stats.when(
         data: (data) {
           final disposable = data.disposableIncome;

           return Column(
             children: [
               // Top Section
               GlassContainer(
                 child: Column(
                   children: [
                     Text(
                       'Reste à Vivre',
                       style: TextStyle(fontSize: 18),
                     ),
                     Text(
                       formatCurrency(disposable),
                       style: TextStyle(
                         fontSize: 48,
                         fontWeight: FontWeight.bold,
                         color: AppTheme.neonEmerald,
                       ),
                     ),
                   ],
                 ),
               ),

               // Allocator
               ...variableGroups.map((group) =>
                 AllocationRow(
                   group: group,
                   disposable: disposable,
                   onChanged: (amount, percent) {
                     setState(() => allocations[group] = amount);
                   },
                 )
               ),

               // Progress Bar
               LinearProgressIndicator(
                 value: _totalAllocated() / disposable,
                 color: _totalAllocated() > disposable
                   ? AppTheme.softRed
                   : AppTheme.neonEmerald,
               ),

               // Monitoring Cards
               Wrap(
                 children: accounts.map((account) =>
                   BudgetMonitorCard(
                     account: account,
                     spent: data.spentByAccount[account.id] ?? 0,
                     budget: account.budget,
                   )
                 ).toList(),
               ),
             ],
           );
         },
         loading: () => CircularProgressIndicator(),
         error: (err, stack) => Text('Erreur: $err'),
       );
     }

     double _totalAllocated() {
       return allocations.values.fold(0, (sum, val) => sum + val);
     }
   }
   ```

#### Checklist de validation
- [ ] Reste à Vivre calculé correctement
- [ ] Inputs bidirectionnels (CHF ↔ %)
- [ ] Progress bar rouge si > 100%
- [ ] Cards monitoring avec progress bars
- [ ] Sauvegarde des budgets dans DB

---

### 5.4 Analysis View
**Durée estimée:** 4h

#### Actions
1. **Backend - Endpoint aggregations**
   ```csharp
   group.MapGet("/analysis", async (
       int year,
       SolverDbContext db,
       HttpContext ctx) =>
   {
       var userId = GetUserId(ctx);

       // Expenses by Group (for donut chart)
       var byGroup = await db.Transactions
           .Include(t => t.Account)
           .Where(t =>
               t.UserId == userId &&
               t.Date.Year == year &&
               t.Account.Type == AccountType.Expense &&
               t.Status == TransactionStatus.Completed
           )
           .GroupBy(t => t.Account.Group)
           .Select(g => new {
               Group = g.Key,
               Total = g.Sum(t => t.Amount)
           })
           .ToListAsync();

       // Income/Expense by Month (for bar chart)
       var byMonth = await db.Transactions
           .Include(t => t.Account)
           .Where(t =>
               t.UserId == userId &&
               t.Date.Year == year &&
               t.Status == TransactionStatus.Completed
           )
           .GroupBy(t => new { t.Date.Month, t.Account.Type })
           .Select(g => new {
               Month = g.Key.Month,
               Type = g.Key.Type,
               Total = g.Sum(t => t.Amount)
           })
           .ToListAsync();

       return new {
           ByGroup = byGroup,
           ByMonth = byMonth
       };
   });
   ```

2. **Frontend - Charts** (utiliser fl_chart package)
   ```dart
   class AnalysisView extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final data = ref.watch(analysisDataProvider(2026));

       return data.when(
         data: (analysis) => Column(
           children: [
             // Donut Chart
             Expanded(
               child: PieChart(
                 PieChartData(
                   sections: analysis.byGroup.map((item) =>
                     PieChartSectionData(
                       value: item.total,
                       title: item.group,
                       color: _getGroupColor(item.group),
                     )
                   ).toList(),
                 ),
               ),
             ),

             // Bar Chart
             Expanded(
               child: BarChart(
                 BarChartData(
                   barGroups: _buildBarGroups(analysis.byMonth),
                 ),
               ),
             ),
           ],
         ),
         loading: () => CircularProgressIndicator(),
         error: (err, stack) => Text('Erreur: $err'),
       );
     }
   }
   ```

#### Checklist de validation
- [ ] Donut chart avec groupes de dépenses
- [ ] Bar chart income/expense par mois
- [ ] Couleurs cohérentes avec design system
- [ ] Responsive

---

## 🎨 Phase 6 : Polish & Optimisation

### 6.1 Responsive Design
**Durée estimée:** 3h

#### Actions
- Tester sur 3 breakpoints : Mobile (<768px), Tablet (768-1024px), Desktop (>1024px)
- Adapter Dashboard grid (scroll horizontal mobile)
- Modal → BottomSheet sur mobile
- Police sizes adaptatives

#### Checklist
- [ ] Testé sur iPhone SE
- [ ] Testé sur iPad
- [ ] Testé sur Desktop 1920px
- [ ] Aucun overflow

---

### 6.2 Animations & Micro-interactions
**Durée estimée:** 2h

#### Actions
- Hover effects sur glass containers
- Fade-in au chargement des KPI cards
- Ripple effect sur boutons
- Smooth scroll dans grille

---

### 6.3 Tests Unitaires (Critiques)
**Durée estimée:** 4h

#### Backend Tests
```csharp
[Fact]
public async Task RecurrenceService_GeneratesCorrectNumberOfTransactions()
{
    // Arrange
    var service = new RecurrenceService();
    var request = new BatchTransactionRequest(/* ... */);

    // Act
    var result = service.GenerateRecurringTransactions(request, userId);

    // Assert
    Assert.Equal(expectedCount, result.Count);
}
```

#### Frontend Tests
```dart
void main() {
  testWidgets('Dashboard displays KPI cards', (tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.byType(KpiCard), findsNWidgets(4));
  });
}
```

#### Checklist
- [ ] RecurrenceService tested
- [ ] DashboardService tested
- [ ] AuthMiddleware tested
- [ ] Critical widgets tested

---

### 6.4 Documentation
**Durée estimée:** 2h

#### Actions
1. **README.md**
   - Setup instructions
   - Environment variables
   - Run commands

2. **API_DOCUMENTATION.md**
   - Tous les endpoints
   - Request/Response examples
   - Auth flow

3. **ARCHITECTURE.md**
   - Diagram backend/frontend
   - Data flow
   - Design decisions

---

## 📦 Checklist Finale

### Backend
- [ ] .NET 10 solution fonctionnelle
- [ ] Supabase connecté avec RLS
- [ ] Auth middleware validé
- [ ] Tous endpoints CRUD testés
- [ ] Batch endpoint fonctionnel
- [ ] Aggregations performantes
- [ ] Tests unitaires passent

### Frontend
- [ ] Flutter Web déployable
- [ ] Deep Glass theme appliqué
- [ ] 5 vues fonctionnelles
- [ ] Routing sans #
- [ ] Localization française
- [ ] Responsive 3 breakpoints
- [ ] State management Riverpod
- [ ] API calls avec Dio + JWT

### DevOps
- [ ] .env.example créé
- [ ] .gitignore complet
- [ ] README complet
- [ ] Commits atomiques
- [ ] Branches feature mergées

---

## 🚀 Ordre d'Exécution Recommandé

1. **Semaine 1** : Phase 0 + Phase 1 (Backend foundation)
2. **Semaine 2** : Phase 2 (Frontend foundation)
3. **Semaine 3** : Phase 3 (Dashboard core)
4. **Semaine 4** : Phase 4 (Récurrence)
5. **Semaine 5** : Phase 5 (Vues secondaires)
6. **Semaine 6** : Phase 6 (Polish)

---

## ⚠️ Pièges à Éviter

1. **Ne pas skip RLS** : Toujours tester l'isolation multi-tenant
2. **Ne pas oublier les indexes** : Performance critique sur UserId et Date
3. **Ne pas exposer secrets** : Jamais de .env dans git
4. **Ne pas négliger CORS** : Configurer dès le départ pour Flutter Web
5. **Ne pas ignorer les timezones** : Toujours UTC côté serveur, conversion client-side
6. **Ne pas créer de N+1 queries** : Toujours utiliser Include() avec EF Core
7. **Ne pas skip la validation** : DTOs avec DataAnnotations
8. **Ne pas hardcoder les URLs** : Environment variables partout

---

**Prochaine étape recommandée :** Commencer par **Phase 0.1 - Configuration Supabase**

Valider cette étape avant de passer au backend .NET.
