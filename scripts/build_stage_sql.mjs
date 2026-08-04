import fs from 'node:fs';

const district = (process.argv[2] || 'prakasam').toLowerCase();
const reportPath = `.tmp/ap_${district}_function_halls.json`;
const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const venues = report.venues || [];

function esc(s) {
  return String(s ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "''");
}

let sql = 'begin;\n';
sql += 'do $body$\n';
sql += 'declare\n';
sql += '  v_job uuid;\n';
sql += '  v_row public.venue_import_staging;\n';
sql += '  v_staged int := 0;\n';
sql += '  v_dup int := 0;\n';
sql += '  v_payload jsonb;\n';
sql += 'begin\n';
sql += "  insert into public.venue_import_jobs (country, state, category_slug, source, status)\n";
sql += "  values ('India', 'Andhra Pradesh', 'function_hall', 'osm', 'fetching')\n";
sql += '  returning id into v_job;\n';

for (const v of venues) {
  const payload = {
    name: v.name,
    category_slug: 'function_hall',
    address_line1: v.address_line1 || '',
    city: v.city || '',
    district: v.district || district,
    state: 'Andhra Pradesh',
    postal_code: v.postal_code || '',
    country: 'IN',
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
    fetched_at: v.fetched_at,
  };
  sql += `  v_payload := '${esc(JSON.stringify(payload))}'::jsonb;\n`;
  sql += '  select * into v_row from public.service_stage_import_venue(v_job, v_payload);\n';
  sql += "  if v_row.status::text = 'duplicate' then v_dup := v_dup + 1; else v_staged := v_staged + 1; end if;\n";
}

sql += `  update public.venue_import_jobs
    set status = 'review',
        venues_fetched = ${venues.length},
        venues_staged = v_staged,
        venues_duplicates = v_dup,
        completed_at = now()
    where id = v_job;\n`;
sql += 'end;\n';
sql += '$body$;\n';
sql += 'select id, status, venues_fetched, venues_staged, venues_duplicates from public.venue_import_jobs order by created_at desc limit 2;\n';
sql += "select count(*)::int as pending_review from public.venue_import_staging where status='pending_review';\n";
sql += 'commit;\n';

const out = `.tmp/stage_${district}.sql`;
fs.writeFileSync(out, sql);
console.log(JSON.stringify({ district, venues: venues.length, out }));
