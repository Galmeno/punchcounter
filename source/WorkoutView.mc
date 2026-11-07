using Toybox.Activity;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class WorkoutView extends WatchUi.View {

    hidden var _w;
    hidden var _timer;

    function initialize(workout) {
        View.initialize();
        _w = workout;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        _w.tick();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;
        var C = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var info = Activity.getActivityInfo();
        var timerMs = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var hr = (info != null) ? info.currentHeartRate : null;

        // Överst: tid
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 0.17, Graphics.FONT_MEDIUM, Util.formatTime(timerMs), C);

        // Status
        if (_w.state == WS.IDLE) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.29, Graphics.FONT_XTINY, "Tryck START", C);
        } else if (_w.state == WS.PAUSED) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.29, Graphics.FONT_XTINY, "PAUS", C);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.29, Graphics.FONT_XTINY, "Rond " + _w.lapNum + "  |  " + _w.lapPunches, C);
        }

        // Mitten: totalt antal slag
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 0.48, Graphics.FONT_NUMBER_HOT, _w.total.toString(), C);

        // Senaste slagtyp (visas 1,5 s)
        if (_w.lastClass != null && System.getTimer() - _w.lastPunchAt < 1500) {
            var name = _w.lastClass >= 0 ? Config.CLASS_NAMES[_w.lastClass] : "Slag";
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 0.64, Graphics.FONT_SMALL, name, C);
        }

        // Fördelning per typ
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var dist;
        if (_w.calibrated) {
            dist = "R " + _w.perClass[0] + "  K " + _w.perClass[1] + "  U " + _w.perClass[2];
            if (_w.unknown > 0) {
                dist += "  ? " + _w.unknown;
            }
        } else {
            dist = "Ej kalibrerad";
        }
        dc.drawText(cx, H * 0.75, Graphics.FONT_XTINY, dist, C);

        // Nederst: puls och slagtakt
        var hrTxt = hr != null ? hr.toString() : "--";
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - W * 0.16, H * 0.86, Graphics.FONT_TINY, hrTxt, C);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + W * 0.16, H * 0.86, Graphics.FONT_TINY, _w.rate().toString() + "/m", C);
    }
}

// Knappar: START = starta/pausa, BACK = ny rond (under pass), BACK före start = tillbaka.
class WorkoutDelegate extends WatchUi.BehaviorDelegate {

    hidden var _w;

    function initialize(workout) {
        BehaviorDelegate.initialize();
        _w = workout;
    }

    function onSelect() {
        if (_w.state == WS.IDLE) {
            _w.start();
        } else if (_w.state == WS.RUNNING) {
            _w.pause();
            PauseMenu.push(_w);
        } else if (_w.state == WS.PAUSED) {
            _w.resume();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_w.state == WS.IDLE) {
            return false; // tillbaka till huvudmenyn
        }
        if (_w.state == WS.RUNNING) {
            _w.lap();
        } else if (_w.state == WS.PAUSED) {
            PauseMenu.push(_w);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        if (_w.state == WS.PAUSED) {
            PauseMenu.push(_w);
            return true;
        }
        return false;
    }
}
