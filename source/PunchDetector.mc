using Toybox.Math;

// Hittar slag i accelerometerströmmen och räknar ut en egenskapsvektor per slag.
//
// Algoritm (per sampel, milli-g):
//   mag = sqrt(x² + y² + z²)            (≈1000 i vila p.g.a. gravitationen)
//   viloläge  -> mag > tröskel           => slag börjar, följ toppen
//   i topp    -> nytt max                => flytta toppen
//             -> POST sampel efter max    => slag klart, räkna egenskaper
//   spärrtid  -> REFRACT sampel efter max => tillbaka till vila
//
// Egenskaper (10 st), fönster = PRE sampel före toppen + POST efter:
//   0-2  medel x,y,z före toppen (g)      - handledens orientering/rörelseriktning
//   3-5  x,y,z i toppen / |toppen|        - riktning på toppaccelerationen
//   6    |toppen| (g)                     - kraft
//   7-9  medel |Δx|,|Δy|,|Δz| i fönstret (g) - vilken axel rörelsen sker längs
class PunchDetector {

    const BUF = 32;

    hidden var _bx;
    hidden var _by;
    hidden var _bz;
    hidden var _bm;
    hidden var _n = 0;
    hidden var _th;
    hidden var _pre;
    hidden var _post;
    hidden var _refract;
    hidden var _state = 0;
    hidden var _peakIdx = 0;
    hidden var _peakMag = 0.0;
    hidden var _cb;

    // callback: Method som tar (features as Array<Float>)
    function initialize(sampleRate, thresholdMg, callback) {
        _bx = new [BUF];
        _by = new [BUF];
        _bz = new [BUF];
        _bm = new [BUF];
        for (var i = 0; i < BUF; i++) {
            _bx[i] = 0;
            _by[i] = 0;
            _bz[i] = 0;
            _bm[i] = 0.0;
        }
        _th = thresholdMg;
        _pre = max((sampleRate * 8 + 12) / 25, 3);       // ≈320 ms
        _post = max((sampleRate * 3 + 12) / 25, 1);      // ≈120 ms
        _refract = max((sampleRate * 3 + 5) / 10, 2);    // ≈300 ms
        if (_refract <= _post) {
            _refract = _post + 1;
        }
        _cb = callback;
    }

    hidden function max(a, b) {
        return a > b ? a : b;
    }

    function setThreshold(mg) {
        _th = mg;
    }

    function addSamples(xs, ys, zs) {
        var n = xs.size();
        if (ys.size() < n) { n = ys.size(); }
        if (zs.size() < n) { n = zs.size(); }
        for (var i = 0; i < n; i++) {
            addSample(xs[i], ys[i], zs[i]);
        }
    }

    function addSample(x, y, z) {
        var m = Math.sqrt(x * x + y * y + z * z);
        var k = _n % BUF;
        _bx[k] = x;
        _by[k] = y;
        _bz[k] = z;
        _bm[k] = m;
        var i = _n;
        _n++;

        if (_state == 0) {
            if (m > _th) {
                _state = 1;
                _peakIdx = i;
                _peakMag = m;
            }
        } else if (_state == 1) {
            if (m > _peakMag) {
                _peakMag = m;
                _peakIdx = i;
            } else if (i - _peakIdx >= _post) {
                if (_peakIdx >= _pre) {
                    _cb.invoke(features());
                }
                _state = 2;
            }
        }
        if (_state == 2 && i - _peakIdx >= _refract) {
            _state = 0;
        }
    }

    hidden function features() {
        var p = _peakIdx;
        var sx = 0.0;
        var sy = 0.0;
        var sz = 0.0;
        for (var j = p - _pre; j < p; j++) {
            var k = j % BUF;
            sx += _bx[k];
            sy += _by[k];
            sz += _bz[k];
        }
        sx = sx / _pre / 1000.0;
        sy = sy / _pre / 1000.0;
        sz = sz / _pre / 1000.0;

        var kp = p % BUF;
        var pm = _bm[kp];
        if (pm < 1.0) {
            pm = 1.0;
        }
        var dx = _bx[kp] / pm;
        var dy = _by[kp] / pm;
        var dz = _bz[kp] / pm;

        var jx = 0.0;
        var jy = 0.0;
        var jz = 0.0;
        for (var j = p - _pre + 1; j <= p + _post; j++) {
            var a = j % BUF;
            var b = (j - 1) % BUF;
            jx += absv(_bx[a] - _bx[b]);
            jy += absv(_by[a] - _by[b]);
            jz += absv(_bz[a] - _bz[b]);
        }
        var cnt = (_pre + _post) * 1000.0;
        return [sx, sy, sz, dx, dy, dz, pm / 1000.0, jx / cnt, jy / cnt, jz / cnt];
    }

    hidden function absv(v) {
        return v < 0 ? -v : v;
    }
}
