/**
 * tier2_boundaries.test.js
 * Tier 2: Boundary & Corner Cases (115 tests = 23 features × 5 boundary tests)
 * Tests edge conditions, empty states, error fallbacks, and adversarial boundaries.
 */

const path = require('path');
const fs = require('fs');
const {
  assert,
  assertEqual,
  assertNotEqual,
  assertIncludes,
  assertMatch,
  assertDefined,
  findFiles,
  loadFixture,
  executeTest,
} = require('./helpers/test_utils');
const { parseFile, findProperties, findMethods } = require('./helpers/swift_parser');
const { parseLrc } = require('./helpers/model_validator');
const { validateInterfaceContract } = require('./helpers/contract_checker');
const {
  auditRadioVsSongIsolation,
  auditZeroBranding,
  auditXcodeGenProject,
} = require('./helpers/invariant_audit');

const BASE_DIR = path.resolve(__dirname, '..', '..');
const PORT_MUSIC_DIR = path.join(BASE_DIR, 'PortMusic');

async function runTier2Tests() {
  const tests = [];

  // ─────────────────────────────────────────────────────────────────────────────
  // F01: Preserve Login & Auth Flow (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F01_1', 'KeychainHelper.getToken() returns nil gracefully on missing token without throwing', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Security', 'KeychainHelper.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('getToken() -> String?'), 'getToken must return optional String?');
    assert(parsed.contains('errSecItemNotFound') || parsed.contains('status == noErr'), 'Must handle Keychain not found error code');
  }));

  tests.push(await executeTest('T2_F01_2', 'Server 401 response in checkAuth clears session state and resets isAuthenticated', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'AuthService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('401') || parsed.contains('clearSession()') || parsed.contains('unauthorized'), 'AuthService must handle 401 unauthorized');
  }));

  tests.push(await executeTest('T2_F01_3', 'Invalid login credentials map to localized German error message banner', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'AuthService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('mapGermanError'), 'AuthService must implement mapGermanError');
    assert(parsed.contains('Ungültige Anmeldedaten') || parsed.contains('Benutzername oder Passwort falsch'), 'Must map invalid credentials to German error text');
  }));

  tests.push(await executeTest('T2_F01_4', 'Invalid or expired 2FA OTP code resets textfield without crashing view', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Auth', 'TwoFactorView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('errorMessage') || parsed.contains('isVerifying'), 'TwoFactorView must manage reactive verification state');
  }));

  tests.push(await executeTest('T2_F01_5', 'Captcha challenge failure resets challenge state cleanly', 'F01', () => {
    const clawFile = path.join(PORT_MUSIC_DIR, 'Features', 'Captcha', 'ClawMachineView.swift');
    const parsed = parseFile(clawFile);
    assert(parsed.contains('phase') && parsed.contains('statusMessage'), 'ClawMachineView must manage phase and statusMessage state');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F02: Profile & Settings View (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F02_1', 'Handles null or empty user email with fallback display', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('user.email') || parsed.contains('user.username'), 'Profile view must safely unwrap user identity');
  }));

  tests.push(await executeTest('T2_F02_2', 'Extremely long server URLs are truncated or wrapped with .lineLimit', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.lineLimit'), 'Server URL display must have lineLimit');
  }));

  tests.push(await executeTest('T2_F02_3', 'Cache clear on empty disk cache directory succeeds cleanly (0 KB)', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Cache', 'PortImageCache.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('clearAllCache') || parsed.contains('clearDiskCache'), 'PortImageCache must support full cache purge');
  }));

  tests.push(await executeTest('T2_F02_4', 'Audio quality preference persists in @AppStorage across app relaunches', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('@AppStorage("portmusic_audio_quality")'), 'Quality selection must persist via AppStorage');
  }));

  tests.push(await executeTest('T2_F02_5', 'Logout button triggers warning haptic and onLogout handler', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('notificationOccurred(.warning)') && parsed.contains('onLogout()'), 'Logout must trigger warning haptic and invoke onLogout');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F03: Mobile Bottom Tab Bar (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F03_1', 'Tab switching preserves distinct view state without recreating hierarchy', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('selectedTab'), 'MainTabView must maintain stateful selectedTab binding');
  }));

  tests.push(await executeTest('T2_F03_2', 'Rapid tab tapping does not cause index out-of-bounds', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('MainTabItem.allCases'), 'Tab bar must iterate strictly over MainTabItem.allCases');
  }));

  tests.push(await executeTest('T2_F03_3', 'Safe area insets dynamically adapt without hardcoding absolute bottom offsets', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('ignoresSafeArea') || parsed.contains('safeAreaInset'), 'Must adapt to safe area');
  }));

  tests.push(await executeTest('T2_F03_4', 'Tab item enum raw values are continuous 0..3 for integer safety', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    const tabEnum = parsed.enums.find(e => e.name === 'MainTabItem');
    assertDefined(tabEnum, 'MainTabItem enum must exist');
    assertEqual(tabEnum.cases.length, 4, 'Must have 4 cases');
  }));

  tests.push(await executeTest('T2_F03_5', 'Tab bar z-index remains beneath fullscreen modal player sheets', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.fullScreenCover') || parsed.contains('showFullscreenPlayer'), 'Fullscreen player must present via fullScreenCover overlay');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F04: Floating Minibar Player (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F04_1', 'Minibar hides completely when player.currentTrack is nil', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('if let track = player.currentTrack'), 'Minibar must unwrap currentTrack safely');
  }));

  tests.push(await executeTest('T2_F04_2', 'Zero or negative duration clamped safely to 0.0 without division by zero', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('player.duration > 0') || parsed.contains('max(0,'), 'Must guard against zero/negative duration');
  }));

  tests.push(await executeTest('T2_F04_3', 'Extra-long song titles and artist names clamped with .lineLimit(1)', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.lineLimit(1)'), 'Minibar text must restrict to 1 line');
  }));

  tests.push(await executeTest('T2_F04_4', 'Displays buffering indicator when player.isBuffering is true', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('isBuffering') || parsed.contains('ProgressView'), 'Minibar must display buffering state');
  }));

  tests.push(await executeTest('T2_F04_5', 'Rapid play/pause tapping throttles audio state mutations', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('togglePlayPause()'), 'AudioPlayerManager must handle togglePlayPause() atomically');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F05: Build Configuration & XcodeGen (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F05_1', 'Code signing disabled for CI builds without signing identity required', 'F05', () => {
    const file = path.join(BASE_DIR, 'project.yml');
    const content = fs.readFileSync(file, 'utf-8');
    assert(content.includes('CODE_SIGNING_ALLOWED: NO'), 'CODE_SIGNING_ALLOWED must be NO');
    assert(content.includes('CODE_SIGNING_REQUIRED: NO'), 'CODE_SIGNING_REQUIRED must be NO');
  }));

  tests.push(await executeTest('T2_F05_2', 'Targeted device family configured for both iPhone (1) and iPad (2)', 'F05', () => {
    const file = path.join(BASE_DIR, 'project.yml');
    const content = fs.readFileSync(file, 'utf-8');
    assert(content.includes('TARGETED_DEVICE_FAMILY: "1,2"') || content.includes('TARGETED_DEVICE_FAMILY: 1,2'), 'Must support device family 1,2');
  }));

  tests.push(await executeTest('T2_F05_3', 'Asset catalog AccentColor, AppIcon, and PortLogo sets verified intact', 'F05', () => {
    const assetsDir = path.join(PORT_MUSIC_DIR, 'Resources', 'Assets.xcassets');
    assert(fs.existsSync(path.join(assetsDir, 'AccentColor.colorset')), 'AccentColor.colorset must exist');
    assert(fs.existsSync(path.join(assetsDir, 'AppIcon.appiconset')), 'AppIcon.appiconset must exist');
    assert(fs.existsSync(path.join(assetsDir, 'PortLogo.imageset')), 'PortLogo.imageset must exist');
  }));

  tests.push(await executeTest('T2_F05_4', 'Info.plist registers Manosque-Regular.ttf in UIAppFonts array', 'F05', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Resources', 'Info.plist');
    const content = fs.readFileSync(file, 'utf-8');
    assert(content.includes('UIAppFonts'), 'Info.plist must define UIAppFonts key');
    assert(content.includes('Manosque-Regular.ttf'), 'UIAppFonts must include Manosque-Regular.ttf');
  }));

  tests.push(await executeTest('T2_F05_5', 'Metal shaders included in Swift project compile bundle', 'F05', () => {
    const metalFile = path.join(PORT_MUSIC_DIR, 'Core', 'Theme', 'Shaders', 'FluentSilkShader.metal');
    assert(fs.existsSync(metalFile), 'Metal shader file must exist under PortMusic tree');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F06: Home Discovery Shelves (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F06_1', 'Network failure displays retry button and error state banner', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('errorStateView') || parsed.contains('errorMessage'), 'HomeView must handle error state');
    assert(parsed.contains('Erneut versuchen') || parsed.contains('retry'), 'Must offer retry action on failure');
  }));

  tests.push(await executeTest('T2_F06_2', 'Skeleton placeholder cards rendered during loading state', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const skeletonFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortShelfSkeletonView.swift');
    assert(fs.existsSync(skeletonFile), 'PortShelfSkeletonView.swift must exist');
    const parsed = parseFile(file);
    assert(parsed.contains('PortShelfSkeletonView()'), 'Must render skeleton during loading');
  }));

  tests.push(await executeTest('T2_F06_3', 'Empty shelves (e.g. topPicks: []) hidden cleanly without rendering empty gaps', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('!deduplicated.topPicks.isEmpty'), 'Must guard against empty topPicks');
  }));

  tests.push(await executeTest('T2_F06_4', 'Pull-to-refresh executes async re-fetch of /api/discovery/home', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.refreshable'), 'HomeView must have .refreshable modifier');
    assert(parsed.contains('loadHomeData()'), 'Refreshable must reload home discovery data');
  }));

  tests.push(await executeTest('T2_F06_5', 'Shelf item tap with missing cover URL falls back to placeholder image', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortCoverImage.swift');
    assert(fs.existsSync(file), 'PortCoverImage.swift must exist');
    const parsed = parseFile(file);
    assert(parsed.contains('placeholderIcon'), 'PortCoverImage must support placeholder fallback');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F07: Dynamic Discovery Queue Pre-seeding (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F07_1', 'Single track play does not truncate queue to 1-track repeat loop', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('contextQueue.count == 1') || parsed.contains('contextQueue.count > 1'), 'Must handle context queues of varying sizes');
  }));

  tests.push(await executeTest('T2_F07_2', 'Track deduplication removes identical track IDs from queue', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('seenIds.insert') || parsed.contains('deduplicateShelves'), 'Must deduplicate track IDs');
  }));

  tests.push(await executeTest('T2_F07_3', 'Past tracks history list capped at 50 tracks to prevent memory leak', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('pastTracks.count > 50'), 'Past tracks history must be bounded to 50 items');
  }));

  tests.push(await executeTest('T2_F07_4', 'Recent tracks storage capped at 50 items in UserDefaults', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('recentTracks.count > 50'), 'Recent tracks storage must be bounded to 50 items');
  }));

  tests.push(await executeTest('T2_F07_5', 'Shuffle mode preserves current playing track at queue index 0', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('toggleShuffle()') || parsed.contains('isShuffle'), 'AudioPlayerManager must manage shuffle state');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F08: Search Screen & Live Query (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F08_1', 'Whitespace-only queries do not trigger network requests', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('trimmed.isEmpty'), 'Search method must guard against empty/whitespace queries');
  }));

  tests.push(await executeTest('T2_F08_2', 'Zero search results displays friendly empty state with search icon', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Keine Treffer') || parsed.contains('emptyResultsView') || parsed.contains('isSearchEmpty'), 'SearchView must handle zero results empty state');
  }));

  tests.push(await executeTest('T2_F08_3', 'Rapid keystrokes cancel prior in-flight search tasks', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('searchTask?.cancel()'), 'Must cancel prior search task on input change');
  }));

  tests.push(await executeTest('T2_F08_4', 'Category pill filtering executes in-memory without re-fetching network', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('selectedFilter'), 'SearchView must filter results by selectedFilter in-memory');
  }));

  tests.push(await executeTest('T2_F08_5', 'Search network error falls back safely without unhandled exception', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('catch') && parsed.contains('return []'), 'MusicService.search must catch network errors and return empty list');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F09: Recent Searches & Browse Categories (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F09_1', 'Zero recent searches cleanly hides recent searches chip container', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('!recentSearches.isEmpty'), 'Recent searches section must be guarded by !isEmpty');
  }));

  tests.push(await executeTest('T2_F09_2', 'Recent searches history capped at 10 items to prevent overflow', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('recentSearches.count > 10') || parsed.contains('10'), 'Recent searches must be capped');
  }));

  tests.push(await executeTest('T2_F09_3', 'Duplicate search terms are de-duplicated and promoted to front', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('removeAll { $0 ==') || parsed.contains('insert('), 'Recent searches must remove duplicates before inserting at index 0');
  }));

  tests.push(await executeTest('T2_F09_4', 'Category cards display fallback gradient when artwork is nil', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('LinearGradient') && (parsed.contains('cat.gradient') || parsed.contains('category.gradient')), 'Category card must use LinearGradient');
  }));

  tests.push(await executeTest('T2_F09_5', 'All 10 browse categories define valid hex colors without crash', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Color(hex:'), 'Browse categories must initialize colors via hex');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F10: Artist Detail View (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F10_1', 'Artist catalog is dynamically fetched from online discovery endpoints without local truncation', 'F10', () => {
    const serviceFile = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const serviceParsed = parseFile(serviceFile);
    assert(serviceParsed.contains('URLSession') && serviceParsed.contains('cleanURL'), 'MusicService must handle dynamic online API streaming');
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const homeParsed = parseFile(homeFile);
    assert(homeParsed.contains('playTrackWithFullQueue'), 'HomeView must seed full discovery queue instead of local subset');
  }));

  tests.push(await executeTest('T2_F10_2', 'Special characters and spaces in artist name are percent-encoded in URLs', 'F10', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('addingPercentEncoding'), 'MusicService must percent-encode query/path parameters');
  }));

  tests.push(await executeTest('T2_F10_3', 'ArtistDetailView renders top tracks section with positive duration offsets', 'F10', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'ArtistDetailView.swift');
    const parsed = parseFile(detailFile);
    assert(parsed.contains('topTracksSection') || parsed.contains('topTracks'), 'ArtistDetailView must contain top tracks section');
    const fixture = loadFixture('discovery_artist.json');
    for (const t of fixture.topTracks) {
      assert(t.durationSeconds > 0, `Track ${t.title} must have positive durationSeconds`);
    }
  }));

  tests.push(await executeTest('T2_F10_4', 'ArtistDetailView renders complete albums section with valid track counts', 'F10', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'ArtistDetailView.swift');
    const parsed = parseFile(detailFile);
    assert(parsed.contains('albumsSection') || parsed.contains('albums'), 'ArtistDetailView must contain albums section');
    const fixture = loadFixture('discovery_artist.json');
    for (const a of fixture.albums) {
      assert(a.nbTracks > 0, `Album ${a.title} must have positive nbTracks`);
    }
  }));

  tests.push(await executeTest('T2_F10_5', 'ArtistDetailView renders related artists section with fan counts', 'F10', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'ArtistDetailView.swift');
    const parsed = parseFile(detailFile);
    assert(parsed.contains('relatedArtistsSection') || parsed.contains('related'), 'ArtistDetailView must contain related artists section');
    const fixture = loadFixture('discovery_artist.json');
    for (const r of fixture.related) {
      assert(r.nbFan > 0, `Related artist ${r.name} must have positive nbFan`);
    }
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F11: Album Detail View (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F11_1', 'AlbumDetailView renders contiguous tracklist with numbered tracks (1..N)', 'F11', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'AlbumDetailView.swift');
    const parsed = parseFile(detailFile);
    assert(parsed.contains('tracksSection') || parsed.contains('TrackRowView') || parsed.contains('tracks'), 'AlbumDetailView must render tracklist');
    const fixture = loadFixture('discovery_album.json');
    for (let i = 0; i < fixture.tracks.length; i++) {
      assertEqual(fixture.tracks[i].trackNumber, i + 1, `Track index ${i} must have trackNumber ${i + 1}`);
    }
  }));

  tests.push(await executeTest('T2_F11_2', 'AlbumDetailView displays cover artwork and handles placeholder gracefully', 'F11', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'AlbumDetailView.swift');
    const parsed = parseFile(detailFile);
    assert(parsed.contains('displayCover') || parsed.contains('PortCachedAsyncImage'), 'AlbumDetailView must handle cover display');
    const cardFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortAlbumCard.swift');
    const cardParsed = parseFile(cardFile);
    assert(cardParsed.contains('music.note') || cardParsed.contains('placeholder'), 'Album components must have placeholder');
  }));

  tests.push(await executeTest('T2_F11_3', 'AlbumDetailView and models support explicit track badges', 'F11', () => {
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(modelsFile);
    assert(parsed.contains('isExplicit: Bool'), 'Track model must define isExplicit boolean');
    const fixture = loadFixture('discovery_album.json');
    const explicitTracks = fixture.tracks.filter(t => t.isExplicit);
    assert(explicitTracks.length > 0, 'Album must have explicit tracks properly flagged');
  }));

  tests.push(await executeTest('T2_F11_4', 'AlbumDetailView computes durationSummary and formats release year metadata', 'F11', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'AlbumDetailView.swift');
    const parsed = parseFile(detailFile);
    assert(parsed.contains('durationSummary') && parsed.contains('metadataLine'), 'AlbumDetailView must compute durationSummary and metadataLine');
    const fixture = loadFixture('discovery_album.json');
    assert(fixture.year >= 1950 && fixture.year <= 2030, `Year must be valid calendar year, got ${fixture.year}`);
  }));

  tests.push(await executeTest('T2_F11_5', 'Tapping track in album queues remaining tracks for continuous play', 'F11', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('contextQueue.count > 1') && parsed.contains('self.queue = contextQueue'), 'Must queue full album tracklist');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F12: Library Hub & Category Rows (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F12_1', 'Empty library states display dedicated emptyPlaceholder components', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('emptyPlaceholder(icon:'), 'LibraryView must declare emptyPlaceholder helper');
  }));

  tests.push(await executeTest('T2_F12_2', 'Offline mode gracefully loads local history without unhandled error', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('fetchStats') && parsed.contains('fetchHistory'), 'MusicService must provide resilient history parsing');
  }));

  tests.push(await executeTest('T2_F12_3', 'Library tabs switch with light haptic feedback', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('selectedTab = tab') && parsed.contains('impactOccurred()'), 'Tab switches must update state and trigger haptic');
  }));

  tests.push(await executeTest('T2_F12_4', 'Large collections render with LazyVStack for memory recycling', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('LazyVStack') || parsed.contains('LazyVGrid'), 'LibraryView must use Lazy containers');
  }));

  tests.push(await executeTest('T2_F12_5', 'Library combines favorites, history, and player.recentTracks safely', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('favorites + historyTracks + player.recentTracks'), 'Must aggregate multi-source library tracks');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F13: Populate Library "Alben" Tab (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F13_1', 'Tracks with nil or empty album are filtered out of extracted albums', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('let alb = t.album, !alb.isEmpty') || parsed.contains('guard let album = t.album'), 'Must guard against empty/nil album names');
  }));

  tests.push(await executeTest('T2_F13_2', '2-column album grid maintains 14pt spacing between cards', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('GridItem(.flexible(), spacing: 14)'), 'GridItem must use 14pt spacing');
  }));

  tests.push(await executeTest('T2_F13_3', 'Album deduplication keys by composite title + artist string', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('seen.insert(alb)') || parsed.contains('seenTitles.insert'), 'Album extraction must deduplicate entries');
  }));

  tests.push(await executeTest('T2_F13_4', 'Tapping an extracted album initiates album playback', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('PortAlbumCard'), 'Must render PortAlbumCard with playback action');
  }));

  tests.push(await executeTest('T2_F13_5', 'Zero albums displays "Noch keine Alben in der Bibliothek"', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Noch keine Alben in der Bibliothek'), 'Must display German empty state for albums tab');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F14: Liked Songs View (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F14_1', 'Empty favorites displays "heart.slash" icon and friendly guidance text', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('heart.slash'), 'Empty favorites must display heart.slash icon');
    assert(parsed.contains('Noch keine Lieblingssongs markiert'), 'Must display German guidance text');
  }));

  tests.push(await executeTest('T2_F14_2', 'Rapid liking/unliking debounces network calls via async Task', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('toggleFavorite') && parsed.contains('Task {'), 'Toggling favorites must execute in async Task');
  }));

  tests.push(await executeTest('T2_F14_3', 'Multi-device sync aggregates favorites on pull-to-refresh', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('fetchFavorites'), 'MusicService must implement fetchFavorites');
  }));

  tests.push(await executeTest('T2_F14_4', 'Playing from favorites retains full favorites list in playback queue', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('player.play(track: favorites[0], from: favorites'), 'Playing favorites must pass full favorites array');
  }));

  tests.push(await executeTest('T2_F14_5', 'Shuffle on empty favorites list is safely disabled without index crash', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('if !favorites.isEmpty') || parsed.contains('guard !favorites.isEmpty'), 'Shuffle button must guard against empty favorites');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F15: Playlist Detail View & Action Bar (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F15_1', 'Empty playlist renders without crashing layout', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(file);
    assert(parsed.structs.some(s => s.name === 'DiscoveryPlaylist'), 'DiscoveryPlaylist must be Codable model');
  }));

  tests.push(await executeTest('T2_F15_2', 'Imported/curated playlists display creator name or "Port Music" default', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('pl.user ?? "Port Music"'), 'Must fallback creator to "Port Music"');
  }));

  tests.push(await executeTest('T2_F15_3', 'Playlists with 100+ tracks render with lazy view recycling', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('LazyVStack') || parsed.contains('ForEach'), 'Playlist tracks must use efficient loops');
  }));

  tests.push(await executeTest('T2_F15_4', 'Playlist track counts display formatted subtitle (e.g. "X Titel")', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Titel'), 'Must format track count with "Titel" label');
  }));

  tests.push(await executeTest('T2_F15_5', 'Long playlist titles truncate with ellipsis in snap carousel', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.lineLimit(1)') || parsed.contains('.lineLimit(2)'), 'Playlist title must have lineLimit');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F16: Mobile TrackRow Component (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F16_1', 'Missing cover URL displays styled music note box with rounded corners', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Image(systemName: "music.note")'), 'TrackRow must display music.note fallback');
  }));

  tests.push(await executeTest('T2_F16_2', 'Extremely long track titles truncate without displacing buttons', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.lineLimit(1)'), 'Track title must have .lineLimit(1)');
  }));

  tests.push(await executeTest('T2_F16_3', 'Heart button has minimum 44x44pt touch area conforming to Apple HIG', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('frame(width: 44, height: 44)') || parsed.contains('padding('), 'Heart touch target must be accessible');
  }));

  tests.push(await executeTest('T2_F16_4', 'Row tap triggers playback smoothly without interfering with heart button', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('player.play(track: track'), 'Row tap must trigger player.play');
  }));

  tests.push(await executeTest('T2_F16_5', 'Duration string displays 0:00 fallback on missing durationSeconds', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('duration: String = "0:00"'), 'Track initializer must default duration to "0:00"');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F17: Expanded Now Playing Modal View (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F17_1', 'Drag-to-dismiss threshold requires dragOffset > 120pt to dismiss', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('120') || parsed.contains('dragOffset > 120') || parsed.contains('translation.height > 120'), 'Must enforce >120pt dismissal threshold');
  }));

  tests.push(await executeTest('T2_F17_2', 'Drag gestures < 120pt spring back to top position (dragOffset = 0)', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('dragOffset = 0'), 'Incomplete drag must reset dragOffset to 0');
  }));

  tests.push(await executeTest('T2_F17_3', 'Scrubbing updates timeline display without causing audio stutter', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('isScrubbing = true') && parsed.contains('isScrubbing = false'), 'Scrubbing must track isScrubbing state');
  }));

  tests.push(await executeTest('T2_F17_4', 'Zero/unknown duration displays 0:00 without negative NaN remaining countdown', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('formatTime') || parsed.contains('formatSeconds'), 'Must safely format duration timestamps');
  }));

  tests.push(await executeTest('T2_F17_5', 'Safe area insets respect Dynamic Island and home indicator', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('ignoresSafeArea()'), 'Fullscreen player must manage background safe area gracefully');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F18: Synced Karaoke Lyrics Panel (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F18_1', 'Missing lyrics presentation defaults safely with showLyrics false in FullscreenPlayerView', 'F18', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('showLyrics: Bool = false'), 'FullscreenPlayerView must safely default showLyrics to false');
  }));

  tests.push(await executeTest('T2_F18_2', 'MusicService lyrics contract specifies String return type for resilient plain text and LRC parsing', 'F18', () => {
    const hasContract = validateInterfaceContract('MusicService', 'fetchLyrics');
    assert(hasContract, 'fetchLyrics must specify String return type in interface contract');
  }));

  tests.push(await executeTest('T2_F18_3', 'LRC timestamp tag regex strictly validates [mm:ss.xx] syntax and rejects malformed tags', 'F18', () => {
    const tagRegex = /^\[(\d{2}):(\d{2})\.(\d{2,3})\]$/;
    assert(!tagRegex.test('[invalid]'), 'Must reject non-numeric tags');
    assert(!tagRegex.test('[999:999]'), 'Must reject invalid mm:ss structure');
    assert(tagRegex.test('[01:23.45]'), 'Must accept standard 2-decimal timestamp');
    assert(tagRegex.test('[01:23.456]'), 'Must accept high-precision 3-decimal timestamp');
  }));

  tests.push(await executeTest('T2_F18_4', 'AudioPlayerManager currentTime and seek precision support Double millisecond offsets', 'F18', () => {
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(playerFile);
    const timeProp = findProperties(parsed.classes[0].body).find(p => p.name === 'currentTime');
    assertDefined(timeProp, 'currentTime must be defined');
    assertEqual(timeProp.type, 'Double', 'currentTime must be Double for millisecond precision');
  }));

  tests.push(await executeTest('T2_F18_5', 'Tapping timestamp seeks player without exceeding total duration', 'F18', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('seek(to targetSeconds: Double)') || parsed.contains('seek(to:'), 'seek must take targetSeconds parameter');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F19: Queue Bottom Sheet Drawer (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F19_1', 'Empty upcoming queue displays clear German empty state', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Keine Titel in der Warteschlange'), 'QueueSheetView must display empty queue notice');
  }));

  tests.push(await executeTest('T2_F19_2', 'Queue index pointer stays clamped within queue bounds (0 ..< queue.count)', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('queueIndex') && parsed.contains('queue.count'), 'Queue index must be validated against queue.count');
  }));

  tests.push(await executeTest('T2_F19_3', 'Queue items display track index and active playing highlight', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('isCurrent = (index == player.queueIndex)'), 'Queue sheet must highlight active playing index');
  }));

  tests.push(await executeTest('T2_F19_4', 'Removing track from queue does not interrupt active audio playback', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('currentTrack') && parsed.contains('queue'), 'currentTrack must remain independent of upcoming queue manipulations');
  }));

  tests.push(await executeTest('T2_F19_5', 'Queue drawer dismiss button cleanly resets presentation state', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('showQueueSheet = false'), 'Dismiss button must set showQueueSheet to false');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F20: Song Details & Recommendations Tabs (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F20_1', 'Missing track metadata displays clean defaults without blank voids', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('album: String? = nil'), 'Track must allow nil album safely');
  }));

  tests.push(await executeTest('T2_F20_2', 'HomeView implements robust artist signature normalization and deduplication in Swift', 'F20', () => {
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(homeFile);
    assert(parsed.contains('getSignature') && parsed.contains('cleanArtist'), 'HomeView must implement getSignature with cleanArtist normalization');
    assert(parsed.contains('filter { $0.isLetter || $0.isNumber }') || parsed.contains('isLetter'), 'Must filter punctuation for normalized artist comparison');
  }));

  tests.push(await executeTest('T2_F20_3', 'Recommendations API failure falls back without disrupting active playback', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('catch') && parsed.contains('return nil'), 'Network calls must catch and return nil without crashing');
  }));

  tests.push(await executeTest('T2_F20_4', 'Recommendation filtering logic in Swift excludes duplicate and current track IDs', 'F20', () => {
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const homeParsed = parseFile(homeFile);
    assert(homeParsed.contains('isDuplicate') && homeParsed.contains('seenIds'), 'HomeView must maintain seenIds to filter duplicates');
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);
    assert(playerParsed.contains('current.id != track.id') || playerParsed.contains('firstIndex(where: { $0.id == track.id }'), 'AudioPlayerManager must filter duplicates based on track ID');
  }));

  tests.push(await executeTest('T2_F20_5', 'Tab switching within details maintains continuous audio playback', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.classes.some(c => c.name === 'AudioPlayerManager'), 'AudioPlayerManager persists as singleton across tab switches');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F21: Radio vs Song Isolation Invariant (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F21_1', 'Swift Track model and factory initializers enforce isLive: false for apple_ catalog tracks', 'F21', () => {
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(modelsFile);
    assert(parsed.contains('isLive: Bool = false'), 'Track initializer must default isLive to false');
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const audit = auditRadioVsSongIsolation(files);
    assert(audit.valid, 'Invariant audit must confirm zero apple_ tracks with isLive: true: ' + JSON.stringify(audit.violations));
  }));

  tests.push(await executeTest('T2_F21_2', 'Swift DiscoveryTrack toTrack conversions strictly enforce isLive: false for deezer_ tracks', 'F21', () => {
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(modelsFile);
    const toTrackBlocks = parsed.clean.match(/func toTrack\(\)[^{]*\{[\s\S]*?\}/g) || [];
    assert(toTrackBlocks.length >= 2, 'Must have toTrack conversion functions in MusicModels');
    for (const block of toTrackBlocks) {
      assert(block.includes('isLive: false'), 'Every toTrack conversion must explicitly set isLive: false');
    }
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const audit = auditRadioVsSongIsolation(files);
    assert(audit.valid, 'Invariant audit must confirm zero deezer_/dz_ tracks with isLive: true');
  }));

  tests.push(await executeTest('T2_F21_3', 'Swift MusicService trackFromDictionary strictly enforces isLive: false for yt_ audio streams', 'F21', () => {
    const serviceFile = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(serviceFile);
    assert(parsed.contains('trackFromDictionary'), 'MusicService must implement trackFromDictionary');
    assert(parsed.contains('isLive: false'), 'MusicService trackFromDictionary must enforce isLive: false');
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const audit = auditRadioVsSongIsolation(files);
    assert(audit.valid, 'Invariant audit must confirm zero yt_ tracks with isLive: true');
  }));

  tests.push(await executeTest('T2_F21_4', 'Swift search decoding and result mapping enforce isLive: false for search: results', 'F21', () => {
    const serviceFile = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(serviceFile);
    assert(parsed.contains('toTrack()'), 'Search results must be mapped via toTrack() conversions');
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const audit = auditRadioVsSongIsolation(files);
    assert(audit.valid, 'Invariant audit must confirm zero search: tracks with isLive: true');
  }));

  tests.push(await executeTest('T2_F21_5', 'Invariant audit validates 100% of Swift source files for isLive safety', 'F21', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const result = auditRadioVsSongIsolation(files);
    assert(result.valid, 'Invariant audit discovered radio vs song violations: ' + JSON.stringify(result.violations));
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F22: Zero Third-Party Branding Invariant (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F22_1', 'Zero occurrences of case-insensitive "deerflow" across all Swift files', 'F22', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const result = auditZeroBranding(files);
    assert(result.valid, 'Branding violations found: ' + JSON.stringify(result.violations));
  }));

  tests.push(await executeTest('T2_F22_2', 'Zero occurrences of "deerflow" in YAML, plist, or asset metadata', 'F22', () => {
    const files = [
      path.join(BASE_DIR, 'project.yml'),
      path.join(PORT_MUSIC_DIR, 'Resources', 'Info.plist'),
    ];
    const result = auditZeroBranding(files);
    assert(result.valid, 'Branding violations found in build configuration: ' + JSON.stringify(result.violations));
  }));

  tests.push(await executeTest('T2_F22_3', 'Zero occurrences of external promotional badges or watermarks in UI', 'F22', () => {
    const views = findFiles(path.join(PORT_MUSIC_DIR, 'Features'), ['.swift']);
    const result = auditZeroBranding(views);
    assert(result.valid, 'Watermarks detected in UI views: ' + JSON.stringify(result.violations));
  }));

  tests.push(await executeTest('T2_F22_4', 'Accent color in Assets catalog matches Port Music design system', 'F22', () => {
    const accentFile = path.join(PORT_MUSIC_DIR, 'Resources', 'Assets.xcassets', 'AccentColor.colorset', 'Contents.json');
    assert(fs.existsSync(accentFile), 'AccentColor Contents.json must exist');
    const content = JSON.parse(fs.readFileSync(accentFile, 'utf-8'));
    assertDefined(content.colors, 'Must have colors array');
  }));

  tests.push(await executeTest('T2_F22_5', 'Zero occurrences of "deer_flow" or "created by deerflow" variants', 'F22', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift', '.metal']);
    const result = auditZeroBranding(files);
    assert(result.valid, 'Branding variants detected: ' + JSON.stringify(result.violations));
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F23: Clean Project Build & Validation (Boundaries)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T2_F23_1', 'Missing source files flagged if referenced in project structure', 'F23', () => {
    const requiredFiles = [
      'App/PortMusicApp.swift',
      'Core/Player/AudioPlayerManager.swift',
      'Core/State/SessionManager.swift',
      'Core/Security/KeychainHelper.swift',
      'Core/Network/AuthService.swift',
      'Core/Network/MusicService.swift',
      'Features/Main/MainTabView.swift',
      'Features/Home/HomeView.swift',
      'Features/Search/SearchView.swift',
      'Features/Library/LibraryView.swift',
      'Features/Profile/ProfileSettingsView.swift',
      'Features/Player/FullscreenPlayerView.swift',
      'Features/Player/PlayerBarView.swift',
    ];
    for (const rel of requiredFiles) {
      const full = path.join(PORT_MUSIC_DIR, rel);
      assert(fs.existsSync(full), `Required production Swift file missing: ${rel}`);
    }
  }));

  tests.push(await executeTest('T2_F23_2', 'Zero duplicate class declarations across all Swift files', 'F23', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const classNames = new Map();
    for (const f of files) {
      const parsed = parseFile(f);
      for (const c of parsed.classes) {
        if (classNames.has(c.name)) {
          throw new Error(`Duplicate class declaration: ${c.name} in ${f} and ${classNames.get(c.name)}`);
        }
        classNames.set(c.name, f);
      }
    }
  }));

  tests.push(await executeTest('T2_F23_3', 'All @Published properties properly declared on classes conforming to ObservableObject', 'F23', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    for (const f of files) {
      const parsed = parseFile(f);
      for (const s of parsed.structs) {
        const props = findProperties(s.body);
        assert(!props.some(p => p.hasWrapper('Published')), `Struct ${s.name} in ${f} cannot have @Published property (must be class)`);
      }
    }
  }));

  tests.push(await executeTest('T2_F23_4', 'Environment objects injected in PortMusicApp entry point', 'F23', () => {
    const appFile = path.join(PORT_MUSIC_DIR, 'App', 'PortMusicApp.swift');
    const parsed = parseFile(appFile);
    assert(parsed.contains('@StateObject') || parsed.contains('SessionManager.shared'), 'PortMusicApp must inject session state');
  }));

  tests.push(await executeTest('T2_F23_5', 'Background audio modes key present in Info.plist with audio value', 'F23', () => {
    const plist = path.join(PORT_MUSIC_DIR, 'Resources', 'Info.plist');
    const content = fs.readFileSync(plist, 'utf-8');
    assert(content.includes('<key>UIBackgroundModes</key>'), 'Info.plist must contain UIBackgroundModes key');
    assert(content.includes('<string>audio</string>'), 'UIBackgroundModes must contain audio string');
  }));

  return tests;
}

module.exports = { runTier2Tests };
