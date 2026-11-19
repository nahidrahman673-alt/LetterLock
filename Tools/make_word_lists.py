"""Builds the app's word lists in LetterLock/WordLists/.

Each output line is one thing (a city, a film, a person...), best known first: its main name, then other
names it goes by, separated by spaces. Names are already in match form (see `key`, which must stay in
step with `WordList.normalized` in the app): "St. Louis" is written "saintlouis".

    python3 -I Tools/make_word_lists.py hand
        animals.txt and food.txt from the hand-written lists in Tools/word_sources/.
    python3 -I Tools/make_word_lists.py cities cities15000.txt
        cities.txt from GeoNames (geonames.org, CC BY 4.0: the app must credit it).
    python3 -I Tools/make_word_lists.py names male.csv female.csv unisex.csv
        boys.txt and girls.txt from Wikidata first names (CC0). Unisex names go on both.
    python3 -I Tools/make_word_lists.py wikidata movies|celebrities|brands results.csv [more.csv ...]
        From Wikidata query results (CC0) with columns item, sitelinks, label, aliases ("|"-separated).
        The queries are in Tools/word_sources/wikidata_queries.md.
"""

import csv
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "LetterLock", "WordLists")
SOURCES = os.path.join(ROOT, "Tools", "word_sources")

# Letters that don't lose their mark when accents are stripped. WordList.swift maps the same ones.
SPECIAL = {"ø": "o", "ł": "l", "ß": "ss", "æ": "ae", "œ": "oe", "đ": "d", "ð": "d", "þ": "th", "ı": "i"}


def plain(text):
    folded = unicodedata.normalize("NFKD", text)
    return "".join(c for c in folded if not unicodedata.combining(c))


def key(name):
    """Lowercase, no accents, "&" read as "and", a leading "The" dropped, "St" read as "Saint",
    then only letters and digits: "The Hague" is "hague", "St. Louis" is "saintlouis"."""
    text = plain(name.lower())
    text = "".join(SPECIAL.get(c, c) for c in text).replace("&", " and ")
    words = ["".join(c for c in w if c.isalnum()) for w in re.split(r"[\s\-]+", text)]
    words = [w for w in words if w]
    if len(words) > 1 and words[0] == "the":
        words.pop(0)
    if words and words[0] == "st":
        words[0] = "saint"
    return "".join(words)


def latin(name):
    """Written in the Latin alphabet (accents fine), so a player could type it on an English keyboard."""
    simple = "".join(SPECIAL.get(c, c) for c in plain(name))
    return bool(simple) and all(ord(c) < 128 for c in simple) and any(c.isalpha() for c in simple)


# GeoNames carries hundreds of spellings per city, including all-lowercase romanisations
# ("an dao er cheng"). Keep other names only if they look like a proper name.
CITY_NAME = re.compile(r"^[A-Z][A-Za-z .'\-]*$")


def city_alias(name):
    simple = plain(name)
    return bool(CITY_NAME.match(simple)) and sum(c.isalpha() for c in simple) >= 4


def write(filename, entries):
    """entries: lists of names, main name first, best known first."""
    lines = []
    for names in entries:
        keys = []
        for name in names:
            k = key(name)
            if k and k not in keys:
                keys.append(k)
        if keys:
            lines.append(" ".join(keys))
    path = os.path.join(OUT, filename)
    with open(path, "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    print(f"{len(lines)} entries written to {os.path.relpath(path, ROOT)}")


def read_hand(filename):
    """A hand-written list: one thing per line, other names after "|", "#" for notes."""
    path = os.path.join(SOURCES, filename)
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as file:
        lines = [line.strip() for line in file]
    return [[part.strip() for part in line.split("|")] for line in lines if line and not line.startswith("#")]


def hand():
    for name in ("animals", "food"):
        write(f"{name}.txt", read_hand(f"{name}.txt"))


def cities(source):
    rows = []
    with open(source, encoding="utf-8") as file:
        for line in file:
            columns = line.rstrip("\n").split("\t")
            name, ascii_name, alternates = columns[1], columns[2], columns[3]
            others = [n for n in [ascii_name, *alternates.split(",")] if n and city_alias(n)]
            rows.append((int(columns[14] or 0), [name, *others]))
    rows.sort(key=lambda row: -row[0])
    write("cities.txt", [names for _, names in rows])


def read_labels(path):
    with open(path, encoding="utf-8") as file:
        return [row[0].strip() for row in csv.reader(file) if row and row[0] != "nLabel"]


def first_name(label):
    # One name ("Jean-Luc" is fine, "Gustaf Wilhelm" is two), Latin letters, not a Wikidata id (Q123).
    return latin(label) and not re.match(r"^Q\d+$", label) and label[0].isupper() and len(label.split()) == 1


def names(male, female, unisex):
    shared = [n for n in read_labels(unisex) if first_name(n)]
    for filename, source in (("boys.txt", male), ("girls.txt", female)):
        seen, entries = set(), []
        for name in [*read_labels(source), *shared]:
            if first_name(name) and key(name) not in seen:
                seen.add(key(name))
                entries.append([name])
        write(filename, entries)


COMPANY_ENDING = re.compile(
    r"(,?\s+(AG|SE|SA|S\.A\.|NV|N\.V\.|plc|PLC|Inc\.?|Ltd\.?|Limited|LLC|GmbH|Corp\.?|Corporation|"
    r"Company|Co\.|Group|Holdings?|International))+$")


def related(alias, label):
    """Brand aliases on Wikidata can be generic ("Fries" for McDonald's fries). Keep one only if it shares
    a word with the main name ("Coca-Cola Hellenic") or is short initials ("IBM")."""
    words = lambda text: {key(w) for w in re.split(r"[\s\-]+", text) if len(key(w)) >= 3}
    return bool(words(alias) & words(label)) or bool(re.match(r"^[A-Z0-9&.]{2,5}$", alias))


def wikidata(kind, sources):
    best = {}
    for source in sources:
        with open(source, encoding="utf-8") as file:
            for row in csv.DictReader(file):
                label = row["label"].strip()
                if not latin(label):
                    continue
                aliases = [a.strip() for a in row.get("aliases", "").split("|") if a.strip() and latin(a)]
                if kind == "brands":
                    aliases = [a for a in aliases if related(a, label)]
                    # "Adidas AG" is typed "Adidas".
                    short = COMPANY_ENDING.sub("", label).strip(" ,")
                    if short and short != label:
                        aliases.insert(0, short)
                sitelinks = int(row["sitelinks"] or 0)
                if row["item"] not in best or sitelinks > best[row["item"]][0]:
                    best[row["item"]] = (sitelinks, [label, *aliases])
    entries = [names for _, names in sorted(best.values(), key=lambda value: -value[0])]
    # Hand-written top-ups (Tools/word_sources/brands_extra.txt...) come first, so their names win.
    write(f"{kind}.txt", read_hand(f"{kind}_extra.txt") + entries)


if __name__ == "__main__":
    command, args = sys.argv[1], sys.argv[2:]
    if command == "hand":
        hand()
    elif command == "cities":
        cities(*args)
    elif command == "names":
        names(*args)
    elif command == "wikidata":
        wikidata(args[0], args[1:])
    else:
        sys.exit(__doc__)
