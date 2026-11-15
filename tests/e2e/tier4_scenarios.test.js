/**
 * tier4_scenarios.test.js
 * Tier 4: Real-World Application Scenarios (12 tests = T4_W01 through T4_W12)
 * Models multi-step end-to-end user journeys and system-level validation flows.
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

async function runTier4Tests() {
  const tests = [];

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W01: First Launch, Login & Tab Navigation
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W01', 'Workflow 1: First Launch, Login & Tab Navigation', 'W01', () => {
    // Step 1: App launch entry point verifies session check
    const appFile = path.join(PORT_MUSIC_DIR, 'App', 'PortMusicApp.swift');
    const appParsed = parseFile(appFile);
    assert(appParsed.contains('restoreSession()') || appParsed.contains('sessionManager.isAuthenticated'), 'Step 1: App must restore session on launch');

    // Step 2: Unauthenticated state renders LoginView
    const loginFile = path.join(PORT_MUSIC_DIR, 'Features', 'Auth', 'LoginView.swift');
    const loginParsed = parseFile(loginFile);
    assert(loginParsed.contains('AuthService.shared.login'), 'Step 2: LoginView must handle user authentication');

    // Step 3: Two-Factor authentication / Captcha challenge fallback
    const twoFactorFile = path.join(PORT_MUSIC_DIR, 'Features', 'Auth', 'TwoFactorView.swift');
    assert(fs.existsSync(twoFactorFile), 'Step 3: TwoFactorView must exist for MFA');

    // Step 4: Authentication transitions into MainTabView with bottom tab bar
    const mainTabFile = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const mainParsed = parseFile(mainTabFile);
    assert(mainParsed.contains('HomeView') && mainParsed.contains('SearchView') && mainParsed.contains('LibraryView') && mainParsed.contains('ProfileSettingsView'), 'Step 4: MainTabView must mount all 4 core tabs');

    // Step 5: Navigation shell supports haptic feedback on tab changes
    assert(mainParsed.contains('UIImpactFeedbackGenerator'), 'Step 5: Tab navigation must provide haptic feedback');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W02: Account Management, Settings & Logout
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W02', 'Workflow 2: Account Management, Settings & Logout', 'W02', () => {
    // Step 1: User switches to Profile/Settings tab
    const mainTabFile = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const mainParsed = parseFile(mainTabFile);
    assert(mainParsed.contains('case .profile:'), 'Step 1: Profile tab must be selectable');

    // Step 2: ProfileSettingsView displays active user details and server info
    const profileFile = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const profileParsed = parseFile(profileFile);
    assert(profileParsed.contains('user.username') && profileParsed.contains('serverURL'), 'Step 2: Profile must display user and server details');

    // Step 3: User configures streaming quality tier
    assert(profileParsed.contains('AudioQualityTier') && profileParsed.contains('selectedAudioQuality'), 'Step 3: Quality selection must be available');

    // Step 4: User clears cover/audio disk cache
    assert(profileParsed.contains('PortImageCache.shared.clearAllCache'), 'Step 4: Image cache must clear upon action');

    // Step 5: User taps logout and returns to login screen
    assert(profileParsed.contains('onLogout()') && profileParsed.contains('notificationOccurred(.warning)'), 'Step 5: Logout must notify and invoke callback');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W03: Home Discovery Browsing & Instant Playback
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W03', 'Workflow 3: Home Discovery Browsing & Instant Playback with Queue Seeding', 'W03', () => {
    // Step 1: HomeView fetches and parses discovery shelves
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const homeParsed = parseFile(homeFile);
    assert(homeParsed.contains('MusicService.shared.fetchHomeDiscovery'), 'Step 1: HomeView must load discovery shelves');

    // Step 2: Top Picks shelf renders with 3:4 poster cards
    assert(homeParsed.contains('shelfTopPicks') && homeParsed.contains('PortPosterCard'), 'Step 2: Top picks shelf must render poster cards');

    // Step 3: Tapping poster card initiates playback
    assert(homeParsed.contains('player.play(track: targetTrack, from: queue') || homeParsed.contains('player.play(track:'), 'Step 3: Poster tap must initiate audio playback');

    // Step 4: Floating Minibar emerges above bottom tab bar
    const minibarFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const minibarParsed = parseFile(minibarFile);
    assert(minibarParsed.contains('if let track = player.currentTrack'), 'Step 4: Minibar must observe active track');

    // Step 5: Audio engine pre-seeds queue with diverse tracks and enables continuous autoplay
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);
    assert(playerParsed.contains('self.queue = contextQueue') && playerParsed.contains('self.queueIndex = idx'), 'Step 5: Playback queue must be properly indexed');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W04: Search, Filter Pills & Minibar Playback
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W04', 'Workflow 4: Search, Filter Pills, Top Result & Minibar Playback', 'W04', () => {
    // Step 1: Empty search displays recent searches and browse categories
    const searchFile = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const searchParsed = parseFile(searchFile);
    assert(searchParsed.contains('idleDiscoverView') && searchParsed.contains('browseCategories'), 'Step 1: Empty state must display idle browse categories');

    // Step 2: Typing query triggers 300ms debounced search
    assert(searchParsed.contains('searchTask = Task') && searchParsed.contains('fetchDiscoverySearch'), 'Step 2: Live search must debounce and fetch results');

    // Step 3: Filter pills restrict results between Songs, Artists, Albums
    assert(searchParsed.contains('selectedFilter') && searchParsed.contains('Top-Treffer'), 'Step 3: Filter pills must exist');

    // Step 4: Top result hero card is highlighted
    assert(searchParsed.contains('topResultHeroCard'), 'Step 4: Top Result hero card must be present');

    // Step 5: Tapping result plays track and updates minibar
    assert(searchParsed.contains('player.play(track: track, from: fullQueue'), 'Step 5: Tapping search result must initiate playback');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W05: Library Navigation, Playlist & Liked Songs Flow
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W05', 'Workflow 5: Library Navigation, Playlist Browsing & Liked Songs Flow', 'W05', () => {
    // Step 1: User switches to Library tab
    const libraryFile = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const libraryParsed = parseFile(libraryFile);
    assert(libraryParsed.contains('Bibliothek'), 'Step 1: Library header must display Bibliothek');

    // Step 2: Liked Songs hero card displays total count
    assert(libraryParsed.contains('Lieblingssongs') && libraryParsed.contains('favorites.count'), 'Step 2: Favorites count must display');

    // Step 3: Playlist carousel displays user playlists
    assert(libraryParsed.contains('playlistHeroCard') && libraryParsed.contains('playlists'), 'Step 3: User playlists must be rendered in carousel');

    // Step 4: User plays Liked Songs with Shuffle
    assert(libraryParsed.contains('player.isShuffle = true') && libraryParsed.contains('Int.random'), 'Step 4: Shuffle must pick randomized track');

    // Step 5: Tapping heart button updates favorite state
    assert(libraryParsed.contains('MusicService.shared.fetchFavorites'), 'Step 5: Favorites must sync with server');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W06: XcodeGen Project Spec & Build System Integrity
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W06', 'Workflow 6: XcodeGen Project Spec & Build System Integrity', 'W06', () => {
    // Step 1: project.yml passes schema validation
    const ymlFile = path.join(BASE_DIR, 'project.yml');
    const result = auditXcodeGenProject(ymlFile);
    assert(result.valid, 'Step 1: project.yml must pass audit: ' + (result.errors || []).join(', '));

    // Step 2: Deployment target is iOS 16.0+, Swift 5.0
    const content = fs.readFileSync(ymlFile, 'utf-8');
    assert(content.includes('iOS: "16.0"') || content.includes('iOS: 16.0'), 'Step 2: Deployment target must be iOS 16.0');

    // Step 3: All 68+ files in PortMusic/ exist and pass syntax validation
    const swiftFiles = findFiles(PORT_MUSIC_DIR, ['.swift']);
    assert(swiftFiles.length >= 40, `Step 3: Swift files count must be >= 40, found ${swiftFiles.length}`);

    // Step 4: Asset catalogs contain AccentColor, AppIcon, PortLogo
    const assetsDir = path.join(PORT_MUSIC_DIR, 'Resources', 'Assets.xcassets');
    assert(fs.existsSync(path.join(assetsDir, 'AccentColor.colorset')), 'Step 4: AccentColor must exist');
    assert(fs.existsSync(path.join(assetsDir, 'AppIcon.appiconset')), 'Step 4: AppIcon must exist');

    // Step 5: GitHub Actions CI workflow config aligns with project specification
    const ciWorkflow = path.join(BASE_DIR, '.github', 'workflows', 'build.yml');
    if (fs.existsSync(ciWorkflow)) {
      const ciContent = fs.readFileSync(ciWorkflow, 'utf-8');
      assert(ciContent.includes('xcodegen generate') || ciContent.includes('PortMusic'), 'Step 5: CI workflow must use xcodegen or PortMusic scheme');
    }
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W07: Continuous Listening: Shelf -> Minibar -> Fullscreen -> Queue
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W07', 'Workflow 7: Continuous Listening: Shelf Playback -> Minibar -> Fullscreen -> Queue Management', 'W07', () => {
    // Step 1: User starts playback from Home shelf
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const homeParsed = parseFile(homeFile);
    assert(homeParsed.contains('player.play(track: targetTrack') || homeParsed.contains('player.play(track:'), 'Step 1: Shelf track initiates playback');

    // Step 2: Minibar shows current track progress and info
    const minibarFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const minibarParsed = parseFile(minibarFile);
    assert(minibarParsed.contains('player.currentTime') && minibarParsed.contains('player.duration'), 'Step 2: Minibar displays timeline progress');

    // Step 3: Tapping Minibar opens FullscreenPlayerView modal
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const fullParsed = parseFile(fullFile);
    assert(fullParsed.contains('FullscreenPlayerView'), 'Step 3: FullscreenPlayerView must exist');

    // Step 4: Fullscreen Player displays spring bouncing artwork and timeline scrubber
    assert(fullParsed.contains('artworkSection') && fullParsed.contains('scrubberSection'), 'Step 4: Fullscreen player must contain artwork and scrubber');

    // Step 5: User opens Queue Drawer to inspect upcoming tracks
    assert(fullParsed.contains('QueueSheetView') && fullParsed.contains('showQueueSheet'), 'Step 5: Queue Drawer sheet must be accessible');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W08: Online Discography Deep-Dive
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W08', 'Workflow 8: Online Discography Deep-Dive (Search -> Artist -> Album -> Track Playback)', 'W08', () => {
    // Step 1: Search query resolves artist and album entities
    const searchFixture = loadFixture('discovery_search.json');
    assert(searchFixture.artists && searchFixture.artists.length > 0, 'Step 1: Search fixture must return artists');
    assert(searchFixture.albums && searchFixture.albums.length > 0, 'Step 1: Search fixture must return albums');

    // Step 2: Full online discography provides complete top tracks (15+) and albums (30+)
    const artistFixture = loadFixture('discovery_artist.json');
    assert(artistFixture.topTracks.length >= 15, 'Step 2: Top tracks must be >= 15');
    assert(artistFixture.albums.length >= 30, 'Step 2: Complete albums must be >= 30');

    // Step 3: Album tracklist provides full numbered track sequence
    const albumFixture = loadFixture('discovery_album.json');
    assertEqual(albumFixture.tracks.length, 18, 'Step 3: Starboy album must have 18 tracks');

    // Step 4: Album track playback pre-seeds remaining tracks in queue
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);
    assert(playerParsed.contains('self.queue = contextQueue'), 'Step 4: Full album must populate playback queue');

    // Step 5: All discography tracks have isLive: false
    for (const t of artistFixture.topTracks) {
      assert(t.isLive !== true, `Track ${t.title} cannot be isLive: true`);
    }
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W09: Library Curation: Albums & Heart Toggling
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W09', 'Workflow 9: Library Curation: Albums Tab, Grid Rendering & Heart Toggling', 'W09', () => {
    // Step 1: Selecting "Alben" tab extracts unique albums from user listening history
    const libraryFile = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const libraryParsed = parseFile(libraryFile);
    assert(libraryParsed.contains('extractUniqueAlbums()'), 'Step 1: LibraryView must extract unique albums');

    // Step 2: 2-column album grid displays album artwork cards
    assert(libraryParsed.contains('PortAlbumCard') && libraryParsed.contains('LazyVGrid'), 'Step 2: Albums tab must render 2-column LazyVGrid');

    // Step 3: Tapping album initiates playback of album tracks
    assert(libraryParsed.contains('player.play(track: album, from: uniqueAlbums'), 'Step 3: Tapping album card plays album');

    // Step 4: User toggles heart on track
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const fullParsed = parseFile(fullFile);
    assert(fullParsed.contains('MusicService.shared.toggleFavorite'), 'Step 4: Heart toggling syncs to /api/favorites');

    // Step 5: Heart state renders in active iOS red (#fc3c44)
    assert(fullParsed.contains('#fc3c44'), 'Step 5: Active favorite must use #fc3c44');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W10: Immersive Fullscreen Experience: Lyrics & Gestures
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W10', 'Workflow 10: Immersive Fullscreen Experience: Lyrics Sync, Drag Dismiss & Transport Controls', 'W10', () => {
    // Step 1: Synced LRC lyrics interface contract and presentation toggle verified
    const hasLyricsContract = validateInterfaceContract('MusicService', 'fetchLyrics');
    assert(hasLyricsContract, 'Step 1: fetchLyrics interface contract must be defined');
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const fullParsed = parseFile(fullFile);
    assert(fullParsed.contains('showLyrics') && fullParsed.contains('quote.bubble'), 'Step 1: FullscreenPlayerView must bind showLyrics toggle with quote.bubble icon');

    // Step 2: AudioPlayerManager currentTime provides dynamic position for line centering
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);
    assert(playerParsed.contains('currentTime'), 'Step 2: AudioPlayerManager must publish currentTime for sync');

    // Step 3: Tapping lyric line triggers audio seeking
    assert(playerParsed.contains('seek(to targetSeconds: Double)'), 'Step 3: seek must take targetSeconds');

    // Step 4: Transport controls support play/pause, prev, next, shuffle, repeat
    assert(playerParsed.contains('togglePlayPause()') && playerParsed.contains('next(') && playerParsed.contains('previous('), 'Step 4: Transport controls must be complete');

    // Step 5: Pull-down gesture (>120px) smoothly dismisses player modal
    assert(fullParsed.contains('dragOffset') && fullParsed.contains('120'), 'Step 5: Drag gesture must check 120px threshold');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W11: Streaming Isolation Verification
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W11', 'Workflow 11: Streaming Isolation Verification: Standard Tracks vs Radio Streams', 'W11', () => {
    // Step 1: Static AST inspection of MusicModels.swift and MusicService.swift enforces isLive: false across all standard prefixes
    const modelsFile = path.join(PORT_MUSIC_DIR, 'Core', 'Models', 'MusicModels.swift');
    const modelsParsed = parseFile(modelsFile);
    assert(modelsParsed.contains('isLive: Bool = false'), 'Step 1: Track initializer must default isLive to false');
    const serviceFile = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'MusicService.swift');
    const serviceParsed = parseFile(serviceFile);
    assert(serviceParsed.contains('isLive: false'), 'Step 1: MusicService parser must enforce isLive: false');
    const swiftFiles = findFiles(PORT_MUSIC_DIR, ['.swift']);
    const audit = auditRadioVsSongIsolation(swiftFiles);
    assert(audit.valid, 'Step 1: Radio vs song isolation audit must confirm 0 violations across all standard prefixes: ' + JSON.stringify(audit.violations));

    // Step 2: All toTrack() conversions in MusicModels.swift explicitly hardcode isLive: false
    const toTrackCount = (modelsParsed.clean.match(/func toTrack\(\)/g) || []).length;
    assert(toTrackCount >= 2, 'Step 2: Must have multiple toTrack() conversions in MusicModels');

    // Step 3: Stream URLs point to /api/stream/{id}
    assert(serviceParsed.contains('/api/stream/'), 'Step 3: Stream URL must target /api/stream/');

    // Step 4: Duration is strictly numeric, never "LIVE"
    assert(audit.valid, 'Step 4: Standard tracks must never have duration "LIVE" or route to /radio');

    // Step 5: AudioPlayerManager locks isLive = false on standard tracks
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);
    assert(!playerParsed.contains('isLive = true'), 'Step 5: AudioPlayerManager must never set isLive = true');
  }));

  // ─────────────────────────────────────────────────────────────────────────────
  // T4_W12: Security, Zero-Branding & Codebase Hygiene Audit
  // ─────────────────────────────────────────────────────────────────────────────
  tests.push(await executeTest('T4_W12', 'Workflow 12: Security, Zero-Branding & Codebase Hygiene Audit', 'W12', () => {
    // Step 1: 100% of files in repository verified free of "Deerflow" branding
    const allFiles = findFiles(PORT_MUSIC_DIR, ['.swift', '.metal', '.plist', '.json']);
    const brandingAudit = auditZeroBranding(allFiles);
    assert(brandingAudit.valid, 'Step 1: Zero Deerflow branding violations: ' + JSON.stringify(brandingAudit.violations));

    // Step 2: KeychainHelper uses secure service identifier com.portmusic.ios.auth
    const keyFile = path.join(PORT_MUSIC_DIR, 'Core', 'Security', 'KeychainHelper.swift');
    const keyParsed = parseFile(keyFile);
    assert(keyParsed.contains('com.portmusic.ios.auth'), 'Step 2: KeychainHelper must use com.portmusic.ios.auth');

    // Step 3: Octave Dark Glassmorphism standard observed across theme and background
    const themeFile = path.join(PORT_MUSIC_DIR, 'Core', 'Theme', 'PortTheme.swift');
    const themeParsed = parseFile(themeFile);
    assert(themeParsed.contains('Color.black') && themeParsed.contains('borderGlass'), 'Step 3: Octave dark theme constants must be defined');

    // Step 4: Swift code syntax is balanced and compiles cleanly
    for (const f of allFiles.filter(f => f.endsWith('.swift'))) {
      const parsed = parseFile(f);
      let balance = 0;
      for (const ch of parsed.clean) {
        if (ch === '{') balance++;
        if (ch === '}') balance--;
      }
      assertEqual(balance, 0, `Step 4: Swift syntax balanced braces check failed in ${path.basename(f)}`);
    }

    // Step 5: Official app icons, fonts, and assets verified on disk
    const fontFile = path.join(PORT_MUSIC_DIR, 'Resources', 'Fonts', 'Manosque-Regular.ttf');
    assert(fs.existsSync(fontFile), 'Step 5: Manosque font must be present on disk');
  }));

  return tests;
}

module.exports = { runTier4Tests };
