/**
 * Stage Phase 6 OSM batch into venue_import_staging via linked Supabase SQL.
 * Reads .tmp/ap_<district>_function_halls.json from fetch script.
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const district = process.argv[2] || 'prakasam';
const reportPath = path.join(
  process.cwd(),
  '.tmp',
  `ap_${district.toLowerCase()}_function_halls.json`,
);

if (!fs.existsSync(reportPath)) {
  console.error('Missing report', reportPath);
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const venues = report.venues || [];

function esc(s) {
  return String(s ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "''");
}

function payloadSql(v) {
  const payload = {
    name: v.name,
    category_slug: v.category_slug || 'function_hall',
    address_line1: v.address_line1 || '',
    city: v.city || '',
    district: v.district || '',
    state: v.state || 'Andhra Pradesh',
    postal_code: v.postal_code || '',
    country: v.country || 'IN',
    phone: v.phone || '',
    website: v.website || '',
    latitude: v.latitude,
    longitude: v.longitude,
    source: 'osm',
    source_place_id: v.source_place_id,
    osm_id: v.osm_id || v.source_place_id,
    operating_hours: v.operating_hours || [],
    amenities: v.amenities || [],
    ratings: v.ratings || {},
    image_refs: v.image_refs || [],
    fetched_at: v.fetched_at || new Date().toISOString(),
  };
  return esc(JSON.stringify(payload));
}

const sqlPath = path.join(process.cwd(), '.tmp', `stage_${district}.sql`);
const lines = [];
lines.push('begin;');
lines.push(`
with job as (
  insert into public.venue_import_jobs (country, state, category_slug, source, status)
  values ('India', 'Andhra Pradesh', 'function_hall', 'osm', 'fetching')
  returning id
)
select id as job_id from job;
`);

// We'll do job create + stage in one script differently - first get job id via separate query
fs.writeFileSync(
  path.join(process.cwd(), '.tmp', 'create_job.sql'),
  `insert into public.venue_import_jobs (country, state, category_slug, source, status)
values ('India', 'Andhra Pradesh', 'function_hall', 'osm', 'fetching')
returning id::text as job_id;`,
);

console.log(JSON.stringify({ report: reportPath, venues: venues.length, next: 'create_job' }));
