/**
 * helpers/contract_checker.js
 * Validates interface contracts defined in PROJECT.md and TEST_INFRA.md
 * across AudioPlayerManager, SessionManager, MusicService, KeychainHelper, and AuthService.
 */

const fs = require('fs');
const path = require('path');
const { parseFile, findProperties, findMethods } = require('./swift_parser');

/**
 * Validates AudioPlayerManager ↔ Views interface contract
 */
function validateAudioPlayerManagerContract(filePath) {
  const parsed = parseFile(filePath);
  const managerClass = parsed.classes.find(c => c.name === 'AudioPlayerManager');

  if (!managerClass) {
    return { valid: false, errors: ['AudioPlayerManager class not found'] };
  }

  const errors = [];
  const properties = findProperties(managerClass.body);
  const methods = findMethods(managerClass.body);

  // Required Published state properties
  const requiredPublishedProps = [
    'currentTrack',
    'isPlaying',
    'isBuffering',
    'currentTime',
    'duration',
    'queue',
    'queueIndex',
    'isShuffle',
    'isRepeat',
  ];

  for (const propName of requiredPublishedProps) {
    const prop = properties.find(p => p.name === propName);
    if (!prop) {
      errors.push(`Missing property: ${propName}`);
    } else if (!prop.hasWrapper('Published')) {
      errors.push(`Property ${propName} must be annotated with @Published`);
    }
  }

  // Required methods
  const requiredMethods = [
    { name: 'play', minParams: 2 },
    { name: 'togglePlayPause', minParams: 0 },
    { name: 'seek', minParams: 1 },
    { name: 'next', minParams: 1 },
    { name: 'previous', minParams: 1 },
  ];

  for (const req of requiredMethods) {
    const found = methods.find(m => m.name === req.name && m.params.length >= req.minParams);
    if (!found) {
      errors.push(`Missing method: ${req.name} with >= ${req.minParams} params`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    propsCount: properties.length,
    methodsCount: methods.length,
  };
}

/**
 * Validates SessionManager ↔ Views interface contract
 */
function validateSessionManagerContract(filePath) {
  const parsed = parseFile(filePath);
  const sessionClass = parsed.classes.find(c => c.name === 'SessionManager');

  if (!sessionClass) {
    return { valid: false, errors: ['SessionManager class not found'] };
  }

  const errors = [];
  const properties = findProperties(sessionClass.body);
  const methods = findMethods(sessionClass.body);

  const requiredProps = ['isAuthenticated', 'currentUser', 'serverURL'];
  for (const propName of requiredProps) {
    const prop = properties.find(p => p.name === propName);
    if (!prop) {
      errors.push(`Missing property: ${propName}`);
    } else if (!prop.hasWrapper('Published')) {
      errors.push(`Property ${propName} must be annotated with @Published`);
    }
  }

  const requiredMethods = [
    { name: 'loginSuccess' },
    { name: 'logout' },
    { name: 'restoreSession' },
  ];

  for (const req of requiredMethods) {
    const found = methods.find(m => m.name === req.name);
    if (!found) {
      errors.push(`Missing method: ${req.name}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validates MusicService ↔ Discovery & Content interface contract
 */
function validateMusicServiceContract(filePath) {
  const parsed = parseFile(filePath);
  const serviceClass = parsed.classes.find(c => c.name === 'MusicService');

  if (!serviceClass) {
    return { valid: false, errors: ['MusicService class not found'] };
  }

  const errors = [];
  const methods = findMethods(serviceClass.body);

  const requiredMethods = [
    { name: 'streamURL' },
    { name: 'fetchHomeDiscovery', isAsync: true },
    { name: 'search', isAsync: true },
    { name: 'fetchDiscoverySearch', isAsync: true },
    { name: 'fetchArtist', isAsync: true },
    { name: 'fetchAlbum', isAsync: true },
    { name: 'fetchPlaylists', isAsync: true },
    { name: 'fetchFavorites', isAsync: true },
    { name: 'toggleFavorite', isAsync: true },
  ];

  for (const req of requiredMethods) {
    const found = methods.find(m => m.name === req.name);
    if (!found) {
      errors.push(`Missing method: ${req.name}`);
    } else if (req.isAsync && !found.isAsync) {
      errors.push(`Method ${req.name} must be declared async`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validates KeychainHelper interface contract
 */
function validateKeychainHelperContract(filePath) {
  const parsed = parseFile(filePath);
  const helperClass = parsed.classes.find(c => c.name === 'KeychainHelper');

  if (!helperClass) {
    return { valid: false, errors: ['KeychainHelper class not found'] };
  }

  const errors = [];
  const methods = findMethods(helperClass.body);

  // Check service identifier
  if (!parsed.rawContains('com.portmusic.ios.auth')) {
    errors.push('KeychainHelper must use service identifier "com.portmusic.ios.auth"');
  }

  const requiredMethods = ['saveToken', 'getToken', 'deleteToken'];
  for (const name of requiredMethods) {
    if (!methods.some(m => m.name === name)) {
      errors.push(`Missing method: ${name}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validates AuthService interface contract
 */
function validateAuthServiceContract(filePath) {
  const parsed = parseFile(filePath);
  const authClass = parsed.classes.find(c => c.name === 'AuthService');

  if (!authClass) {
    return { valid: false, errors: ['AuthService class not found'] };
  }

  const errors = [];
  const methods = findMethods(authClass.body);

  const requiredMethods = [
    { name: 'checkAuth', isAsync: true },
    { name: 'login', isAsync: true },
    { name: 'verify2FA', isAsync: true },
  ];

  for (const req of requiredMethods) {
    const found = methods.find(m => m.name === req.name);
    if (!found) {
      errors.push(`Missing method: ${req.name}`);
    } else if (req.isAsync && !found.isAsync) {
      errors.push(`Method ${req.name} must be declared async`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

function findProjectMdPath() {
  if (process.env.PROJECT_MD_PATH && fs.existsSync(process.env.PROJECT_MD_PATH)) {
    return process.env.PROJECT_MD_PATH;
  }
  const scratchBase = 'C:\\Users\\Pirat1345\\.gemini\\antigravity\\scratch\\teamwork';
  if (fs.existsSync(scratchBase)) {
    try {
      const runs = fs.readdirSync(scratchBase);
      for (const r of runs.reverse()) {
        const p = path.join(scratchBase, r, '.agents', 'teamwork', 'PROJECT.md');
        if (fs.existsSync(p)) return p;
      }
    } catch (_) {}
  }
  const localProject = path.resolve(__dirname, '..', '..', '..', 'PROJECT.md');
  if (fs.existsSync(localProject)) return localProject;
  return null;
}

let cachedProjectMd = null;
function getProjectMdContent() {
  if (cachedProjectMd) return cachedProjectMd;
  const p = findProjectMdPath();
  if (p && fs.existsSync(p)) {
    cachedProjectMd = fs.readFileSync(p, 'utf-8');
    return cachedProjectMd;
  }
  return '';
}

function validateInterfaceContract(serviceName, methodName) {
  const content = getProjectMdContent();
  if (!content) return false;
  const regex = new RegExp(`\`?${methodName}\\b`, 'i');
  return regex.test(content);
}

function validateFeatureSpecification(featureNumber) {
  const content = getProjectMdContent();
  if (!content) return false;
  const regex = new RegExp(`\\|\\s*${featureNumber}\\s*\\|`, 'm');
  return regex.test(content);
}

module.exports = {
  validateAudioPlayerManagerContract,
  validateSessionManagerContract,
  validateMusicServiceContract,
  validateKeychainHelperContract,
  validateAuthServiceContract,
  validateInterfaceContract,
  validateFeatureSpecification,
  getProjectMdContent,
};
