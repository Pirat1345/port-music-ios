# Port Music iOS

Native iOS-App fuer Port Music, entwickelt in SwiftUI mit OLED-Dark-Design.

## Aufbau

```
IPA/
├── PortMusic/
│   ├── PortMusicApp.swift        # App Entry Point (@main)
│   ├── ServerSetupView.swift     # Server-IP Eingabe & Verifikation
│   ├── ServerPingService.swift   # Netzwerk-Ping & URL-Normalisierung
│   ├── PortTheme.swift           # OLED-Farbschema (#000000, Glassmorphism)
│   ├── Info.plist                # App-Konfiguration & ATS-Freigabe
│   └── Assets.xcassets/          # AppIcon & PortLogo
├── PortMusic.xcodeproj/          # Xcode-Projektdatei & Schema
├── project.yml                   # Deklarative XcodeGen-Konfiguration
└── .github/workflows/build.yml   # GitHub Actions CI fuer automatischen IPA-Build
```

## Erster Schritt: Server-IP Eingabe & Ping
Beim ersten Start fordert die App den Nutzer auf, die Server-IP oder Domain einzugeben.
Beim Klick auf "Weiter":
1. Die Eingabe wird normalisiert (automatische Ergaenzung von `http://`, Bereinigung von Schraegstrichen).
2. Ein asynchroner Ping prueft die Erreichbarkeit des Servers (`/api/health`, `/api/state`).
3. Bei erfolgreicher Rueckmeldung wird die Latenz angezeigt und der Server fuer die naechsten Schritte gespeichert.
4. Bei Verbindungsfehlern erhaelt der Nutzer eine praezise Rueckmeldung (Zeitueberschreitung, Verbindung abgelehnt etc.).
