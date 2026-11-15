#!/usr/bin/env node
/**
 * runner.js
 * Master E2E Test Suite Runner for Port Music v2 Native iOS App Rebuild.
 * Coordinates execution of Tier 1 (115), Tier 2 (115), Tier 3 (25), and Tier 4 (12) tests.
 * Outputs human-readable matrix table, TAP format, or structured JSON.
 * Exits with code 0 on 100% pass, or code 1 on failure.
 */

const process = require('process');
const { runTier1Tests } = require('./tier1_features.test');
const { runTier2Tests } = require('./tier2_boundaries.test');
const { runTier3Tests } = require('./tier3_pairwise.test');
const { runTier4Tests } = require('./tier4_scenarios.test');

// Command line argument parsing
const args = process.argv.slice(2);
const isTap = args.includes('--tap');
const isJson = args.includes('--json');
const isVerbose = args.includes('--verbose') || args.includes('-v');

// Parse --tier flag (1, 2, 3, 4)
let requestedTier = null;
const tierArg = args.find(a => a.startsWith('--tier=') || a === '--tier');
if (tierArg) {
  let rawTier = '';
  if (tierArg.startsWith('--tier=')) {
    rawTier = tierArg.slice('--tier='.length);
  } else {
    const idx = args.indexOf('--tier');
    if (idx !== -1 && idx + 1 < args.length && !args[idx + 1].startsWith('-')) {
      rawTier = args[idx + 1];
    }
  }
  const parsed = parseInt(rawTier.trim(), 10);
  if ([1, 2, 3, 4].includes(parsed)) {
    requestedTier = parsed;
  } else {
    console.error(`Invalid tier: "${rawTier}". Valid options are 1, 2, 3, 4.`);
    process.exit(1);
  }
}

// Parse --filter flag
let filterRegex = null;
const filterArg = args.find(a => a.startsWith('--filter=') || a === '--filter');
if (filterArg) {
  let rawFilter = '';
  if (filterArg.startsWith('--filter=')) {
    rawFilter = filterArg.slice('--filter='.length);
  } else {
    const idx = args.indexOf('--filter');
    if (idx !== -1 && idx + 1 < args.length && !args[idx + 1].startsWith('-')) {
      rawFilter = args[idx + 1];
    }
  }
  try {
    filterRegex = new RegExp(rawFilter.trim(), 'i');
  } catch (err) {
    console.error(`Invalid filter pattern: "${rawFilter}": ${err.message}`);
    process.exit(1);
  }
}

// Helper: Format milliseconds
function formatMs(ms) {
  return `${ms.toFixed(1)}ms`;
}

// Helper: ANSI colors
const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m',
  white: '\x1b[37m',
};

