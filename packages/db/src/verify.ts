/**
 * Post-migration smoke check. Proves that the guarantees the application
 * relies on are actually enforced by the database, not just described in a
 * document: workflow immutability, task workflow pinning, row_version bumps
 * and location_pings partitioning.
 *
 * Run against a scratch database: pnpm --filter @dijigoo/db run verify
 */
import postgres from 'postgres';

const url = process.env['DATABASE_URL'];
if (!url) {
  console.error('DATABASE_URL tanimli degil.');
  process.exit(1);
}

const sql = postgres(url, { max: 1, prepare: false, onnotice: () => {} });

let failures = 0;

function check(name: string, ok: boolean, detail = '') {
  console.log(`${ok ? '  ok  ' : ' FAIL '} ${name}${detail ? ` — ${detail}` : ''}`);
  if (!ok) failures += 1;
}

async function expectRejection(name: string, run: () => Promise<unknown>, fragment: string) {
  try {
    await run();
    check(name, false, 'islem reddedilmedi');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    check(name, message.includes(fragment), message.slice(0, 120));
  }
}

try {
  const [tables] = await sql<{ count: number }[]>`
    select count(*)::int as count from information_schema.tables
    where table_schema = 'public' and table_type = 'BASE TABLE'
  `;
  const tableCount = tables?.count ?? 0;
  check('tablolar olusturuldu', tableCount >= 30, `${tableCount} tablo`);

  const [version] = await sql<{ postgis: string }[]>`select postgis_version() as postgis`;
  check('PostGIS aktif', Boolean(version?.postgis), version?.postgis ?? 'yok');

  const partitions = await sql<{ relname: string }[]>`
    select c.relname from pg_class c
    join pg_inherits i on i.inhrelid = c.oid
    join pg_class p on p.oid = i.inhparent
    where p.relname = 'location_pings'
  `;
  check('location_pings bolumlendi', partitions.length >= 2, `${partitions.length} bolum`);

  // --- Seed a minimal graph ------------------------------------------------
  const [tenant] = await sql<{ id: string }[]>`
    insert into tenants (name, slug) values ('Verify', ${`verify-${Date.now()}`}) returning id
  `;
  const tenantId = tenant!.id;

  const [courier] = await sql<{ id: string }[]>`
    insert into couriers (tenant_id, phone, full_name)
    values (${tenantId}, ${`+9053${Date.now().toString().slice(-8)}`}, 'Test Kurye')
    returning id
  `;
  const courierId = courier!.id;

  const [wf] = await sql<{ id: string }[]>`
    insert into workflows (tenant_id, key, version, name, status, applies_to, steps, outcomes, min_app_build)
    values (${tenantId}, 'verify_akis', 1, 'Verify', 'published',
            ${sql.json(['DELIVERY'])}, ${sql.json([])}, ${sql.json([])}, 1)
    returning id
  `;
  const workflowId = wf!.id;

  // --- Rule K2: published workflows are immutable --------------------------
  await expectRejection(
    'yayinlanmis workflow degistirilemez',
    () => sql`update workflows set name = 'Degisti' where id = ${workflowId}`,
    'Yayinlanmis workflow degistirilemez',
  );

  await expectRejection(
    'yayinlanmis workflow silinemez',
    () => sql`delete from workflows where id = ${workflowId}`,
    'Yayinlanmis workflow silinemez',
  );

  // Archiving without touching the definition is the one permitted update.
  await sql`update workflows set status = 'archived' where id = ${workflowId}`;
  const [archived] = await sql<{ status: string }[]>`
    select status from workflows where id = ${workflowId}
  `;
  check('arsivleme serbest', archived?.status === 'archived', archived?.status ?? 'yok');

  // --- row_version is maintained by the database ---------------------------
  const [task] = await sql<{ id: string; row_version: number }[]>`
    insert into tasks (tenant_id, courier_id, reference, type, address_line1, city,
                       workflow_id, workflow_key, workflow_version, position)
    values (${tenantId}, ${courierId}, ${`VER-${Date.now()}`}, 'DELIVERY',
            'Test Mah. 1', 'Istanbul', ${workflowId}, 'verify_akis', 1,
            ST_SetSRID(ST_MakePoint(28.9784, 41.0082), 4326))
    returning id, row_version
  `;
  const taskId = task!.id;
  check('yeni gorev row_version = 0', task!.row_version === 0, String(task!.row_version));

  await sql`update tasks set status = 'ACCEPTED' where id = ${taskId}`;
  const [afterUpdate] = await sql<{ row_version: number; updated_at: Date }[]>`
    select row_version, updated_at from tasks where id = ${taskId}
  `;
  check('guncelleme row_version artirir', afterUpdate!.row_version === 1, String(afterUpdate!.row_version));

  // --- Rule K3: a started task keeps its workflow version ------------------
  await sql`update tasks set started_at = now() where id = ${taskId}`;
  await expectRejection(
    'baslamis gorevin workflow surumu sabit',
    () => sql`update tasks set workflow_version = 2 where id = ${taskId}`,
    'workflow surumu degistirilemez',
  );

  // --- Geography distance, the query shape the API actually uses -----------
  const nearby = await sql<{ id: string; meters: number }[]>`
    select id, ST_Distance(position::geography,
                           ST_SetSRID(ST_MakePoint(28.9790, 41.0085), 4326)::geography) as meters
    from tasks
    where ST_DWithin(position::geography,
                     ST_SetSRID(ST_MakePoint(28.9790, 41.0085), 4326)::geography, 200)
      and id = ${taskId}
  `;
  check(
    'ST_DWithin metre cinsinden calisiyor',
    nearby.length === 1 && nearby[0]!.meters < 200,
    nearby[0] ? `${Math.round(nearby[0].meters)} m` : 'sonuc yok',
  );

  // --- location_pings routes into the right partition ----------------------
  const [shift] = await sql<{ id: string }[]>`
    insert into shifts (courier_id, started_at) values (${courierId}, now()) returning id
  `;
  await sql`
    insert into location_pings (shift_id, courier_id, position, accuracy, captured_at)
    values (${shift!.id}, ${courierId},
            ST_SetSRID(ST_MakePoint(28.9784, 41.0082), 4326), 12.5, now())
  `;
  const [pings] = await sql<{ count: number }[]>`
    select count(*)::int as count from location_pings where shift_id = ${shift!.id}
  `;
  check('konum kaydi bolume yazildi', pings?.count === 1, `${pings?.count ?? 0} kayit`);

  // --- One open shift per courier -----------------------------------------
  await expectRejection(
    'kurye basina tek acik vardiya',
    () => sql`insert into shifts (courier_id, started_at) values (${courierId}, now())`,
    'shifts_open_courier_uq',
  );

  // Cleanup. Tenant references are `restrict` by design, so the order here is
  // the reverse of the dependency graph rather than a single cascading delete.
  await sql`delete from location_pings where courier_id = ${courierId}`;
  await sql`delete from tasks where tenant_id = ${tenantId}`;
  await sql`delete from couriers where tenant_id = ${tenantId}`;
  await sql`delete from workflows where tenant_id = ${tenantId}`;
  await sql`delete from tenants where id = ${tenantId}`;

  console.log(failures === 0 ? '\nTum kontroller gecti.' : `\n${failures} kontrol basarisiz.`);
  process.exitCode = failures === 0 ? 0 : 1;
} catch (error) {
  console.error('Dogrulama hatasi:', error);
  process.exitCode = 1;
} finally {
  await sql.end();
}
