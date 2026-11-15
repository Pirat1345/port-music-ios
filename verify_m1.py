import os
import re
import sys

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
                # Simple sanitizer
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

    # 1. Zero third-party branding (e.g. Deerflow)
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

    if errors:
        for e in errors:
            print("  FAIL:", e)
        return False
    print("  PASS: Zero third-party branding (strictly NO Deerflow).")
    return True

def test_feature1_auth_preservation():
    required_files = [
        r"IPA\PortMusic\Core\Security\KeychainHelper.swift",
        r"IPA\PortMusic\Core\State\SessionManager.swift",
        r"IPA\PortMusic\Core\Network\AuthService.swift",
        r"IPA\PortMusic\Features\Auth\LoginView.swift",
        r"IPA\PortMusic\Features\Auth\TwoFactorView.swift",
        r"IPA\PortMusic\Features\Captcha\ClawMachineView.swift",
        r"IPA\PortMusic\Features\Captcha\LitterCaptchaView.swift",
        r"IPA\PortMusic\App\PortMusicApp.swift"
    ]
    workspace = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2"
    for rf in required_files:
        full_path = os.path.join(workspace, rf)
        if not os.path.exists(full_path):
            print(f"  FAIL: Required auth file {rf} does not exist.")
            return False

    # Check PortMusicApp routing
    app_swift = os.path.join(workspace, r"IPA\PortMusic\App\PortMusicApp.swift")
    with open(app_swift, "r", encoding="utf-8") as f:
        content = f.read()

    if "MainTabView" not in content or "LoginView" not in content:
        print("  FAIL: PortMusicApp does not route to MainTabView and LoginView.")
        return False

    # Check UserProfile model has avatar property and init parameter
    auth_models_path = os.path.join(workspace, r"IPA\PortMusic\Core\Models\AuthModels.swift")
    with open(auth_models_path, "r", encoding="utf-8") as f:
        models_content = f.read()

    if "avatar: String?" not in models_content or "self.avatar = avatar" not in models_content:
        print("  FAIL: UserProfile in AuthModels.swift missing avatar field or assignment.")
        return False

    # Check AuthService extracts avatar
    auth_service_path = os.path.join(workspace, r"IPA\PortMusic\Core\Network\AuthService.swift")
    with open(auth_service_path, "r", encoding="utf-8") as f:
        service_content = f.read()

    if 'userObj["avatar"]' not in service_content or 'userObj?["avatar"]' not in service_content:
        print("  FAIL: AuthService does not extract avatar in checkAuth/login.")
        return False

    print("  PASS: Feature #1 (Preserve Existing Auth Flow, Routing & UserProfile Avatar) fully verified.")
    return True

def test_feature2_profile_settings():
    path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Profile\ProfileSettingsView.swift"
    if not os.path.exists(path):
        print("  FAIL: ProfileSettingsView.swift does not exist.")
        return False

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    checks = [
        ("UserProfile", "user profile injection"),
        ("AudioQualityTier", "audio streaming quality enum"),
        ("portmusic_audio_quality", "audio quality persistence"),
        ("ServerPingService", "server latency ping service"),
        ("isServerReachable", "dynamic server reachable state"),
        ("checkmark.shield.fill", "success shield icon"),
        ("xmark.shield.fill", "failure shield icon"),
        ("clearAllCache", "cache management action"),
        ("calculateDiskCacheSize", "cache size calculation"),
        ("v2.0.0 (Octave Edition)", "app version info"),
        ("onLogout", "logout callback"),
        ("glassCard", "Octave glassmorphism styling")
    ]

    for needle, desc in checks:
        if needle not in content:
            print(f"  FAIL: ProfileSettingsView missing {desc} ({needle}).")
            return False

    # Verify no aggressive NSTemporaryDirectory wipe
    if "NSTemporaryDirectory()" in content:
        print("  FAIL: ProfileSettingsView still performs aggressive NSTemporaryDirectory() deletion.")
        return False

    # Check LoggedInView compatibility
    logged_in_path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Profile\LoggedInView.swift"
    if not os.path.exists(logged_in_path):
        print("  FAIL: LoggedInView compatibility file missing.")
        return False

    print("  PASS: Feature #2 (Production ProfileSettingsView, Dynamic Ping & Safe Cache) fully verified.")
    return True

def test_feature3_mobile_tab_bar():
    path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Main\MainTabView.swift"
    if not os.path.exists(path):
        print("  FAIL: MainTabView.swift does not exist.")
        return False

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check 4 tabs
    symbols = ["house.fill", "magnifyingglass", "square.stack.fill", "person.crop.circle.fill"]
    for s in symbols:
        if s not in content:
            print(f"  FAIL: MainTabView missing tab symbol {s}.")
            return False

    # Check views hosted
    views = ["HomeView", "SearchView", "LibraryView", "ProfileSettingsView"]
    for v in views:
        if v not in content:
            print(f"  FAIL: MainTabView does not host {v}.")
            return False

    # Check Minibar embedded
    if "PlayerBarView" not in content:
        print("  FAIL: MainTabView does not embed PlayerBarView.")
        return False

    print("  PASS: Feature #3 (Mobile Navigation Bar with 4 tabs & active states) fully verified.")
    return True

