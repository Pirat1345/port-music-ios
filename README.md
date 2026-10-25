# 🎵 Port-Music iOS App (Octave Native)

Dieses Verzeichnis enthält das **vollständige native iOS-Projekt** der Octave-App, angepasst für die direkte Anbindung an dein lokales **`port-music-v2` Backend** (`http://192.168.178.19:3000`).

---

## ✨ Features & Neuerungen

* **Natives Login- & Registrierungs-System (`GateView.swift`, `AccountStore.swift`)**:
  * **Anmelden:** Login mit Benutzername oder E-Mail & Passwort gegen dein lokales Backend (`POST /api/auth/login`).
  * **Registrieren:** Neues Konto direkt in der iOS-App anlegen (`POST /api/auth/register`).
  * **Session-Persistenz:** Nach dem Login bleibst du dauerhaft angemeldet. Auf Wunsch kannst du dich in den Kontoeinstellungen jederzeit wieder abmelden.
* **Editierbare Server-Adresse (`OctaveBackend.swift`)**:
  * Standardmäßig vorkonfiguriert auf **`http://192.168.178.19:3000`**.
  * Die Server-Adresse kann direkt auf dem Login-Bildschirm oder in den App-Einstellungen geändert werden, falls sich deine PC-IP oder Domain ändert.
* **App Transport Security (ATS) Freischaltung (`Info.plist`)**:
  * `NSAllowsArbitraryLoads = true` ist aktiv, damit iOS unverschlüsselte lokale HTTP-Verbindungen im WLAN (`http://192.168.178.19:3000`) ohne Zertifikatswarnungen erlaubt.
* **High-Performance Audio & Synced Lyrics Engine**:
  * Streaming über `/audio/320/<id>` und `/audio/atmos/<id>` aus deinem `port-music-v2` Backend.
  * Synchrone Lyrics und Karaoke-Hervorhebung über `/api/lyrics/<id>`.
  * Automatische Konvertierung und Auflösung numerischer Apple-Music-Track-IDs in YouTube-Audiostreams.

---

## 🚀 In 3 Schritten zur fertigen App auf deinem iPhone (via GitHub Actions)

Du benötigst **keinen Mac**! Ein kostenloser macOS-Cloud-Server von GitHub kompiliert den Swift-Code und erzeugt die fertige `.ipa` für dich.

### Schritt 1: GitHub-Repository anlegen & Code hochladen
1. Erstelle auf [github.com/new](https://github.com/new) ein neues (privates oder öffentliches) Repository, z. B. `port-music-ios`.
2. Öffne dein Terminal im Ordner `c:\Users\Pirat1345\Documents\.workspace\port-music-v2\IPA` und führe aus:
   ```bash
   git init
   git add .
   git commit -m "Initial: Octave iOS with Port-Music backend integration"
   git branch -M main
   git remote add origin https://github.com/<DEIN-GITHUB-NUTZERNAME>/port-music-ios.git
   git push -u origin main
   ```

### Schritt 2: Build auf GitHub beobachten & IPA herunterladen
1. Gehe in deinem GitHub-Repository auf den Reiter **Actions**.
2. Der Workflow **"Build Octave iOS IPA"** startet automatisch auf einem macOS-Runner.
3. Nach ca. 2 bis 3 Minuten ist der Build erfolgreich abgeschlossen (grünes Häkchen).
4. Klicke auf den Workflow-Lauf und lade unter **Artifacts** die Datei **`Octave-iOS-IPA`** (ZIP) herunter.
5. Entpacke die ZIP-Datei, um die fertige **`Octave.ipa`** zu erhalten.

### Schritt 3: Mit Sideloadly auf dem iPhone installieren
1. Schließe dein iPhone per USB-Kabel an deinen Windows-PC an.
2. Starte **[Sideloadly](https://sideloadly.io/)**.
3. Ziehe die Datei `Octave.ipa` per Drag & Drop in das Sideloadly-Fenster.
4. Gib deine normale Apple-ID ein und klicke auf **Start**.
5. Nach wenigen Sekunden ist die App auf deinem iPhone installiert!
6. Auf dem iPhone einmalig unter *Einstellungen > Allgemein > VPN und Geräteverwaltung* deiner Apple-ID vertrauen.
7. Starte die Octave-App, melde dich mit deinem Benutzerkonto an und teste das Streaming! 🎉

---

## 🛠️ Lokale Entwicklung auf einem Mac (Optional)
Falls du einen Mac besitzt:
1. Öffne `Octave.xcodeproj` in Xcode (ab Version 16.0).
2. Wähle dein iPhone als Zielgerät aus und drücke `Cmd + R`.
