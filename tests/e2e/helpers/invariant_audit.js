/**
 * helpers/invariant_audit.js
 * Invariant enforcement and compliance audits for Port Music v2.
 * 1. Strict Radio vs. Song Isolation (AGENTS.md Invariant 2)
 * 2. Zero Third-Party Branding / Deerflow Prohibition (AGENTS.md Invariant 5)
 * 3. XcodeGen Project Spec & Build Configuration Audit
 */

const fs = require('fs');
const path = require('path');
const { parseFile, extractBraceBlock, stripComments } = require('./swift_parser');

/**
 * Standard track ID prefixes that must NEVER be treated as radio
 */
const STANDARD_SONG_PREFIXES = [
  'apple_',
  'deezer_',
  'dz_',
  'yt_',
  'search:',
  'loc_',
  'custom-',
  'pick_',
  'tth_',
  't100_',
];

/**
 * Audits Swift codebase for Radio vs. Song Isolation
 */
function auditRadioVsSongIsolation(swiftFiles) {
  const violations = [];

  for (const file of swiftFiles) {
    const content = fs.readFileSync(file, 'utf-8');

    // Invariant 2: Tracks must never have isLive: true if they are standard songs
    // Search for assignments or definitions setting isLive: true on normal track constructors
    for (const prefix of STANDARD_SONG_PREFIXES) {
      const regex = new RegExp(`["']${prefix}[^"']*["'][^;]*isLive:\\s*true`, 'i');
      if (regex.test(content)) {
        violations.push({
          file,
          rule: 'isLive_true_on_standard_track',
          detail: `Track with prefix ${prefix} assigned isLive: true in ${file}`,
        });
      }
    }

    // Normal tracks must never have duration "LIVE"
    const liveDurationRegex = /Track\s*\([^)]*duration:\s*["']LIVE["']/i;
    if (liveDurationRegex.test(content)) {
      violations.push({
        file,
        rule: 'live_duration_on_track',
        detail: `Track initialized with duration: "LIVE" in ${file}`,
      });
    }

    // Normal tracks must never redirect to /radio
    if (content.includes('/radio')) {
      const clean = stripComments(content);

      // 1. Check all func definitions of play(track: ...)
      const funcPlayRegex = /func\s+play\s*\([^)]*track\s*:[^{]*\{/g;
      let match;
      while ((match = funcPlayRegex.exec(clean)) !== null) {
        const braceIdx = match.index + match[0].indexOf('{');
        const block = extractBraceBlock(clean, braceIdx);
        if (block && /["']\/?radio["']/i.test(block.body)) {
          violations.push({
            file,
            rule: 'redirect_to_radio',
            detail: `Found illegal redirection or routing to /radio inside play(track:) method body in ${file}`,
          });
        }
      }

      // 2. Check any function containing play(track: ...) that also performs /radio routing
      const funcRegex = /func\s+([A-Za-z0-9_]+)\s*\([^)]*\)[^{]*\{/g;
      while ((match = funcRegex.exec(clean)) !== null) {
        const funcName = match[1];
        if (funcName === 'play') continue;
        const braceIdx = match.index + match[0].indexOf('{');
        const block = extractBraceBlock(clean, braceIdx);
        if (block && /play\s*\(\s*track\s*:/i.test(block.body)) {
          if (/["']\/?radio["']/i.test(block.body) && /(?:redirect|route|navigate|navigationPath|append|push|tab|destination|present)/i.test(block.body)) {
            violations.push({
              file,
              rule: 'redirect_to_radio',
              detail: `Found illegal redirection to /radio during track playback in method ${funcName} in ${file}`,
            });
          }
        }
      }

      // 3. Multi-line statement scanner for adjacent playback and /radio navigation statements
      const adjacentRegex = /(?:play\s*\(\s*track\s*:[^;}]*[\s\S]{0,300}?(?:redirect|route|navigate|navigationPath|push|append|present)[^;}]*["']\/?radio["']|(?:redirect|route|navigate|navigationPath|push|append|present)[^;}]*["']\/?radio["'][\s\S]{0,300}?play\s*\(\s*track\s*:)/i;
      if (adjacentRegex.test(clean)) {
        if (!violations.some(v => v.file === file && v.rule === 'redirect_to_radio')) {
          violations.push({
            file,
            rule: 'redirect_to_radio',
            detail: `Found illegal redirection to /radio during track playback in ${file}`,
          });
        }
      }
    }
  }

  return {
    valid: violations.length === 0,
    violations,
    filesAudited: swiftFiles.length,
  };
}

/**
 * Forbidden third-party branding patterns (case-insensitive)
 */
const FORBIDDEN_BRANDING_PATTERNS = [
  /\bdeerflow\b/i,
  /deerflow\.tech/i,
  /deer_flow/i,
  /created\s+by\s+deerflow/i,
];

/**
 * Audits repository files for forbidden third-party branding
 */
function auditZeroBranding(filePaths) {
  const violations = [];

  for (const filePath of filePaths) {
    if (!fs.existsSync(filePath)) continue;
    // Skip binary files and git internals
    if (filePath.endsWith('.png') || filePath.endsWith('.ttf') || filePath.endsWith('.ipa') || filePath.includes('.git')) {
      continue;
    }

    let content = '';
    try {
      content = fs.readFileSync(filePath, 'utf-8');
    } catch {
      continue;
    }

    for (const pattern of FORBIDDEN_BRANDING_PATTERNS) {
      if (pattern.test(content)) {
        violations.push({
          file: filePath,
          matchedPattern: pattern.toString(),
        });
      }
    }
  }

  return {
    valid: violations.length === 0,
    violations,
    filesAudited: filePaths.length,
  };
}

/**
 * Audits XcodeGen project.yml configuration
 */
function auditXcodeGenProject(projectYmlPath) {
  if (!fs.existsSync(projectYmlPath)) {
    return { valid: false, errors: [`project.yml not found at ${projectYmlPath}`] };
  }

  const content = fs.readFileSync(projectYmlPath, 'utf-8');
  const errors = [];

  // Check iOS deployment target 16.0
  if (!content.includes('iOS: "16.0"') && !content.includes('deploymentTarget:\n      iOS: "16.0"') && !content.includes('iOS: 16.0')) {
    errors.push('project.yml must specify iOS deployment target 16.0');
  }

  // Check Swift version 5.0
  if (!content.includes('SWIFT_VERSION: "5.0"') && !content.includes('SWIFT_VERSION: 5.0')) {
    errors.push('project.yml must specify SWIFT_VERSION "5.0"');
  }

  // Check bundle identifier prefix or product bundle identifier
  if (!content.includes('com.portmusic.app') && !content.includes('bundleIdPrefix: com.portmusic')) {
    errors.push('project.yml must configure bundle identifier com.portmusic.app');
  }

  // Check source directory PortMusic
  if (!content.includes('path: PortMusic')) {
    errors.push('project.yml must include "PortMusic" sources directory');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

module.exports = {
  STANDARD_SONG_PREFIXES,
  auditRadioVsSongIsolation,
  auditZeroBranding,
  auditXcodeGenProject,
};
