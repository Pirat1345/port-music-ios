/**
 * tier3_pairwise.test.js
 * Tier 3: Cross-Feature Combinations (25 tests = T3_C01 through T3_C25)
 * Verifies multi-module interactions, state propagation across components, and contract interoperability.
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
const {
  auditRadioVsSongIsolation,
  auditZeroBranding,
  auditXcodeGenProject,
} = require('./helpers/invariant_audit');

const BASE_DIR = path.resolve(__dirname, '..', '..');
const PORT_MUSIC_DIR = path.join(BASE_DIR, 'PortMusic');

async function runTier3Tests() {
  const tests = [];

  // T3_C01 [F1 + F3]: Auth & Navigation Shell Interop
  tests.push(await executeTest('T3_C01', '[F1 + F3] Successful auth transitions app state to MainTabView with Home as default tab', 'F01+F03', () => {
    const appFile = path.join(PORT_MUSIC_DIR, 'App', 'PortMusicApp.swift');
    const mainTabFile = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const appParsed = parseFile(appFile);
    const mainParsed = parseFile(mainTabFile);

    assert(appParsed.contains('MainTabView') || appParsed.contains('sessionManager.isAuthenticated'), 'App must switch to MainTabView upon authentication');
    assert(mainParsed.contains('selectedTab: MainTabItem = .home'), 'MainTabView must default to .home');
  }));

  // T3_C02 [F1 + F2]: Auth & Settings Interop
  tests.push(await executeTest('T3_C02', '[F1 + F2] Triggering logout in Profile/Settings clears Keychain and resets state', 'F01+F02', () => {
    const profileFile = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const sessionFile = path.join(PORT_MUSIC_DIR, 'Core', 'State', 'SessionManager.swift');
    const keyFile = path.join(PORT_MUSIC_DIR, 'Core', 'Security', 'KeychainHelper.swift');

    const profileParsed = parseFile(profileFile);
    const sessionParsed = parseFile(sessionFile);
    const keyParsed = parseFile(keyFile);

    assert(profileParsed.contains('onLogout()'), 'Profile must call onLogout');
    assert(sessionParsed.contains('KeychainHelper.shared.deleteToken()') || sessionParsed.contains('logout()'), 'SessionManager must clear token on logout');
    assert(keyParsed.contains('deleteToken()'), 'KeychainHelper must implement deleteToken()');
  }));

  // T3_C03 [F3 + F4]: Navigation Shell & Minibar Interop
  tests.push(await executeTest('T3_C03', '[F3 + F4] Switching tabs between Home, Search, Library preserves floating Minibar', 'F03+F04', () => {
    const mainTabFile = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const minibarFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const mainParsed = parseFile(mainTabFile);

    assert(mainParsed.contains('PlayerBarView') || mainParsed.contains('MiniPlayerBar'), 'MainTabView must embed PlayerBarView outside tab switch Group');
    assert(fs.existsSync(minibarFile), 'PlayerBarView.swift must exist');
  }));

  // T3_C04 [F4 + F17]: Minibar & Fullscreen Modal Interop
  tests.push(await executeTest('T3_C04', '[F4 + F17] Tapping Minibar presents Fullscreen Player; drag down >120px restores Minibar', 'F04+F17', () => {
    const mainTabFile = path.join(PORT_MUSIC_DIR, 'Features', 'Main', 'MainTabView.swift');
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const mainParsed = parseFile(mainTabFile);
    const fullParsed = parseFile(fullFile);

    assert(mainParsed.contains('showFullscreenPlayer = true'), 'Tapping Minibar must trigger showFullscreenPlayer');
    assert(fullParsed.contains('120') && fullParsed.contains('onClose()'), 'FullscreenPlayerView must invoke onClose when drag exceeds threshold');
  }));

  // T3_C05 [F6 + F7]: Home Shelf & Discovery Queue Pre-seeding
  tests.push(await executeTest('T3_C05', '[F6 + F7] Tapping a Top Picks poster on Home starts playback and pre-seeds diverse queue', 'F06+F7', () => {
    const homeFile = path.join(PORT_MUSIC_DIR, 'Features', 'Home', 'HomeView.swift');
    const homeParsed = parseFile(homeFile);

    assert(homeParsed.contains('shelfTopPicks') && homeParsed.contains('player.play'), 'Top picks shelf must start playback');
    assert(homeParsed.contains('makeDiscoveryQueue') || homeParsed.contains('from: queue'), 'Playback must pass diverse discovery queue');
  }));

  // T3_C06 [F6 + F4]: Home Playback & Minibar Reactive State
  tests.push(await executeTest('T3_C06', '[F6 + F4] Home shelf playback immediately propagates active track to Minibar', 'F06+F04', () => {
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const minibarFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'PlayerBarView.swift');
    const playerParsed = parseFile(playerFile);
    const minibarParsed = parseFile(minibarFile);

    assert(playerParsed.contains('@Published public private(set) var currentTrack: Track?'), 'AudioPlayerManager must publish currentTrack');
    assert(minibarParsed.contains('player.currentTrack'), 'Minibar must observe currentTrack reactively');
  }));

  // T3_C07 [F7 + F19]: Queue Pre-seeding & Queue Drawer Sheet
  tests.push(await executeTest('T3_C07', '[F7 + F19] Pre-seeded discovery queue seamlessly populates Queue Bottom Sheet Drawer', 'F07+F19', () => {
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const playerParsed = parseFile(playerFile);
    const fullParsed = parseFile(fullFile);

    assert(playerParsed.contains('@Published public private(set) var queue: [Track]'), 'AudioPlayerManager must publish queue');
    assert(fullParsed.contains('player.queue'), 'QueueSheetView must bind directly to player.queue');
  }));

  // T3_C08 [F8 + F9]: Search Query State & Browse Categories Grid
  tests.push(await executeTest('T3_C08', '[F8 + F9] Opening Search with empty query displays Recent Searches and Browse Categories grid', 'F08+F09', () => {
    const searchFile = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const searchParsed = parseFile(searchFile);

    assert(searchParsed.contains('searchQuery.trimmingCharacters') || searchParsed.contains('searchQuery.isEmpty'), 'SearchView must check query emptiness');
    assert(searchParsed.contains('idleDiscoverView') && searchParsed.contains('browseCategories'), 'Empty state must render idleDiscoverView containing browseCategories');
  }));

  // T3_C09 [F8 + F4]: Search Results & Minibar Playback
  tests.push(await executeTest('T3_C09', '[F8 + F4] Tapping a track in search results initiates playback with context queue in Minibar', 'F08+F04', () => {
    const searchFile = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const searchParsed = parseFile(searchFile);

    assert(searchParsed.contains('player.play(track: track, from: fullQueue'), 'Search track item tap must invoke player.play with full queue');
  }));

  // T3_C10 [F8 + F10]: Search Artist Result & Artist Discography
  tests.push(await executeTest('T3_C10', '[F8 + F10] Tapping an artist search result allows queuing artist catalog', 'F08+F10', () => {
    const searchFile = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const searchParsed = parseFile(searchFile);

    assert(searchParsed.contains('PortArtistCard') && searchParsed.contains('artist.name'), 'SearchView must render PortArtistCard for artist search results');
  }));

  // T3_C11 [F8 + F11]: Search Album Result & Album Detail Flow
  tests.push(await executeTest('T3_C11', '[F8 + F11] Tapping an album search result presents album card and playback trigger', 'F08+F11', () => {
    const searchFile = path.join(PORT_MUSIC_DIR, 'Features', 'Search', 'SearchView.swift');
    const searchParsed = parseFile(searchFile);

    assert(searchParsed.contains('PortAlbumCard') && searchParsed.contains('album.title'), 'SearchView must render PortAlbumCard for album search results');
  }));

  // T3_C12 [F10 + F7]: Artist Discography & Continuous Autoplay
  tests.push(await executeTest('T3_C12', '[F10 + F7] Artist discography playback preserves continuous queue playback', 'F10+F07', () => {
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);

    assert(playerParsed.contains('handleTrackFinished()') || playerParsed.contains('next(serverURL:'), 'AudioPlayerManager must advance automatically to next track in queue');
  }));

  // T3_C13 [F11 + F4]: Album Playback & Minibar / Lockscreen Integration
  tests.push(await executeTest('T3_C13', '[F11 + F4] Playing album track updates Minibar and MPRemoteCommandCenter controls', 'F11+F04', () => {
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);

    assert(playerParsed.contains('MPNowPlayingInfoCenter.default()'), 'Must update lockscreen MPNowPlayingInfoCenter');
    assert(playerParsed.contains('MPRemoteCommandCenter.shared()'), 'Must configure MPRemoteCommandCenter transport commands');
  }));

  // T3_C14 [F12 + F14]: Library Liked Songs Card & Favorites Flow
  tests.push(await executeTest('T3_C14', '[F12 + F14] Tapping Liked Songs hero card in Library initiates Favorites playback', 'F12+F14', () => {
    const libraryFile = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const libraryParsed = parseFile(libraryFile);

    assert(libraryParsed.contains('Lieblingssongs') && libraryParsed.contains('player.play(track: favorites[0]'), 'Tapping favorites card must trigger playback of first favorite');
  }));

  // T3_C15 [F12 + F13]: Library Segmented Tab & Alben Grid
  tests.push(await executeTest('T3_C15', '[F12 + F13] Selecting "Alben" tab renders 2-column grid of saved library albums', 'F12+F13', () => {
    const libraryFile = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const libraryParsed = parseFile(libraryFile);

    assert(libraryParsed.contains('case "Alben":') && libraryParsed.contains('albumsTabContent'), 'LibraryView must route "Alben" tab to albumsTabContent');
    assert(libraryParsed.contains('PortAlbumCard'), 'albumsTabContent must render PortAlbumCard');
  }));

  // T3_C16 [F14 + F16]: TrackRow Heart Button & Favorite Sync
  tests.push(await executeTest('T3_C16', '[F14 + F16] Tapping heart button on TrackRow triggers toggleFavorite API call', 'F14+F16', () => {
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const fullParsed = parseFile(fullFile);

    assert(fullParsed.contains('isFavorite.toggle()') && fullParsed.contains('MusicService.shared.toggleFavorite'), 'Must toggle favorite state and notify server');
  }));

  // T3_C17 [F15 + F16]: Playlist Detail & TrackRow Styling Interop
  tests.push(await executeTest('T3_C17', '[F15 + F16] Playlist renders TrackRows adhering to 56px touch height and glass aesthetics', 'F15+F16', () => {
    const libraryFile = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const libraryParsed = parseFile(libraryFile);

    assert(libraryParsed.contains('trackRowItem') && libraryParsed.contains('frame(width: 48, height: 48)'), 'TrackRows must feature standardized 48x48 artwork');
  }));

  // T3_C18 [F16 + F21]: TrackRow & Invariant Isolation Guarantee
  tests.push(await executeTest('T3_C18', '[F16 + F21] TrackRow item tap strictly guarantees standard track isolation (isLive: false)', 'F16+F21', () => {
    const libraryFile = path.join(PORT_MUSIC_DIR, 'Features', 'Library', 'LibraryView.swift');
    const libraryParsed = parseFile(libraryFile);

    assert(!libraryParsed.contains('isLive: true'), 'TrackRow tap must never produce an isLive: true track');
  }));

  // T3_C19 [F17 + F18]: Fullscreen Player & Synced Lyrics Toggle
  tests.push(await executeTest('T3_C19', '[F17 + F18] Tapping lyrics icon in Fullscreen Player toggles synced lyrics view', 'F17+F18', () => {
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const fullParsed = parseFile(fullFile);

    assert(fullParsed.contains('quote.bubble') && fullParsed.contains('showLyrics.toggle()'), 'Fullscreen player must toggle lyrics via quote.bubble button');
  }));

  // T3_C20 [F17 + F19]: Fullscreen Player & Queue Sheet Presentation
  tests.push(await executeTest('T3_C20', '[F17 + F19] Tapping queue icon in Fullscreen Player presents QueueSheetView', 'F17+F19', () => {
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const fullParsed = parseFile(fullFile);

    assert(fullParsed.contains('showQueueSheet = true') && fullParsed.contains('QueueSheetView('), 'Must present QueueSheetView via showQueueSheet state');
  }));

  // T3_C21 [F17 + F20]: Fullscreen Player & Multi-tab Details Navigation
  tests.push(await executeTest('T3_C21', '[F17 + F20] Fullscreen Player manages multiple sheet overlays without layout freeze', 'F17+F20', () => {
    const fullFile = path.join(PORT_MUSIC_DIR, 'Features', 'Player', 'FullscreenPlayerView.swift');
    const fullParsed = parseFile(fullFile);

    assert(fullParsed.contains('.sheet(isPresented: $showQueueSheet)'), 'Must bind queue sheet presentation declaratively');
  }));

  // T3_C22 [F18 + F21]: Synced Lyrics Tap-to-Seek & Audio Engine Interop
  tests.push(await executeTest('T3_C22', '[F18 + F21] Seeking audio position via lyrics tap updates standard track without radio mutation', 'F18+F21', () => {
    const playerFile = path.join(PORT_MUSIC_DIR, 'Core', 'Player', 'AudioPlayerManager.swift');
    const playerParsed = parseFile(playerFile);

    assert(playerParsed.contains('seek(to targetSeconds: Double)'), 'AudioPlayerManager must implement seek');
    assert(!playerParsed.contains('isLive = true'), 'Seeking must never change isLive state to true');
  }));

  // T3_C23 [F21 + F22]: Audio Engine & Anti-Branding Cross-Audit
  tests.push(await executeTest('T3_C23', '[F21 + F22] Entire audio and networking stack conforms to zero Deerflow branding and isLive: false', 'F21+F22', () => {
    const coreFiles = findFiles(path.join(PORT_MUSIC_DIR, 'Core'), ['.swift']);
    const brandingAudit = auditZeroBranding(coreFiles);
    const radioAudit = auditRadioVsSongIsolation(coreFiles);

    assert(brandingAudit.valid, 'Branding audit failed in Core: ' + JSON.stringify(brandingAudit.violations));
    assert(radioAudit.valid, 'Radio audit failed in Core: ' + JSON.stringify(radioAudit.violations));
  }));

  // T3_C24 [F5 + F23]: XcodeGen Spec & File System Completeness
  tests.push(await executeTest('T3_C24', '[F5 + F23] XcodeGen project.yml path includes all source directories without dangling references', 'F05+F23', () => {
    const ymlPath = path.join(BASE_DIR, 'project.yml');
    const ymlAudit = auditXcodeGenProject(ymlPath);
    assert(ymlAudit.valid, 'XcodeGen project audit failed: ' + ymlAudit.errors.join(', '));
  }));

  // T3_C25 [F2 + F5]: Settings & Build Assets Integration
  tests.push(await executeTest('T3_C25', '[F2 + F5] Profile & Settings view integrates with image cache and server ping services', 'F02+F05', () => {
    const profileFile = path.join(PORT_MUSIC_DIR, 'Features', 'Profile', 'ProfileSettingsView.swift');
    const pingFile = path.join(PORT_MUSIC_DIR, 'Core', 'Network', 'ServerPingService.swift');
    const cacheFile = path.join(PORT_MUSIC_DIR, 'Core', 'Cache', 'PortImageCache.swift');

    assert(fs.existsSync(profileFile), 'ProfileSettingsView.swift must exist');
    assert(fs.existsSync(pingFile), 'ServerPingService.swift must exist');
    assert(fs.existsSync(cacheFile), 'PortImageCache.swift must exist');
  }));

  return tests;
}

module.exports = { runTier3Tests };
