# Functional Specification: TV Gids App (Apple TV & Google TV)

## 1. Algemeen & Doel
Een gestroomlijnde TV-gids applicatie voor tvOS (Apple TV) en Android TV / Google TV. Gebruikers zien een horizontaal EPG-raster en kunnen bij het selecteren van een programma direct doorschakelen naar de bijbehorende streaming-app.

## 2. Kanalen & App Mapping
De gids bevat de volgende 11 zenders, gekoppeld aan hun respectievelijke apps en deep link schemes:

| Zender | Bron-ID (Telenet EPG) | Doel-app | Deep Link Scheme |
|---|---|---|---|
| VTM | VTM.be | VTM GO | `vtmgo://` |
| VTM 2 | VTM2.be | VTM GO | `vtmgo://` |
| VTM 3 | VTM3.be | VTM GO | `vtmgo://` |
| VTM 4 | VTM4.be | VTM GO | `vtmgo://` |
| VTM Gold | VTMGold.be | VTM GO | `vtmgo://` |
| Play4 | Play4.be | GoPlay / Play | `goplay-app://` |
| Play5 | Play5.be | GoPlay / Play | `goplay-app://` |
| Play6 | Play6.be | GoPlay / Play | `goplay-app://` |
| Play7 | Play7.be | GoPlay / Play | `goplay-app://` |
| VRT 1 | VRT1.be | VRT MAX | bundle-ID `be.vrt.vrtnu` (zie noot) |
| VRT Canvas | VRTCanvas.be | VRT MAX | bundle-ID `be.vrt.vrtnu` (zie noot) |

**Noot VRT MAX:** de tvOS-app heeft geen URL-scheme (`vrtmax://`, `vrtnu://` en varianten getest) en reageert niet op universal links. De gids opent VRT MAX daarom op bundle-ID via de privé-API `LSApplicationWorkspace` (`PrivateLauncher.swift`); de kijker kiest daarna zelf de zender. Dit werkt voor eigen installaties via Xcode, niet voor een App Store-release.

## 3. Data Pipeline & Backend
- **Bron:** Data wordt opgehaald uit de repository `iptv-org/epg` (site: `telenet.tv`).
- **Cron Job:** Een dagelijkse GitHub Action (elke nacht om 03:00 UTC) haalt de nieuwste XMLTV-data op, converteert deze naar een geoptimaliseerd JSON-formaat en publiceert deze op GitHub Pages (of CDN).
- **Client Sync:** Bij het starten/ontwaken van de app controleert de frontend of de lokale caching up-to-date is en haalt zo nodig de nieuwste JSON op.

## 4. Frontend & TV Interface (D-Pad compatible)
- **Vaste Kolom:** De linker-kolom staat vast tijdens horizontaal scrollen en bevat het zenderlogo + zendernaam.
- **Tijdgrid & Focus:**
  - Horizontale tijdsbalk bovenaan met intervallen van 30 minuten (bijv. 00:00, 00:30, 01:00).
  - Het zichtbare tijdsvenster omvat precies **3 uur**.
  - **Focusbeheer:** Bij het openen van de app staat de focus automatisch op het **huidige live-programma van de eerste zender** (VTM).
- **'Nu-lijn' & Visualisatie:**
  - De **'Nu-lijn'** markeert het exacte huidige tijdstip.
  - Programma-blokken *links* van de Nu-lijn (verleden) gebruiken de basiskleur.
  - Programma-blokken *rechts* van de Nu-lijn (toekomst) gebruiken de lichtere variant van de kleur.
  - **Overlappende programma's:** Wanneer een programma deels voor en deels na de Nu-lijn valt, wordt het programmablok **visueel in tweeën gesplitst**: het linkergedeelte krijgt de verleden-kleur en het rechtergedeelte de toekomst-kleur.
- **Kleurenschema:**
  Programma's krijgen deterministisch een van onderstaande 5 kleurenparen toegewezen (gebaseerd op programmacontext, zodat herladen dezelfde kleur geeft). Aangrenzende programma's mogen nooit hetzelfde kleurenpaar hebben:

  | Palet Optie | Verleden (Links van Nu-lijn) | Toekomst (Rechts van Nu-lijn) |
  |---|---|---|
  | **1. Soft Blue** | `#B9D9F3` | `#D0E2EF` |
  | **2. Soft Lavender** | `#B3B1E8` | `#CFCEEC` |
  | **3. Soft Peach** | `#F3D3C6` | `#F0DED7` |
  | **4. Soft Coral** | `#FAB9AC` | `#F7D3CC` |
  | **5. Soft Sage** | `#B4D7C8` | `#CDE1D9` |

- **Detailvenster (Onderaan het scherm):**
  - Update direct wanneer de focus (D-pad afstandsbediening) verandert.
  - **Eyebrow:** Zendernaam | Starttijd - Eindtijd (bijv. "VRT 1 | 20:35 - 21:25")
  - **Titel:** Titel van het geselecteerde programma
  - **Beschrijving:** Korte inhoud/synopsis van het programma

## 5. Interactie & App Launching
- **Deep Linking:** Bij het klikken/selecteren van een programma opent de app het betreffende URI scheme (`vtmgo://`, `goplay-app://` of `vrtmax://`).
- **Fallback:** Als de target-app niet is geïnstalleerd op het toestel (tvOS of Android TV), verschijnt er een melding op het scherm met een optie/directe link om de betreffende app te downloaden in de App Store of Google Play Store.
