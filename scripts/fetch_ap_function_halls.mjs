/**
 * Phase 6: small-batch OSM Overpass fetch for Andhra Pradesh Function Halls.
 * Compliant public Overpass API only. Writes report JSON; optional --stage
 * prints SQL-ready payloads (staging done via supabase db query separately).
 *
 * Usage:
 *   node scripts/fetch_ap_function_halls.mjs
 *   node scripts/fetch_ap_function_halls.mjs --district=Prakasam --limit=20
 */
import fs from 'node:fs';
import path from 'node:path';

const OVERPASS = 'https://overpass-api.de/api/interpreter';
const UA = 'BookMySpace/1.0 (venue-import; compliant OSM; phase6)';

const DISTRICTS = {
  Prakasam: [15.20, 79.40, 16.00, 80.40],
  Guntur: [15.90, 79.90, 16.70, 80.80],
  Krishna: [16.00, 80.40, 16.90, 81.30],
  Visakhapatnam: [17.40, 82.90, 18.10, 83.60],
};

function parseArgs(argv) {
  const out = { district: 'Prakasam', limit: 20 };
  for (const a of argv.slice(2)) {
    if (a.startsWith('--district=')) out.district = a.slice(11);
    if (a.startsWith('--limit=')) out.limit = Number(a.slice(8)) || 20;
  }
  return out;
}

function buildQuery(bbox) {
  const [s, w, n, e] = bbox;
  return `
[out:json][timeout:60];
(
  nwr["amenity"="events_venue"](${s},${w},${n},${e});
  nwr["amenity"="community_centre"](${s},${w},${n},${e});
  nwr["amenity"="community_center"](${s},${w},${n},${e});
  nwr["name"~"Function Hall|Kalyan|Marriage|Convention|Banquet|Mandapam",i](${s},${w},${n},${e});
);
out center tags;
`;
}

function mapEl(el) {
  const tags = el.tags || {};
  const lat = el.lat ?? el.center?.lat ?? 0;
  const lon = el.lon ?? el.center?.lon ?? 0;
  const osmId = `${el.type}/${el.id}`;
  const amenities = [];
  if (tags.wifi === 'yes') amenities.push('WiFi');
  if (tags.parking === 'yes') amenities.push('Parking');
  if (tags.toilets === 'yes') amenities.push('Restrooms');
  if (tags.air_conditioning === 'yes') amenities.push('Air conditioning');
  const image_refs = [];
  if (tags.image) image_refs.push({ url: tags.image, alt: tags.name });
  if (tags.wikimedia_commons) {
    image_refs.push({
      url: `https://commons.wikimedia.org/wiki/Special:FilePath/${tags.wikimedia_commons}`,
      alt: tags.name,
    });
  }
  const address = [tags['addr:housenumber'], tags['addr:street']].filter(Boolean).join(' ');
  return {
    name: String(tags.name || '').trim(),
    category_slug: 'function_hall',
    address_line1: address,
    city: tags['addr:city'] || tags['addr:town'] || '',
    district: tags['addr:district'] || tags['addr:suburb'] || '',
    state: 'Andhra Pradesh',
    postal_code: tags['addr:postcode'] || '',
    country: 'IN',
    phone: tags.phone || tags['contact:phone'] || '',
    website: tags.website || tags['contact:website'] || '',
    latitude: lat,
    longitude: lon,
    source: 'osm',
    source_place_id: osmId,
    osm_id: osmId,
    operating_hours: tags.opening_hours ? [{ raw: tags.opening_hours }] : [],
    amenities,
    ratings: {},
    image_refs,
    fetched_at: new Date().toISOString(),
  };
}

function dedupeKey(v) {
  if (v.source_place_id) return `id:${v.source_place_id}`;
  const lat = Math.round(v.latitude * 1000);
  const lng = Math.round(v.longitude * 1000);
  return `nl:${v.name.toLowerCase().trim()}|${lat}|${lng}`;
}

async function main() {
  const { district, limit } = parseArgs(process.argv);
  const bbox = DISTRICTS[district];
  if (!bbox) {
    console.error('Unknown district. Choose:', Object.keys(DISTRICTS).join(', '));
    process.exit(1);
  }

  const body = buildQuery(bbox);
  const res = await fetch(OVERPASS, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': UA },
    body,
  });
  if (!res.ok) {
    console.error('Overpass failed', res.status, await res.text());
    process.exit(2);
  }
  const data = await res.json();
  const raw = (data.elements || [])
    .filter((el) => el.tags?.name)
    .map(mapEl)
    .filter((v) => v.name && v.latitude && v.longitude);

  const seen = new Set();
  const unique = [];
  let duplicates = 0;
  for (const v of raw) {
    const k = dedupeKey(v);
    if (seen.has(k)) {
      duplicates += 1;
      continue;
    }
    seen.add(k);
    unique.push(v);
  }

  const batch = unique.slice(0, limit);
  const withImages = batch.filter((v) => v.image_refs.length > 0).length;
  const cities = [...new Set(batch.map((v) => v.city || v.district || 'unknown'))];

  const report = {
    district,
    country: 'India',
    category: 'function_hall',
    source: 'osm',
    found: raw.length,
    valid: unique.length,
    duplicates,
    staged_ready: batch.length,
    images: withImages,
    districts_or_cities: cities,
    fetched_at: new Date().toISOString(),
    venues: batch,
  };

  const outDir = path.join(process.cwd(), '.tmp');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `ap_${district.toLowerCase()}_function_halls.json`);
  fs.writeFileSync(outPath, JSON.stringify(report, null, 2));
  console.log(JSON.stringify({
    FOUND: report.found,
    VALID: report.valid,
    DUPLICATES: report.duplicates,
    STAGED_READY: report.staged_ready,
    IMAGES: report.images,
    DISTRICTS: report.districts_or_cities,
    OUT: outPath,
  }, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
