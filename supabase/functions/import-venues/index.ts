// Fetches public venue data from OSM Overpass (and optionally Google Places)
// and stages rows via service_stage_import_venue. Admin auth required.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const GOOGLE_PLACES_API_KEY = Deno.env.get('GOOGLE_PLACES_API_KEY') ?? '';

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';
const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type CategoryMapping = {
  category_slug: string;
  osm_tags: string[] | unknown;
  google_place_type?: string;
  is_active?: boolean;
};

type ImportRequest = {
  job_id?: string;
  country?: string;
  state?: string;
  district?: string;
  category_slug?: string;
  enrich_with_places?: boolean;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'missing_auth' }, 401);

  const userResponse = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authHeader, apikey: SUPABASE_SERVICE_ROLE_KEY },
  });
  if (!userResponse.ok) return json({ error: 'unauthorized' }, 401);
  const user = await userResponse.json();

  const adminCheck = await adminRequest(
    `/rest/v1/rpc/is_admin_user`,
    { method: 'POST', body: JSON.stringify({ p_uid: user.id }) },
  );
  if (!adminCheck.ok) return json({ error: 'admin_check_failed' }, 403);
  const isAdmin = (await adminCheck.json()) as boolean;
  if (!isAdmin) return json({ error: 'admin_required' }, 403);

  try {
    const body = (await req.json()) as ImportRequest;
    let jobId = body.job_id;
    const enrichWithPlaces = Boolean(body.enrich_with_places);

    if (!jobId) {
      if (!body.country || !body.state || !body.category_slug) {
        return json({ error: 'missing_fields' }, 400);
      }
      const createJob = await adminRequest(
        '/rest/v1/rpc/admin_create_venue_import_job',
        {
          method: 'POST',
          body: JSON.stringify({
            p_country: body.country,
            p_state: body.state,
            p_category_slug: body.category_slug,
            p_source: enrichWithPlaces && GOOGLE_PLACES_API_KEY ? 'osm+google' : 'osm',
            p_district: body.district ?? null,
          }),
        },
      );
      if (!createJob.ok) {
        const err = await createJob.text();
        console.error('create job failed', err);
        return json({ error: 'job_create_failed', detail: err }, 500);
      }
      const job = await createJob.json();
      jobId = job.id;
    }

    await adminRequest(
      `/rest/v1/venue_import_jobs?id=eq.${encodeURIComponent(jobId!)}`,
      {
        method: 'PATCH',
        body: JSON.stringify({ status: 'fetching' }),
      },
    );

    const jobRow = await adminRequest(
      `/rest/v1/venue_import_jobs?id=eq.${encodeURIComponent(jobId!)}&select=*`,
    );
    const jobs = jobRow.ok ? await jobRow.json() : [];
    const job = jobs[0];
    if (!job) return json({ error: 'job_not_found' }, 404);

    const mappingRes = await adminRequest(
      `/rest/v1/venue_import_category_mappings?category_slug=eq.${encodeURIComponent(job.category_slug)}&select=*`,
    );
    const mappings = mappingRes.ok ? await mappingRes.json() : [];
    const mapping = mappings[0] as CategoryMapping | undefined;
    if (!mapping) return json({ error: 'category_mapping_not_found' }, 400);
    if (mapping.is_active === false) {
      return json({ error: 'category_disabled' }, 400);
    }

    const osmTags = normalizeOsmTags(mapping.osm_tags);
    const district = (job.district || body.district || '').trim();

    let staged = 0;
    let duplicates = 0;
    let fetched = 0;

    const osmResults = await fetchOsmVenues(
      job.country,
      job.state,
      osmTags,
      district,
    );
    fetched += osmResults.length;

    for (const venue of osmResults) {
      const payload = {
        name: venue.name,
        category_slug: job.category_slug,
        address_line1: venue.address,
        city: venue.city,
        district: venue.district || district || '',
        state: job.state,
        postal_code: venue.postal_code,
        country: job.country === 'India' ? 'IN' : job.country,
        phone: venue.phone,
        website: venue.website,
        latitude: venue.lat,
        longitude: venue.lng,
        source: 'osm',
        source_place_id: venue.osm_id,
        osm_id: venue.osm_id,
        operating_hours: venue.hours,
        amenities: venue.amenities,
        ratings: {},
        image_refs: venue.image_refs,
        fetched_at: new Date().toISOString(),
      };

      const stageRes = await adminRequest(
        '/rest/v1/rpc/service_stage_import_venue',
        { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_payload: payload }) },
      );
      if (stageRes.ok) {
        const row = await stageRes.json();
        if (row.status === 'duplicate') duplicates += 1;
        else staged += 1;
      }
    }

    // Optional Google Places supplement when explicitly requested and key configured.
    if (enrichWithPlaces && GOOGLE_PLACES_API_KEY && mapping.google_place_type) {
      const googleResults = await fetchGooglePlaces(
        job.country,
        job.state,
        mapping.google_place_type,
        district,
      );
      fetched += googleResults.length;
      for (const venue of googleResults) {
        const payload = {
          name: venue.name,
          category_slug: job.category_slug,
          address_line1: venue.address,
          city: venue.city,
          state: job.state,
          country: job.country === 'India' ? 'IN' : job.country,
          phone: venue.phone,
          website: venue.website,
          latitude: venue.lat,
          longitude: venue.lng,
          source: 'google_places',
          source_place_id: venue.place_id,
          operating_hours: venue.hours,
          amenities: venue.amenities,
          ratings: venue.ratings,
          image_refs: venue.image_refs,
          fetched_at: new Date().toISOString(),
        };
        const stageRes = await adminRequest(
          '/rest/v1/rpc/service_stage_import_venue',
          { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_payload: payload }) },
        );
        if (stageRes.ok) {
          const row = await stageRes.json();
          if (row.status === 'duplicate') duplicates += 1;
          else staged += 1;
        }
      }
    }

    await adminRequest(
      `/rest/v1/venue_import_jobs?id=eq.${encodeURIComponent(jobId!)}`,
      {
        method: 'PATCH',
        body: JSON.stringify({
          status: 'review',
          venues_fetched: fetched,
          venues_staged: staged,
          venues_duplicates: duplicates,
          completed_at: new Date().toISOString(),
        }),
      },
    );

    return json({
      job_id: jobId,
      venues_fetched: fetched,
      venues_staged: staged,
      venues_duplicates: duplicates,
      source: enrichWithPlaces && GOOGLE_PLACES_API_KEY ? 'osm+google' : 'osm',
    });
  } catch (error) {
    console.error('import-venues error', error);
    return json({ error: 'import_failed', detail: String(error) }, 500);
  }
});

