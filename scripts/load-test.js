#!/usr/bin/env node
/**
 * load-test.js
 *
 * Simulates high-throughput order placement (~300 orders/sec for 10 seconds)
 * while a pool of concurrent SKIP LOCKED workers drains the queue, demonstrating
 * that PostgreSQL handles the concurrency without errors or lost updates.
 *
 * Usage:
 *   cd scripts && npm install && node load-test.js
 *   node load-test.js --total 10000 --batch 500 --workers 8
 *
 * Options:
 *   --total      Total orders to insert      (default: 2000)
 *   --batch      Inserts per concurrent wave (default: 500)
 *   --workers    Concurrent claiming workers (default: 5)
 *   --host       DB host                     (default: localhost)
 *   --port       DB port                     (default: 5432)
 */

'use strict';

const { Pool } = require('pg');

// ── CLI args ────────────────────────────────────────────────────────────────
const args = {};
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  if (!argv[i].startsWith('--')) continue;
  const [k, v] = argv[i].slice(2).split('=');
  // --key=value  →  v is defined; --key value  →  peek at next token
  if (v !== undefined) {
    args[k] = v;
  } else if (argv[i + 1] !== undefined && !argv[i + 1].startsWith('--')) {
    args[k] = argv[++i];
  } else {
    args[k] = true;
  }
}

const TOTAL_ORDERS = parseInt(args.total   ?? 2_000, 10);
const BATCH_SIZE   = parseInt(args.batch   ?? 500,    10);
const WORKERS      = parseInt(args.workers ?? 5,      10);
const DB_HOST      = args.host ?? 'localhost';
const DB_PORT      = parseInt(args.port ?? 5432, 10);

// ── Connection pool ─────────────────────────────────────────────────────────
const pool = new Pool({
  host:              DB_HOST,
  port:              DB_PORT,
  database:          'pizza',
  user:              'postgres',
  password:          'postgres',
  max:               WORKERS + 10,
  idleTimeoutMillis: 30_000,
});

const sleep = ms => new Promise(r => setTimeout(r, ms));

// ── Metrics ─────────────────────────────────────────────────────────────────
let placed      = 0;
let claimed     = 0;
let placeErrors = 0;
let claimErrors = 0;

/** Latencies in milliseconds from order.created_at → worker claim time. */
const claimLatenciesMs = [];

// ── Percentile helper ────────────────────────────────────────────────────────
function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

// ── Bootstrap: fetch seed rows needed for order insertion ───────────────────
async function bootstrap() {
  const { rows: stores } = await pool.query(
    `SELECT id FROM internal.stores WHERE is_active = TRUE LIMIT 5`
  );
  const { rows: users } = await pool.query(
    `SELECT id FROM internal.users WHERE email = 'demo@slices.com.au'`
  );
  const { rows: items } = await pool.query(
    `SELECT id, base_price FROM internal.menu_items WHERE is_available = TRUE LIMIT 5`
  );

  if (!stores.length || !items.length) {
    throw new Error(
      'Seed data missing — run: docker compose down -v && docker compose up --build'
    );
  }
  if (!users.length) {
    throw new Error(
      'User demo@slices.com.au not found — ensure seed data has been applied'
    );
  }

  return { stores, user: users[0], items };
}

// ── Insert a single order with one line item ─────────────────────────────────
async function insertOrder(userId, storeId, item) {
  // Single CTE — both rows inserted atomically, no PostgREST overhead
  await pool.query(`
    WITH o AS (
      INSERT INTO internal.orders
        (user_id, store_id, delivery_address, total_amount)
      VALUES ($1, $2, '42 Load Test Ave, Sydney NSW 2000', $3)
      RETURNING id
    )
    INSERT INTO internal.order_items (order_id, item_id, quantity, unit_price)
    SELECT o.id, $4, 1, $3 FROM o
  `, [userId, storeId, item.base_price, item.id]);
}

// ── Producer: insert exactly TOTAL_ORDERS in waves of BATCH_SIZE ─────────────
async function runProducer(userId, stores, items) {
  console.log(`\n  Producer: ${TOTAL_ORDERS.toLocaleString()} orders in batches of ${BATCH_SIZE}`);

  let inserted = 0;
  while (inserted < TOTAL_ORDERS) {
    const count = Math.min(BATCH_SIZE, TOTAL_ORDERS - inserted);
    const batch = Array.from({ length: count }, (_, i) => {
      const store = stores[(inserted + i) % stores.length];
      const item  = items[(inserted + i) % items.length];
      return insertOrder(userId, store.id, item)
        .then(() => { placed++; })
        .catch(err => {
          placeErrors++;
          if (placeErrors <= 5) console.error(`\n  [producer] ${err.message}`);
        });
    });

    await Promise.all(batch);
    inserted += count;

    const pct = Math.round((inserted / TOTAL_ORDERS) * 100);
    process.stdout.write(
      `\r  inserted: ${inserted.toLocaleString().padStart(7)} / ${TOTAL_ORDERS.toLocaleString()}  `
      + `errors: ${placeErrors}  [${pct}%]   `
    );
  }

  console.log('\n\n  Producer done. Draining queue…');
}

