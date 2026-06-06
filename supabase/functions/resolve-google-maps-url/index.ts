import {
  isSupportedGoogleMapsUrl,
  parseGoogleMapsDocument,
  parseGoogleMapsCoordinates,
} from "../_shared/google_maps_url.mjs";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  let input: unknown;
  try {
    input = (await request.json())?.url;
  } catch {
    return jsonResponse({ error: "invalid_google_maps_url" }, 400);
  }

  if (typeof input !== "string" || !isSupportedGoogleMapsUrl(input)) {
    return jsonResponse({ error: "invalid_google_maps_url" }, 400);
  }

  const direct = parseGoogleMapsCoordinates(input);
  if (direct) return resolvedResponse(direct, input);

  try {
    let currentUrl = input;
    for (let redirect = 0; redirect < 6; redirect += 1) {
      if (!isSupportedGoogleMapsUrl(currentUrl)) {
        return jsonResponse({ error: "invalid_google_maps_url" }, 400);
      }

      const response = await fetch(currentUrl, {
        method: "GET",
        redirect: "manual",
        headers: {
          "User-Agent":
            "Mozilla/5.0 (compatible; HS360GoogleMapsResolver/1.0)",
        },
      });

      if (response.status >= 300 && response.status < 400) {
        const location = response.headers.get("location");
        if (!location) break;
        currentUrl = new URL(location, currentUrl).toString();
        const redirected = parseGoogleMapsCoordinates(currentUrl);
        if (redirected) return resolvedResponse(redirected, currentUrl);
        continue;
      }

      const responseUrl = response.url || currentUrl;
      const fromUrl = parseGoogleMapsCoordinates(responseUrl);
      if (fromUrl) return resolvedResponse(fromUrl, responseUrl);

      const contentType = response.headers.get("content-type") ?? "";
      if (contentType.includes("text/html")) {
        const html = (await response.text()).slice(0, 1_000_000);
        const fromHtml = parseGoogleMapsDocument(html);
        if (fromHtml) return resolvedResponse(fromHtml, responseUrl);
      }
      break;
    }
  } catch {
    return jsonResponse({ error: "resolution_failed" }, 502);
  }

  return jsonResponse({ error: "coordinates_not_found" }, 422);
});

function resolvedResponse(
  coordinates: { latitude: number; longitude: number },
  resolvedUrl: string,
): Response {
  return jsonResponse({
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    resolved_url: resolvedUrl,
    resolved_at: new Date().toISOString(),
  });
}
