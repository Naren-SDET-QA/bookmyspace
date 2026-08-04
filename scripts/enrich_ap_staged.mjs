/**
 * Phase 6: Enrich staged AP function halls via Google Places API v1.
 * OSM remains discovery source; enrichment fills phone/website/photos/hours/rating.
 *
 * Usage:
 *   node scripts/enrich_ap_staged.mjs
 *   node scripts/enrich_ap_staged.mjs --district=prakasam --limit=10
 *   node scripts/enrich_ap_staged.mjs --expand-osm   # fetch Krishna + Visakhapatnam
 *
 * Requires GOOGLE_PLACES_API_KEY in env or .env (never logged).
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const PLACES_SEARCH = 'https://places.googleapis.com/v1/places:searchText';
const FIELD_MASK = [
  'places.id',
  'places.displayName',
  'places.formattedAddress',
  'places.location',
  'places.nationalPhoneNumber',
  'places.websiteUri',
  'places.rating',
  'places.userRatingCount',
  'places.regularOpeningHours',
  'places.photos',
].join(',');

const DEFAULT_DISTRICTS = ['prakasam', 'guntur'];
const EXPAND_DISTRICTS = ['krishna', 'visakhapatnam'];

function loadEnv() {
  const envPath = path.join(process.cwd(), '.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (!m || process.env[m[1]]) continue;
    process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

function parseArgs(argv) {
  const out = {
    districts: [...DEFAULT_DISTRICTS],
    limit: 25,
    expandOsm: false,
    dryRun: false,
  };
  for (const a of argv.slice(2)) {
    if (a.startsWith('--district=')) {
      out.districts = a
        .slice(11)
        .split(',')
        .map((d) => d.trim().toLowerCase())
        .filter(Boolean);
    }
    if (a.startsWith('--limit=')) out.limit = Number(a.slice(8)) || 25;
    if (a === '--expand-osm') out.expandOsm = true;
    if (a === '--dry-run') out.dryRun = true;
  }
  if (out.expandOsm) {
    for (const d of EXPAND_DISTRICTS) {
      if (!out.districts.includes(d)) out.districts.push(d);
    }
  }
  return out;
}

function needsEnrichment(v) {
  return (
    !v.phone &&
    !v.website &&
    (!v.image_refs || v.image_refs.length === 0) &&
    (!v.ratings || Object.keys(v.ratings).length === 0)
  );
}

function tokenOverlap(a, b) {
  const ta = new Set(a.toLowerCase().split(/\s+/).filter((t) => t.length > 2));
  const tb = new Set(b.toLowerCase().split(/\s+/).filter((t) => t.length > 2));
  if (!ta.size || !tb.size) return a.toLowerCase().includes(b.toLowerCase()) ? 0.6 : 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter += 1;
  return inter / new Set([...ta, ...tb]).size;
}

function haversineM(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

async function searchGooglePlace(venue, apiKey) {
  const hint = [venue.city, venue.district, venue.state].filter(Boolean).join(', ');
  const textQuery = hint
    ? `${venue.name} function hall ${hint}`
    : `${venue.name} function hall`;

  const res = await fetch(PLACES_SEARCH, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': FIELD_MASK,
    },
    body: JSON.stringify({
      textQuery,
      maxResultCount: 3,
      locationBias: {
        circle: {
          center: { latitude: venue.latitude, longitude: venue.longitude },
          radius: 500,
        },
      },
    }),
  });

  if (!res.ok) return null;
  const data = await res.json();
  const places = data.places || [];
  let best = null;
  let bestScore = 0;
  for (const p of places) {
    const name = p.displayName?.text || '';
    const lat = p.location?.latitude;
    const lng = p.location?.longitude;
    if (lat == null || lng == null) continue;
    const dist = haversineM(venue.latitude, venue.longitude, lat, lng);
    if (dist > 500) continue;
    const score = tokenOverlap(venue.name, name) * 0.7 + (1 - dist / 500) * 0.3;
    if (score > bestScore) {
      bestScore = score;
      best = p;
    }
  }
  if (!best || bestScore < 0.45) return null;
  return { place: best, score: bestScore };
}

function buildEnrichmentPatch(venue, match, apiKey) {
  const p = match.place;
  const placeId = p.id || '';
  const fields = [];
  const patch = {
    google_place_id: placeId,
    enrichment_provenance: {
      google_places: {
        place_id: placeId,
        fetched_at: new Date().toISOString(),
        match: 'text_search+location_bias',
        score: match.score,
      },
    },
  };

  if (!venue.phone && p.nationalPhoneNumber) {
    patch.phone = p.nationalPhoneNumber;
    fields.push('phone');
  }
  if (!venue.website && p.websiteUri) {
    patch.website = p.websiteUri;
    fields.push('website');
  }
  if ((!venue.image_refs || !venue.image_refs.length) && p.photos?.length) {
    // Never embed API keys in stored URLs — keep Places photo resource name only.
    patch.image_refs = p.photos.slice(0, 3).map((photo) => ({
      photo_name: photo.name,
      alt: p.displayName?.text || venue.name,
      source: 'google_places',
    }));
    fields.push('image_refs');
  }
  if ((!venue.ratings || !Object.keys(venue.ratings).length) && p.rating != null) {
    patch.ratings = {
      avg: p.rating,
      count: p.userRatingCount || 0,
      source: 'google_places',
    };
    fields.push('ratings');
  }
  const weekdays = p.regularOpeningHours?.weekdayDescriptions;
  if ((!venue.operating_hours || !venue.operating_hours.length) && weekdays?.length) {
    patch.operating_hours = [
      { source: 'google_places', weekday_descriptions: weekdays },
    ];
    fields.push('operating_hours');
  }
  patch.enrichment_provenance.google_places.fields = fields;
  return { patch, fields };
}

function esc(s) {
  return String(s ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "''");
}

function ensureOsmReport(district, limit) {
  const reportPath = path.join(
    process.cwd(),
    '.tmp',
    `ap_${district}_function_halls.json`,
  );
  if (fs.existsSync(reportPath)) return reportPath;

  const fetchScript = path.join(process.cwd(), 'scripts', 'fetch_ap_function_halls.mjs');
  const cap = district.charAt(0).toUpperCase() + district.slice(1);
  spawnSync(process.execPath, [fetchScript, `--district=${cap}`, `--limit=${limit}`], {
    stdio: 'inherit',
    cwd: process.cwd(),
  });
  return reportPath;
}

async function enrichDistrict(district, apiKey, limit, dryRun) {
  const reportPath = ensureOsmReport(district, limit);
  if (!fs.existsSync(reportPath)) {
    return { district, error: 'missing_osm_report', enriched: 0, images: 0, phones: 0 };
  }

  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const venues = (report.venues || []).slice(0, limit);
  const usedGoogleIds = new Set();
  const results = [];
  let enriched = 0;
  let images = 0;
  let phones = 0;

  for (const venue of venues) {
    if (!needsEnrichment(venue) && venue.google_place_id) continue;

    let match = null;
    if (apiKey) {
      match = await searchGooglePlace(venue, apiKey);
      await new Promise((r) => setTimeout(r, 200));
    }

    if (!match) {
      results.push({
        name: venue.name,
        source_place_id: venue.source_place_id,
        enriched: false,
      });
      continue;
    }

    const { patch, fields } = buildEnrichmentPatch(venue, match, apiKey);
    if (patch.google_place_id && usedGoogleIds.has(patch.google_place_id)) {
      results.push({
        name: venue.name,
        source_place_id: venue.source_place_id,
        enriched: false,
        reason: 'google_place_id_duplicate',
      });
      continue;
    }
    if (patch.google_place_id) usedGoogleIds.add(patch.google_place_id);

    enriched += 1;
    if (fields.includes('phone')) phones += 1;
    if (fields.includes('image_refs')) images += 1;

    results.push({
      name: venue.name,
      source_place_id: venue.source_place_id,
      osm_id: venue.osm_id,
      enriched: true,
      fields,
      google_place_id: patch.google_place_id,
      patch,
    });
  }

  const outDir = path.join(process.cwd(), '.tmp');
  fs.mkdirSync(outDir, { recursive: true });
  const enrichReport = path.join(outDir, `enrich_${district}.json`);
  fs.writeFileSync(
    enrichReport,
    JSON.stringify(
      {
        district,
        total: venues.length,
        enriched,
        images,
        phones,
        api_configured: Boolean(apiKey),
        results,
        generated_at: new Date().toISOString(),
      },
      null,
      2,
    ),
  );

  if (!dryRun && apiKey) {
    const sqlPath = path.join(outDir, `enrich_${district}.sql`);
    let sql = '-- Match staged rows by source_place_id (OSM preserved)\n';
    sql += 'begin;\n';
    for (const r of results.filter((x) => x.enriched)) {
      sql += `update public.venue_import_staging s\n`;
      sql += `set google_place_id = coalesce(nullif('${esc(r.google_place_id)}',''), s.google_place_id),\n`;
      sql += `    phone = case when coalesce(s.phone,'')='' and '${esc(r.patch.phone || '')}'<>'' then public.normalize_venue_phone('${esc(r.patch.phone || '')}') else s.phone end,\n`;
      sql += `    website = case when coalesce(s.website,'')='' and '${esc(r.patch.website || '')}'<>'' then '${esc(r.patch.website || '')}' else s.website end,\n`;
      sql += `    ratings = case when coalesce(s.ratings,'{}'::jsonb)='{}'::jsonb then '${esc(JSON.stringify(r.patch.ratings || {}))}'::jsonb else s.ratings end,\n`;
      sql += `    image_refs = public.merge_venue_image_refs(s.image_refs, '${esc(JSON.stringify(r.patch.image_refs || []))}'::jsonb),\n`;
      sql += `    operating_hours = case when jsonb_array_length(coalesce(s.operating_hours,'[]'::jsonb))=0 then '${esc(JSON.stringify(r.patch.operating_hours || []))}'::jsonb else s.operating_hours end,\n`;
      sql += `    enrichment_provenance = s.enrichment_provenance || '${esc(JSON.stringify(r.patch.enrichment_provenance))}'::jsonb,\n`;
      sql += `    status = 'pending_review',\n`;
      sql += `    updated_at = now()\n`;
      sql += `where s.source='osm' and s.source_place_id='${esc(r.source_place_id)}';\n\n`;
    }
    sql += "select count(*)::int as pending_review from public.venue_import_staging where status='pending_review';\n";
    sql += 'commit;\n';
    fs.writeFileSync(sqlPath, sql);
  }

  return { district, enriched, images, phones, venues: venues.length, report: enrichReport };
}

async function main() {
  loadEnv();
  const { districts, limit, expandOsm, dryRun } = parseArgs(process.argv);
  const apiKey = (process.env.GOOGLE_PLACES_API_KEY || '').trim();
  const placeholder = !apiKey || /PLACEHOLDER|YOUR_/i.test(apiKey);

  const summaries = [];
  for (const district of districts) {
    if (expandOsm && EXPAND_DISTRICTS.includes(district)) {
      const reportPath = ensureOsmReport(district, Math.min(limit, 15));
      if (fs.existsSync(reportPath)) {
        const stageScript = path.join(process.cwd(), 'scripts', 'build_stage_sql.mjs');
        spawnSync(process.execPath, [stageScript, district], {
          stdio: 'inherit',
          cwd: process.cwd(),
        });
      }
    }
    summaries.push(
      await enrichDistrict(district, placeholder ? '' : apiKey, limit, dryRun),
    );
  }

  const totalEnriched = summaries.reduce((n, s) => n + (s.enriched || 0), 0);
  const totalImages = summaries.reduce((n, s) => n + (s.images || 0), 0);
  const totalPhones = summaries.reduce((n, s) => n + (s.phones || 0), 0);
  const totalStaged = summaries.reduce((n, s) => n + (s.venues || 0), 0);

  console.log(
    JSON.stringify(
      {
        ENRICHED: totalEnriched,
        IMAGES: totalImages,
        PHONES: totalPhones,
        DISTRICTS: districts,
        STAGED: totalStaged,
        BLOCKER: placeholder
          ? 'GOOGLE_PLACES_API_KEY not configured — OSM expansion only'
          : null,
        summaries,
      },
      null,
      2,
    ),
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