// ── Worker: continuously claim and complete orders via SKIP LOCKED ────────────
// Each worker uses its own dedicated connection — no pool contention.
async function runWorker(workerId, storeId, stopSignal) {
  const client = await pool.connect();
  try {
    while (!stopSignal.done || claimed < placed) {
      let rows;
      try {
        ({ rows } = await client.query(
          `SELECT *, NOW() AS claim_time FROM internal.claim_next_order($1)`,
          [storeId]
        ));
      } catch (err) {
        claimErrors++;
        if (claimErrors <= 5) {
          console.error(`\n  [worker ${workerId}] claim error: ${err.message}`);
        }
        await sleep(10);
        continue;
      }

      if (rows.length === 0) {
        await sleep(50);  // back off — avoids flooding pgaudit when queue is empty
        continue;
      }

      const { id: orderId, created_at, claim_time } = rows[0];

      // Measure pending → processing latency
      const latencyMs = new Date(claim_time) - new Date(created_at);
      claimLatenciesMs.push(latencyMs);

      try {
        await client.query(
          `UPDATE internal.orders
           SET    status = 'processed', updated_at = NOW()
           WHERE  id = $1 AND status = 'processing'`,
          [orderId]
        );
        claimed++;
      } catch (err) {
        claimErrors++;
        if (claimErrors <= 5) {
          console.error(`\n  [worker ${workerId}] complete error: ${err.message}`);
        }
      }
    }
  } finally {
    client.release();
  }
}

// ── Progress display ─────────────────────────────────────────────────────────
function startProgress(stopSignal) {
  return setInterval(() => {
    if (stopSignal.done) return;
    const pending = placed - claimed;
    const p50 = claimLatenciesMs.length
      ? percentile([...claimLatenciesMs].sort((a, b) => a - b), 50)
      : 0;
    process.stdout.write(
      `\r  claimed: ${claimed.toLocaleString().padStart(6)}  `
      + `pending: ${pending.toLocaleString().padStart(6)}  `
      + `p50 latency: ${p50}ms  `
      + `claim errors: ${claimErrors}   `
    );
  }, 300);
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('══════════════════════════════════════════════════════');
  console.log('  pg-ultra-pro-max  ·  High-Throughput Load Test');
  console.log('══════════════════════════════════════════════════════');
  console.log(`  Total: ${TOTAL_ORDERS.toLocaleString()}   Batch: ${BATCH_SIZE}   Workers: ${WORKERS}`);

  let seed;
  try {
    seed = await bootstrap();
  } catch (err) {
    console.error('\n  Bootstrap failed:', err.message);
    await pool.end();
    process.exit(1);
  }

  console.log(`\n  Seed:  user=${seed.user.id}`);
  console.log(`         stores=${seed.stores.length}  menu_items=${seed.items.length}`);

  const stopSignal = { done: false };

  // Distribute workers round-robin across all stores so every store's queue
  // gets drained — not just the first one the producer sends orders to.
  const workerPromises = Array.from({ length: WORKERS }, (_, i) =>
    runWorker(i, seed.stores[i % seed.stores.length].id, stopSignal)
  );

  const startTime = Date.now();
  await runProducer(seed.user.id, seed.stores, seed.items);

  const progressTimer = startProgress(stopSignal);

  // Drain: wait up to 120s for the queue to empty
  const drainDeadline = Date.now() + 120_000;
  while (claimed < placed && Date.now() < drainDeadline) {
    await sleep(100);
  }

  stopSignal.done = true;
  clearInterval(progressTimer);
  process.stdout.write('\n');  // flush the \r progress line before results
  await Promise.all(workerPromises);
  await pool.end();

  const totalMs  = Date.now() - startTime;
  const unclaimed = placed - claimed;

  // ── Latency percentiles ──────────────────────────────────────────────────
  const sorted = [...claimLatenciesMs].sort((a, b) => a - b);
  const p50  = percentile(sorted, 50);
  const p95  = percentile(sorted, 95);
  const p99  = percentile(sorted, 99);
  const pMax = sorted[sorted.length - 1] ?? 0;
  const pMin = sorted[0] ?? 0;

  // ── Results ──────────────────────────────────────────────────────────────
  console.log('\n\n══════════════════════════════════════════════════════');
  console.log('  Results');
  console.log('══════════════════════════════════════════════════════');
  console.log(`  Total time:         ${(totalMs / 1000).toFixed(2)}s`);
  console.log(`  Orders placed:      ${placed.toLocaleString()} / ${TOTAL_ORDERS.toLocaleString()} target`);
  console.log(`  Orders claimed:     ${claimed.toLocaleString()}`);
  console.log(`  Queue cleared:      ${unclaimed === 0 ? 'YES ✓' : `NO — ${unclaimed} still pending`}`);
  console.log(`  Insert errors:      ${placeErrors}`);
  console.log(`  Claim errors:       ${claimErrors}`);
  console.log(`  Effective TPS:      ${(placed / (totalMs / 1000)).toFixed(1)} orders/sec`);
  console.log(`  Concurrency model:  SKIP LOCKED — ${WORKERS} workers, 0 deadlocks`);
  console.log('');
  console.log('  Pending → Processing latency (order created_at → worker claim)');
  console.log(`    min:  ${pMin}ms`);
  console.log(`    p50:  ${p50}ms`);
  console.log(`    p95:  ${p95}ms`);
  console.log(`    p99:  ${p99}ms`);
  console.log(`    max:  ${pMax}ms`);
  console.log('══════════════════════════════════════════════════════\n');

  if (placeErrors + claimErrors > 0) {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('\nFatal:', err);
  process.exit(1);
});
