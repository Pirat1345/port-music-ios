/**
 * helpers/model_validator.js
 * Validates Codable Swift models (Track, DiscoveryTrack, DiscoveryHomeResponse, etc.)
 * against schema definitions, JSON fixtures, toTrack() conversions, and LRC lyrics parsing.
 */

const fs = require('fs');
const path = require('path');
const { parseFile, findStructs, findProperties } = require('./swift_parser');

/**
 * Validates Track struct definition in MusicModels.swift
 */
function validateTrackModel(filePath) {
  const parsed = parseFile(filePath);
  const trackStruct = parsed.structs.find(s => s.name === 'Track');

  if (!trackStruct) {
    return { valid: false, errors: ['Track struct not found in ' + filePath] };
  }

  const errors = [];
  const requiredFields = [
    { name: 'id', type: 'String' },
    { name: 'title', type: 'String' },
    { name: 'artist', type: 'String' },
    { name: 'album', type: 'String?' },
    { name: 'duration', type: 'String' },
    { name: 'durationSeconds', type: 'Double' },
    { name: 'coverUrl', type: 'String?' },
    { name: 'isLive', type: 'Bool' },
    { name: 'isExplicit', type: 'Bool' },
  ];

  const props = findProperties(trackStruct.body);
  for (const field of requiredFields) {
    const prop = props.find(p => p.name === field.name);
    if (!prop) {
      errors.push(`Missing field in Track: ${field.name}`);
    } else if (field.type && !prop.type?.includes(field.type.replace('?', ''))) {
      errors.push(`Field ${field.name} expected type ${field.type}, got ${prop.type}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    propsCount: props.length,
  };
}

/**
 * Validates that all toTrack() conversion methods hardcode isLive: false
 */
function validateToTrackConversions(filePath) {
  const parsed = parseFile(filePath);
  const errors = [];
  const structsWithToTrack = [];

  for (const str of parsed.structs) {
    if (str.body.includes('func toTrack()')) {
      structsWithToTrack.push(str.name);

      // Verify isLive: false is present in toTrack body
      const toTrackMatch = str.body.match(/func toTrack\(\)[^{]*\{([^}]+)\}/);
      if (toTrackMatch) {
        const body = toTrackMatch[1];
        if (!body.includes('isLive: false')) {
          errors.push(`Struct ${str.name}.toTrack() must explicitly set isLive: false`);
        }
      } else {
        errors.push(`Could not parse body of ${str.name}.toTrack()`);
      }
    }
  }

  return {
    valid: errors.length === 0 && structsWithToTrack.length > 0,
    errors,
    structsCount: structsWithToTrack.length,
    structs: structsWithToTrack,
  };
}

/**
 * Validates a JSON fixture against expected response structures
 */
function validateDiscoveryHomeFixture(fixturePath) {
  const data = JSON.parse(fs.readFileSync(fixturePath, 'utf-8'));
  const errors = [];

  const expectedArrays = [
    'topPicks',
    'trendingEverywhere',
    'newMusic',
    'todaysTopHits',
    'top100Global',
    'topAlbums',
    'topPlaylists',
    'trendingArtists',
    'trendingAlbums',
    'moodsAndGenres',
  ];

  for (const key of expectedArrays) {
    if (data[key] !== undefined && !Array.isArray(data[key])) {
      errors.push(`Key ${key} in DiscoveryHomeResponse must be an Array or undefined`);
    }
  }

  if (data.topPicks && data.topPicks.length > 0) {
    const pick = data.topPicks[0];
    if (!pick.id || !pick.title || !pick.cover) {
      errors.push('DiscoveryPosterPick missing required fields (id, title, cover)');
    }
  }

  if (data.trendingEverywhere && data.trendingEverywhere.length > 0) {
    const track = data.trendingEverywhere[0];
    if (!track.id || !track.title || !track.artist) {
      errors.push('DiscoveryTrack missing required fields (id, title, artist)');
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validates DiscoverySearchResponse fixture
 */
function validateDiscoverySearchFixture(fixturePath) {
  const data = JSON.parse(fs.readFileSync(fixturePath, 'utf-8'));
  const errors = [];

  const expectedArrays = ['tracks', 'albums', 'artists', 'playlists'];
  for (const key of expectedArrays) {
    if (data[key] !== undefined && !Array.isArray(data[key])) {
      errors.push(`Key ${key} in DiscoverySearchResponse must be an Array`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Parses LRC lyrics content and returns array of timestamped lines
 */
function parseLrc(content) {
  const lines = content.split('\n');
  const result = [];
  const tagRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/;

  for (const line of lines) {
    const match = line.trim().match(tagRegex);
    if (match) {
      const min = parseInt(match[1], 10);
      const sec = parseInt(match[2], 10);
      const msPart = match[3];
      const ms = msPart.length === 2 ? parseInt(msPart, 10) * 10 : parseInt(msPart, 10);
      const totalSeconds = min * 60 + sec + ms / 1000;
      const text = match[4].trim();

      result.push({
        timestamp: totalSeconds,
        formattedTime: `${match[1]}:${match[2]}`,
        text,
      });
    }
  }

  return result;
}

/**
 * Validates AuthCheckResponse fixture (/api/auth/check)
 */
function validateAuthCheckFixture(fixturePath) {
  const data = JSON.parse(fs.readFileSync(fixturePath, 'utf-8'));
  const errors = [];

  if (typeof data.authenticated !== 'boolean') {
    errors.push('Key authenticated in AuthCheckResponse must be a boolean');
  }
  if (!data.user || typeof data.user !== 'object') {
    errors.push('Missing user object in auth_check fixture');
  } else {
    if (!data.user.id && !data.user.userId) {
      errors.push('User missing id or userId in auth_check fixture');
    }
    if (!data.user.username) {
      errors.push('User missing username in auth_check fixture');
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    data,
  };
}

module.exports = {
  validateTrackModel,
  validateToTrackConversions,
  validateDiscoveryHomeFixture,
  validateDiscoverySearchFixture,
  validateAuthCheckFixture,
  parseLrc,
};
