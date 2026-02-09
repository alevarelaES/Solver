# **PROJECT SOLVER: Master Technical Specifications**

**Version:** 2.0 (Final Architecture)

**Role:** Senior Fullstack Architect (Flutter & .NET)

**Objective:** Build "Solver", a premium financial SaaS platform.

**Target:** Web First (Desktop/Tablet), responsive for Mobile.

**Language:** UI text in **French**. Code, comments, and commits in **English**.

## **1\. Core Philosophy & Business Rules**

### **1.1 The "Solver" Concept**

Solver combines the data density of a spreadsheet with the rigor of an accounting system. It is designed to eliminate financial anxiety by strictly separating **Real Money** (Bank account today) from **Projected Money** (End of month forecast).

### **1.2 The Two Timelines (Strict Logic)**

1. **Real Balance (Past & Present Validated):**  
   * Formula: Initial Balance \+ Sum of all completed transactions.  
   * **Usage:** Shows the actual cash available *right now*. Displayed in the Top KPI Card.  
2. **Projected Balance (Future):**  
   * Formula: Real Balance \+ Sum of pending transactions (Income \- Expenses).  
   * **Usage:** Shows where the user will land at the end of the month if everything goes according to plan. Displayed in the "Solde Fin de Mois" row.

### **1.3 Immutability**

* An Expense is **ALWAYS** negative (visually red, mathematically negative).  
* An Income is **ALWAYS** positive (visually green, mathematically positive).

## **2\. Technology Stack (The "Bleeding Edge")**

### **2.1 Backend & Database**

* **Language:** **C\# (.NET 10 Preview** or **.NET 9 Stable**).  
* **Framework:** ASP.NET Core **Minimal APIs** (for performance).  
* **Database:** **Supabase** (PostgreSQL).  
* **ORM:** **Entity Framework Core (EF Core)**.  
* **Auth:** **Supabase Auth** (JWT Token validation via Middleware). Extract UserId from claims to enforce data isolation.

### **2.2 Frontend (Flutter)**