function normalizeOsmTags(raw: unknown): string[] {
  if (Array.isArray(raw)) return raw.map(String).filter(Boolean);
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed.map(String).filter(Boolean);
    } catch {
      return raw ? [raw] : [];
    }
  }
  return [];
}

function buildTagQueries(osmTags: string[], areaRef = 'area.searchArea'): string {
  return osmTags.map((tag) => {
    const t = String(tag).trim();
    if (t.startsWith('name~=')) {
      const pattern = t.slice('name~='.length).replace(/"/g, '\\"');
      return `nwr["name"~"${pattern}",i](${areaRef});`;
    }
    if (t.includes('=')) {
      const i = t.indexOf('=');
      const k = t.slice(0, i).replace(/"/g, '\\"');
      const v = t.slice(i + 1).replace(/"/g, '\\"');
      return `nwr["${k}"="${v}"](${areaRef});`;
    }
    return `nwr["${t.replace(/"/g, '\\"')}"](${areaRef});`;
  }).join('\n  ');
}

async function fetchOsmVenues(
  country: string,
  state: string,
  osmTags: string[],
  district = '',
): Promise<OsmVenue[]> {
  if (!osmTags.length) return [];

  const areaName = district && district !== 'Entire state'
    ? `${district}, ${state}, ${country}`
    : `${state}, ${country}`;
  const tagQueries = buildTagQueries(osmTags);

  let areaBlock = `area["name"="${state}"]["admin_level"~"4|5"]->.searchArea;`;
  if (district && district !== 'Entire state') {
    areaBlock = `
area["name"="${state}"]["admin_level"~"4|5"]->.stateArea;
area["name"="${district}"]["admin_level"~"5|6"](area.stateArea)->.searchArea;`;
  }

  const query = `
[out:json][timeout:25];
${areaBlock}
(
  ${tagQueries}
);
out center tags;
`;

  const response = await fetch(OVERPASS_URL, {
    method: 'POST',
    body: query,
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    signal: AbortSignal.timeout(30_000),
  });

  if (!response.ok) {
    console.warn('Overpass failed, trying Nominatim area fallback');
    return await fetchOsmViaNominatim(areaName, osmTags);
  }

  const data = await response.json();
  const elements = data.elements ?? [];
  return elements
    .filter((el: Record<string, unknown>) => el.tags && (el.tags as Record<string, string>).name)
    .map((el: Record<string, unknown>) => mapOsmElement(el));
}

async function fetchOsmViaNominatim(areaName: string, osmTags: string[]): Promise<OsmVenue[]> {
  const nominatim = await fetch(
    `${NOMINATIM_URL}?q=${encodeURIComponent(areaName)}&format=json&limit=1`,
    {
      headers: { 'User-Agent': 'BookMySpace/1.0 (venue-import; contact@bookmyspace.app)' },
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (!nominatim.ok) return [];
  const areas = await nominatim.json();
  if (!areas[0]) return [];

  const bbox = areas[0].boundingbox as string[];
  const south = bbox[0];
  const north = bbox[1];
  const west = bbox[2];
  const east = bbox[3];

  const tagFilter = buildTagQueries(osmTags, `${south},${west},${north},${east}`);

  const query = `
[out:json][timeout:25];
(
  ${tagFilter}
);
out center tags;
`;

  const response = await fetch(OVERPASS_URL, {
    method: 'POST',
    body: query,
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) return [];
  const data = await response.json();
  return (data.elements ?? [])
    .filter((el: Record<string, unknown>) => el.tags && (el.tags as Record<string, string>).name)
    .map((el: Record<string, unknown>) => mapOsmElement(el));
}

type OsmVenue = {
  name: string;
  address: string;
  city: string;
  district: string;
  postal_code: string;
  phone: string;
  website: string;
  lat: number;
  lng: number;
  osm_id: string;
  hours: unknown[];
  amenities: string[];
  image_refs: Array<{ url: string; alt: string }>;
};

function mapOsmElement(el: Record<string, unknown>): OsmVenue {
  const tags = el.tags as Record<string, string>;
  const lat = (el.lat as number) ?? (el.center as { lat: number })?.lat ?? 0;
  const lng = (el.lon as number) ?? (el.center as { lon: number })?.lon ?? 0;
  const osmType = el.type as string;
  const osmId = `${osmType}/${el.id}`;

  const amenities: string[] = [];
  if (tags.wifi === 'yes') amenities.push('WiFi');
  if (tags.parking === 'yes') amenities.push('Parking');
  if (tags.toilets === 'yes') amenities.push('Restrooms');
  if (tags.air_conditioning === 'yes') amenities.push('Air conditioning');

  const imageRefs: Array<{ url: string; alt: string }> = [];
  if (tags.image) {
    imageRefs.push({ url: tags.image, alt: tags.name });
  }
  if (tags.wikimedia_commons) {
    imageRefs.push({
      url: `https://commons.wikimedia.org/wiki/Special:FilePath/${tags.wikimedia_commons}`,
      alt: tags.name,
    });
  }

  return {
    name: tags.name,
    address: [tags['addr:street'], tags['addr:housenumber']].filter(Boolean).join(' '),
    city: tags['addr:city'] ?? tags['addr:town'] ?? '',
    district: tags['addr:district'] ?? tags['addr:suburb'] ?? '',
    postal_code: tags['addr:postcode'] ?? '',
    phone: tags.phone ?? tags['contact:phone'] ?? '',
    website: tags.website ?? tags['contact:website'] ?? '',
    lat,
    lng,
    osm_id: osmId,
    hours: [],
    amenities,
    image_refs: imageRefs,
  };
}

async function fetchGooglePlaces(
  country: string,
  state: string,
  placeType: string,
  district = '',
): Promise<GoogleVenue[]> {
  const area = district && district !== 'Entire state'
    ? `${district}, ${state}, ${country}`
    : `${state}, ${country}`;
  const textQuery = `${placeType} in ${area}`;
  const response = await fetch('https://places.googleapis.com/v1/places:searchText', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': GOOGLE_PLACES_API_KEY,
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.nationalPhoneNumber,places.websiteUri,places.rating,places.userRatingCount,places.photos',
    },
    body: JSON.stringify({ textQuery, maxResultCount: 20 }),
    signal: AbortSignal.timeout(20_000),
  });

  if (!response.ok) {
    console.warn('Google Places search failed', await response.text());
    return [];
  }

  const data = await response.json();
  const places = data.places ?? [];

  return places.map((p: Record<string, unknown>) => ({
    place_id: p.id as string,
    name: (p.displayName as { text: string })?.text ?? '',
    address: p.formattedAddress as string ?? '',
    city: '',
    phone: p.nationalPhoneNumber as string ?? '',
    website: p.websiteUri as string ?? '',
    lat: (p.location as { latitude: number })?.latitude ?? 0,
    lng: (p.location as { longitude: number })?.longitude ?? 0,
    hours: [],
    amenities: [],
    ratings: {
      avg: p.rating ?? 0,
      count: p.userRatingCount ?? 0,
    },
    // Never embed API keys in stored URLs.
    image_refs: ((p.photos as Array<{ name: string }>) ?? []).slice(0, 3).map((photo) => ({
      photo_name: photo.name,
      source: 'google_places',
      alt: (p.displayName as { text: string })?.text ?? '',
    })),
  }));
}

type GoogleVenue = {
  place_id: string;
  name: string;
  address: string;
  city: string;
  phone: string;
  website: string;
  lat: number;
  lng: number;
  hours: unknown[];
  amenities: string[];
  ratings: Record<string, number>;
  image_refs: Array<{ url: string; alt: string }>;
};

function adminRequest(path: string, init: RequestInit = {}) {
  return fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
