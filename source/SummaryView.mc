using Toybox.Graphics;
using Toybox.WatchUi;

// Visas efter att passet sparats.
class SummaryView extends WatchUi.View {

    hidden var _w;
    hidden var _time;

    function initialize(workout) {
        View.initialize();
        _w = workout;
        _time = workout.elapsedMs;
    }

    function onUpdate(dc) {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;
        var C = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 0.16, Graphics.FONT_SMALL, "Sparat", C);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 0.30, Graphics.FONT_TINY, Util.formatTime(_time) + "  |  " + _w.lapNum + " ronder", C);
        dc.drawText(cx, H * 0.47, Graphics.FONT_NUMBER_MEDIUM, _w.total.toString(), C);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 0.60, Graphics.FONT_XTINY, "slag", C);
        dc.drawText(cx, H * 0.72, Graphics.FONT_XTINY,
            "Rakt " + _w.perClass[0] + "  Krok " + _w.perClass[1], C);
        dc.drawText(cx, H * 0.81, Graphics.FONT_XTINY,
            "Upper " + _w.perClass[2] + "  Okänt " + _w.unknown, C);
    }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
