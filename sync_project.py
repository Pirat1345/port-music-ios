import os
import hashlib

def gen_id(prefix_int, path):
    # Standard Xcode 24-character hexadecimal ID: 8 hex chars prefix + 16 hex chars hash
    h = hashlib.md5(f"{prefix_int}:{path}".encode('utf-8')).hexdigest()[:16].upper()
    return f"{prefix_int:08X}{h}"

def main():
    base_dir = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic"
    pbx_path = r"c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\PortMusic.xcodeproj\project.pbxproj"

    # Collect all files excluding internal Assets.xcassets contents
    all_files = []
    for root, dirs, files in os.walk(base_dir):
        if "Assets.xcassets" in root:
            continue
        for f in files:
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, base_dir).replace("\\", "/")
            all_files.append((rel_path, f))

    sources_files = [f for f in all_files if f[1].endswith(".swift") or f[1].endswith(".metal")]
    resource_files = [f for f in all_files if f[1].endswith(".ttf") or f[1].endswith(".png") or f[1].endswith(".plist")]
    # Assets.xcassets is a directory
    asset_dir = ("Resources/Assets.xcassets", "Assets.xcassets")

    print(f"Found {len(sources_files)} Sources files, {len(resource_files)} resources")

    # Generate PBXBuildFile section
    build_files = []
    file_refs = []
    sources_entries = []
    resources_entries = []

    # Map relative path to IDs
    file_ref_map = {}
    build_ref_map = {}

    idx = 100
    for rel, name in sources_files:
        idx += 1
        f_id = gen_id(0x00100000 + idx, f"fileref:{rel}")
        b_id = gen_id(0x00200000 + idx, f"buildfile:{rel}")
        file_ref_map[rel] = f_id
        build_ref_map[rel] = b_id

        file_type = "sourcecode.swift" if name.endswith(".swift") else "sourcecode.metal"
        build_files.append(f"\t\t{b_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {name} */; }};")
        file_refs.append(f"\t\t{f_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = \"{name}\"; sourceTree = \"<group>\"; }};")
        sources_entries.append(f"\t\t\t\t{b_id} /* {name} in Sources */,")

    # Assets
    idx += 1
    f_assets = gen_id(0x00100000 + idx, f"fileref:{asset_dir[0]}")
    b_assets = gen_id(0x00200000 + idx, f"buildfile:{asset_dir[0]}")
    file_ref_map[asset_dir[0]] = f_assets
    build_ref_map[asset_dir[0]] = b_assets
    build_files.append(f"\t\t{b_assets} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {f_assets} /* Assets.xcassets */; }};")
    file_refs.append(f"\t\t{f_assets} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = \"Assets.xcassets\"; sourceTree = \"<group>\"; }};")
    resources_entries.append(f"\t\t\t\t{b_assets} /* Assets.xcassets in Resources */,")

    # Other resources
    for rel, name in resource_files:
        idx += 1
        f_id = gen_id(0x00100000 + idx, f"fileref:{rel}")
        b_id = gen_id(0x00200000 + idx, f"buildfile:{rel}")
        file_ref_map[rel] = f_id
        build_ref_map[rel] = b_id

        file_type = "image.png" if name.endswith(".png") else ("file" if name.endswith(".ttf") else "text.plist.xml")
        build_files.append(f"\t\t{b_id} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {name} */; }};")
        file_refs.append(f"\t\t{f_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = \"{name}\"; sourceTree = \"<group>\"; }};")
        resources_entries.append(f"\t\t\t\t{b_id} /* {name} in Resources */,")

    # Build group hierarchy
    group_defs = []

    def make_group(group_id, name, children_ids, path=None):
        child_lines = "\n".join([f"\t\t\t\t{cid}," for cid in children_ids])
        path_line = f"\t\t\tpath = \"{path}\";\n" if path else ""
        name_line = f"\t\t\tname = \"{name}\";\n" if (name and not path) or (name and path and name != path) else ""
        return (f"\t\t{group_id} /* {name} */ = {{\n"
                f"\t\t\tisa = PBXGroup;\n"
                f"\t\t\tchildren = (\n"
                f"{child_lines}\n"
                f"\t\t\t);\n"
                f"{name_line}"
                f"{path_line}"
                f"\t\t\tsourceTree = \"<group>\";\n"
                f"\t\t}};")

    # Helper to get file_id for relative path
    def get_fid(rel):
        return f"{file_ref_map[rel]} /* {os.path.basename(rel)} */"

    # Groups
    g_id = 2000
    def next_gid(group_name="Group"):
        nonlocal g_id
        g_id += 1
        return gen_id(0x00300000 + g_id, f"group:{group_name}:{g_id}")

    # Leaf groups
    # App
    gid_app = next_gid("App")
    app_children = [get_fid("App/PortMusicApp.swift")]
    group_defs.append(make_group(gid_app, "App", app_children, "App"))

    # Core leaf groups
    gid_cache = next_gid("Cache")
    group_defs.append(make_group(gid_cache, "Cache", [get_fid("Core/Cache/PortImageCache.swift")], "Cache"))

    gid_models = next_gid("Models")
    group_defs.append(make_group(gid_models, "Models", [get_fid("Core/Models/AuthModels.swift"), get_fid("Core/Models/BrowseCategoryModels.swift"), get_fid("Core/Models/MusicModels.swift")], "Models"))

    gid_network = next_gid("Network")
    group_defs.append(make_group(gid_network, "Network", [get_fid("Core/Network/AuthService.swift"), get_fid("Core/Network/MusicService.swift"), get_fid("Core/Network/ServerPingService.swift")], "Network"))

    gid_player = next_gid("Player")
    player_files = [
        "Core/Player/AudioPlayerManager.swift",
        "Core/Player/FavoritesManager.swift",
        "Core/Player/SystemVolumeManager.swift"
    ]
    group_defs.append(make_group(gid_player, "Player", [get_fid(f) for f in player_files], "Player"))

    gid_security = next_gid("Security")
    group_defs.append(make_group(gid_security, "Security", [get_fid("Core/Security/KeychainHelper.swift")], "Security"))

    gid_state = next_gid("State")
    group_defs.append(make_group(gid_state, "State", [get_fid("Core/State/SessionManager.swift")], "State"))

    # Shaders group under Theme
    gid_shaders = next_gid("Shaders")
    group_defs.append(make_group(gid_shaders, "Shaders", [get_fid("Core/Theme/Shaders/FluentSilkShader.metal")], "Shaders"))

    gid_theme = next_gid("Theme")
    theme_files = [
        "Core/Theme/FluentBackgroundView.swift",
        "Core/Theme/MetalSilkBackgroundView.swift",
        "Core/Theme/MetalSilkRenderer.swift",
        "Core/Theme/PortCachedAsyncImage.swift",
        "Core/Theme/PortTheme.swift"
    ]
    theme_children = [get_fid(f) for f in theme_files] + [f"{gid_shaders} /* Shaders */"]
    group_defs.append(make_group(gid_theme, "Theme", theme_children, "Theme"))

    gid_core = next_gid("Core")
    group_defs.append(make_group(gid_core, "Core", [
        f"{gid_cache} /* Cache */",
        f"{gid_models} /* Models */",
        f"{gid_network} /* Network */",
        f"{gid_player} /* Player */",
        f"{gid_security} /* Security */",
        f"{gid_state} /* State */",
        f"{gid_theme} /* Theme */"
    ], "Core"))

    # Features
    gid_auth = next_gid()
    auth_files = [
        "Features/Auth/CaptchaChallengeSheetView.swift",
        "Features/Auth/CaptchaWidgetView.swift",
        "Features/Auth/LoginView.swift",
        "Features/Auth/TwoFactorView.swift"
    ]
    group_defs.append(make_group(gid_auth, "Auth", [get_fid(f) for f in auth_files], "Auth"))

    gid_captcha = next_gid()
    captcha_files = [
        "Features/Captcha/CaptchaChallengeContainerView.swift",
        "Features/Captcha/ClawMachineView.swift",
        "Features/Captcha/LitterCaptchaView.swift"
    ]
    group_defs.append(make_group(gid_captcha, "Captcha", [get_fid(f) for f in captcha_files], "Captcha"))

    gid_common = next_gid()
    group_defs.append(make_group(gid_common, "Common", [get_fid("Features/Common/PortLogoView.swift")], "Common"))

    gid_home_comp = next_gid()
    home_comp_files = [
        "Features/Home/Components/PortAlbumCard.swift",
        "Features/Home/Components/PortArtistCard.swift",
        "Features/Home/Components/PortCoverImage.swift",
        "Features/Home/Components/PortPosterCard.swift",
        "Features/Home/Components/PortShelfContainer.swift",
        "Features/Home/Components/PortShelfHeader.swift",
        "Features/Home/Components/PortShelfSkeletonView.swift",
        "Features/Home/Components/PortTrackCard.swift"
    ]
    group_defs.append(make_group(gid_home_comp, "Components", [get_fid(f) for f in home_comp_files], "Components"))

    gid_home = next_gid()
    group_defs.append(make_group(gid_home, "Home", [
        get_fid("Features/Home/HomeView.swift"),
        f"{gid_home_comp} /* Components */"
    ], "Home"))

    gid_library = next_gid()
    library_files = [
        "Features/Library/LibraryAlbumsView.swift",
        "Features/Library/LibraryCategoryDetailView.swift",
        "Features/Library/LibraryView.swift",
        "Features/Library/LikedSongsView.swift",
        "Features/Library/PlaylistDetailView.swift",
        "Features/Library/TrackRowView.swift"
    ]
    group_defs.append(make_group(gid_library, "Library", [get_fid(f) for f in library_files], "Library"))

    gid_main = next_gid()
    group_defs.append(make_group(gid_main, "Main", [get_fid("Features/Main/MainTabView.swift")], "Main"))

    gid_feat_player = next_gid()
    feat_player_files = [
        "Features/Player/FullscreenPlayerView.swift",
        "Features/Player/MiniPlayerBar.swift",
        "Features/Player/PlayerBarView.swift"
    ]
    group_defs.append(make_group(gid_feat_player, "Player", [get_fid(f) for f in feat_player_files], "Player"))

    gid_profile = next_gid()
    profile_files = [
        "Features/Profile/LoggedInView.swift",
        "Features/Profile/ProfileSettingsView.swift"
    ]
    group_defs.append(make_group(gid_profile, "Profile", [get_fid(f) for f in profile_files], "Profile"))

    gid_search = next_gid()
    group_defs.append(make_group(gid_search, "Search", [get_fid("Features/Search/SearchView.swift")], "Search"))

    gid_setup = next_gid()
    group_defs.append(make_group(gid_setup, "ServerSetup", [get_fid("Features/ServerSetup/ServerSetupView.swift")], "ServerSetup"))

    gid_detail = next_gid()
    detail_files = [
        "Features/Detail/AlbumDetailView.swift",
        "Features/Detail/AppleCategoryDetailView.swift",
        "Features/Detail/AppRoute.swift",
        "Features/Detail/ArtistDetailView.swift"
    ]
    group_defs.append(make_group(gid_detail, "Detail", [get_fid(f) for f in detail_files], "Detail"))

    gid_features = next_gid()
    group_defs.append(make_group(gid_features, "Features", [
        f"{gid_auth} /* Auth */",
        f"{gid_captcha} /* Captcha */",
        f"{gid_common} /* Common */",
        f"{gid_detail} /* Detail */",
        f"{gid_home} /* Home */",
        f"{gid_library} /* Library */",
        f"{gid_main} /* Main */",
        f"{gid_feat_player} /* Player */",
        f"{gid_profile} /* Profile */",
        f"{gid_search} /* Search */",
        f"{gid_setup} /* ServerSetup */"
    ], "Features"))

    # Resources
    gid_fonts = next_gid()
    group_defs.append(make_group(gid_fonts, "Fonts", [get_fid("Resources/Fonts/Manosque-Regular.ttf")], "Fonts"))

    gid_toys = next_gid()
    toy_files = [
        f"Resources/Toys/{t}.png" for t in ["bear", "bunny", "cat", "dino", "duck", "fox", "frog", "panda", "penguin", "puppy", "unicorn", "whale"]
    ]
    group_defs.append(make_group(gid_toys, "Toys", [get_fid(f) for f in toy_files], "Toys"))

    gid_resources = next_gid()
    res_files = [
        get_fid("Resources/Assets.xcassets"),
        get_fid("Resources/Info.plist"),
        get_fid("Resources/port-logo.png"),
        get_fid("Resources/port-logo-512.png"),
        f"{gid_fonts} /* Fonts */",
        f"{gid_toys} /* Toys */"
    ]
    group_defs.append(make_group(gid_resources, "Resources", res_files, "Resources"))

    # Root PortMusic Group
    gid_portmusic = "000000012026111400000004"
    group_defs.append(make_group(gid_portmusic, "PortMusic", [
        f"{gid_app} /* App */",
        f"{gid_core} /* Core */",
        f"{gid_features} /* Features */",
        f"{gid_resources} /* Resources */"
    ], "PortMusic"))

    # Products Group
    gid_products = "000000012026111400000005"
    group_defs.append(make_group(gid_products, "Products", [
        "000000012026111400000006 /* PortMusic.app */"
    ], None))

    # Main Group
    gid_main_group = "000000012026111400000003"
    group_defs.append(make_group(gid_main_group, "Main", [
        f"{gid_portmusic} /* PortMusic */",
        f"{gid_products} /* Products */"
    ], None))

    build_files_str = "\n".join(build_files)
    file_refs_str = "\n".join(file_refs)
    groups_str = "\n".join(group_defs)
    sources_str = "\n".join(sources_entries)
    resources_str = "\n".join(resources_entries)

    project_pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_files_str}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t000000012026111400000006 /* PortMusic.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PortMusic.app; sourceTree = BUILT_PRODUCTS_DIR; }};
{file_refs_str}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t000000012026111400000009 /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{groups_str}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t000000012026111400000002 /* PortMusic */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 000000012026111400000024 /* Build configuration list for PBXNativeTarget "PortMusic" */;
\t\t\tbuildPhases = (
\t\t\t\t000000012026111400000007 /* Sources */,
\t\t\t\t000000012026111400000009 /* Frameworks */,
\t\t\t\t000000012026111400000008 /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = PortMusic;
\t\t\tproductName = PortMusic;
\t\t\tproductReference = 000000012026111400000006 /* PortMusic.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t000000012026111400000001 /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t000000012026111400000002 = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = 000000012026111400000021 /* Build configuration list for PBXProject "PortMusic" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = de;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\tde,
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = 000000012026111400000003 /* Main */;
\t\t\tproductRefGroup = 000000012026111400000005 /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t000000012026111400000002 /* PortMusic */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t000000012026111400000008 /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{resources_str}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t000000012026111400000007 /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sources_str}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t000000012026111400000022 /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t000000012026111400000023 /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t000000012026111400000025 /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = PortMusic/Resources/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 2.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.portmusic.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t000000012026111400000026 /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = PortMusic/Resources/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 2.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.portmusic.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t000000012026111400000021 /* Build configuration list for PBXProject "PortMusic" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t000000012026111400000022 /* Debug */,
\t\t\t\t000000012026111400000023 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t000000012026111400000024 /* Build configuration list for PBXNativeTarget "PortMusic" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t000000012026111400000025 /* Debug */,
\t\t\t\t000000012026111400000026 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = 000000012026111400000001 /* Project object */;
}}
"""

    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(project_pbxproj)

    print("Successfully updated project.pbxproj!")

if __name__ == "__main__":
    main()
