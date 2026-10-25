# 🎵 Port Music iOS App

Das native iOS-Projekt für **Port Music**, vollständig angebunden an dein lokales Backend (`http://192.168.178.19:3000`) und gestaltet nach den **Port Music Design Guidelines** (OLED Dark Mode mit dezenten grünen Marken-Akzenten).

---

## ✨ Features & Highlights

* **100% Natives Port Music Branding & Design:**
  * **App-Icon & Logo:** Hochauflösendes Port Music Icon und Logo direkt aus der Web-App übernommen.
  * **OLED Dark Aesthetic:** Reines Tiefschwarz (`#0a0a0a`), subtil abgestufte Oberflächen (`#121212`, `#181818`) und dezente Ränder (`rgba(255,255,255,0.08)`).
  * **Marken-Akzent:** Port Music Grün (`#1db954`) gezielt für Play-Buttons, Fortschrittsanzeigen und aktive Titel eingesetzt.
  * **Keine störenden Effekte:** Verzicht auf grelle Regenbogen-Gradients oder künstliche Leuchtringe.
  * **Vollständige deutsche Lokalisierung:** Home, Entdecken, Radio, Bibliothek, Suche, Kontoeinstellungen und Songtexte.

* **Reibungsloses Online-Audio-Streaming:**
  * **Kompatibel mit iOS AVPlayer:** Das Backend streamt verifiziert im nativeren `audio/mp4` (AAC) Format mit `accept-ranges: bytes` für blitzschnelles Buffern und Seeking.
  * **Auto-Next:** Nach Beenden eines Tracks schaltet der Player automatisch auf den nächsten Titel der Warteschlange.
  * **Mini-Player:** Schwebender Player mit Live-Fortschrittsbalken über der Tab-Bar.
  * **Vollbild-Player:** Inklusive Cover, Zeitleiste, Favorite-Button und Schließen-Geste.

* **Natives Login- & Registrierungs-System:**
  * **Anmelden:** Login mit Benutzername oder E-Mail & Passwort gegen dein lokales Backend (`POST /api/auth/login`).
  * **Registrieren:** Neues Konto direkt in der iOS-App anlegen (`POST /api/auth/register`).
  * **Session-Persistenz:** Nach dem Login bleibst du dauerhaft angemeldet.

* **Konfigurierbare Server-Adresse:**
  * Standardmäßig vorkonfiguriert auf **`http://192.168.178.19:3000`**.
  * Jederzeit auf dem Anmeldebildschirm oder in den Einstellungen änderbar.
  * `NSAllowsArbitraryLoads = true` in der `Info.plist` erlaubt lokale HTTP-Verbindungen im Heimnetzwerk ohne SSL-Zertifikat.

* **Synchrone Songtexte (Word-Sync Lyrics):**
  * Millisekundengenaue Anzeige synchroner Liedtexte über `/api/lyrics/<id>`.

---

## 🚀 Installation auf dem iPhone mit Sideloadly

Die App wurde bereits über GitHub Actions für iOS 18 / Xcode 16 gebaut. Die fertige IPA-Datei liegt lokal für dich bereit:

1. **Datei finden:**  
   Die fertige Datei liegt unter:  
   `c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA\build\PortMusic.ipa`
2. **iPhone verbinden:**  
   Schließe dein iPhone per USB an deinen Windows-PC an.
3. **Sideloadly öffnen:**  
   Starte [Sideloadly](https://sideloadly.io/).
4. **IPA hineinziehen:**  
   Ziehe die Datei `PortMusic.ipa` in das Sideloadly-Fenster.
5. **Apple-ID eingeben & starten:**  
   Gib deine gewohnte Apple-ID ein und klicke auf **Start**.
6. **Zertifikat vertrauen (einmalig):**  
   Auf dem iPhone unter *Einstellungen > Allgemein > VPN und Geräteverwaltung* auf deine Apple-ID tippen und auf *Vertrauen* tippen.
7. **Port Music starten:**  
   Öffne **Port Music** auf deinem iPhone, melde dich an und genieße deine Musik! 🎧

---

## ☁️ Automatischer Cloud-Build (GitHub Actions)

Jeder Push auf den Branch `main` des Repositories [`https://github.com/Pirat1345/port-music-ios.git`](https://github.com/Pirat1345/port-music-ios.git) startet automatisch den Workflow:
- Runner: `macos-15` (macOS Sequoia)
- Xcode: Version 16.4
- Kompilierung von App & Widgets
- Automatisches Erstellen und Hochladen des IPA-Artifacts `PortMusic-iOS-IPA`
