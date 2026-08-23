# India location master sources

This repository does not bundle Indian geography. Runtime Flutter code never
calls these government sites. Source files are acquired offline, validated,
normalized, dry-run, reviewed, and only then eligible for a separately
approved DEV import.

## Authoritative sources

### LGD — administrative hierarchy

- Authority: Government of India, Ministry of Panchayati Raj
- Portal: <https://lgdirectory.gov.in/>
- Download entry: <https://lgdirectory.gov.in/demo/downloadDirectory.do>
- Data.gov.in catalog: <https://www.data.gov.in/catalog/local-government-directory-lgd>
- Required exports: States/UTs, Districts, Sub-Districts, Development Blocks
  where available, Villages, and the corresponding LGD code/relationship
  exports.
- LGD codes and source relationships are authoritative. Names alone must not
  create parent relationships.

The LGD portal may require an interactive/manual export. CAPTCHA-protected
downloads must be obtained manually; this project does not scrape or bypass
CAPTCHA.

### India Post / OGD — postal hierarchy and PIN mappings

- Catalog: <https://www.data.gov.in/catalog/all-india-pincode-directory-through-webservice>
- Resource: <https://www.data.gov.in/resource/all-india-pincode-directory-till-last-month>
- Optional related resource: the official “Locality based Pincode” dataset,
  when its machine-readable export and provenance are available.
- Required fields where supplied: PIN, post-office name, office type,
  delivery status, district, state, and locality/sub-district fields.

India Post rows are postal evidence, not LGD administrative entities. One PIN
may map to many post offices/locations, and one location may have many PINs.

### GeoNames

GeoNames is optional enrichment only. It is not required for India hierarchy
ingestion and must never override LGD or India Post relationships.

## Offline source layout

```text
data/location/sources/
  lgd/                         # manually downloaded official LGD exports
  india-post/                  # official OGD/India Post exports
  manifest.json                # provenance/checksum for files that exist
  normalized/                  # generated JSONL; never hand-authored
```

The importer accepts the filenames listed in `manifest.json`; it does not
assume GeoNames filenames such as `allCountries.zip` or `IN.zip`.

Each manifest entry must contain:

```json
{
  "authority": "LGD",
  "dataset": "states",
  "official_url": "https://...",
  "local_file": "lgd/states.csv",
  "published_at": "YYYY-MM-DD",
  "sha256": "<sha256 of the present file>",
  "record_count": 0,
  "coverage": "description of levels/states covered",
  "parser_version": "1"
}
```

Do not add a checksum, record count, coverage claim, or normalized output until
the referenced file is actually present and validated.

## Required workflow

```text
official file → manifest/checksum validation → format validation
→ source-code parent validation → normalization → dry-run → review
→ explicitly approved DEV import
```

The current task stops before normalization/import because the official LGD and
India Post files have not been supplied in this worktree.

