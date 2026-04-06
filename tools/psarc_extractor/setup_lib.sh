#!/usr/bin/env bash
# tools/psarc_extractor/setup_lib.sh
# Downloads iminashi/Rocksmith2014.NET source into tools/psarc_extractor/lib/
# Called by `make setup` – lib/ is gitignored.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

RS_VERSION="main"
RS_URL="https://github.com/iminashi/Rocksmith2014.NET/archive/refs/heads/${RS_VERSION}.zip"
TMP_ZIP="/tmp/rs2014net.zip"
TMP_DIR="/tmp/Rocksmith2014.NET-${RS_VERSION}"

echo "[setup] Downloading Rocksmith2014.NET (${RS_VERSION}) …"
wget -q "$RS_URL" -O "$TMP_ZIP"
rm -rf "$TMP_DIR"
unzip -q "$TMP_ZIP" -d /tmp

echo "[setup] Installing to $LIB_DIR …"
rm -rf "$LIB_DIR"
mkdir -p "$LIB_DIR"

for pkg in Rocksmith2014.FSharpExtensions \
           Rocksmith2014.Common \
           Rocksmith2014.PSARC \
           Rocksmith2014.SNG; do
    cp -r "$TMP_DIR/src/$pkg" "$LIB_DIR/"
done

# Copy solution-level build/package props (required for Central Package Management)
cp "$TMP_DIR/Directory.Build.props" "$LIB_DIR/"
cp "$TMP_DIR/Directory.Packages.props" "$LIB_DIR/"

echo "[setup] Applying build compatibility patches …"
python3 - <<'PYEOF'
import pathlib, re, sys

lib = pathlib.Path(sys.argv[0]).resolve().parent / "lib"
# Script is run inline so lib is relative to $LIB_DIR set in bash
import os
lib = pathlib.Path(os.environ.get("LIB_DIR", lib))

FSPROJ_FILES = list(lib.rglob("*.fsproj"))

for fsproj in FSPROJ_FILES:
    text = fsproj.read_text()

    # 1. Remove bare <PackageReference Include="FSharp.Core" /> to avoid
    #    duplicate-reference error (SDK includes it implicitly; CPM pins the version).
    text = re.sub(r'\s*<PackageReference Include="FSharp\.Core"\s*/>\n', '\n', text)

    # 2. Ensure LangVersion=latest so backgroundTask {} and $"" work.
    if '<LangVersion>' not in text:
        text = text.replace(
            '<TargetFramework>net10.0</TargetFramework>',
            '<TargetFramework>net10.0</TargetFramework>\n    <LangVersion>latest</LangVersion>'
        )
    fsproj.write_text(text)

# 3. FSharpExtensions needs FSharp.Core from CPM (no other packages listed).
ext_fsproj = lib / "Rocksmith2014.FSharpExtensions" / "Rocksmith2014.FSharpExtensions.fsproj"
text = ext_fsproj.read_text()
if '<PackageReference Include="FSharp.Core"' not in text:
    text = text.replace('</Project>', '''\
  <ItemGroup>
    <PackageReference Include="FSharp.Core" />
  </ItemGroup>

</Project>''')
    ext_fsproj.write_text(text)

# 4. Common needs explicit FSharp.Core reference so CPM can resolve the version.
common_fsproj = lib / "Rocksmith2014.Common" / "Rocksmith2014.Common.fsproj"
text = common_fsproj.read_text()
if '<PackageReference Include="FSharp.Core"' not in text:
    text = text.replace(
        '<PackageReference Include="FSharp.SystemTextJson"',
        '<PackageReference Include="FSharp.Core" />\n    <PackageReference Include="FSharp.SystemTextJson"'
    )
    common_fsproj.write_text(text)

print("[setup] Patches applied.")
PYEOF

rm -f "$TMP_ZIP"
echo "[setup] Done. Run 'make ext' to build the extractor."
