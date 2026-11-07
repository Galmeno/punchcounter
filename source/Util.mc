using Toybox.Attention;
using Toybox.Lang;

module Util {

    function join(arr) {
        var s = "";
        for (var i = 0; i < arr.size(); i++) {
            if (i > 0) {
                s += ",";
            }
            s += arr[i].format("%.3f");
        }
        return s;
    }

    function formatTime(ms) {
        if (ms == null) {
            ms = 0;
        }
        var t = ms / 1000;
        var h = t / 3600;
        var m = (t % 3600) / 60;
        var s = t % 60;
        if (h > 0) {
            return Lang.format("$1$:$2$:$3$", [h, m.format("%02d"), s.format("%02d")]);
        }
        return Lang.format("$1$:$2$", [m.format("%02d"), s.format("%02d")]);
    }

    function vibrate(ms) {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(60, ms)]);
        }
    }
}
