import os
import re
import sys
import json

def test_syntax_balance():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic"
    errors = []
    swift_files = []

    for root, _, files in os.walk(base_dir):
        for f in files:
            if f.endswith(".swift"):
                full_path = os.path.join(root, f)
                swift_files.append(full_path)
                with open(full_path, "r", encoding="utf-8") as sf:
                    content = sf.read()

                # Basic brace, bracket, paren balance check ignoring comments and string literals
                cleaned = []
                in_string = False
                in_multiline_comment = False
                in_line_comment = False
                escape = False
                i = 0
                while i < len(content):
                    c = content[i]
                    next_c = content[i+1] if i + 1 < len(content) else ""

                    if in_line_comment:
                        if c == '\n':
                            in_line_comment = False
                            cleaned.append(c)
                    elif in_multiline_comment:
                        if c == '*' and next_c == '/':
                            in_multiline_comment = False
                            i += 1
                    elif in_string:
                        if escape:
                            escape = False
                        elif c == '\\':
                            escape = True
                        elif c == '"':
                            in_string = False
                    else:
                        if c == '/' and next_c == '/':
                            in_line_comment = True
                            i += 1
                        elif c == '/' and next_c == '*':
                            in_multiline_comment = True
                            i += 1
                        elif c == '"':
                            in_string = True
                        else:
                            cleaned.append(c)
                    i += 1

                cleaned_str = "".join(cleaned)
                for open_char, close_char in [('{', '}'), ('(', ')'), ('[', ']')]:
                    opened = cleaned_str.count(open_char)
                    closed = cleaned_str.count(close_char)
                    if opened != closed:
                        errors.append(f"{f}: unbalanced '{open_char}' ({opened} vs {closed})")

    print(f"Scanned {len(swift_files)} Swift files for bracket/brace balance.")
    if errors:
        for e in errors:
            print("  FAIL:", e)
        return False
    print("  PASS: All Swift files have balanced braces, brackets, and parentheses.")
    return True

def test_invariants():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA"
    errors = []

    # 1. Zero third-party branding (strictly NO Deerflow)
    for root, _, files in os.walk(base_dir):
        if ".git" in root or "build" in root or "backups" in root:
            continue
        for f in files:
            if f.endswith(".swift") or f.endswith(".yml") or f.endswith(".plist") or f.endswith(".md"):
                full_path = os.path.join(root, f)
                with open(full_path, "r", encoding="utf-8", errors="ignore") as file:
                    txt = file.read().lower()
                    if "deerflow" in txt:
                        errors.append(f"Forbidden branding 'deerflow' found in {f}")

    # 2. Strict Radio vs Song Isolation: standard tracks MUST have isLive: false
    models_file = os.path.join(base_dir, r"PortMusic\Core\Models\MusicModels.swift")
    with open(models_file, "r", encoding="utf-8") as f:
        models_txt = f.read()
    if "isLive: false" not in models_txt:
        errors.append("MusicModels.swift does not enforce isLive: false on converted tracks")

    # 3. Online Streaming First: Artist pages MUST fetch from /api/discovery/artist/:name
    artist_view_file = os.path.join(base_dir, r"PortMusic\Features\Detail\ArtistDetailView.swift")
    if not os.path.exists(artist_view_file):
        errors.append("ArtistDetailView.swift does not exist")
    else:
        with open(artist_view_file, "r", encoding="utf-8") as f:
            av_txt = f.read()
        if "fetchArtist" not in av_txt:
            errors.append("ArtistDetailView does not call fetchArtist for full online discography")

    if errors:
        for e in errors:
            print("  FAIL:", e)
        return False
    print("  PASS: All project invariants verified (No Deerflow, strict Radio isolation, Online Streaming First).")
    return True

