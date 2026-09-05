# Phase 16 — Supabase India location migration plan

## Gate

Import is blocked until all of these are independently evidenced:

- `POSTAL_METADATA_STATUS=COMPLETE`
- `LGD_COVERAGE_STATUS=COMPLETE`
- `POSTAL_LGD_MAPPING_STATUS=COMPLETE`
- `PINCODE_LOOKUP_STATUS=READY`
- `IMPORT_READINESS=READY`

Current decision: `POSTAL_LGD_MAPPING_INCOMPLETE`. No import, migration execution, or remote database write is authorized.

## Repository schema review

- Supabase project identifier in `supabase/config.toml`: `bookmyspace`.
- Application schema used by migrations and Flutter repositories: `public`.
- Location hierarchy: `public.location_nodes`, introduced by `20260820080000_global_location_master.sql`.
- Location aliases: `public.location_aliases`.
- Location suggestions: `public.location_suggestions`.
- Location history: `public.location_change_history`.
- Postal links: `public.location_postal_codes`, introduced by `20260823120000_india_location_pin_master.sql`.
- Venue association: nullable `public.venues.location_node_id`.
- Legacy venue fields remain: `city`, `state`, and `postal_code`; these must not be silently replaced.

The existing tables should be reused. Do not create a second state, district, village, or pincode hierarchy.

## Existing hierarchy model

`location_nodes.parent_id` is a self-reference with levels currently covering:

`country`, `state_province`, `district_county`, `mandal_taluk_tehsil_block`, `city_town`, `village`, and `area_locality`.

`official_code` is available for an authoritative LGD identifier. `metadata` is available for source provenance during the review period, but a future import should use explicit provenance columns or a dedicated source mapping table only if the final reviewed design requires them.

`location_postal_codes` is intentionally many-to-many: its primary key is `(location_id, postal_code)`, and `postal_code` has a six-digit check constraint plus a lookup index. This supports one pincode mapping to multiple locations.

## Existing integrity and security

- `location_nodes.parent_id` has a foreign key to `location_nodes(id)`.
- `location_postal_codes.location_id` has a foreign key to `location_nodes(id)` with cascade delete.
- Active sibling names are unique by `(parent_id, level, normalized_name)` through a partial unique index.
- Parent/level/status and country/level/status indexes exist.
- Active level/name and active parent/name indexes exist.
- RLS is enabled on location tables and postal links.
- Public reads are restricted to active, approved locations; administrative writes use existing role authorization through `public.has_role`.
- The application uses `location_nodes`, `location_postal_codes`, the descendant/path RPCs where available, and `venues.location_node_id` for location-aware search and pincode lookup.

## Proposed source-to-schema mapping

| Source record | Existing target | Required mapping |
|---|---|---|
| State/UT | `location_nodes` | `level=state_province`, LGD ID in `official_code`, parent India node |
| District | `location_nodes` | `level=district_county`, validated state parent |
| Sub-district | `location_nodes` | `level=mandal_taluk_tehsil_block`, validated district parent |
| Village | `location_nodes` | `level=village`, validated sub-district parent |
| Town/city/locality | `location_nodes` | corresponding existing level, validated parent |
| Pincode-to-location link | `location_postal_codes` | six-digit code plus verified `location_id` |
| Postal office metadata | **not currently represented as a dedicated table** | requires reviewed additive design; do not overload `location_nodes` or invent a one-to-one pincode mapping |

Postal office rows must not be imported into `location_nodes`. A future postal-office table or reviewed metadata extension must preserve office identity, circle, region, division, delivery status, source file, page, and row provenance, while allowing multiple offices per pincode.

## Planned indexes and duplicate prevention

Reuse existing indexes first. After the readiness gate, validate whether additional indexes are needed for:

- `location_nodes(official_code, level, country_code)` with a uniqueness rule scoped to the authoritative source;
- postal-office lookup by normalized office name and pincode;
- source provenance and deterministic source-record identity;
- LGD parent traversal through the existing `parent_id` indexes.

Any new uniqueness rule must be based on authoritative source identity, not normalized name alone. Conflicts and duplicate official IDs must be resolved in the dry-run report before SQL is prepared for execution.

## Application query impact

The Flutter location repository reads active approved `location_nodes`, traverses `parent_id`, looks up `location_postal_codes`, and falls back to legacy `metadata` pincode fields when no postal link exists. Venue search also uses `venues.location_node_id`, legacy postal text, and the existing descendant RPC. The import must preserve these query contracts and must not alter booking, pricing, payment, or venue behavior.

## Migration sequence after approval

1. Complete and sign off LGD and postal source audits.
2. Produce deterministic postal-office and postal-to-LGD mapping artifacts.
3. Reconcile conflicts against the DEV database read-only.
4. Review exact additive SQL and RLS policy changes.
5. Run migration only against DEV with an explicit approval.
6. Import in bounded, resumable batches using stable source IDs.
7. Reconcile counts, parent integrity, pincode lookups, RLS behavior, and application queries.
8. Do not promote to production until the same evidence is complete.

## Explicit non-actions in Phase 16.0

- No Supabase connection was made.
- No SQL was executed.
- No migration file was created for execution.
- No tables, columns, indexes, policies, or data were changed.
- No production configuration or application data was changed.
