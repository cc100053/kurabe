
**Context:**
I am refining the "Link with Email" flow.
**Current Logic:** Ask for Email & Password.
**Challenge:**
1.  **Scenario A (New Email):** If the email is new, `updateUser` works perfectly (Guest becomes Registered User).
2.  **Scenario B (Existing Email):** If the email is already taken, `updateUser` throws an error. We must then allow the user to **Sign In** and **MOVE** their guest data to the existing account.

**Task: Implement Email Linking with Data Migration Strategy**

**1. Database RPC (The "Mover"):**
* Create a generic SQL function to transfer ownership of records.
* **SQL:** `transfer_guest_data(record_ids bigint[])`
    * **Security:** Use `SECURITY DEFINER` (to bypass RLS, allowing the new user to "claim" the old guest records).
    * **Logic:** `UPDATE price_records SET user_id = auth.uid() WHERE id = ANY(record_ids);`

**2. Update `ProfileTab` Logic (`_linkWithEmail`):**
* **Step 1:** Try `await Supabase.instance.client.auth.updateUser(...)`.
    * If successful: Show "Confirmation email sent". Done.
* **Step 2 (The Fallback):** Catch `AuthException` where code/message indicates "User already registered".
* **Step 3:** Show Dialog: "Account exists. Log in to merge data?"
    * Input: Password (reuse from previous dialog).
* **Step 4 (The Migration Dance):**
    * **A. Preserve Data:** Query all IDs of current guest's records:
        `final guestRecordIds = ... (Select id from price_records where user_id = current_guest_id)`
    * **B. Sign In:** `await signInWithPassword(email, password)`. (This switches the auth session to the existing user).
    * **C. Claim Data:** If login success AND `guestRecordIds` is not empty:
        `await rpc('transfer_guest_data', params: {'record_ids': guestRecordIds})`.
    * **D. Feedback:** Show "Logged in & Data Merged!".

**Output:**
1.  The **SQL Command** for `transfer_guest_data`.
