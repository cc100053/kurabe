Act as a Senior Flutter Engineer. I need to connect real data to the `ProfileScreen` (`@profile_screen.dart`).

**Current Status:**
The screen currently displays hardcoded dummy data.

**Requirement 1: Real User Info**
- Get the `User` from `Supabase.instance.client.auth.currentUser`.
- **Avatar:** Display the user's Google/Apple profile picture (`user.userMetadata?['avatar_url']`). If null, show the current green circle with initials. Make it changeable, so the user can upload a new picture as an avatar.
- **Name:** Display the user's Google/Apple profile name (`user.userMetadata?['name']`). If null, show the user's email. Make it changeable, so the user can change their name.

**Requirement 2: Real Stats (Replace Dummy Cards)**
- Fetch statistics from `price_records` table for the current `user_id`.
- **Card 1: "Scans" (Total Uploads)**
  - Logic: `COUNT(*)` of records by this user.
- **Card 2: "Level" (Rank)**
  - Logic: Calculate based on Scan count.
  - 0-9 scans: "Beginner" (見習)
  - 10-49 scans: "Pro" (熟練)
  - 50+ scans: "Master" (達人)
  - Replace the old "#5" with this text.
- **Card 3: "Active Days" (Instead of Money Saved)**
  - Logic: Count distinct days the user uploaded a record. (If too complex for now, just hide this card or show "Join Date").

**Technical Implementation:**
- Create a `Future<Map<String, dynamic>> fetchProfileStats()` function in the widget.
- Use a `FutureBuilder` to load these numbers.
- Handle the loading state (show spinners instead of numbers).

**Action:**
Refactor `@profile_screen.dart` to implement this logic using Supabase Query (Postgrest).