* **Channel:** Flutter Web Stable.  
* **State Management:** **Riverpod** (Generator syntax).  
* **Routing:** **GoRouter** (with url\_strategy to remove the \# hash).  
* **Localization:** flutter\_localizations (ARB files).  
* **HTTP Client:** Dio (with Interceptors for Supabase JWT).

## **3\. Data Architecture (SQL Schema)**

### **3.1 Table: Accounts**

Represents financial categories or wallets.

| Column | Type | Constraints | Description |
| :---- | :---- | :---- | :---- |
| Id | UUID | PK | Unique ID. |
| UserId | UUID | Not Null | Multi-tenancy isolation. |
| Name | String | Not Null | Display name (e.g., "Loyer"). |
| Type | Enum | 'income', 'expense' | Flow direction. |
| Group | String | Not Null | Grouping (e.g., "Fixes", "Loisirs"). |
| IsFixed | Bool | Default False | Used for "Disposable Income" calculation. |
| Budget | Decimal | Default 0 | Monthly target amount. |

### **3.2 Table: Transactions**

The ledger entries.

| Column | Type | Constraints | Description |
| :---- | :---- | :---- | :---- |
| Id | UUID | PK | Unique ID. |
| AccountId | UUID | FK \-\> Accounts | Link to category. |
| UserId | UUID | Not Null | Multi-tenancy isolation. |
| Date | Date | Not Null | Transaction date. |
| Amount | Decimal | Not Null | Absolute value. |
| Note | String | Nullable | Description. |
| Status | Enum | 'completed', 'pending' | Payment status. |
| IsAuto | Bool | Default False | True \= Auto-debit, False \= Manual. |

## **4\. Design System: "Deep Glass"**

The UI must replicate a premium, dark-mode, futuristic aesthetic.

* **Background:** Deep Black (\#050505) with fixed ambient, blurred radial gradients (Blue/Purple) behind content layers.  
* **Glass Containers:**  
  * Color: Colors.white.withOpacity(0.05)  
  * Blur: BackdropFilter (Sigma 10\)  
  * Border: Thin 1px white.withOpacity(0.1) or Linear Gradient.  
  * Radius: 24px.  
* **Colors:**  
  * **Primary:** Electric Blue (\#3B82F6).  
  * **Success (Income):** Neon Emerald (\#10B981).  
  * **Danger (Expense):** Soft Red (\#EF4444).  
  * **Pending/Future:** Cool Purple (\#A855F7) or Slate Grey.  
* **Typography:** Modern Sans-Serif (e.g., 'Plus Jakarta Sans'). **Monospace** for all financial numbers.

## **5\. Backend Business Logic (.NET API)**

### **5.1 Endpoint: POST /api/transactions/batch (The Recurrence Engine)**

This is the core feature for planning.

* **Input:** TransactionDto, RecurrenceOptions (StartDate, DayOfMonth).  
* **Logic:**  
  1. Determine current month.  
  2. Loop from StartDate.Month to 12 (December).  
  3. Create a Transaction entity for each month.  
  4. **Date Logic:** Force the specific DayOfMonth (handle Feb 28/29).  
  5. **Status Logic:**  
     * If Month \== Current Month: Use status provided by user.  
     * If Month \> Current Month: **Force status to 'pending'** (Future is always projection).  
  6. **Atomic Save:** Use \_context.Transactions.AddRangeAsync.

### **5.2 Endpoint: GET /api/dashboard (Server-Side Aggregation)**

To keep the frontend light, aggregate the matrix on the server.

* **Input:** Year (int).  
* **Logic:** Group transactions by AccountId and Month.  
* **Returns:** A nested JSON object structure optimized for the grid view.

## **6\. Frontend Features & Views (Flutter Web)**

### **6.1 App Shell (Web First Layout)**

* **Desktop:** Fixed Left Sidebar (Glassmorphic). Content area on the right.  
* **Mobile:** Bottom Navigation Bar (Hidden on Desktop).  
* **Routing:** ShellRoute in GoRouter to maintain the sidebar/bottombar state.

### **6.2 View 1: Dashboard ("Tableau")**

The "Matrix" view.

* **Header:** 4 KPI Cards (Current Real Balance, Income, Expense, "New Transaction" button).  
* **The Grid:**  
  * **Rows:** Accounts grouped by Group (Sticky Headers).  
  * **Columns:** 12 Months.  
  * **Visual Logic (Time-Aware):**  
    * **Past Months:** Background heavily dimmed (Colors.white.withOpacity(0.02)), Text dimmed.  
    * **Current Month:** Highlighted background (Colors.white.withOpacity(0.1)), Bright Text.  
    * **Future Months:** Text in *Italic*.  
  * **Cell Indicators:**  
    * If pending \> 0 in current/past month: Show **Purple Clock Icon**.  
    * Amount color: Red (Expense) / Green (Income).  
* **Footer:** Sticky "Solde Fin de Mois" row (Projected Balance).

### **6.3 View 2: Journal**

A chronological list for audit.

* **Filters (Header):** Dropdowns for Group, Account, Status.  
* **"Show Future" Toggle:** By default, **hide** pending transactions \> current month. Only show history \+ current month pending.  
* **List Groups:** Group items by "Month Year" (e.g., "Mars 2024").  
* **Row Actions:**  
  * **Status Button:**  
    * If completed: Green Check badge.  
    * If pending: "Valider" Button (Outline).  
  * **Validation Logic:** Clicking "Valider" opens a **Confirmation Modal** ("Confirm payment?"). This triggers the API to update status to completed.

### **6.4 View 3: Schedule ("Échéancier")**

The "Radar" for upcoming bills.

* **Filter:** Only fetch status \== 'pending' AND date \>= today.  
* **Split View (Columns):**  
  1. **Auto-Debits:** List of transactions where isAuto \== true. Icon: **Zap/Lightning**. Visuals: Calm Blue.  
  2. **Manual Bills:** List of transactions where isAuto \== false. Icon: **AlertTriangle**. Visuals: Amber/Orange.  
* **Widget:** Display "Next 7 Days" summary on the Dashboard.

### **6.5 View 4: Budget ("Planification")**

The Strategy & Zero-Based Budgeting tool.

* **Top Section (Disposable Income):**  
  * Formula: (Avg Income) \- (Sum of Fixed Accounts Budgets).  
  * Display: Large "Reste à Vivre" number.  
* **Allocator (Groups):**  
  * List of Variable Groups (Loisirs, Vie Quotidienne).  
  * **Bidirectional Input:**  
    * Input A: Amount (CHF).  
    * Input B: Percentage (%).  
    * *Logic:* Changing one updates the other based on Disposable Income.  
  * **Total Bar:** A progress bar showing % of Disposable Income allocated. Turn RED if \> 100%.  
* **Monitoring (Bottom):**  
  * Cards for each Account (Tactical) showing: Real Spent (from API) vs Target Budget.  
  * Progress bars colored by consumption.

### **6.6 View 5: Analysis**

* **Donut Chart:** Expenses by Group.  
* **Trend Chart:** Bar chart (Income/Expense side by side) per month.

### **6.7 Modal: Transaction Form**

* **Type:** Central Dialog (Web) / BottomSheet (Mobile).  
* **Fields:** Account, Date, Amount, Note.  
* **Switches:**  
  * "Prélèvement Automatique" (isAuto): Only for expenses.  
  * "Déjà payé ?" (status): Toggles completed/pending.  
  * **"Répéter jusqu'en Décembre"**:  
    * If checked: Show "Jour du mois" input.  
    * Trigger Batch API endpoint.

## **7\. Development Roadmap**

1. **Backend Setup:** Init .NET 10 solution, EF Core, Postgres connection, Supabase Auth Middleware.  
2. **Flutter Setup:** Init project, Theme (Dark Glass), Router (Web focus), L10n (French).  
3. **Core Feature:** Implement Transaction CRUD and the **Dashboard Matrix** logic (Backend aggregation \+ Frontend rendering).  
4. **Planning Feature:** Implement the **Recurrence Engine** (Batch create) and the **Budget Allocator**.  
5. **Refinement:** Apply "Deep Glass" UI polish, implement filtering, and "Show Future" logic.