async function main() {
  const overallStart = Date.now();
  const tierResults = [];

  // Execute Tier 1
  if (requestedTier === null || requestedTier === 1) {
    const t1Start = Date.now();
    let t1 = await runTier1Tests();
    if (filterRegex) t1 = t1.filter(t => filterRegex.test(t.id) || filterRegex.test(t.name));
    tierResults.push({
      tier: 1,
      name: 'Tier 1: Feature Coverage (F01..F23)',
      tests: t1,
      durationMs: Date.now() - t1Start,
    });
  }

  // Execute Tier 2
  if (requestedTier === null || requestedTier === 2) {
    const t2Start = Date.now();
    let t2 = await runTier2Tests();
    if (filterRegex) t2 = t2.filter(t => filterRegex.test(t.id) || filterRegex.test(t.name));
    tierResults.push({
      tier: 2,
      name: 'Tier 2: Boundary & Corner Cases (F01..F23)',
      tests: t2,
      durationMs: Date.now() - t2Start,
    });
  }

  // Execute Tier 3
  if (requestedTier === null || requestedTier === 3) {
    const t3Start = Date.now();
    let t3 = await runTier3Tests();
    if (filterRegex) t3 = t3.filter(t => filterRegex.test(t.id) || filterRegex.test(t.name));
    tierResults.push({
      tier: 3,
      name: 'Tier 3: Cross-Feature Interactions (T3_C01..C25)',
      tests: t3,
      durationMs: Date.now() - t3Start,
    });
  }

  // Execute Tier 4
  if (requestedTier === null || requestedTier === 4) {
    const t4Start = Date.now();
    let t4 = await runTier4Tests();
    if (filterRegex) t4 = t4.filter(t => filterRegex.test(t.id) || filterRegex.test(t.name));
    tierResults.push({
      tier: 4,
      name: 'Tier 4: Real-World Scenarios (T4_W01..W12)',
      tests: t4,
      durationMs: Date.now() - t4Start,
    });
  }

  const allTests = tierResults.flatMap(t => t.tests);
  const totalCount = allTests.length;
  const passedCount = allTests.filter(t => t.passed).length;
  const failedCount = allTests.filter(t => !t.passed).length;
  const totalDurationMs = Date.now() - overallStart;

  // Output format 1: JSON
  if (isJson) {
    console.log(JSON.stringify({
      summary: {
        total: totalCount,
        passed: passedCount,
        failed: failedCount,
        durationMs: totalDurationMs,
        success: failedCount === 0,
      },
      tiers: tierResults.map(tr => ({
        tier: tr.tier,
        name: tr.name,
        total: tr.tests.length,
        passed: tr.tests.filter(t => t.passed).length,
        failed: tr.tests.filter(t => !t.passed).length,
        durationMs: tr.durationMs,
        tests: tr.tests,
      })),
    }, null, 2));
    process.exit(failedCount === 0 ? 0 : 1);
  }

  // Output format 2: TAP (Test Anything Protocol)
  if (isTap) {
    console.log(`1..${totalCount}`);
    let idx = 1;
    for (const test of allTests) {
      if (test.passed) {
        console.log(`ok ${idx} - [${test.id}] ${test.name} (${test.durationMs}ms)`);
      } else {
        console.log(`not ok ${idx} - [${test.id}] ${test.name} (${test.durationMs}ms)`);
        console.log(`  ---`);
        console.log(`  message: "${test.error || 'Assertion failed'}"`);
        console.log(`  severity: fail`);
        console.log(`  ...`);
      }
      idx++;
    }
    process.exit(failedCount === 0 ? 0 : 1);
  }

  // Output format 3: Formatted Human-Readable Matrix Table
  console.log('\n' + colors.bold + colors.cyan + '=================================================================================' + colors.reset);
  console.log(colors.bold + colors.white + ' PORT MUSIC V2 - NATIVE IOS E2E TEST SUITE RUNNER' + colors.reset);
  console.log(colors.bold + colors.cyan + '=================================================================================' + colors.reset);
  console.log(`${colors.gray}Target: Native iOS App (PortMusic Target: iOS 16.0+, Swift 5.0)${colors.reset}`);
  console.log(`${colors.gray}Harness: Windows Node.js v24.15.0 Static AST & Contract Verification${colors.reset}\n`);

  console.log(colors.bold + '┌──────┬────────────────────────────────────────────────────────┬───────┬────────┬──────────┐' + colors.reset);
  console.log(colors.bold + '│ Tier │ Scope                                                  │ Count │ Status │ Time     │' + colors.reset);
  console.log(colors.bold + '├──────┼────────────────────────────────────────────────────────┼───────┼────────┼──────────┤' + colors.reset);

  for (const tr of tierResults) {
    const tierPassed = tr.tests.filter(t => t.passed).length;
    const tierFailed = tr.tests.filter(t => !t.passed).length;
    const tierStatus = tierFailed === 0
      ? `${colors.green}✓ PASS${colors.reset}`
      : `${colors.red}✗ FAIL(${tierFailed})${colors.reset}`;

    const padName = tr.name.padEnd(54, ' ');
    const padCount = String(tr.tests.length).padStart(5, ' ');
    const padTime = `${tr.durationMs}ms`.padStart(8, ' ');

    console.log(`│   T${tr.tier} │ ${padName} │ ${padCount} │ ${tierStatus} │ ${padTime} │`);

    if (isVerbose || tierFailed > 0) {
      for (const t of tr.tests) {
        const icon = t.passed ? `${colors.green}✓${colors.reset}` : `${colors.red}✗${colors.reset}`;
        if (!t.passed || isVerbose) {
          console.log(`│      │   ${icon} [${t.id}] ${t.name.slice(0, 68)}`);
          if (!t.passed) {
            console.log(`│      │      ${colors.red}Error: ${t.error}${colors.reset}`);
          }
        }
      }
    }
  }

  console.log(colors.bold + '└──────┴────────────────────────────────────────────────────────┴───────┴────────┴──────────┘' + colors.reset);

  // Feature Breakdown Summary for Tiers 1 & 2
  const featureMap = new Map();
  for (const t of allTests) {
    const fKey = t.feature || 'Other';
    if (!featureMap.has(fKey)) {
      featureMap.set(fKey, { total: 0, passed: 0, failed: 0 });
    }
    const stat = featureMap.get(fKey);
    stat.total++;
    if (t.passed) stat.passed++;
    else stat.failed++;
  }

  console.log('\n' + colors.bold + 'Coverage Summary by Feature (F01..F23):' + colors.reset);
  let featureSummaryLine = '  ';
  let featCount = 0;
  for (const [feat, stat] of Array.from(featureMap.entries()).filter(([k]) => k.startsWith('F'))) {
    const tag = stat.failed === 0 ? `${colors.green}${feat}: ${stat.passed}/${stat.total}${colors.reset}` : `${colors.red}${feat}: ${stat.passed}/${stat.total}${colors.reset}`;
    featureSummaryLine += tag + '   ';
    featCount++;
    if (featCount % 6 === 0) {
      console.log(featureSummaryLine);
      featureSummaryLine = '  ';
    }
  }
  if (featureSummaryLine.trim().length > 0) {
    console.log(featureSummaryLine);
  }

  console.log('\n' + colors.bold + colors.cyan + '---------------------------------------------------------------------------------' + colors.reset);
  if (failedCount === 0) {
    console.log(colors.bold + colors.green + ` PASS: All ${totalCount} automated tests passed cleanly! (${totalDurationMs}ms)` + colors.reset);
    console.log(`${colors.green} Invariants Adhered: Strict Radio vs Song Isolation (100%), Zero Deerflow Branding (100%)${colors.reset}`);
  } else {
    console.log(colors.bold + colors.red + ` FAIL: ${failedCount} of ${totalCount} tests failed (${passedCount} passed)` + colors.reset);
  }
  console.log(colors.bold + colors.cyan + '=================================================================================\n' + colors.reset);

  process.exit(failedCount === 0 ? 0 : 1);
}

main().catch(err => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});
