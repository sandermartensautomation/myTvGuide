import sys
import xml.etree.ElementTree as ET
from datetime import datetime

TITEL = "Geen uitzending"
BESCHRIJVING = "geen uitzending"
MIN_GAT_SECONDEN = 60  # kleinere gaten zijn afrondingsruis


def parse(s):
    s = s.strip()
    if " " in s:
        return datetime.strptime(s, "%Y%m%d%H%M%S %z")
    return datetime.strptime(s[:14], "%Y%m%d%H%M%S")


def main(pad):
    tree = ET.parse(pad)
    root = tree.getroot()

    per_zender = {}
    for p in root.findall("programme"):
        per_zender.setdefault(p.get("channel"), []).append(p)

    toegevoegd = 0
    for zender, progs in per_zender.items():
        progs.sort(key=lambda p: parse(p.get("start")))
        for vorige, volgende in zip(progs, progs[1:]):
            einde = parse(vorige.get("stop"))
            begin = parse(volgende.get("start"))
            if (begin - einde).total_seconds() < MIN_GAT_SECONDEN:
                continue
            nieuw = ET.Element("programme", {
                "start": vorige.get("stop"),
                "stop": volgende.get("start"),
                "channel": zender,
            })
            titel = ET.SubElement(nieuw, "title", {"lang": "nl"})
            titel.text = TITEL
            desc = ET.SubElement(nieuw, "desc", {"lang": "nl"})
            desc.text = BESCHRIJVING
            idx = list(root).index(vorige)
            root.insert(idx + 1, nieuw)
            toegevoegd += 1

    tree.write(pad, encoding="utf-8", xml_declaration=True)
    print(f"{toegevoegd} gaten opgevuld met '{TITEL}'")


if __name__ == "__main__":
    main(sys.argv[1])
