using Toybox.Sensor;

// En enda accelerometerlyssnare för hela appen; den vy som är aktiv
// (pass eller kalibrering) kopplar in sin PunchDetector.
var gFeed = null;

class SensorFeed {

    hidden var _active = false;
    hidden var _target = null;

    function initialize() {
    }

    function start(detector, rate) {
        stop();
        _target = detector;
        var opts = {
            :period => 1,
            :accelerometer => {
                :enabled => true,
                :sampleRate => rate
            }
        };
        Sensor.registerSensorDataListener(method(:onData), opts);
        _active = true;
    }

    function stop() {
        if (_active) {
            Sensor.unregisterSensorDataListener();
            _active = false;
        }
        _target = null;
    }

    function onData(data as Sensor.SensorData) as Void {
        if (_target == null || data == null) {
            return;
        }
        var a = data.accelerometerData;
        if (a == null || a.x == null || a.y == null || a.z == null) {
            return;
        }
        _target.addSamples(a.x, a.y, a.z);
    }
}

module Sensors {

    // Faktisk samplingsfrekvens (begärd frekvens, begränsad av klockans max).
    function sampleRate() {
        var r = Config.SAMPLE_RATE;
        if (Sensor has :getMaxSampleRate) {
            var mx = Sensor.getMaxSampleRate();
            if (mx != null && mx > 0 && mx < r) {
                r = mx;
            }
        }
        return r;
    }

    function start(detector) {
        if ($.gFeed == null) {
            $.gFeed = new SensorFeed();
        }
        $.gFeed.start(detector, sampleRate());
    }

    function stop() {
        if ($.gFeed != null) {
            $.gFeed.stop();
        }
    }
}
