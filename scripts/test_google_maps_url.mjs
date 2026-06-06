import assert from "node:assert/strict";

import {
  isSupportedGoogleMapsUrl,
  parseGoogleMapsDocument,
  parseGoogleMapsCoordinates,
} from "../supabase/functions/_shared/google_maps_url.mjs";

assert.deepEqual(
  parseGoogleMapsCoordinates(
    "https://www.google.com/maps/place/Test/@29.3759,47.9774,17z",
  ),
  { latitude: 29.3759, longitude: 47.9774 },
);
assert.deepEqual(
  parseGoogleMapsCoordinates("https://maps.google.com/?q=29.3759,47.9774"),
  { latitude: 29.3759, longitude: 47.9774 },
);
assert.deepEqual(
  parseGoogleMapsCoordinates(
    "https://www.google.com/maps/place/Test/data=!3d29.3759!4d47.9774",
  ),
  { latitude: 29.3759, longitude: 47.9774 },
);
assert.deepEqual(
  parseGoogleMapsCoordinates(
    "https://www.google.com/maps/place/Test/@25.7856293,55.9607666,2890m/" +
      "data=!4m6!3m5!1s0x0!8m2!3d25.7800955!4d55.9693682",
  ),
  { latitude: 25.7800955, longitude: 55.9693682 },
);
assert.equal(
  parseGoogleMapsCoordinates("https://maps.app.goo.gl/short-link"),
  null,
);
assert.equal(isSupportedGoogleMapsUrl("https://example.com/maps"), false);
assert.deepEqual(
  parseGoogleMapsDocument(
    '<meta content="https://www.google.com/maps/@29.3759,47.9774,17z">',
  ),
  { latitude: 29.3759, longitude: 47.9774 },
);
assert.equal(parseGoogleMapsDocument("<div>Version 1, 2</div>"), null);

console.log("Google Maps URL parser tests passed.");
