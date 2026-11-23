import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

STYLES = {
    "outlined": "round-outlined-radius-2-stroke-2",
    "filled": "round-filled-radius-2-stroke-2",
}
IOS = Path(__file__).resolve().parent.parent
MANIFEST = IOS / "central-icons.txt"
OUTPUT = IOS / "TimeKeeper" / "Assets.xcassets" / "Central"


def read_manifest():
    icons = []
    for line in MANIFEST.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        style, name = line.split()
        if style not in STYLES:
            sys.exit(f"Style inconnu : {style}")
        icons.append((style, name))
    return icons


def asset_name(style, name):
    kebab = re.sub(r"(?<!^)(?=[A-Z])|(?<=[a-z])(?=[0-9])", "-", name[len("Icon"):]).lower()
    return f"central-{kebab}-{style}"


def install(styles, workdir):
    key = os.environ.get("CENTRAL_LICENSE_KEY")
    local = os.environ.get("CENTRAL_ICONS_DIR")
    found = {}
    for style in styles:
        package = STYLES[style]
        if local and (Path(local) / package).is_dir():
            found[style] = Path(local) / package
        elif local and Path(local).name == package:
            found[style] = Path(local)
    missing = [s for s in styles if s not in found]
    if missing and key:
        subprocess.run(
            ["npm", "install", "--no-save", "--no-audit", "--no-fund", "--prefix", str(workdir)]
            + [f"@central-icons-react/{STYLES[s]}" for s in missing],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        for style in missing:
            found[style] = workdir / "node_modules" / "@central-icons-react" / STYLES[style]
    return found


def to_svg(package, name):
    source = json.loads((package / name / "index.mjs.map").read_text())["sourcesContent"][-1]
    match = re.search(r"<CentralIconBase[^>]*>(.*)</CentralIconBase>", source, re.S)
    if not match:
        sys.exit(f"Tracé introuvable pour {name}")
    body = re.sub(r"\b([a-zA-Z]+)(?==)", lambda m: re.sub(r"(?<=[a-z])([A-Z])", lambda c: "-" + c.group(1).lower(), m.group(1)), match.group(1))
    body = body.replace("currentColor", "#000000")
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">{body}</svg>\n'


def main():
    icons = read_manifest()
    with tempfile.TemporaryDirectory() as tmp:
        packages = install({style for style, _ in icons}, Path(tmp))
        if len(packages) < len({style for style, _ in icons}):
            print("Central Icons absents : l'app garde les symboles Apple.")
            shutil.rmtree(OUTPUT, ignore_errors=True)
            return
        shutil.rmtree(OUTPUT, ignore_errors=True)
        OUTPUT.mkdir(parents=True)
        (OUTPUT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
        for style, name in icons:
            asset = asset_name(style, name)
            folder = OUTPUT / f"{asset}.imageset"
            folder.mkdir()
            (folder / f"{asset}.svg").write_text(to_svg(packages[style], name))
            (folder / "Contents.json").write_text(json.dumps({
                "images": [{"filename": f"{asset}.svg", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
                "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
            }, indent=2))
        print(f"{len(icons)} Central Icons générées dans {OUTPUT.relative_to(IOS)}.")


main()
