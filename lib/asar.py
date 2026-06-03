#!/usr/bin/env python3
"""Minimal read-only reader for Electron ASAR archives.

The Antigravity *agent* ships its application code (and its window icon) inside
``resources/app.asar``. The packaging scripts only need two things from it:

    asar.py version <archive>                -> print root package.json "version"
    asar.py extract <archive> <path> <dest>  -> write an archived file to disk

ASAR layout is a tiny binary envelope around a JSON header::

    [u32 =4][u32 header_size][u32 json_pickle_size][u32 json_len][json...][data...]

Every file entry in the JSON header records a byte ``offset`` (relative to the
start of the data section) and a ``size``. The data section begins at
``8 + header_size``. That is the whole format - no third-party module required.
"""
import json
import struct
import sys


def _open_index(fileobj):
    """Return ``(index_dict, data_start)`` for an open ASAR file object."""
    # Four little-endian uint32 fields precede the JSON header; the fourth is
    # the exact JSON byte length. The data section starts at 8 + header_size.
    _, header_size, _, json_len = struct.unpack("<IIII", fileobj.read(16))
    index = json.loads(fileobj.read(json_len).decode("utf-8"))
    return index, 8 + header_size


def _lookup(index, archive_path):
    """Walk the header tree to the entry for ``archive_path`` (e.g. ``icon.png``)."""
    node = index
    for part in archive_path.strip("/").split("/"):
        node = node["files"][part]
    return node


def _read(fileobj, data_start, entry):
    fileobj.seek(data_start + int(entry["offset"]))
    return fileobj.read(int(entry["size"]))


def main(argv):
    if len(argv) < 3:
        sys.exit("usage: asar.py version|extract <archive> [path] [dest]")

    op, archive = argv[1], argv[2]
    with open(archive, "rb") as fileobj:
        index, data_start = _open_index(fileobj)

        if op == "version":
            pkg = json.loads(_read(fileobj, data_start, _lookup(index, "package.json")))
            print(pkg["version"])

        elif op == "extract":
            if len(argv) < 5:
                sys.exit("usage: asar.py extract <archive> <path> <dest>")
            data = _read(fileobj, data_start, _lookup(index, argv[3]))
            with open(argv[4], "wb") as out:
                out.write(data)

        else:
            sys.exit("asar.py: unknown operation %r" % op)


if __name__ == "__main__":
    main(sys.argv)
