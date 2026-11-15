/**
 * helpers/swift_parser.js
 * Robust Swift AST tokenizer and syntax extractor for Port Music iOS app.
 * Handles comment stripping (preserving string literals), struct/class/enum discovery,
 * property wrapper analysis (@Published, @State, etc.), method scanning, and SwiftUI structure inspection.
 */

const fs = require('fs');
const path = require('path');

/**
 * Strips single-line and multiline comments from Swift source code
 * without modifying string literals or multiline strings.
 */
function stripComments(source) {
  let result = '';
  let i = 0;
  const len = source.length;

  let inSingleQuote = false;
  let inDoubleQuote = false;
  let inMultilineString = false;
  let inLineComment = false;
  let inBlockComment = 0; // Supports nested block comments in Swift

  while (i < len) {
    const char = source[i];
    const next = i + 1 < len ? source[i + 1] : '';
    const next2 = i + 2 < len ? source[i + 2] : '';

    if (inLineComment) {
      if (char === '\n') {
        inLineComment = false;
        result += char;
      }
      i++;
      continue;
    }

    if (inBlockComment > 0) {
      if (char === '/' && next === '*') {
        inBlockComment++;
        i += 2;
        continue;
      } else if (char === '*' && next === '/') {
        inBlockComment--;
        i += 2;
        continue;
      }
      i++;
      continue;
    }

    if (inMultilineString) {
      if (char === '"' && next === '"' && next2 === '"') {
        inMultilineString = false;
        result += '"""';
        i += 3;
        continue;
      }
      result += char;
      i++;
      continue;
    }

    if (inDoubleQuote) {
      if (char === '\\') {
        result += char + next;
        i += 2;
        continue;
      }
      if (char === '"') {
        inDoubleQuote = false;
      }
      result += char;
      i++;
      continue;
    }

    // Check for comment starts
    if (char === '/' && next === '/') {
      inLineComment = true;
      i += 2;
      continue;
    }

    if (char === '/' && next === '*') {
      inBlockComment = 1;
      i += 2;
      continue;
    }

    // Check for string starts
    if (char === '"' && next === '"' && next2 === '"') {
      inMultilineString = true;
      result += '"""';
      i += 3;
      continue;
    }

    if (char === '"') {
      inDoubleQuote = true;
      result += char;
      i++;
      continue;
    }

    result += char;
    i++;
  }

  return result;
}

/**
 * Extracts a balanced code block starting at the opening brace '{'
 */
function extractBraceBlock(source, startIndex) {
  let openCount = 0;
  let blockStart = -1;

  for (let i = startIndex; i < source.length; i++) {
    if (source[i] === '{') {
      if (openCount === 0) blockStart = i;
      openCount++;
    } else if (source[i] === '}') {
      openCount--;
      if (openCount === 0) {
        return {
          start: blockStart,
          end: i + 1,
          body: source.substring(blockStart + 1, i),
        };
      }
    }
  }

  return null;
}

/**
 * Discovers all struct declarations
 */