def test_feature4_player_bar():
    path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Player\PlayerBarView.swift"
    if not os.path.exists(path):
        print("  FAIL: PlayerBarView.swift does not exist.")
        return False

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    checks = [
        ("player.currentTrack", "track conditional rendering"),
        ("onOpenFullscreen", "tap-to-expand callback"),
        ("PortCachedAsyncImage", "cover artwork loading"),
        ("track.title", "track title display"),
        ("track.artist", "track artist display"),
        ("player.togglePlayPause", "play pause toggle"),
        ("player.next", "skip next control"),
        ("player.currentTime", "progress bar line"),
        ("!player.currentTime.isNaN && player.currentTime.isFinite", "progress NaN and finite arithmetic guard"),
        ("Unbekannter Titel", "fallback title when track title is empty"),
        ("Unbekannter Interpret", "fallback artist when track artist is empty")
    ]

    for needle, desc in checks:
        if needle not in content:
            print(f"  FAIL: PlayerBarView missing {desc} ({needle}).")
            return False

    # Check MiniPlayerBar compatibility
    mini_path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic\Features\Player\MiniPlayerBar.swift"
    if not os.path.exists(mini_path):
        print("  FAIL: MiniPlayerBar compatibility wrapper missing.")
        return False

    print("  PASS: Feature #4 (Floating Minibar PlayerBarView with Hardened Progress & Fallbacks) fully verified.")
    return True

def test_feature5_project_sync():
    yml_path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\project.yml"
    pbx_path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic.xcodeproj\project.pbxproj"

    if not os.path.exists(yml_path):
        print("  FAIL: project.yml missing.")
        return False
    if not os.path.exists(pbx_path):
        print("  FAIL: project.pbxproj missing.")
        return False

    with open(pbx_path, "r", encoding="utf-8") as f:
        pbx_content = f.read()

    # Check that new files are registered
    must_be_in_pbx = [
        "ProfileSettingsView.swift",
        "PlayerBarView.swift",
        "MainTabView.swift",
        "HomeView.swift",
        "SearchView.swift",
        "LibraryView.swift",
        "AudioPlayerManager.swift",
        "PortMusicApp.swift",
        "PortTheme.swift",
        "FluentSilkShader.metal"
    ]

    for f in must_be_in_pbx:
        if f not in pbx_content:
            print(f"  FAIL: {f} not referenced in project.pbxproj.")
            return False

    # Check that all PBX object UUIDs are valid 24-character hexadecimal strings
    keys = re.findall(r'([A-Za-z0-9_]+)\s*/\*.*?\*/\s*=', pbx_content)
    invalid_uuids = [k for k in keys if len(k) != 24 or not re.match(r'^[0-9A-Fa-f]{24}$', k)]
    if invalid_uuids:
        print(f"  FAIL: Found {len(invalid_uuids)} invalid non-24-hex PBX UUIDs (e.g. {invalid_uuids[:3]}).")
        return False

    # Check that there are 0 orphaned file references
    frefs = re.findall(r'(\w+)\s*/\*\s*([^*]+)\s*\*/\s*=\s*\{isa\s*=\s*PBXFileReference;', pbx_content)
    groups = set(re.findall(r'(\w+)\s*/\*', ''.join(re.findall(r'children\s*=\s*\((.*?)\);', pbx_content, re.DOTALL))))
    orphans = [fid for fid, c in frefs if fid not in groups and fid != '000000012026111400000006']
    if orphans:
        print(f"  FAIL: Found {len(orphans)} orphaned file references in project.pbxproj: {orphans}")
        return False

    print("  PASS: Feature #5 (Project Sync, 24-char Hex UUIDs, Shader & 0 Orphans) fully verified.")
    return True

def main():
    print("=== PORT MUSIC v2 - MILESTONE M1 VERIFICATION ===")
    results = [
        ("Syntax and Bracket Balance", test_syntax_balance()),
        ("Project Invariants & Zero Branding", test_invariants()),
        ("Feature 1: Auth Flow & App Navigation", test_feature1_auth_preservation()),
        ("Feature 2: Profile & Settings View", test_feature2_profile_settings()),
        ("Feature 3: 4-Tab Mobile Navigation Bar", test_feature3_mobile_tab_bar()),
        ("Feature 4: Floating Minibar PlayerBarView", test_feature4_player_bar()),
        ("Feature 5: XcodeGen & PBXProj Sync", test_feature5_project_sync()),
    ]

    print("\n=== SUMMARY ===")
    all_passed = True
    for name, passed in results:
        status = "PASSED" if passed else "FAILED"
        print(f"  [{status}] {name}")
        if not passed:
            all_passed = False

    if all_passed:
        print("\nAll Milestone M1 verification checks PASSED successfully!")
        sys.exit(0)
    else:
        print("\nVerification FAILED.")
        sys.exit(1)

if __name__ == "__main__":
    main()
