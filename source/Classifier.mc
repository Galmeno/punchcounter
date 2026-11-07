using Toybox.Application.Storage;
using Toybox.System;
using Toybox.Math;
using Toybox.Lang;

// Närmaste-normvärde-klassning med varians per egenskap.
// Varje klass har ett normvärde {"m" => medel[], "s" => std[], "n" => antal}.
// Normer från kalibrering på klockan (Storage) går före inbyggda (Norms.mc).
module Classifier {

    const SIGMA_FLOOR = 0.12;   // minsta std så att få sampel inte ger orimlig vikt
    const REJECT = 12.0;        // medel-z² över detta => "okänt" slag

    function storageKey(c) {
        return "norm" + c;
    }

    function loadNorms() {
        var out = new [Config.NUM_CLASSES];
        for (var c = 0; c < Config.NUM_CLASSES; c++) {
            var v = Storage.getValue(storageKey(c));
            if (v == null) {
                v = Norms.DEFAULTS[c];
            }
            out[c] = v;
        }
        return out;
    }

    function isCalibrated(c) {
        return Storage.getValue(storageKey(c)) != null;
    }

    function calibratedCount(c) {
        var v = Storage.getValue(storageKey(c));
        if (v == null) {
            return 0;
        }
        return (v as Lang.Dictionary)["n"];
    }

    function clearAll() {
        for (var c = 0; c < Config.NUM_CLASSES; c++) {
            Storage.deleteValue(storageKey(c));
        }
    }

    // Returnerar klassindex, eller -1 om inget normvärde passar (okänt slag).
    function classify(norms, f) {
        var best = -1;
        var bestD = 1.0e9;
        for (var c = 0; c < norms.size(); c++) {
            var nm = norms[c];
            if (nm == null) {
                continue;
            }
            var d = distance(nm, f);
            if (d < bestD) {
                bestD = d;
                best = c;
            }
        }
        if (best >= 0 && bestD > REJECT) {
            return -1;
        }
        return best;
    }

    function distance(nm, f) {
        var m = nm["m"];
        var s = nm["s"];
        var sum = 0.0;
        var n = f.size();
        for (var k = 0; k < n; k++) {
            var sd = s[k];
            if (sd < SIGMA_FLOOR) {
                sd = SIGMA_FLOOR;
            }
            var z = (f[k] - m[k]) / sd;
            sum += z * z;
        }
        return sum / n;
    }

    // Räknar ut normvärde från en lista egenskapsvektorer.
    function buildNorm(samples) {
        var n = samples.size();
        var dim = samples[0].size();
        var mean = new [dim];
        var std = new [dim];
        for (var k = 0; k < dim; k++) {
            var s = 0.0;
            for (var i = 0; i < n; i++) {
                s += samples[i][k];
            }
            mean[k] = s / n;
        }
        for (var k = 0; k < dim; k++) {
            var v = 0.0;
            for (var i = 0; i < n; i++) {
                var d = samples[i][k] - mean[k];
                v += d * d;
            }
            std[k] = Math.sqrt(v / (n > 1 ? n - 1 : 1));
        }
        return {"m" => mean, "s" => std, "n" => n};
    }

    function saveNorm(c, norm) {
        Storage.setValue(storageKey(c), norm);
        System.println("N," + c + "," + norm["n"] + ",M," + Util.join(norm["m"]) + ",S," + Util.join(norm["s"]));
    }
}
