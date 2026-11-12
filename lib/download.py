#!/usr/bin/env python3
"""Downloads a Node.js runtime into runtimes/NAME/.

Usage: lib/download.py NAME

  nodejs.org      the official build of the current Node.js LTS, 24
  nodejs.org-N    the official build of Node.js N, for example nodejs.org-20
  debian-13       Debian 13's nodejs package, with the packages it depends on

Every download is checked against the checksums published next to it.
"""

import hashlib
import io
import lzma
import os
import platform
import re
import shutil
import sys
import tarfile
import tempfile
import urllib.request

NODEJS_ORG_LTS = 24

DEBIAN_RELEASES = {
    "debian-13": [
        ("https://deb.debian.org/debian", "trixie"),
        ("https://deb.debian.org/debian", "trixie-updates"),
        ("https://deb.debian.org/debian-security", "trixie-security"),
    ],
}

# The C library comes from your system: it has to match the system's dynamic
# loader. corepack is a package manager tool that the examples don't use.
SKIPPED_PACKAGES = {"libc6", "node-corepack"}

# Parts of the packages that node doesn't need.
SKIPPED_PATHS = ("./usr/share/doc/", "./usr/share/man/", "./usr/share/lintian/")


def log(message):
    print(message, file=sys.stderr)


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "node-symlink-resolution"})
    with urllib.request.urlopen(request) as response:
        return response.read()


def fetch_checked(url, sha256):
    data = fetch(url)
    if hashlib.sha256(data).hexdigest() != sha256:
        raise SystemExit(f"Checksum mismatch: {url}")
    return data


def extract(archive, directory, members=None):
    try:
        archive.extractall(directory, members=members, filter="tar")
    except TypeError:  # Python older than 3.12 and without the backport
        archive.extractall(directory, members=members)


def download_nodejs_org(major, target):
    system = {"Linux": "linux", "Darwin": "darwin"}.get(platform.system())
    arch = {"x86_64": "x64", "AMD64": "x64", "aarch64": "arm64", "arm64": "arm64"}.get(platform.machine())
    if not system or not arch:
        raise SystemExit(f"No nodejs.org build for {platform.system()} on {platform.machine()}")

    base = f"https://nodejs.org/dist/latest-v{major}.x"
    checksums = fetch(f"{base}/SHASUMS256.txt").decode()
    sha256, name = next(line.split() for line in checksums.splitlines() if line.endswith(f"-{system}-{arch}.tar.xz"))
    log(f"Downloading {name}")
    tarball = fetch_checked(f"{base}/{name}", sha256)

    with tempfile.TemporaryDirectory(dir=os.path.dirname(target)) as temporary:
        with tarfile.open(fileobj=io.BytesIO(tarball)) as archive:
            extract(archive, temporary)
        os.rename(os.path.join(temporary, name.removesuffix(".tar.xz")), target)


# Comparing Debian package versions, as dpkg does.


def compare_versions(a, b):
    def split(version):
        epoch, _, rest = version.rpartition(":") if ":" in version else ("0", "", version)
        upstream, _, revision = rest.rpartition("-") if "-" in rest else (rest, "", "")
        return int(epoch), upstream, revision

    def order(character):
        if character == "~":
            return -1
        if not character or character.isalpha():
            return ord(character or "\0")
        return ord(character) + 256

    def compare_part(a, b):
        while a or b:
            a_text, b_text = re.match(r"\D*", a).group(), re.match(r"\D*", b).group()
            for i in range(max(len(a_text), len(b_text))):
                difference = order(a_text[i : i + 1]) - order(b_text[i : i + 1])
                if difference:
                    return difference
            a, b = a[len(a_text) :], b[len(b_text) :]
            a_number, b_number = re.match(r"\d*", a).group(), re.match(r"\d*", b).group()
            difference = int(a_number or 0) - int(b_number or 0)
            if difference:
                return difference
            a, b = a[len(a_number) :], b[len(b_number) :]
        return 0

    (a_epoch, a_upstream, a_revision), (b_epoch, b_upstream, b_revision) = split(a), split(b)
    return a_epoch - b_epoch or compare_part(a_upstream, b_upstream) or compare_part(a_revision, b_revision)


