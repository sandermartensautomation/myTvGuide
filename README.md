# TV Gids (tvOS + Android TV)

EPG-raster voor 11 Vlaamse zenders met doorschakelen naar VTM GO, GoPlay en VRT MAX. Specificatie: [planning.md](planning.md).

## Structuur
- `pipeline/` – `channels.json` (zenders, bron-ID's, schemes, logo's), `make_channels_xml.py` (channels.xml voor iptv-org/epg), `convert.py` (XMLTV→JSON), `tests/`
- `shared/palette.json` – kleurenparen + toewijzingsregels (identiek op beide platforms)
- `docs/` – `schema.json`, `sample.json` (fictief), `logos/`; wordt gepubliceerd via GitHub Pages
- `scripts/make_sample.py` – genereert `docs/sample.json` rond het huidige tijdstip
- `tvos/`, `androidtv/` – native apps
- `.github/workflows/` – dagelijkse data-sync (03:00 UTC)

## Sample-data vernieuwen
```
python3 scripts/make_sample.py
```

## Pipeline
```
python3 -m unittest discover -s pipeline/tests -v
python3 pipeline/convert.py guide.xml pipeline/channels.json guide.json
```
De workflow `.github/workflows/sync-epg.yml` draait dagelijks om 03:00 UTC en publiceert `guide.json`, `schema.json` en `logos/` naar GitHub Pages. Bij een mislukte grab of lege zender faalt de workflow en blijft de vorige publicatie staan.

**Eenmalig:** GitHub repo → Settings → Pages → Source: *GitHub Actions*.

## tvOS
```
cd tvos && xcodegen generate     # genereert TvGids.xcodeproj uit project.yml
open TvGids.xcodeproj
xcodebuild -project TvGids.xcodeproj -scheme TvGids -destination 'platform=tvOS Simulator,name=Apple TV' test
```
`channels.json` en `palette.json` worden direct uit `pipeline/` en `shared/` in de app gebundeld.

VRT MAX wordt op bundle-ID (`be.vrt.vrtnu`) geopend via een privé-API, omdat de tvOS-app geen URL-scheme heeft. Fijn voor eigen installaties via Xcode; een App Store-build wordt daarop afgekeurd.
