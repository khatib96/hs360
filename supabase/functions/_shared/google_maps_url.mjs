const coordinatePatterns = [
  /!3d(-?\d{1,3}(?:\.\d+)?)[^!]*!4d(-?\d{1,3}(?:\.\d+)?)/,
  /@(-?\d{1,3}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)/,
  /(?:^|[^0-9.-])(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)(?:$|[^0-9.-])/,
];

const coordinateQueryKeys = [
  "query",
  "q",
  "ll",
  "destination",
  "daddr",
  "center",
];

export function isSupportedGoogleMapsUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    return false;
  }

  if (url.protocol !== "https:" && url.protocol !== "http:") return false;
  const host = url.hostname.toLowerCase();
  return (
    host === "maps.app.goo.gl" ||
    host === "goo.gl" ||
    host === "google.com" ||
    host === "www.google.com" ||
    host === "maps.google.com" ||
    /^(www|maps)\.google\.[a-z]{2,3}(\.[a-z]{2})?$/.test(host)
  );
}

export function parseGoogleMapsCoordinates(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    return null;
  }
  if (!isSupportedGoogleMapsUrl(url.toString())) return null;

  const candidates = [
    url.toString(),
    url.pathname,
    url.hash,
    ...coordinateQueryKeys
      .map((key) => url.searchParams.get(key))
      .filter(Boolean),
  ];

  for (const candidate of candidates) {
    const pair = parseCoordinatePair(candidate);
    if (pair) return pair;
  }
  return null;
}

export function parseCoordinatePair(value) {
  let decoded = value;
  try {
    decoded = decodeURIComponent(value);
  } catch {
    // The original value may already be decoded or contain a malformed escape.
  }

  for (const pattern of coordinatePatterns) {
    const match = pattern.exec(decoded);
    if (!match) continue;
    const latitude = Number(match[1]);
    const longitude = Number(match[2]);
    if (
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180
    ) {
      return { latitude, longitude };
    }
  }
  return null;
}

export function parseGoogleMapsDocument(value) {
  const html = value.replaceAll("&amp;", "&");
  const urlPattern =
    /https?:\/\/(?:www\.|maps\.)?google\.[a-z.]+\/maps[^"'<>\\\s]*/gi;

  for (const match of html.matchAll(urlPattern)) {
    const coordinates = parseGoogleMapsCoordinates(match[0]);
    if (coordinates) return coordinates;
  }

  for (const pattern of coordinatePatterns.slice(0, 2)) {
    const match = pattern.exec(html);
    if (!match) continue;
    const coordinates = validateCoordinates(match[1], match[2]);
    if (coordinates) return coordinates;
  }
  return null;
}

function validateCoordinates(latitudeValue, longitudeValue) {
  const latitude = Number(latitudeValue);
  const longitude = Number(longitudeValue);
  if (
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180
  ) {
    return { latitude, longitude };
  }
  return null;
}