def read_package_lists(repositories, architecture):
    """Returns the newest version of every package in the repositories."""
    packages = {}
    for base, suite in repositories:
        url = f"{base}/dists/{suite}/main/binary-{architecture}/Packages.xz"
        log(f"Reading {url}")
        for stanza in lzma.decompress(fetch(url)).decode().split("\n\n"):
            fields = dict(re.findall(r"^([\w-]+): (.*)$", stanza, re.MULTILINE))
            if "Package" not in fields:
                continue
            fields["Base"] = base
            current = packages.get(fields["Package"])
            if current is None or compare_versions(fields["Version"], current["Version"]) > 0:
                packages[fields["Package"]] = fields
    return packages


def with_dependencies(name, packages):
    """Returns the package and every package it depends on."""
    selected, queue = [], [name]
    while queue:
        name = queue.pop(0)
        if name in selected or name in SKIPPED_PACKAGES:
            continue
        selected.append(name)
        fields = packages[name]
        for dependency in (fields.get("Pre-Depends", "") + "," + fields.get("Depends", "")).split(","):
            # Takes the first of any alternatives, without the version.
            alternatives = re.findall(r"([a-z0-9][a-z0-9+.-]+)[^|]*", dependency)
            if alternatives:
                queue.append(next((a for a in alternatives if a in packages), alternatives[0]))
    return selected


def data_tar(deb):
    """Returns the data.tar member of a .deb file, which is an ar archive."""
    position = 8
    while position < len(deb):
        name = deb[position : position + 16].decode().strip().rstrip("/")
        size = int(deb[position + 48 : position + 58])
        content = deb[position + 60 : position + 60 + size]
        position += 60 + size + size % 2
        if name.startswith("data.tar"):
            return tarfile.open(fileobj=io.BytesIO(content))
    raise SystemExit("No data.tar in the package")


def make_builtin_paths_relative(root):
    """Debian's libnode loads a few of Node.js's built-in modules, such as
    acorn and undici, from files in /usr/share/nodejs, and stops at startup if
    they are missing. Their paths are compiled in, for example
    "/usr/share/nodejs/acorn/dist/acorn.js". This turns each one into
    "usr/share/nodejs//acorn/dist/acorn.js", which has the same length and is
    relative to the directory node runs in. Nothing else changes."""
    for directory, _, files in os.walk(os.path.join(root, "usr/lib")):
        for name in files:
            if name.startswith("libnode.so."):
                path = os.path.join(directory, name)
                with open(path, "rb") as library:
                    content = library.read()
                content, count = re.subn(rb"/usr/share/nodejs/(?=[\w@./-]+\.js\0)", b"usr/share/nodejs//", content)
                if count == 0:
                    raise SystemExit(f"No built-in module paths found in {path}")
                with open(path, "wb") as library:
                    library.write(content)
                log(f"Made {count} built-in module paths relative in {name}")


def download_debian(release, target):
    if platform.system() != "Linux":
        raise SystemExit(f"{release} runs on Linux only")
    architecture = {"x86_64": "amd64", "aarch64": "arm64"}.get(platform.machine())
    if not architecture:
        raise SystemExit(f"{release}: unsupported machine {platform.machine()}")

    packages = read_package_lists(DEBIAN_RELEASES[release], architecture)
    with tempfile.TemporaryDirectory(dir=os.path.dirname(target)) as temporary:
        root = os.path.join(temporary, "root")
        for name in with_dependencies("nodejs", packages):
            fields = packages[name]
            log(f"Downloading {name} {fields['Version']}")
            deb = fetch_checked(f"{fields['Base']}/{fields['Filename']}", fields["SHA256"])
            with data_tar(deb) as archive:
                members = [m for m in archive.getmembers() if not (m.name + "/").startswith(SKIPPED_PATHS)]
                extract(archive, root, members)
        make_builtin_paths_relative(root)
        os.rename(root, target)


def main():
    name = sys.argv[1] if len(sys.argv) == 2 else ""
    target = os.path.join("runtimes", name)
    os.makedirs("runtimes", exist_ok=True)
    if match := re.fullmatch(r"nodejs\.org(?:-(\d+))?", name):
        download_nodejs_org(match.group(1) or NODEJS_ORG_LTS, target)
    elif name in DEBIAN_RELEASES:
        download_debian(name, target)
    else:
        log(f"Unknown runtime: {name}. Use nodejs.org, nodejs.org-N or {', '.join(DEBIAN_RELEASES)}.")
        sys.exit(2)


if __name__ == "__main__":
    main()
