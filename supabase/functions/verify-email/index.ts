import { serve } from "https://deno.land/std@0.210.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jwtVerify } from "https://esm.sh/jose@5.2.4";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const verifySecret = Deno.env.get("EMAIL_VERIFY_SECRET") ?? "";
const redirectUrl = Deno.env.get("EMAIL_VERIFY_REDIRECT_URL") ?? "";

serve(async (req) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");
  if (!token || !verifySecret) {
    return new Response("Missing token", { status: 400 });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response("Missing configuration", { status: 500 });
  }

  let payload: { sub?: string } = {};
  try {
    const result = await jwtVerify(
      token,
      new TextEncoder().encode(verifySecret),
    );
    payload = result.payload as { sub?: string };
  } catch (_) {
    return new Response("Invalid token", { status: 400 });
  }

  const userId = payload.sub;
  if (!userId) {
    return new Response("Invalid token", { status: 400 });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data, error } = await admin.auth.admin.getUserById(userId);
  if (error || !data?.user) {
    return new Response("User not found", { status: 404 });
  }

  const nextMetadata = {
    ...(data.user.user_metadata ?? {}),
    email_verified: true,
    email_verified_at: new Date().toISOString(),
  };

  const { error: updateError } = await admin.auth.admin.updateUserById(
    userId,
    {
      user_metadata: nextMetadata,
    },
  );

  if (updateError) {
    return new Response("Failed to update user", { status: 500 });
  }

  if (redirectUrl) {
    return Response.redirect(redirectUrl, 302);
  }

  return new Response("Email verified", { status: 200 });
});
