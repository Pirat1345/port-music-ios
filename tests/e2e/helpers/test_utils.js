/**
 * helpers/test_utils.js
 * Assertion helpers and execution utilities for E2E tests.
 */

const fs = require('fs');
const path = require('path');

function assert(condition, message = 'Assertion failed') {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message || 'Assertion failed'}: expected [${expected}], got [${actual}]`);
  }
}

function assertNotEqual(actual, expected, message) {
  if (actual === expected) {
    throw new Error(`${message || 'Assertion failed'}: expected value NOT to equal [${expected}]`);
  }
}

function assertIncludes(haystack, needle, message) {
  if (!haystack || !haystack.includes(needle)) {
    throw new Error(`${message || 'Assertion failed'}: expected [${haystack}] to include [${needle}]`);
  }
}

function assertMatch(text, regex, message) {
  if (!regex.test(text)) {
    throw new Error(`${message || 'Assertion failed'}: text does not match regex ${regex}`);
  }
}

function assertDefined(val, message) {
  if (val === undefined || val === null) {
    throw new Error(message || 'Expected value to be defined and not null');
  }
}

/**
 * Recursively find all files with given extensions in a directory
 */
function findFiles(dir, extensions = ['.swift']) {
  let results = [];
  if (!fs.existsSync(dir)) return results;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results = results.concat(findFiles(fullPath, extensions));
    } else if (extensions.some(ext => entry.name.endsWith(ext))) {
      results.push(fullPath);
    }
  }
  return results;
}

/**
 * Loads a fixture from the fixtures folder
 */
function loadFixture(name) {
  const p = path.resolve(__dirname, '..', 'fixtures', name);
  if (!fs.existsSync(p)) {
    throw new Error(`Fixture not found: ${p}`);
  }
  if (name.endsWith('.json')) {
    return JSON.parse(fs.readFileSync(p, 'utf-8'));
  }
  return fs.readFileSync(p, 'utf-8');
}

/**
 * Executes a single test case safely
 */
async function executeTest(id, name, feature, fn) {
  const start = Date.now();
  try {
    await fn();
    const durationMs = Date.now() - start;
    return {
      id,
      name,
      feature,
      passed: true,
      durationMs,
    };
  } catch (err) {
    const durationMs = Date.now() - start;
    return {
      id,
      name,
      feature,
      passed: false,
      error: err.message,
      durationMs,
    };
  }
}

module.exports = {
  assert,
  assertEqual,
  assertNotEqual,
  assertIncludes,
  assertMatch,
  assertDefined,
  findFiles,
  loadFixture,
  executeTest,
};
