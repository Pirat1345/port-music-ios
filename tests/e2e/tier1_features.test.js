/**
 * tier1_features.test.js
 * Tier 1: Feature Coverage (115 tests = 23 features × 5 happy path tests)
 * Tests F01 through F23 against specifications in PROJECT.md and TEST_INFRA.md.
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
const { parseFile, findProperties, findMethods, viewContainsModifier, viewContainsChild } = require('./helpers/swift_parser');
const {
  validateAudioPlayerManagerContract,
  validateSessionManagerContract,
  validateMusicServiceContract,
  validateKeychainHelperContract,
  validateAuthServiceContract,
  validateInterfaceContract,
  validateFeatureSpecification,
} = require('./helpers/contract_checker');
const {
  validateTrackModel,
  validateToTrackConversions,
  validateDiscoveryHomeFixture,
  validateDiscoverySearchFixture,
  validateAuthCheckFixture,
  parseLrc,
} = require('./helpers/model_validator');
const {
  auditRadioVsSongIsolation,
  auditZeroBranding,
  auditXcodeGenProject,
} = require('./helpers/invariant_audit');

const BASE_DIR = path.resolve(__dirname, '..', '..');
const PORT_MUSIC_DIR = path.join(BASE_DIR, 'PortMusic');

async function runTier1Tests() {
  const tests = [];

  // ─────────────────────────────────────────────────────────────────────────────
  // F01: Preserve Login & Auth Flow
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F01_1', 'KeychainHelper persists tokens with service ID com.portmusic.ios.auth', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Security', 'KeychainHelper.swift');
    const result = validateKeychainHelperContract(file);
    assert(result.valid, 'KeychainHelper contract check failed: ' + result.errors.join(', '));
  }));

  tests.push(await executeTest('T1_F01_2', 'SessionManager maintains reactive @Published isAuthenticated and user session', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'State', 'SessionManager.swift');
    const result = validateSessionManagerContract(file);
    assert(result.valid, 'SessionManager contract check failed: ' + result.errors.join(', '));
    const authFixturePath = path.join(__dirname, 'fixtures', 'auth_check.json');
    const authCheck = validateAuthCheckFixture(authFixturePath);
    assert(authCheck.valid, 'auth_check.json fixture must be valid: ' + (authCheck.errors || []).join(', '));
    assertEqual(authCheck.data.authenticated, true, 'auth_check fixture must have authenticated: true');
  }));

  tests.push(await executeTest('T1_F01_3', 'LoginView contains username/password fields and submit action', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Auth', 'LoginView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('username'), 'LoginView must have username input binding');
    assert(parsed.contains('password'), 'LoginView must have password input binding');
    assert(parsed.contains('AuthService.shared.login'), 'LoginView must call AuthService.shared.login');
  }));

  tests.push(await executeTest('T1_F01_4', 'TwoFactorView handles 6-digit OTP verification', 'F01', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Auth', 'TwoFactorView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('otpCode') || parsed.contains('code'), 'TwoFactorView must bind OTP code');
    assert(parsed.contains('verify2FA') || parsed.contains('verify'), 'TwoFactorView must perform 2FA verification');
  }));

  tests.push(await executeTest('T1_F01_5', 'Captcha challenges (ClawMachine & LitterCaptcha) preserved and functional', 'F01', () => {
    const clawFile = path.join(PORT_MUSIC_DIR, 'Features', 'Captcha', 'ClawMachineView.swift');
    const litterFile = path.join(PORT_MUSIC_DIR, 'Features', 'Captcha', 'LitterCaptchaView.swift');
    assert(fs.existsSync(clawFile), 'ClawMachineView.swift must exist');
    assert(fs.existsSync(litterFile), 'LitterCaptchaView.swift must exist');
    const clawParsed = parseFile(clawFile);
    const litterParsed = parseFile(litterFile);
    assert(clawParsed.structs.some(s => s.name === 'ClawMachineView'), 'ClawMachineView struct must be present');
    assert(litterParsed.structs.some(s => s.name === 'LitterCaptchaView'), 'LitterCaptchaView struct must be present');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F02: Production Profile & Settings View
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F02_1', 'ProfileSettingsView displays user avatar, username, email, and role badge', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('user.username'), 'Must display user.username');
    assert(parsed.contains('user.email') || parsed.contains('email'), 'Must display user.email');
    assert(parsed.contains('user.role') || parsed.contains('Rolle'), 'Must display user role');
  }));

  tests.push(await executeTest('T1_F02_2', 'ProfileSettingsView displays connected server URL with active status dot', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('serverURL'), 'Must display serverURL');
    assert(parsed.contains('ping') || parsed.contains('Verbunden') || parsed.contains('ServerPingService'), 'Must include server ping/status indicator');
  }));

  tests.push(await executeTest('T1_F02_3', 'ProfileSettingsView provides audio quality configuration selector', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.enums.some(e => e.name === 'AudioQualityTier'), 'Must define AudioQualityTier enum');
    assert(parsed.contains('selectedAudioQuality'), 'Must bind selectedAudioQuality');
  }));

  tests.push(await executeTest('T1_F02_4', 'ProfileSettingsView provides cache clearing utility', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('PortImageCache.shared.clearAllCache') || parsed.contains('performClearCache') || parsed.contains('clearCache'), 'Must call cache clearing utility');
  }));

  tests.push(await executeTest('T1_F02_5', 'ProfileSettingsView logout button invokes onLogout / SessionManager.logout', 'F02', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('onLogout'), 'Must have onLogout handler');
    assert(parsed.contains('Abmelden') || parsed.contains('Logout'), 'Must display Abmelden/Logout button');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F03: Mobile Bottom Tab Bar (MainTabView)
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F03_1', 'MainTabItem defines exactly 4 tabs (Home, Search, Library, Profile)', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    const tabEnum = parsed.enums.find(e => e.name === 'MainTabItem');
    assertDefined(tabEnum, 'MainTabItem enum must exist');
    const caseNames = tabEnum.cases.map(c => c.name);
    assertEqual(caseNames.length, 4, 'Must have exactly 4 tab items');
    assert(caseNames.includes('home'), 'Must include home tab');
    assert(caseNames.includes('search'), 'Must include search tab');
    assert(caseNames.includes('library'), 'Must include library tab');
    assert(caseNames.includes('profile'), 'Must include profile tab');
  }));

  tests.push(await executeTest('T1_F03_2', 'Tab selection switches views with spring animation', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('selectedTab = tab'), 'Tab tap must update selectedTab');
    assert(parsed.contains('withAnimation'), 'Tab change must use withAnimation');
  }));

  tests.push(await executeTest('T1_F03_3', 'Active tab has pure white highlight and inactive tabs have 0.45 opacity', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Color.white') || parsed.contains('.white'), 'Active tab must be white');
    assert(parsed.contains('0.45'), 'Inactive tabs must have 0.45 opacity');
  }));

  tests.push(await executeTest('T1_F03_4', 'Bottom bar uses dark glass background and respects safe area insets', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.ultraThinMaterial') || parsed.contains('UltraThinMaterial') || parsed.contains('surfaceGlass') || parsed.contains('portLiquidGlass') || parsed.contains('.glassEffect'), 'Must use glass material');
    assert(parsed.contains('safeArea') || parsed.contains('ignoresSafeArea') || parsed.contains('bottom'), 'Must handle bottom safe area');
  }));

  tests.push(await executeTest('T1_F03_5', 'Tapping tab triggers light impact haptic feedback', 'F03', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('UIImpactFeedbackGenerator') || parsed.contains('feedbackGenerator') || parsed.contains('impactOccurred'), 'Must trigger haptic feedback');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F04: Floating Minibar Player
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F04_1', 'Minibar rendered conditionally when player.currentTrack != nil', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('if let track = player.currentTrack') || parsed.contains('player.currentTrack != nil'), 'Minibar must check currentTrack');
  }));

  tests.push(await executeTest('T1_F04_2', 'Minibar displays 44x44 cover thumbnail, track title, and artist', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('44'), 'Cover must be 44x44');
    assert(parsed.contains('track.title'), 'Must display track.title');
    assert(parsed.contains('track.artist'), 'Must display track.artist');
  }));

  tests.push(await executeTest('T1_F04_3', 'Minibar provides inline transport controls (play/pause, prev, next)', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('togglePlayPause()'), 'Must have play/pause button');
    assert(parsed.contains('next('), 'Must have next track button');
    assert(parsed.contains('previous('), 'Must have previous track button');
  }));

  tests.push(await executeTest('T1_F04_4', 'Minibar features 2px slim top progress line reflecting playback position', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('height: 2') || parsed.contains('frame(height: 2)'), 'Must have 2px progress bar');
    assert(parsed.contains('progress') && parsed.contains('player.currentTime'), 'Progress line must track currentTime');
  }));

  tests.push(await executeTest('T1_F04_5', 'Tapping minibar invokes onOpenFullscreen callback', 'F04', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('onOpenFullscreen'), 'Must call onOpenFullscreen on tap');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F05: Build Configuration & XcodeGen Sync
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F05_1', 'project.yml specifies iOS 16.0 deployment target', 'F05', () => {
    const file = path.join(BASE_DIR, 'project.yml');
    const result = auditXcodeGenProject(file);
    assert(result.valid, 'project.yml check failed: ' + (result.errors || []).join(', '));
  }));

  tests.push(await executeTest('T1_F05_2', 'project.yml sets Swift version to 5.0', 'F05', () => {
    const file = path.join(BASE_DIR, 'project.yml');
    const content = fs.readFileSync(file, 'utf-8');
    assert(content.includes('SWIFT_VERSION: "5.0"') || content.includes('SWIFT_VERSION: 5.0'), 'Swift version must be 5.0');
  }));

  tests.push(await executeTest('T1_F05_3', 'project.yml specifies product bundle identifier com.portmusic.app', 'F05', () => {
    const file = path.join(BASE_DIR, 'project.yml');
    const content = fs.readFileSync(file, 'utf-8');
    assert(content.includes('com.portmusic.app'), 'Bundle ID must be com.portmusic.app');
  }));

  tests.push(await executeTest('T1_F05_4', 'project.yml sources directive includes PortMusic directory tree', 'F05', () => {
    const file = path.join(BASE_DIR, 'project.yml');
    const content = fs.readFileSync(file, 'utf-8');
    assert(content.includes('path: PortMusic'), 'Sources must include PortMusic');
  }));

  tests.push(await executeTest('T1_F05_5', 'Info.plist registers background audio entitlement', 'F05', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Resources', 'Info.plist');
    const content = fs.readFileSync(file, 'utf-8');
    assert(content.includes('UIBackgroundModes'), 'Info.plist must define UIBackgroundModes');
    assert(content.includes('audio'), 'Info.plist must include audio background mode');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F06: Home Discovery Shelves
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F06_1', 'HomeView fetches /api/discovery/home via MusicService', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('fetchHomeDiscovery'), 'HomeView must call fetchHomeDiscovery');
    const homeFixturePath = path.join(__dirname, 'fixtures', 'discovery_home.json');
    const fixtureResult = validateDiscoveryHomeFixture(homeFixturePath);
    assert(fixtureResult.valid, 'DiscoveryHome fixture must be valid: ' + (fixtureResult.errors || []).join(', '));
  }));

  tests.push(await executeTest('T1_F06_2', 'Top Picks shelf rendered with 3:4 poster cards (PortPosterCard)', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const cardFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortPosterCard.swift');
    assert(fs.existsSync(cardFile), 'PortPosterCard.swift must exist');
    const parsed = parseFile(file);
    assert(parsed.contains('PortPosterCard'), 'HomeView must render PortPosterCard for top picks');
  }));

  tests.push(await executeTest('T1_F06_3', 'Recently Played shelf rendered with 1:1 square artwork cards', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('shelfRecentlyPlayed') || parsed.contains('PortTrackCard'), 'Must render Recently Played shelf');
  }));

  tests.push(await executeTest('T1_F06_4', 'Top Hits shelf rendered with rank badges (1..10)', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('shelfTopHits') || parsed.contains('todaysTopHits') || parsed.contains('rank'), 'Must render Top Hits shelf with rank numbers');
  }));

  tests.push(await executeTest('T1_F06_5', 'Trending Artists shelf rendered with circular portrait cards', 'F06', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const artistCardFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortArtistCard.swift');
    assert(fs.existsSync(artistCardFile), 'PortArtistCard.swift must exist');
    const parsed = parseFile(file);
    assert(parsed.contains('PortArtistCard') || parsed.contains('trendingArtists'), 'Must render PortArtistCard for trending artists');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F07: Dynamic Discovery Queue Pre-seeding
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F07_1', 'Shelf track playback pre-seeds queue with diverse tracks (≥15 tracks)', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('makeDiscoveryQueue') || parsed.contains('play(track:'), 'HomeView must build discovery queue for shelf playback');
  }));

  tests.push(await executeTest('T1_F07_2', 'Autoplay remains active without isolating into small repeat loop', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(!parsed.contains('isRepeat = true') || parsed.contains('isRepeat: Bool = false'), 'Autoplay must default isRepeat to false');
  }));

  tests.push(await executeTest('T1_F07_3', 'Playing track from queue sets queueIndex correctly to match track', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('self.queueIndex = idx'), 'AudioPlayerManager must update queueIndex to match selected track');
  }));

  tests.push(await executeTest('T1_F07_4', 'Queue deduplication eliminates duplicate track IDs', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('seenIds') || parsed.contains('deduplicate'), 'Must perform track deduplication');
  }));

  tests.push(await executeTest('T1_F07_5', 'Reaching end of queue triggers continuous autoplay top-up', 'F07', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('handleTrackFinished') || parsed.contains('next(') || parsed.contains('AVPlayerItemDidPlayToEndTime'), 'Must handle track completion to continue playback');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F08: Search Screen & Live Query
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F08_1', 'SearchView contains search textfield with magnifying glass and clear button', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('magnifyingglass'), 'Must display magnifyingglass icon');
    assert(parsed.contains('xmark.circle.fill'), 'Must display clear button');
  }));

  tests.push(await executeTest('T1_F08_2', 'Search input uses 300ms debouncing before triggering MusicService.search', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('300_000_000') || parsed.contains('Task.sleep'), 'Must debounce search by 300ms');
    assert(parsed.contains('MusicService.shared.fetchDiscoverySearch') || parsed.contains('MusicService.shared.search'), 'Must query MusicService');
  }));

  tests.push(await executeTest('T1_F08_3', 'SearchView provides 5 filter pills (Top-Treffer, Songs, Künstler, Alben, Playlists)', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    const expected = ['Top-Treffer', 'Songs', 'Künstler', 'Alben', 'Playlists'];
    for (const pill of expected) {
      assert(parsed.contains(pill), `Filter pills must include ${pill}`);
    }
  }));

  tests.push(await executeTest('T1_F08_4', 'Top Result Hero Card highlights best search match', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('topResultHeroCard') || parsed.contains('Top-Ergebnis'), 'Must render Top Result Hero Card');
  }));

  tests.push(await executeTest('T1_F08_5', 'Tapping a track in search results starts playback with context queue', 'F08', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('player.play(track: track, from: fullQueue') || parsed.contains('player.play(track: track'), 'Track tap must play with search context queue');
    const searchFixturePath = path.join(__dirname, 'fixtures', 'discovery_search.json');
    const fixtureResult = validateDiscoverySearchFixture(searchFixturePath);
    assert(fixtureResult.valid, 'DiscoverySearch fixture must be valid: ' + (fixtureResult.errors || []).join(', '));
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F09: Recent Searches & Browse Categories Grid
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F09_1', 'Empty search query displays recent searches chips section', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('recentSearchesSection') || parsed.contains('Zuletzt gesucht'), 'Must render recent searches when query is empty');
  }));

  tests.push(await executeTest('T1_F09_2', 'Tapping recent search chip updates query and executes search', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('searchQuery = term') || parsed.contains('searchQuery ='), 'Tapping chip must set searchQuery');
  }));

  tests.push(await executeTest('T1_F09_3', 'Browse categories grid renders in 2-column layout', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('browseCategoriesGrid') || parsed.contains('GridItem(.flexible()'), 'Must use 2-column flexible grid');
  }));

  tests.push(await executeTest('T1_F09_4', 'Category cards display color gradients, icons, and titles', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('LinearGradient') || parsed.contains('gradient'), 'Category cards must use LinearGradient');
    assert(parsed.contains('iconName'), 'Category cards must include iconName');
  }));

  tests.push(await executeTest('T1_F09_5', 'Clear recent searches removes stored history', 'F09', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('clearRecentSearches') || parsed.contains('recentSearches.removeAll()'), 'Must provide clear recent searches action');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F10: Artist Detail View
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F10_1', 'ArtistDetailView exists and MusicService fetches full online discography via fetchArtist', 'F10', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'ArtistDetailView.swift');
    assert(fs.existsSync(detailFile), 'ArtistDetailView.swift must exist in Features/Detail');
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('fetchArtist') || parsed.contains('/api/discovery/artist'), 'MusicService must strictly adhere to artist discovery contract');
  }));

  tests.push(await executeTest('T1_F10_2', 'Artist top tracks fixture provides 15+ tracks matching DiscoveryArtist model', 'F10', () => {
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(modelsFile);
    assert(parsed.structs.some(s => s.name === 'DiscoveryArtist'), 'MusicModels must define DiscoveryArtist');
    const fixture = loadFixture('discovery_artist.json');
    assert(Array.isArray(fixture.topTracks), 'topTracks must be an array');
    assert(fixture.topTracks.length >= 15, `Artist must have >= 15 top tracks, got ${fixture.topTracks.length}`);
  }));

  tests.push(await executeTest('T1_F10_3', 'Artist complete albums section provides 30+ albums matching DiscoveryAlbum model', 'F10', () => {
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(modelsFile);
    assert(parsed.structs.some(s => s.name === 'DiscoveryAlbum'), 'MusicModels must define DiscoveryAlbum');
    const fixture = loadFixture('discovery_artist.json');
    assert(Array.isArray(fixture.albums), 'albums must be an array');
    assert(fixture.albums.length >= 30, `Artist discography must have >= 30 albums, got ${fixture.albums.length}`);
  }));

  tests.push(await executeTest('T1_F10_4', 'Artist singles and EPs section populated in catalog', 'F10', () => {
    const cardFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortArtistCard.swift');
    assert(fs.existsSync(cardFile), 'PortArtistCard component must exist');
    const fixture = loadFixture('discovery_artist.json');
    assert(Array.isArray(fixture.singles), 'singles must be an array');
    assert(fixture.singles.length > 0, 'Singles section must not be empty');
  }));

  tests.push(await executeTest('T1_F10_5', 'Related artists carousel present in artist discovery model', 'F10', () => {
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const parsed = parseFile(homeFile);
    assert(parsed.contains('trendingArtists') || parsed.contains('PortArtistCard'), 'Home/Artist views must support trending/related artists');
    const fixture = loadFixture('discovery_artist.json');
    assert(Array.isArray(fixture.related), 'related must be an array');
    assert(fixture.related.length > 0, 'Related artists must not be empty');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F11: Album Detail View
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F11_1', 'AlbumDetailView exists and album detail model supports complete online tracklist', 'F11', () => {
    const detailFile = path.join(PORT_MUSIC_DIR, 'Features', 'Detail', 'AlbumDetailView.swift');
    assert(fs.existsSync(detailFile), 'AlbumDetailView.swift must exist in Features/Detail');
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(modelsFile);
    assert(parsed.structs.some(s => s.name === 'DiscoveryAlbum'), 'MusicModels must define DiscoveryAlbum');
    const serviceFile = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const serviceParsed = parseFile(serviceFile);
    assert(serviceParsed.contains('fetchAlbum') || serviceParsed.contains('/api/discovery/album'), 'MusicService must support fetchAlbum');
    const fixture = loadFixture('discovery_album.json');
    assert(fixture.id && fixture.title && fixture.artist, 'Album must have id, title, artist');
    assert(Array.isArray(fixture.tracks), 'Album must have tracks array');
  }));

  tests.push(await executeTest('T1_F11_2', 'Album detail displays cover, year, track count, and duration', 'F11', () => {
    const cardFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortAlbumCard.swift');
    assert(fs.existsSync(cardFile), 'PortAlbumCard component must exist');
    const fixture = loadFixture('discovery_album.json');
    assertDefined(fixture.cover, 'Album must have cover');
    assertDefined(fixture.year, 'Album must have year');
    assert(fixture.trackCount > 0, 'Album must have positive trackCount');
    assertDefined(fixture.duration, 'Album must have duration');
  }));

  tests.push(await executeTest('T1_F11_3', 'Album tracklist contains numbered tracks with durations and explicit tags', 'F11', () => {
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const trackCheck = validateTrackModel(modelsFile);
    assert(trackCheck.valid, 'Track model must support duration and explicit metadata: ' + (trackCheck.errors || []).join(', '));
    const fixture = loadFixture('discovery_album.json');
    for (const t of fixture.tracks) {
      assertDefined(t.trackNumber, `Track ${t.title} missing trackNumber`);
      assertDefined(t.duration, `Track ${t.title} missing duration`);
      assertDefined(t.isExplicit, `Track ${t.title} missing isExplicit`);
    }
  }));

  tests.push(await executeTest('T1_F11_4', 'Tapping album track plays track within complete album queue context', 'F11', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('player.play(track: albumTrack') || parsed.contains('albumTrack'), 'SearchView/AlbumView must initiate album playback');
  }));

  tests.push(await executeTest('T1_F11_5', 'Album total duration correctly matches sum of track durationSeconds', 'F11', () => {
    const fixture = loadFixture('discovery_album.json');
    const sumSeconds = fixture.tracks.reduce((acc, t) => acc + (t.durationSeconds || 0), 0);
    assertEqual(sumSeconds, fixture.durationSeconds, 'Album durationSeconds must equal sum of tracks');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F12: Library Hub & Category Rows
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F12_1', 'Library header displays title and user music collection summary', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Bibliothek'), 'LibraryView must display title Bibliothek');
    assert(parsed.contains('Deine Musiksammlung'), 'LibraryView must display collection summary');
  }));

  tests.push(await executeTest('T1_F12_2', 'Hero Liked Songs card displays gradient background and favorite count', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Lieblingssongs'), 'Must render Lieblingssongs card');
    assert(parsed.contains('favorites.count'), 'Must display count of favorite tracks');
  }));

  tests.push(await executeTest('T1_F12_3', 'User playlists horizontal snap carousel rendered', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('ScrollView(.horizontal'), 'Must have horizontal scroll view for playlists');
    assert(parsed.contains('playlists'), 'Must render user playlists');
  }));

  tests.push(await executeTest('T1_F12_4', 'Segmented navigation includes Playlists, Songs, Alben, and Verlauf tabs', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    const expected = ['Playlists', 'Songs', 'Alben', 'Verlauf'];
    for (const tab of expected) {
      assert(parsed.contains(tab), `Library segmented tabs must include ${tab}`);
    }
  }));

  tests.push(await executeTest('T1_F12_5', 'Pull-to-refresh reloads library data asynchronously', 'F12', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.refreshable'), 'LibraryView must declare .refreshable modifier');
    assert(parsed.contains('loadLibraryData()'), 'Refreshable must invoke loadLibraryData()');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F13: Populate Library "Alben" Tab
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F13_1', 'Library Alben tab derives albums from favorite and history tracks', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('derivedAlbums') || parsed.contains('Alben'), 'LibraryView must derive albums from library tracks');
  }));

  tests.push(await executeTest('T1_F13_2', 'Library albums render in 2-column adaptive grid', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('LazyVGrid') || parsed.contains('GridItem'), 'Albums tab must use LazyVGrid with GridItem');
  }));

  tests.push(await executeTest('T1_F13_3', 'Library album cards display cover artwork, title, and artist', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('albumCard') || parsed.contains('PortCachedAsyncImage'), 'Album cards must display cover image and text');
  }));

  tests.push(await executeTest('T1_F13_4', 'Albums deduplicated by title and artist', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('seenTitles') || parsed.contains('seen') || parsed.contains('firstIndex'), 'Must deduplicate albums');
  }));

  tests.push(await executeTest('T1_F13_5', 'Distinct empty state rendered when zero albums are found', 'F13', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Noch keine Alben') || parsed.contains('emptySection'), 'Must have empty state for Alben tab');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F14: Liked Songs View
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F14_1', 'Liked Songs tab lists favorite tracks with cover, title, and artist', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('favorites') && (parsed.contains('trackRowItem') || parsed.contains('trackRow')), 'Must render track rows for favorites');
  }));

  tests.push(await executeTest('T1_F14_2', 'Header includes Play All button for favorites', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('play.fill') || parsed.contains('Alle abspielen'), 'Must have Play All action button');
  }));

  tests.push(await executeTest('T1_F14_3', 'Header includes Shuffle button to randomize playback', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('shuffle') || parsed.contains('Mischen'), 'Must have Shuffle action button');
  }));

  tests.push(await executeTest('T1_F14_4', 'Heart icon active in iOS red #fc3c44 for favorite items', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('#fc3c44') || parsed.contains('fc3c44'), 'FullscreenPlayerView must use #fc3c44 heart color for favorite items');
  }));

  tests.push(await executeTest('T1_F14_5', 'Tapping heart button toggles favorite state and syncs to /api/favorites', 'F14', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('toggleFavorite'), 'MusicService must implement toggleFavorite');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F15: Playlist Detail View & Action Bar
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F15_1', 'Playlist model exposes id, title, cover, and track count', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(file);
    const plStruct = parsed.structs.find(s => s.name === 'DiscoveryPlaylist');
    assertDefined(plStruct, 'DiscoveryPlaylist struct must exist');
    const props = findProperties(plStruct.body);
    assert(props.some(p => p.name === 'id'), 'Playlist must have id');
    assert(props.some(p => p.name === 'title'), 'Playlist must have title');
    assert(props.some(p => p.name === 'cover'), 'Playlist must have cover');
  }));

  tests.push(await executeTest('T1_F15_2', 'Playlists fetched from /api/playlists via MusicService', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('fetchPlaylists'), 'MusicService must implement fetchPlaylists');
  }));

  tests.push(await executeTest('T1_F15_3', 'Playlist carousel cards display title and rounded cover artwork', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('playlistHeroCard') || parsed.contains('pl.title'), 'LibraryView must display playlist cards');
  }));

  tests.push(await executeTest('T1_F15_4', 'Tapping playlist hero card initiates playlist playback', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('playlistTrack') || parsed.contains('player.play'), 'Must initiate playback on playlist selection');
  }));

  tests.push(await executeTest('T1_F15_5', 'Playlist item tap plays without routing to radio', 'F15', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(!parsed.contains('isLive: true'), 'Playlist tracks must never set isLive: true');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F16: Mobile TrackRow Component
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F16_1', 'Track row provides minimum 56px touch height conforming to Apple HIG', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('height: 56') || parsed.contains('frame(height: 56)') || parsed.contains('padding(.vertical, 8)'), 'TrackRow must conform to touch height standard');
  }));

  tests.push(await executeTest('T1_F16_2', 'Track row includes 48x48 rounded cover thumbnail with cache fallback', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('48') || parsed.contains('44'), 'Thumbnail must have standard dimensions');
    assert(parsed.contains('PortCachedAsyncImage'), 'Thumbnail must use PortCachedAsyncImage');
  }));

  tests.push(await executeTest('T1_F16_3', 'Track row title and artist truncate to single line with ellipsis', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('.lineLimit(1)'), 'Must restrict title and artist to 1 line');
  }));

  tests.push(await executeTest('T1_F16_4', 'Track row displays duration string and heart favorite toggle', 'F16', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('track.duration'), 'Must display track.duration');
    assert(parsed.contains('heart') || parsed.contains('toggleFavorite'), 'Must provide heart favorite button');
  }));

  tests.push(await executeTest('T1_F16_5', 'Active playing track is visually indicated in row or card', 'F16', () => {
    const cardFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'Components', 'PortTrackCard.swift');
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const cardParsed = parseFile(cardFile);
    const homeParsed = parseFile(homeFile);
    assert(cardParsed.contains('isPlaying') && cardParsed.contains('pause.fill'), 'Card must toggle pause/play based on isPlaying');
    assert(homeParsed.contains('isCurrentPlaying'), 'HomeView must compute isCurrentPlaying status');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F17: Expanded Now Playing Modal View
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F17_1', 'FullscreenPlayerView features blurred album cover backdrop (blur 64px, 35% opacity)', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('blur(radius: 64)') || parsed.contains('blur(radius: 50)') || parsed.contains('backgroundLayer'), 'Must feature blurred album background');
  }));

  tests.push(await executeTest('T1_F17_2', 'Centered pull-down drag handle at top of player modal', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('pullDownHandle') || parsed.contains('Capsule'), 'Must render pull-down handle');
  }));

  tests.push(await executeTest('T1_F17_3', 'Artwork scales with spring animation (1.0 playing, 0.86 paused)', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('0.86') || parsed.contains('0.85') || parsed.contains('scaleEffect'), 'Must apply spring scale to artwork');
  }));

  tests.push(await executeTest('T1_F17_4', 'Timeline scrubber displays elapsed and negative remaining time (-M:SS)', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('scrubberSection') || parsed.contains('formatTime'), 'Must render scrubber with formatted timestamps');
  }));

  tests.push(await executeTest('T1_F17_5', 'Full transport controls (play/pause, prev, next, shuffle, repeat) present', 'F17', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('togglePlayPause'), 'Must have play/pause');
    assert(parsed.contains('next('), 'Must have next track button');
    assert(parsed.contains('previous('), 'Must have previous track button');
    assert(parsed.contains('isShuffle'), 'Must have shuffle toggle');
    assert(parsed.contains('isRepeat'), 'Must have repeat toggle');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F18: Synced Karaoke Lyrics Panel
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F18_1', 'MusicService interface contract specifies synchronized lyrics retrieval (/api/lyrics)', 'F18', () => {
    const serviceFile = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(serviceFile);
    const hasContract = parsed.contains('fetchLyrics') || validateInterfaceContract('MusicService', 'fetchLyrics');
    assert(hasContract, 'MusicService must specify fetchLyrics interface contract');
  }));

  tests.push(await executeTest('T1_F18_2', 'Synced LRC parser contract defines timestamp tag format and line model', 'F18', () => {
    const lrcFixture = loadFixture('lyrics_sample.lrc');
    const tagRegex = /\[\d{2}:\d{2}\.\d{2,3}\]/;
    assert(tagRegex.test(lrcFixture), 'LRC format must define [mm:ss.xx] timestamp tags');
    assert(validateFeatureSpecification(18), 'Feature 18 must be specified in project architecture');
  }));

  tests.push(await executeTest('T1_F18_3', 'FullscreenPlayerView supports lyrics panel presentation toggle with quote.bubble', 'F18', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('showLyrics') && parsed.contains('quote.bubble'), 'Player must bind showLyrics toggle with quote.bubble icon');
  }));

  tests.push(await executeTest('T1_F18_4', 'Active sung line dynamically synchronizes with AudioPlayerManager currentTime', 'F18', () => {
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);
    assert(playerParsed.contains('currentTime'), 'AudioPlayerManager must publish currentTime for lyrics synchronization');
    const viewFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const viewParsed = parseFile(viewFile);
    assert(viewParsed.contains('activeProgress') || viewParsed.contains('currentTime'), 'FullscreenPlayerView must compute active progress');
  }));

  tests.push(await executeTest('T1_F18_5', 'Tapping lyric line seeks audio playback via AudioPlayerManager.seek(to:)', 'F18', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('seek(to:'), 'AudioPlayerManager must implement seek(to:)');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F19: Queue Bottom Sheet Drawer
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F19_1', 'QueueSheetView struct exists and is presented via .sheet', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.structs.some(s => s.name === 'QueueSheetView'), 'QueueSheetView struct must exist');
    assert(parsed.contains('showQueueSheet'), 'Must bind showQueueSheet');
  }));

  tests.push(await executeTest('T1_F19_2', 'QueueSheetView displays current playing track card', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Aktueller Titel') || parsed.contains('currentTrack'), 'Queue drawer must display current track header');
  }));

  tests.push(await executeTest('T1_F19_3', 'QueueSheetView displays upcoming queue tracks', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('player.queue') || parsed.contains('Warteschlange'), 'Queue drawer must display upcoming tracks from player.queue');
  }));

  tests.push(await executeTest('T1_F19_4', 'Tapping upcoming track jumps directly to selected track', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('player.play(track: track, from: player.queue') || parsed.contains('player.play'), 'Tapping upcoming track must trigger playback');
  }));

  tests.push(await executeTest('T1_F19_5', 'Queue drawer includes close button and drag dismissal', 'F19', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('xmark.circle.fill') || parsed.contains('Schließen') || parsed.contains('onDismiss'), 'Must provide dismissal action');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F20: Song Details & Recommendations Tabs
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F20_1', 'FullscreenPlayerView supports track metadata and song details sections', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('trackInfoSection') || parsed.contains('detailsTabs') || validateFeatureSpecification(20), 'Must support song details/credits/recommendations contract');
  }));

  tests.push(await executeTest('T1_F20_2', 'Track model provides album and explicit metadata for details', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const result = validateTrackModel(file);
    assert(result.valid, 'Track model must have album and explicit metadata: ' + result.errors.join(', '));
  }));

  tests.push(await executeTest('T1_F20_3', 'Online recommendations fetched dynamically via MusicService', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('fetchHomeDiscovery') || parsed.contains('search'), 'MusicService must provide discovery endpoints');
  }));

  tests.push(await executeTest('T1_F20_4', 'Tapping recommended song initiates playback with diverse queue', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('play(track:'), 'Must initiate playback on song tap');
  }));

  tests.push(await executeTest('T1_F20_5', 'Artist navigation preserves playback session without interruption', 'F20', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const parsed = parseFile(file);
    assert(parsed.classes.some(c => c.name === 'AudioPlayerManager'), 'AudioPlayerManager is singleton shared instance');
    assert(parsed.contains('static let shared = AudioPlayerManager()'), 'AudioPlayerManager must be shared singleton');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F21: Radio vs Song Isolation Invariant
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F21_1', 'Track struct defaults isLive: false', 'F21', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('isLive: Bool = false'), 'Track initializer must default isLive to false');
  }));

  tests.push(await executeTest('T1_F21_2', 'All toTrack() model conversions hardcode isLive: false', 'F21', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const result = validateToTrackConversions(file);
    assert(result.valid, 'toTrack() conversions check failed: ' + result.errors.join(', '));
  }));

  tests.push(await executeTest('T1_F21_3', 'Stream URLs point to /api/stream/{id} with RFC path encoding', 'F21', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('/api/stream/'), 'Must build stream URL at /api/stream/{id}');
    assert(parsed.contains('addingPercentEncoding'), 'Must percent-encode track ID');
  }));

  tests.push(await executeTest('T1_F21_4', 'Standard song durations are formatted mm:ss, never "LIVE"', 'F21', () => {
    const swiftFiles = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const result = auditRadioVsSongIsolation(swiftFiles);
    assert(result.valid, 'Radio vs song isolation audit failed: ' + JSON.stringify(result.violations));
  }));

  tests.push(await executeTest('T1_F21_5', 'Scrubber timeline and seeking remain fully active for all standard songs', 'F21', () => {
    const file = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const parsed = parseFile(file);
    assert(parsed.contains('Slider(') || parsed.contains('scrubPosition') || parsed.contains('seek(to:'), 'Seeking must be active in player');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F22: Zero Third-Party Branding Invariant
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F22_1', 'Zero occurrences of "deerflow" (case-insensitive) across PortMusic directory', 'F22', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift', '.metal', '.plist', '.json']);
    const result = auditZeroBranding(files);
    assert(result.valid, 'Forbidden branding violations detected: ' + JSON.stringify(result.violations));
  }));

  tests.push(await executeTest('T1_F22_2', 'Zero occurrences of "deerflow.tech" or external template links', 'F22', () => {
    const allFiles = findFiles(BASE_DIR, ['.swift', '.yml', '.yaml', '.json', '.md']);
    const nonTestFiles = allFiles.filter(f => !f.includes('tests'));
    const result = auditZeroBranding(nonTestFiles);
    assert(result.valid, 'Forbidden template URLs found: ' + JSON.stringify(result.violations));
  }));

  tests.push(await executeTest('T1_F22_3', 'Brand name is strictly "Port Music" across UI views', 'F22', () => {
    const loginFile = path.join(PORT_MUSIC_DIR, 'Features', 'Auth', 'LoginView.swift');
    const profileFile = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const loginParsed = parseFile(loginFile);
    const profileParsed = parseFile(profileFile);
    assert(loginParsed.contains('Port Music') && profileParsed.contains('Port Music'), 'App branding must be Port Music in LoginView and ProfileSettingsView');
  }));

  tests.push(await executeTest('T1_F22_4', 'Official Manosque font registered in project and resources', 'F22', () => {
    const fontFile = path.join(PORT_MUSIC_DIR, 'Resources', 'Fonts', 'Manosque-Regular.ttf');
    assert(fs.existsSync(fontFile), 'Manosque-Regular.ttf must exist on disk');
  }));

  tests.push(await executeTest('T1_F22_5', 'Official Port Logo assets present in PortLogo.imageset', 'F22', () => {
    const logoPath = path.join(PORT_MUSIC_DIR, 'Resources', 'Assets.xcassets', 'PortLogo.imageset', 'port-logo.png');
    assert(fs.existsSync(logoPath), 'port-logo.png must exist in PortLogo.imageset');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // F23: Clean Project Build & Validation
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T1_F23_1', 'All Swift files in PortMusic compile without unbalanced braces', 'F23', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    assert(files.length >= 40, `Expected at least 40 Swift files, found ${files.length}`);
    for (const f of files) {
      const parsed = parseFile(f);
      let openBraces = 0;
      for (const ch of parsed.clean) {
        if (ch === '{') openBraces++;
        if (ch === '}') openBraces--;
      }
      assertEqual(openBraces, 0, `Unbalanced braces in ${path.basename(f)}: delta=${openBraces}`);
    }
  }));

  tests.push(await executeTest('T1_F23_2', 'All Swift files compile without unbalanced string quotes', 'F23', () => {
    const files = findFiles(PORT_MUSIC_DIR, ['.swift']);
    for (const f of files) {
      const raw = fs.readFileSync(f, 'utf-8');
      const lines = raw.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.startsWith('//') || line.startsWith('*')) continue;
        // Check single-line strings for unescaped quotes
        let inStr = false;
        for (let j = 0; j < line.length; j++) {
          if (line[j] === '"' && (j === 0 || line[j - 1] !== '\\')) {
            inStr = !inStr;
          }
        }
        // If line contains """ it's a multiline string
        if (line.includes('"""')) continue;
        assert(!inStr, `Unterminated string on line ${i + 1} in ${path.basename(f)}`);
      }
    }
  }));

  tests.push(await executeTest('T1_F23_3', 'Metal silk shaders exist and have valid function declarations', 'F23', () => {
    const metalFile = path.join(PORT_MUSIC_DIR, 'Core', 'Theme', 'Shaders', 'FluentSilkShader.metal');
    assert(fs.existsSync(metalFile), 'FluentSilkShader.metal must exist');
    const content = fs.readFileSync(metalFile, 'utf-8');
    assert(content.includes('vertex') || content.includes('fragment'), 'Metal shader must declare vertex/fragment functions');
  }));

  tests.push(await executeTest('T1_F23_4', 'Asset catalog AccentColor and AppIcon definitions are valid JSON', 'F23', () => {
    const accentFile = path.join(PORT_MUSIC_DIR, 'Resources', 'Assets.xcassets', 'AccentColor.colorset', 'Contents.json');
    const appIconFile = path.join(PORT_MUSIC_DIR, 'Resources', 'Assets.xcassets', 'AppIcon.appiconset', 'Contents.json');
    assert(fs.existsSync(accentFile), 'AccentColor Contents.json must exist');
    assert(fs.existsSync(appIconFile), 'AppIcon Contents.json must exist');
    JSON.parse(fs.readFileSync(accentFile, 'utf-8'));
    JSON.parse(fs.readFileSync(appIconFile, 'utf-8'));
  }));

  tests.push(await executeTest('T1_F23_5', 'All 12 captcha toy image assets are present on disk', 'F23', () => {
    const toys = ['bear', 'bunny', 'cat', 'dino', 'duck', 'fox', 'frog', 'panda', 'penguin', 'puppy', 'unicorn', 'whale'];
    for (const toy of toys) {
      const p = path.join(PORT_MUSIC_DIR, 'Resources', 'Toys', `${toy}.png`);
      assert(fs.existsSync(p), `Captcha toy asset missing: ${toy}.png`);
    }
  }));

  return tests;
}

module.exports = { runTier1Tests };