function findStructs(cleanCode) {
  const structs = [];
  const regex = /(?:(public|private|fileprivate|internal)\s+)?struct\s+([A-Za-z0-9_]+)(?:\s*:\s*([^{]+))?\s*\{/g;
  let match;

  while ((match = regex.exec(cleanCode)) !== null) {
    const access = match[1] || 'internal';
    const name = match[2];
    const protocols = match[3] ? match[3].split(',').map(p => p.trim()) : [];
    const block = extractBraceBlock(cleanCode, match.index);

    if (block) {
      structs.push({
        name,
        access,
        protocols,
        body: block.body,
        rawHeader: match[0],
      });
    }
  }

  return structs;
}

/**
 * Discovers all class declarations
 */
function findClasses(cleanCode) {
  const classes = [];
  const regex = /(?:(public|private|fileprivate|internal)\s+)?(?:(final)\s+)?class\s+([A-Za-z0-9_]+)(?:\s*:\s*([^{]+))?\s*\{/g;
  let match;

  while ((match = regex.exec(cleanCode)) !== null) {
    const access = match[1] || 'internal';
    const isFinal = !!match[2];
    const name = match[3];
    const inheritance = match[4] ? match[4].split(',').map(p => p.trim()) : [];
    const block = extractBraceBlock(cleanCode, match.index);

    if (block) {
      classes.push({
        name,
        access,
        isFinal,
        inheritance,
        body: block.body,
        rawHeader: match[0],
      });
    }
  }

  return classes;
}

/**
 * Discovers all enum declarations and their cases
 */
function findEnums(cleanCode) {
  const enums = [];
  const regex = /(?:(public|private|fileprivate|internal)\s+)?enum\s+([A-Za-z0-9_]+)(?:\s*:\s*([^{]+))?\s*\{/g;
  let match;

  while ((match = regex.exec(cleanCode)) !== null) {
    const access = match[1] || 'internal';
    const name = match[2];
    const protocols = match[3] ? match[3].split(',').map(p => p.trim()) : [];
    const block = extractBraceBlock(cleanCode, match.index);

    if (block) {
      const cases = [];
      const caseRegex = /case\s+([A-Za-z0-9_]+)(?:\s*=\s*([^,\n]+))?/g;
      let caseMatch;
      while ((caseMatch = caseRegex.exec(block.body)) !== null) {
        cases.push({
          name: caseMatch[1],
          rawValue: caseMatch[2] ? caseMatch[2].trim() : undefined,
        });
      }

      enums.push({
        name,
        access,
        protocols,
        cases,
        body: block.body,
      });
    }
  }

  return enums;
}

/**
 * Scans a code block for property declarations with property wrappers
 */
function findProperties(body) {
  const properties = [];
  const propRegex = /(?:(@[A-Za-z0-9_]+(?:\([^)]*\))?)\s+)*(?:(public|private|fileprivate|internal)(?:\((?:set|get)\))?\s+)*(?:(static)\s+)?(var|let)\s+([A-Za-z0-9_]+)\s*(?::\s*([^=;\n{]+))?(?:\s*=\s*([^;\n{]+))?/g;
  let match;

  while ((match = propRegex.exec(body)) !== null) {
    const fullMatch = match[0];
    const wrappers = [];
    const wrapperRegex = /@([A-Za-z0-9_]+)(?:\(([^)]*)\))?/g;
    let wMatch;
    while ((wMatch = wrapperRegex.exec(fullMatch)) !== null) {
      wrappers.push({ name: wMatch[1], args: wMatch[2] || null });
    }

    const isStatic = !!match[3];
    const kind = match[4]; // var | let
    const name = match[5];
    const type = match[6] ? match[6].trim() : null;
    const initialValue = match[7] ? match[7].trim() : null;

    properties.push({
      name,
      kind,
      type,
      initialValue,
      isStatic,
      wrappers,
      hasWrapper: (wName) => wrappers.some(w => w.name === wName),
    });
  }

  return properties;
}

/**
 * Scans a code block for method definitions
 */
function findMethods(body) {
  const methods = [];
  const methodRegex = /(?:(public|private|fileprivate|internal)\s+)*(?:(static)\s+)?func\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)(?:\s*(async))?(?:\s*(throws))?(?:\s*->\s*([^{]+))?/g;
  let match;

  while ((match = methodRegex.exec(body)) !== null) {
    const access = match[1] || 'internal';
    const isStatic = !!match[2];
    const name = match[3];
    const rawParams = match[4].trim();
    const isAsync = !!match[5];
    const isThrows = !!match[6];
    const returnType = match[7] ? match[7].trim() : 'Void';

    const params = rawParams.length > 0
      ? rawParams.split(',').map(p => {
          const parts = p.trim().split(':');
          return {
            name: parts[0]?.trim() || '',
            type: parts[1]?.trim() || '',
          };
        })
      : [];

    methods.push({
      name,
      access,
      isStatic,
      isAsync,
      isThrows,
      returnType,
      params,
    });
  }

  return methods;
}

/**
 * Checks if a view body contains a specific SwiftUI modifier
 */
function viewContainsModifier(body, modifierName) {
  const regex = new RegExp(`\\.${modifierName}\\s*\\(`, 'm');
  return regex.test(body);
}

/**
 * Checks if a view body contains a child component or view
 */
function viewContainsChild(body, childName) {
  const regex = new RegExp(`\\b${childName}\\s*\\(`, 'm');
  return regex.test(body);
}

/**
 * Checks if code imports a module
 */
function hasImport(code, moduleName) {
  const regex = new RegExp(`^\\s*import\\s+${moduleName}\\b`, 'm');
  return regex.test(code);
}

/**
 * High-level parser for a Swift file
 */
function parseFile(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Swift file not found: ${filePath}`);
  }

  const raw = fs.readFileSync(filePath, 'utf-8');
  const clean = stripComments(raw);

  return {
    filePath,
    raw,
    clean,
    structs: findStructs(clean),
    classes: findClasses(clean),
    enums: findEnums(clean),
    hasImport: (mod) => hasImport(clean, mod),
    contains: (pattern) => {
      if (pattern instanceof RegExp) return pattern.test(clean);
      return clean.includes(pattern);
    },
    rawContains: (pattern) => {
      if (pattern instanceof RegExp) return pattern.test(raw);
      return raw.includes(pattern);
    },
  };
}

module.exports = {
  stripComments,
  extractBraceBlock,
  findStructs,
  findClasses,
  findEnums,
  findProperties,
  findMethods,
  viewContainsModifier,
  viewContainsChild,
  hasImport,
  parseFile,
};
