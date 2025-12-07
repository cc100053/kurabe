Act as a Senior Product Designer. I want to balance my Bottom Navigation Bar by adding a 4th Tab. Use the same design to keep consistency.

**Current Problem:**
3 Tabs + 1 Center FAB creates an asymmetrical layout (2 items on left, 1 on right).

**Solution:**
Add a new tab to create a symmetrical **2-1-2 layout**:
`[Timeline] [Catalog] --(SCAN)-- [Shopping List] [Profile]`

**Task 1: Create the "Shopping List" Placeholder**
- Create a new file `@shopping_list_screen.dart`.
- For now, just make it a simple `Scaffold` with a title "Shopping List" (買い物リスト) and a placeholder "Coming Soon" UI.
- Use `PhosphorIcons.checkSquare` (or `listChecks`) as the icon.

**Task 2: Update Main Scaffold (`@main_scaffold.dart`)**
- Update the `NavigationBar` items list to include this new tab at index 2 (shifting Profile to index 3).
- **Critical Layout Adjustment:**
  - Ensure the `FloatingActionButton` (Scan) is docked in the center.
  - Configure the `BottomAppBar` (or NavigationBar) to have a "notch" or gap for the FAB, strictly enforcing the 2-items-left and 2-items-right split.
  - If using a standard `NavigationBar`, ensure the sequence is: `Timeline, Catalog, (Gap), ShoppingList, Profile`.

**Task 3: About database**
- tell me if anything I have to change on supabase, like create new table, etc.

**Visual Goal:**
Achieve perfect visual symmetry.