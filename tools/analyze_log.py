#!/usr/bin/env python3
"""Analysera kalibreringsdata från Slagräknare-loggen och generera Norms.mc.

Klockan skriver en rad per kalibrerat slag till loggfilen:
    F,<klass>,f0,f1,...,f9
(se README för hur du får fram loggfilen via USB).

Användning:
    python3 analyze_log.py SLAGRAKNARE.TXT
    python3 analyze_log.py SLAGRAKNARE.TXT --write-norms ../source/Norms.mc

Skriptet visar:
  * antal slag och medel/std per egenskap och klass
  * leave-one-out-träffsäkerhet med samma klassning som klockan
  * förväxlingsmatris (vilka slag blandas ihop)
Endast standardbiblioteket behövs.
"""
import argparse
import math
import sys

CLASS_NAMES = ["Rakt", "Krok", "Uppercut", "Bakgrund"]
FEATURES = ["medel_x", "medel_y", "medel_z", "topp_dx", "topp_dy", "topp_dz",
            "topp_g", "rörelse_x", "rörelse_y", "rörelse_z"]
SIGMA_FLOOR = 0.12   # samma som Classifier.mc
REJECT = 12.0


def parse(path):
    data = {c: [] for c in range(len(CLASS_NAMES))}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line.startswith("F,"):
                continue
            parts = line.split(",")
            try:
                c = int(parts[1])
                f = [float(v) for v in parts[2:]]
            except ValueError:
                continue
            if c in data and len(f) == len(FEATURES):
                data[c].append(f)
    return data


def build_norm(samples):
    n = len(samples)
    dim = len(samples[0])
    mean = [sum(s[k] for s in samples) / n for k in range(dim)]
    std = [math.sqrt(sum((s[k] - mean[k]) ** 2 for s in samples) / max(n - 1, 1))
           for k in range(dim)]
    return {"m": mean, "s": std, "n": n}


def distance(norm, f):
    tot = 0.0
    for k, v in enumerate(f):
        sd = max(norm["s"][k], SIGMA_FLOOR)
        z = (v - norm["m"][k]) / sd
        tot += z * z
    return tot / len(f)


def classify(norms, f):
    best, best_d = -1, 1e9
    for c, nm in norms.items():
        if nm is None:
            continue
        d = distance(nm, f)
        if d < best_d:
            best, best_d = c, d
    if best >= 0 and best_d > REJECT:
        return -1
    return best


def loo(data):
    """Leave-one-out: klassa varje slag med normer byggda utan just det slaget."""
    classes = [c for c in data if len(data[c]) >= 2]
    conf = {c: {} for c in classes}
    correct = total = 0
    for c in classes:
        for i, f in enumerate(data[c]):
            norms = {}
            for c2 in classes:
                s = data[c2] if c2 != c else data[c2][:i] + data[c2][i + 1:]
                norms[c2] = build_norm(s) if len(s) >= 2 else None
            p = classify(norms, f)
            conf[c][p] = conf[c].get(p, 0) + 1
            correct += (p == c)
            total += 1
    return correct, total, conf, classes


def write_norms(path, norms):
    def arr(v):
        return "[" + ", ".join("%.4f" % x for x in v) + "]"
    lines = [
        "// GENERERAD av tools/analyze_log.py - inbyggda normvärden.",
        "// Används för klasser som inte kalibrerats på klockan.",
        "module Norms {",
        "    const DEFAULTS = [",
    ]
    entries = []
    for c in range(len(CLASS_NAMES)):
        nm = norms.get(c)
        if nm is None:
            entries.append("        null")
        else:
            entries.append('        {"m" => %s,\n         "s" => %s,\n         "n" => %d}  // %s'
                           % (arr(nm["m"]), arr(nm["s"]), nm["n"], CLASS_NAMES[c]))
    # kommatecken måste stå före kommentaren
    fixed = []
    for i, e in enumerate(entries):
        if i < len(entries) - 1:
            if "//" in e:
                head, _, comment = e.rpartition("  //")
                e = head + ",  //" + comment
            else:
                e = e + ","
        fixed.append(e)
    lines += fixed
    lines += ["    ];", "}", ""]
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log", help="loggfil från klockan (GARMIN/APPS/LOGS/<APP>.TXT)")
    ap.add_argument("--write-norms", metavar="NORMS_MC", help="skriv source/Norms.mc")
    args = ap.parse_args()

    data = parse(args.log)
    if not any(data.values()):
        sys.exit("Hittade inga F-rader i loggen. Har du skapat loggfilen innan du kalibrerade?")

    norms = {}
    print("Slag per klass:")
    for c, s in data.items():
        print("  %-9s %4d" % (CLASS_NAMES[c], len(s)))
        norms[c] = build_norm(s) if len(s) >= 2 else None

    print("\nMedel (std) per egenskap:")
    print("  %-10s" % "" + "".join("%17s" % CLASS_NAMES[c] for c in data if norms[c]))
    for k, name in enumerate(FEATURES):
        row = "  %-10s" % name
        for c in data:
            if norms[c]:
                row += "%10.2f (%4.2f)" % (norms[c]["m"][k], norms[c]["s"][k])
        print(row)

    correct, total, conf, classes = loo(data)
    if total:
        print("\nLeave-one-out-träffsäkerhet: %d/%d = %.0f %%" % (correct, total, 100.0 * correct / total))
        cols = classes + [-1]
        print("\nFörväxlingsmatris (rad = verkligt, kolumn = gissat):")
        print("  %-9s" % "" + "".join("%9s" % (CLASS_NAMES[c] if c >= 0 else "Okänt") for c in cols))
        for c in classes:
            print("  %-9s" % CLASS_NAMES[c] + "".join("%9d" % conf[c].get(p, 0) for p in cols))

    if args.write_norms:
        write_norms(args.write_norms, norms)
        print("\nSkrev", args.write_norms)


if __name__ == "__main__":
    main()
