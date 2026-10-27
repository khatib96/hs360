// Login operations that need the Auth admin API (service role):
//   create_user          admin creates an employee login with an initial password
//   reset_password       admin sets a new password; the employee must change it
//   change_own_password  the signed-in user sets their own password
//
// Every permission decision runs in the database through the caller's own JWT
// (get_my_permissions, register_tenant_user, prepare_tenant_user_password_reset),
// so RPC rules stay authoritative and audit rows name the real actor. No e-mail
// is sent. Uses plain fetch so it runs the same locally and on a self-hosted VPS.

const MIN_PASSWORD_LENGTH = 10;
const LOGIN_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

class RequestError extends Error {
  constructor(readonly code: string, readonly status = 400) {
    super(code);
  }
}

type Env = { url: string; anonKey: string; serviceKey: string };

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function readEnv(): Env {
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    throw new RequestError("server_not_configured", 500);
  }
  return { url, anonKey, serviceKey };
}

const permissionErrors = new Set([
  "permission_denied",
  "manager_required",
  "permission_not_held",
  "cannot_modify_self",
]);

/** Calls an RPC as the signed-in caller; database errors become RequestErrors. */
async function callerRpc(
  env: Env,
  authorization: string,
  fn: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const response = await fetch(`${env.url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      apikey: env.anonKey,
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
  });
  const payload = await response.json().catch(() => null);
  if (response.ok) return payload;

  if (payload?.code === "42501") throw new RequestError("permission_denied", 403);
  const code = typeof payload?.message === "string" ? payload.message : "request_failed";
  throw new RequestError(code, permissionErrors.has(code) ? 403 : 400);
}

async function serviceRpc(env: Env, fn: string, args: Record<string, unknown>) {
  const response = await fetch(`${env.url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      apikey: env.serviceKey,
      Authorization: `Bearer ${env.serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
  });
  if (!response.ok) throw new RequestError("request_failed", 502);
}

function authAdmin(
  env: Env,
  method: string,
  path: string,
  body?: Record<string, unknown>,
): Promise<Response> {
  return fetch(`${env.url}/auth/v1/admin${path}`, {
    method,
    headers: {
      apikey: env.serviceKey,
      Authorization: `Bearer ${env.serviceKey}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
}

function requirePassword(value: unknown): string {
  const password = typeof value === "string" ? value : "";
  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new RequestError("weak_password");
  }
  return password;
}

async function setPassword(env: Env, userId: string, password: string) {
  const response = await authAdmin(env, "PUT", `/users/${userId}`, { password });
  if (!response.ok) throw new RequestError("password_update_failed", 502);
}

async function createUser(env: Env, authorization: string, body: Record<string, unknown>) {
  const login = String(body.login ?? "").trim().toLowerCase();
  const displayName = String(body.display_name ?? "").trim();
  const accountType = body.account_type === "manager" ? "manager" : "user";
  const password = requirePassword(body.password);
  if (!LOGIN_PATTERN.test(login)) throw new RequestError("invalid_login");
  if (!displayName) throw new RequestError("validation_failed");

  // Checked again by register_tenant_user; checked here first so no login is
  // created for a caller who cannot add users.
  const permissions = await callerRpc(env, authorization, "get_my_permissions", {}) as {
    is_manager?: boolean;
    permissions?: string[];
  };
  const isManager = permissions?.is_manager === true;
  if (!isManager && !(permissions?.permissions ?? []).includes("settings.users.invite")) {
    throw new RequestError("permission_denied", 403);
  }
  if (accountType === "manager" && !isManager) {
    throw new RequestError("manager_required", 403);
  }

  const created = await authAdmin(env, "POST", "/users", {
    email: login,
    password,
    email_confirm: true,
    user_metadata: { name: displayName },
  });
  const createdBody = await created.json().catch(() => null);
  if (!created.ok) {
    const text = JSON.stringify(createdBody ?? {}).toLowerCase();
    if (created.status === 422 && (text.includes("already") || text.includes("exists"))) {
      throw new RequestError("login_taken", 409);
    }
    throw new RequestError("login_create_failed", 502);
  }

  const userId = String(createdBody.id);
  try {
    const tenantUserId = await callerRpc(env, authorization, "register_tenant_user", {
      p_user_id: userId,
      p_display_name: displayName,
      p_account_type: accountType,
    });
    return jsonResponse({ tenant_user_id: tenantUserId, user_id: userId });
  } catch (error) {
    // Never leave a login that belongs to no company.
    await authAdmin(env, "DELETE", `/users/${userId}`).catch(() => undefined);
    throw error;
  }
}

async function resetPassword(env: Env, authorization: string, body: Record<string, unknown>) {
  const tenantUserId = String(body.tenant_user_id ?? "");
  const password = requirePassword(body.password);
  if (!tenantUserId) throw new RequestError("validation_failed");

  const userId = await callerRpc(env, authorization, "prepare_tenant_user_password_reset", {
    p_tenant_user_id: tenantUserId,
  });
  await setPassword(env, String(userId), password);
  return jsonResponse({ ok: true });
}

async function changeOwnPassword(env: Env, authorization: string, body: Record<string, unknown>) {
  const password = requirePassword(body.password);

  const userResponse = await fetch(`${env.url}/auth/v1/user`, {
    headers: { apikey: env.anonKey, Authorization: authorization },
  });
  const user = await userResponse.json().catch(() => null);
  if (!userResponse.ok || !user?.id) throw new RequestError("not_authenticated", 401);

  await setPassword(env, String(user.id), password);
  await serviceRpc(env, "complete_own_password_change", { p_user_id: user.id });
  return jsonResponse({ ok: true });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return jsonResponse({ error: "not_authenticated" }, 401);
  }

  try {
    const env = readEnv();
    const body = await request.json().catch(() => {
      throw new RequestError("invalid_request");
    });

    switch (body?.action) {
      case "create_user":
        return await createUser(env, authorization, body);
      case "reset_password":
        return await resetPassword(env, authorization, body);
      case "change_own_password":
        return await changeOwnPassword(env, authorization, body);
      default:
        throw new RequestError("invalid_action");
    }
  } catch (error) {
    if (error instanceof RequestError) {
      return jsonResponse({ error: error.code }, error.status);
    }
    return jsonResponse({ error: "request_failed" }, 500);
  }
});