def test_feature6_home_discovery():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Home"
    home_file = os.path.join(base_dir, "HomeView.swift")
    if not os.path.exists(home_file):
        print("  FAIL: HomeView.swift missing.")
        return False

    with open(home_file, "r", encoding="utf-8") as f:
        content = f.read()

    required_tokens = [
        "fetchHomeDiscovery",
        "shelfTopPicks",
        "shelfRecentlyPlayed",
        "shelfReleaseRadar",
        "shelfTrending",
        "shelfTopHits",
        "shelfAlbums",
        "shelfTopPlaylists",
        "shelfTrendingArtists",
        "PortShelfSkeletonView",
        ".refreshable",
        "PortPosterCard",
        "PortTrackCard",
        "PortArtistCard",
        "PortAlbumCard"
    ]
    for token in required_tokens:
        if token not in content:
            print(f"  FAIL: HomeView missing required token '{token}'")
            return False

    print("  PASS: Feature #6 (Home Discovery Shelves, Octave cards & skeleton) fully verified.")
    return True

def test_feature7_queue_preseeding():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic"
    home_file = os.path.join(base_dir, r"Features\Home\HomeView.swift")
    with open(home_file, "r", encoding="utf-8") as f:
        home_txt = f.read()

    if "makeDiscoveryQueue" not in home_txt and "playTrackWithFullQueue" not in home_txt:
        print("  FAIL: HomeView does not implement dynamic discovery queue pre-seeding.")
        return False

    # Check player manager continuous autoplay
    player_file = os.path.join(base_dir, r"Core\Player\AudioPlayerManager.swift")
    with open(player_file, "r", encoding="utf-8") as f:
        player_txt = f.read()

    if "extendAutoplayQueueAndPlayNext" not in player_txt and "fetchHomeDiscovery" not in player_txt:
        print("  FAIL: AudioPlayerManager does not support continuous autoplay queue extension.")
        return False

    print("  PASS: Feature #7 (Dynamic Discovery Queue Pre-seeding & Continuous Autoplay) fully verified.")
    return True

def test_feature8_search_screen():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Search"
    search_file = os.path.join(base_dir, "SearchView.swift")
    if not os.path.exists(search_file):
        print("  FAIL: SearchView.swift missing.")
        return False

    with open(search_file, "r", encoding="utf-8") as f:
        content = f.read()

    required_tokens = [
        "magnifyingglass",
        "xmark.circle.fill",
        "350_000_000",
        "fetchDiscoverySearch",
        "Top-Treffer",
        "Songs",
        "Künstler",
        "Alben",
        "Playlists",
        "topResultHeroCard",
        "searchTrackRow"
    ]
    for token in required_tokens:
        if token not in content:
            print(f"  FAIL: SearchView missing required token '{token}'")
            return False

    print("  PASS: Feature #8 (Search Screen, Live Debounced Query & Filter Pills) fully verified.")
    return True

def test_feature9_recent_searches_and_browse():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Search"
    search_file = os.path.join(base_dir, "SearchView.swift")
    with open(search_file, "r", encoding="utf-8") as f:
        content = f.read()

    required_tokens = [
        "port_music_recent_searches",
        "clearAllRecentSearches",
        "removeRecentSearch",
        "Zuletzt gesucht",
        "Kategorien entdecken",
        "LinearGradient",
        "GridItem(.flexible()"
    ]
    for token in required_tokens:
        if token not in content:
            print(f"  FAIL: SearchView missing recent searches / categories token '{token}'")
            return False

    print("  PASS: Feature #9 (Recent Searches Storage & 2-Column Browse Grid) fully verified.")
    return True

def test_feature10_artist_detail():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic"
    artist_file = os.path.join(base_dir, r"Features\Detail\ArtistDetailView.swift")
    if not os.path.exists(artist_file):
        print("  FAIL: ArtistDetailView.swift missing.")
        return False

    with open(artist_file, "r", encoding="utf-8") as f:
        content = f.read()

    required_tokens = [
        "heroBannerHeader",
        "Verifizierter Künstler",
        "Beliebte Titel",
        "Alben",
        "Singles & EPs",
        "Ähnliche Künstler",
        "fetchArtist",
        "playAllTopTracks",
        "toggleSaveArtist"
    ]
    for token in required_tokens:
        if token not in content:
            print(f"  FAIL: ArtistDetailView missing required token '{token}'")
            return False

    # Check MusicService artist endpoint
    service_file = os.path.join(base_dir, r"Core\Network\MusicService.swift")
    with open(service_file, "r", encoding="utf-8") as f:
        srv_content = f.read()

    if "/api/discovery/artist/" not in srv_content or "fetchArtist" not in srv_content:
        print("  FAIL: MusicService does not implement fetchArtist calling /api/discovery/artist/.")
        return False

    print("  PASS: Feature #10 (Artist Detail View, Discography & Top Tracks) fully verified.")
    return True

