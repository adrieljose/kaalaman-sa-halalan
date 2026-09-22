"""Patch ONLY a string constant in the verified September 8 production pack.

Godot format references: core/io/file_access_pack.cpp and
modules/gdscript/gdscript_tokenizer_buffer.cpp. No game re-export is performed.
"""
import hashlib
import json
import re
import struct
import shutil
import sys
from pathlib import Path
import zstandard

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "build/web"
OUT = ROOT / "output/chapter3_patch_notes"

def directory(blob):
    assert blob[:4] == b"GDPC"
    assert struct.unpack_from("<I", blob, 4)[0] == 4
    assert struct.unpack_from("<I", blob, 20)[0] == 2
    base, offset = struct.unpack_from("<QQ", blob, 24)
    count = struct.unpack_from("<I", blob, offset)[0]
    cursor = offset + 4
    entries = {}
    for _ in range(count):
        length = struct.unpack_from("<I", blob, cursor)[0]
        cursor += 4
        name = blob[cursor:cursor + length].rstrip(b"\0").decode()
        cursor += length
        start, size = struct.unpack_from("<QQ", blob, cursor)
        digest = blob[cursor + 16:cursor + 32]
        flags = struct.unpack_from("<I", blob, cursor + 32)[0]
        assert flags == 0
        content = blob[base + start:base + start + size]
        assert hashlib.md5(content).digest() == digest, name
        entries[name] = (content, cursor)
        cursor += 36
    return entries, base, offset

def unpack_script(blob):
    assert blob[:4] == b"GDSC"
    size = struct.unpack_from("<I", blob, 8)[0]
    contents = zstandard.ZstdDecompressor().decompress(blob[12:], max_output_size=size) if size else blob[12:]
    assert not size or len(contents) == size
    return contents

def notes_constant(contents):
    marker = b"[center][color=#6f211b][font_size=12][b]WHAT'S NEW"
    assert contents.count(marker) == 1
    pos = contents.index(marker)
    kind, size = struct.unpack_from("<II", contents, pos - 8)
    assert kind == 4  # Godot Variant::STRING, UTF-8 bytes followed by 4-byte padding.
    return pos - 8, pos + size + (-size % 4), contents[pos:pos + size].decode()

def inspect():
    pack = (SOURCE / "index.pck").read_bytes()
    assert hashlib.sha1(pack).hexdigest() == "022c7cafc0cc869d20a52f1ce06895b30e0b0954"
    entries, _, _ = directory(pack)
    target = next(name for name in entries if name.endswith("/main_menu.gdc"))
    contents = unpack_script(entries[target][0])
    _, _, notes = notes_constant(contents)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "previous_notes.txt").write_text(notes, encoding="utf-8")
    print(json.dumps({"entries": len(entries), "menu": target,
        "chapter3_icons": sum("skill_icons/chapter3/" in k and k.endswith(".import") for k in entries),
        "chapter3_audio_paths": [k for k in entries if "chapter3" in k and (".ogg" in k or ".wav" in k)][:8],
        "chapter3_resources": [k for k in entries if "data/enemies/ch3_" in k]}, indent=2))
    print(notes[:160])

def build():
    inspect()
    source_text = (ROOT / "scripts/main_menu.gd").read_text(encoding="utf-8")
    new_notes = re.search(r'const PATCH_NOTES_COPY := """(.*?)"""', source_text, re.S)[1]
    pack = (SOURCE / "index.pck").read_bytes()
    entries, base, offset = directory(pack)
    target = "scripts/main_menu.gdc"
    original_script, entry_offset = entries[target]
    contents = unpack_script(original_script)
    start, end, old_notes = notes_constant(contents)
    assert "Chapter 3 — Provincial Capitol" not in old_notes
    assert new_notes[new_notes.index('[color=#234c63][font_size=15][b]v1.3'): ] == old_notes[old_notes.index('[color=#234c63][font_size=15][b]v1.3'): ]
    encoded = new_notes.encode("utf-8")
    replacement = struct.pack("<II", 4, len(encoded)) + encoded + bytes(-len(encoded) % 4)
    revised = contents[:start] + replacement + contents[end:]
    script = original_script[:8] + struct.pack("<I", len(revised)) + zstandard.ZstdCompressor(level=9).compress(revised)
    assert unpack_script(script) == revised
    # Preserve every other resource byte-for-byte; append the new script before
    # the directory, redirect only its single entry, and retain the old payload.
    payload = pack[:offset] + script
    payload += bytes(-len(payload) % 16)
    new_offset = len(payload)
    result = bytearray(payload + pack[offset:])
    struct.pack_into("<Q", result, 32, new_offset)
    new_entry_offset = new_offset + entry_offset - offset
    struct.pack_into("<QQ", result, new_entry_offset, offset - base, len(script))
    result[new_entry_offset + 16:new_entry_offset + 32] = hashlib.md5(script).digest()
    revised_entries, _, _ = directory(result)
    assert entries.keys() == revised_entries.keys()
    changed = [k for k in entries if entries[k][0] != revised_entries[k][0]]
    assert changed == [target]
    check = unpack_script(revised_entries[target][0])
    a, b, copied = notes_constant(check)
    assert copied == new_notes
    assert check[:a] == contents[:start] and check[b:] == contents[end:]
    stage = OUT / "site"
    assert not stage.exists(), "Do not overwrite an existing release staging directory"
    stage.mkdir()
    expected = {
        "index.apple-touch-icon.png": "0325f543f236c8c84d56b90ce7b0d095d2a6caeb",
        "index.audio.position.worklet.js": "006bd6de7d9b8a8cc7bb50764861538256f125ce",
        "index.audio.worklet.js": "fa4ddbcecba3dbaefaf6722b9af8e9964d42a1df",
        "index.html": "9c3753d914bab41bcc1623097fd4bdf05b14fd0e",
        "index.icon.png": "4243ae46c34f7781b029a29f262db0c40ec5729a",
        "index.js": "b263ebc082b302b8f2eb5674a3e851401d1faf39",
        "index.pck": "022c7cafc0cc869d20a52f1ce06895b30e0b0954",
        "index.png": "110005335350cda331d8cf2bd259dd92d8f39c72",
        "index.wasm": "2eef1dfa9471ed1745c58d442ed62b9925eab2ce",
        "vercel.json": "150575a2cb046a0ef8307347759bf0e78305430a",
    }
    for name, sha in expected.items():
        data = (SOURCE / name).read_bytes()
        assert hashlib.sha1(data).hexdigest() == sha, name
        shutil.copy2(SOURCE / name, stage / name)
    (stage / "index.pck").write_bytes(result)
    html = (stage / "index.html").read_bytes()
    old_size = ('"index.pck":' + str(len(pack))).encode()
    assert html.count(old_size) == 1
    (stage / "index.html").write_bytes(html.replace(old_size, ('"index.pck":' + str(len(result))).encode()))
    (stage / ".vercel").mkdir()
    shutil.copy2(SOURCE / ".vercel/project.json", stage / ".vercel/project.json")
    report = {"source_deployment": "dpl_HZbbk7ymGdPRHgcJz33KkKzik9S9",
        "verified_source_files": expected, "packed_resources": len(entries),
        "changed_resources": changed, "only_notes_literal_changed": True,
        "other_resources_unchanged": len(entries) - 1,
        "html_change": "PCK download size only", "new_pck_size": len(result)}
    (OUT / "isolation_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (OUT / "published_notes.txt").write_text(new_notes, encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    build() if "--build" in sys.argv else inspect()
