# Migration ordering — read this before adding or filtering migrations

Every file in this directory is applied, in filename order, to every
environment that runs these migrations — including a fresh dev database,
CI, and production. There is no "dev-only" migration in the sense of
"safe to skip": files named `*_dev.sql`, `*_dev_verify*.sql`, or
`dev_reconciled_*.sql` describe *when they were authored/tested*, not
*where they're allowed to run*. Several of them contain schema
corrections (added columns, dropped columns, renamed constraints) that a
later migration depends on being present — for example
`20260820090200_dev_reconciled_0015_engagement.sql` is what makes
`public.notifications` end up with the `read`/`read_at`/`updated_at`
columns the Flutter client actually uses, correcting a column set
(`is_read`) that an earlier migration (`0006`) created first. Skipping a
"dev" file by name will leave the schema in the state before that
correction — go read the migration content, not the filename, before
deciding a file is optional.

If you're auditing for duplicate `create table`/`create policy`
declarations across files: most duplicates in this directory are
deliberately idempotent (`create table if not exists`, `drop policy if
exists` + `create policy`) and are safe to re-run. A small number are
NOT idempotent (a plain `create table` followed later by a
differently-shaped `create table if not exists` for the same name) —
those are exactly the drift-then-patch pairs described above, and the
patch file is load-bearing, not optional cleanup.
