using Toybox.Graphics;
using Toybox.System;
using Toybox.WatchUi;

var gCalibMenu = null;

// Meny: välj vilken slagtyp som ska kalibreras.
module CalibMenu {

    function subLabel(c) {
        var n = Classifier.calibratedCount(c);
        return n > 0 ? ("Sparad, " + n + " st") : "Ej kalibrerad";
    }

    function push() {
        var m = new WatchUi.Menu2({:title => "Kalibrera"});
        for (var c = 0; c < Config.NUM_CLASSES; c++) {
            m.addItem(new WatchUi.MenuItem(Config.CLASS_NAMES[c], subLabel(c), c, {}));
        }
        $.gCalibMenu = m;
        WatchUi.pushView(m, new CalibMenuDelegate(), WatchUi.SLIDE_LEFT);
    }

    function refresh() {
        var m = $.gCalibMenu;
        if (m != null) {
            for (var c = 0; c < Config.NUM_CLASSES; c++) {
                var i = m.findItemById(c);
                if (i >= 0) {
                    m.getItem(i).setSubLabel(subLabel(c));
                }
            }
        }
        MainMenu.refresh();
    }
}

class CalibMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var s = new CalibSession(item.getId());
        WatchUi.pushView(new CalibView(s), new CalibDelegate(s), WatchUi.SLIDE_LEFT);
    }

    function onBack() {
        $.gCalibMenu = null;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Samlar egenskapsvektorer för en slagtyp.
class CalibSession {

    // phase: 0 = redo, 1 = spelar in, 2 = sparad, 3 = för få slag
    var cls;
    var phase = 0;
    var samples = [];
    var lastMag = 0.0;
    hidden var _detector;

    function initialize(c) {
        cls = c;
        _detector = new PunchDetector(Sensors.sampleRate(), Config.threshold(), method(:onPunch));
    }

    function start() {
        samples = [];
        phase = 1;
        System.println("CAL_START," + cls + "," + Config.CLASS_NAMES[cls] + ",th=" + Config.threshold() + ",hz=" + Sensors.sampleRate());
        Sensors.start(_detector);
        Util.vibrate(300);
    }

    function cancel() {
        Sensors.stop();
        phase = 0;
        samples = [];
    }

    function finish() {
        Sensors.stop();
        if (samples.size() < Config.MIN_CALIB) {
            phase = 3;
            Util.vibrate(600);
            return;
        }
        Classifier.saveNorm(cls, Classifier.buildNorm(samples));
        phase = 2;
        Util.vibrate(150);
        CalibMenu.refresh();
    }

    function onPunch(f) {
        if (phase != 1) {
            return;
        }
        samples.add(f);
        lastMag = f[6];
        // En rad per slag i loggfilen, för analys på datorn (tools/analyze_log.py).
        System.println("F," + cls + "," + Util.join(f));
        WatchUi.requestUpdate();
    }
}

class CalibView extends WatchUi.View {

    hidden var _s;

    function initialize(session) {
        View.initialize();
        _s = session;
    }

    function hint(c) {
        if (c == Config.CLASS_BG) {
            return ["Rör dig utan att slå:", "studsa, gardera, pendla"];
        }
        return ["Slå 15-30 st " + Config.CLASS_NAMES[c].toLower(), "med klockarmen"];
    }

    function onUpdate(dc) {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;
        var C = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 0.18, Graphics.FONT_SMALL, Config.CLASS_NAMES[_s.cls], C);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var p = _s.phase;
        if (p == 0) {
            var h = hint(_s.cls);
            dc.drawText(cx, H * 0.42, Graphics.FONT_XTINY, h[0], C);
            dc.drawText(cx, H * 0.52, Graphics.FONT_XTINY, h[1], C);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.72, Graphics.FONT_TINY, "START = börja", C);
        } else if (p == 1) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.30, Graphics.FONT_XTINY, "REC - spelar in", C);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.50, Graphics.FONT_NUMBER_HOT, _s.samples.size().toString(), C);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.67, Graphics.FONT_XTINY, "topp " + _s.lastMag.format("%.1f") + " g", C);
            dc.drawText(cx, H * 0.80, Graphics.FONT_XTINY, "START = spara  BACK = avbryt", C);
        } else if (p == 2) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.45, Graphics.FONT_SMALL, "Sparat!", C);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.58, Graphics.FONT_TINY, _s.samples.size().toString() + " slag", C);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.75, Graphics.FONT_XTINY, "START = gör om", C);
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.45, Graphics.FONT_SMALL, "För få slag", C);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.58, Graphics.FONT_XTINY, "minst " + Config.MIN_CALIB + " - prova högre", C);
            dc.drawText(cx, H * 0.66, Graphics.FONT_XTINY, "känslighet", C);
            dc.drawText(cx, H * 0.78, Graphics.FONT_XTINY, "START = försök igen", C);
        }
    }
}

class CalibDelegate extends WatchUi.BehaviorDelegate {

    hidden var _s;

    function initialize(session) {
        BehaviorDelegate.initialize();
        _s = session;
    }

    // Pekskärm (epix 2): ignorera tryck så att slag mot skärmen inte pausar.
    function onTap(evt) {
        return true;
    }

    function onSelect() {
        if (_s.phase == 1) {
            _s.finish();
        } else {
            _s.start();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_s.phase == 1) {
            _s.cancel();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