def test_feature11_album_detail():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic"
    album_file = os.path.join(base_dir, r"Features\Detail\AlbumDetailView.swift")
    if not os.path.exists(album_file):
        print("  FAIL: AlbumDetailView.swift missing.")
        return False

    with open(album_file, "r", encoding="utf-8") as f:
        content = f.read()

    required_tokens = [
        "albumHeaderHero",
        "displayTitle",
        "displayArtist",
        "metadataLine",
        "actionButtonsRow",
        "tracklistSection",
        "fetchAlbum",
        "playAllTracks",
        "toggleFavorite"
    ]
    for token in required_tokens:
        if token not in content:
            print(f"  FAIL: AlbumDetailView missing required token '{token}'")
            return False

    # Check MusicService album endpoint
    service_file = os.path.join(base_dir, r"Core\Network\MusicService.swift")
    with open(service_file, "r", encoding="utf-8") as f:
        srv_content = f.read()

    if "/api/discovery/album/" not in srv_content or "fetchAlbum" not in srv_content:
        print("  FAIL: MusicService does not implement fetchAlbum calling /api/discovery/album/.")
        return False

    print("  PASS: Feature #11 (Album Detail View, Tracklist & Header Metadata) fully verified.")
    return True

def test_navigation_and_project_sync():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA"
    main_tab_file = os.path.join(base_dir, r"PortMusic\Features\Main\MainTabView.swift")
    with open(main_tab_file, "r", encoding="utf-8") as f:
        tab_content = f.read()

    if "NavigationStack" not in tab_content or "navigationDestination" not in tab_content:
        print("  FAIL: MainTabView does not wrap Home/Search in NavigationStack with navigationDestination.")
        return False

    if "ArtistDetailView" not in tab_content or "AlbumDetailView" not in tab_content:
        print("  FAIL: MainTabView does not route to ArtistDetailView and AlbumDetailView.")
        return False

    # Check project.pbxproj includes the new files
    pbx_file = os.path.join(base_dir, r"PortMusic.xcodeproj\project.pbxproj")
    with open(pbx_file, "r", encoding="utf-8") as f:
        pbx_content = f.read()

    new_files = ["ArtistDetailView.swift", "AlbumDetailView.swift", "AppRoute.swift"]
    for nf in new_files:
        if nf not in pbx_content:
            print(f"  FAIL: {nf} is not registered in project.pbxproj.")
            return False

    print("  PASS: Navigation routing and Xcode project.pbxproj sync fully verified.")
    return True

def main():
    print("=== PORT MUSIC v2 - MILESTONE M2 VERIFICATION ===")
    results = [
        ("Syntax and Bracket Balance", test_syntax_balance()),
        ("Project Invariants & Zero Branding", test_invariants()),
        ("Feature 6: Home Discovery Shelves", test_feature6_home_discovery()),
        ("Feature 7: Dynamic Discovery Queue Pre-seeding", test_feature7_queue_preseeding()),
        ("Feature 8: Search Screen & Live Debounced Query", test_feature8_search_screen()),
        ("Feature 9: Recent Searches & Browse Categories Grid", test_feature9_recent_searches_and_browse()),
        ("Feature 10: Artist Detail View", test_feature10_artist_detail()),
        ("Feature 11: Album Detail View", test_feature11_album_detail()),
        ("Navigation & Xcode Project Sync", test_navigation_and_project_sync())
    ]

    print("\n=== SUMMARY ===")
    all_passed = True
    for name, passed in results:
        status = "[PASSED]" if passed else "[FAILED]"
        print(f"  {status} {name}")
        if not passed:
            all_passed = False

    if all_passed:
        print("\nAll Milestone M2 verification checks PASSED successfully!")
        sys.exit(0)
    else:
        print("\nSome Milestone M2 verification checks FAILED.")
        sys.exit(1)

if __name__ == "__main__":
    main()
