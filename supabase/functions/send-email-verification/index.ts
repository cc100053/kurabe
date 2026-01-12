import { serve } from "https://deno.land/std@0.210.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT } from "https://esm.sh/jose@5.2.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";
const resendFrom = Deno.env.get("RESEND_FROM") ?? "";
const verifyUrl = Deno.env.get("EMAIL_VERIFY_URL") ?? "";
const verifySecret = Deno.env.get("EMAIL_VERIFY_SECRET") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    console.error("[send-email-verification] Missing Authorization header");
    return new Response("Unauthorized", {
      status: 401,
      headers: corsHeaders,
    });
  }

  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !resendApiKey ||
    !resendFrom ||
    !verifyUrl ||
    !verifySecret
  ) {
    console.error("[send-email-verification] Missing configuration", {
      supabaseUrl: !!supabaseUrl,
      supabaseAnonKey: !!supabaseAnonKey,
      resendApiKey: !!resendApiKey,
      resendFrom: !!resendFrom,
      verifyUrl: !!verifyUrl,
      verifySecret: !!verifySecret,
    });
    return new Response("Missing email verification configuration", {
      status: 500,
      headers: corsHeaders,
    });
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data, error } = await supabase.auth.getUser();
  if (error || !data?.user || !data.user.email) {
    console.error("[send-email-verification] getUser failed", {
      error: error?.message,
    });
    return new Response("Unauthorized", {
      status: 401,
      headers: corsHeaders,
    });
  }

  const metaValue = data.user.user_metadata?.email_verified;
  const verifiedAt = data.user.user_metadata?.email_verified_at;
  if (metaValue === true && verifiedAt) {
    return new Response(JSON.stringify({ status: "already_verified" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const token = await new SignJWT({ email: data.user.email })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("24h")
    .setSubject(data.user.id)
    .sign(new TextEncoder().encode(verifySecret));

  const link = `${verifyUrl}?token=${encodeURIComponent(token)}`;
  console.log("[send-email-verification] Sending email", {
    to: data.user.email,
    linkHost: new URL(verifyUrl).host,
  });

  const html = `
<div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px; background-color: #ffffff; color: #333333;">
  <div style="text-align: center; margin-bottom: 30px;">
    <img src="https://lgwdwfotnwfparvxqqnq.supabase.co/storage/v1/object/public/icon/icon_inside.png" alt="カイログ" width="100" style="display: block; margin: 0 auto 15px auto;">
  </div>
  <div style="padding: 30px; background-color: #f8f9fa; border-radius: 12px; border: 1px solid #e9ecef;">
    <h2 style="color: #333; margin-top: 0; font-size: 20px; text-align: center;">メールアドレスの確認</h2>
    <p style="color: #555; font-size: 15px; line-height: 1.8; margin-top: 20px;">
      カイログにご登録いただき、ありがとうございます。<br>
      以下のボタンをクリックして、メールアドレスの認証を完了させてください。
    </p>
    <div style="text-align: center; margin: 40px 0;">
      <a href="${link}" style="background-color: #00796B; color: #ffffff; padding: 14px 32px; text-decoration: none; border-radius: 50px; font-weight: bold; font-size: 16px; box-shadow: 0 4px 6px rgba(0,121,107, 0.2);">メールアドレスを認証する</a>
    </div>
    <p style="color: #888; font-size: 13px; line-height: 1.6; text-align: center;">
      ※このメールにお心当たりがない場合は、このまま破棄していただいて問題ありません。
    </p>
  </div>
  <div style="text-align: center; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px;">
    <p style="font-size: 11px; color: #aaa;">&copy; Kairogu Team</p>
  </div>
</div>
`;
  const text = `カイログにご登録いただき、ありがとうございます。\n以下のリンクからメールアドレスの認証を完了してください。\n\n${link}\n\nこのメールにお心当たりがない場合は破棄してください。`;

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: resendFrom,
      to: data.user.email,
      subject: "メールアドレスの確認",
      html,
      text,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error("[send-email-verification] Resend error", {
      status: response.status,
      body,
    });
    return new Response(body, {
      status: 500,
      headers: corsHeaders,
    });
  }

  return new Response(JSON.stringify({ status: "sent" }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
