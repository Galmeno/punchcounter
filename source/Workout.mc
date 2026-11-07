using Toybox.ActivityRecording;
using Toybox.FitContributor;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Activity;

// Passets tillstånd.
module WS {
    const IDLE = 0;
    const RUNNING = 1;
    const PAUSED = 2;
    const DONE = 3;
}

// Ett boxningspass: aktivitetsinspelning + slagräkning + FIT-fält.
class Workout {

    var state = WS.IDLE;
    var elapsedMs = 0;
    var total = 0;
    var perClass = [0, 0, 0];
    var unknown = 0;
    var lapPunches = 0;
    var lapNum = 1;
    var lastClass = null;     // -1 = okänt, 0..2 = slagklass
    var lastPunchAt = 0;      // System.getTimer() ms
    var calibrated = false;

    hidden var _session = null;
    hidden var _detector;
    hidden var _norms;
    hidden var _recent = [];  // tidsstämplar (ms) för slag senaste minuten

    hidden var _fTotal;
    hidden var _fClass;
    hidden var _fLap;
    hidden var _fRate;

    function initialize() {
        _norms = Classifier.loadNorms();
        for (var c = 0; c < Config.NUM_PUNCH_CLASSES; c++) {
            if (_norms[c] != null) {
                calibrated = true;
            }
        }
        _detector = new PunchDetector(Sensors.sampleRate(), Config.threshold(), method(:onPunch));
    }

    function start() {
        if (_session == null) {
            _session = ActivityRecording.createSession({
                :name => "Boxning",
                :sport => ActivityRecording.SPORT_TRAINING,
                :subSport => ActivityRecording.SUB_SPORT_CARDIO_TRAINING
            });
            createFields();
        }
        _session.start();
        Sensors.start(_detector);
        state = WS.RUNNING;
        Util.vibrate(300);
    }

    function pause() {
        if (state != WS.RUNNING) {
            return;
        }
        _session.stop();
        Sensors.stop();
        state = WS.PAUSED;
        Util.vibrate(150);
    }

    function resume() {
        if (state != WS.PAUSED) {
            return;
        }
        _session.start();
        Sensors.start(_detector);
        state = WS.RUNNING;
        Util.vibrate(150);
    }

    // Ny rond = nytt varv i FIT-filen.
    function lap() {
        if (state != WS.RUNNING) {
            return;
        }
        _fLap.setData(lapPunches);
        _session.addLap();
        lapPunches = 0;
        _fLap.setData(0);
        lapNum++;
        Util.vibrate(200);
    }

    function save() {
        Sensors.stop();
        var info = Activity.getActivityInfo();
        if (info != null && info.timerTime != null) {
            elapsedMs = info.timerTime;
        }
        if (_session != null) {
            if (_session.isRecording()) {
                _session.stop();
            }
            _fLap.setData(lapPunches);
            _session.save();
        }
        _session = null;
        state = WS.DONE;
        System.println("PASS," + total + "," + perClass[0] + "," + perClass[1] + "," + perClass[2] + "," + unknown);
    }

    function discard() {
        Sensors.stop();
        if (_session != null) {
            if (_session.isRecording()) {
                _session.stop();
            }
            _session.discard();
        }
        _session = null;
        state = WS.DONE;
    }

    hidden function createFields() {
        var S = FitContributor.MESG_TYPE_SESSION;
        _fTotal = _session.createField("slag_totalt", 0, FitContributor.DATA_TYPE_UINT16, {:mesgType => S, :units => "slag"});
        _fClass = [
            _session.createField("slag_raka", 1, FitContributor.DATA_TYPE_UINT16, {:mesgType => S, :units => "slag"}),
            _session.createField("slag_krokar", 2, FitContributor.DATA_TYPE_UINT16, {:mesgType => S, :units => "slag"}),
            _session.createField("slag_uppercuts", 3, FitContributor.DATA_TYPE_UINT16, {:mesgType => S, :units => "slag"})
        ];
        _fLap = _session.createField("slag_rond", 4, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "slag"});
        _fRate = _session.createField("slagtakt", 5, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "slag/min"});
        _fTotal.setData(0);
        for (var i = 0; i < _fClass.size(); i++) {
            _fClass[i].setData(0);
        }
        _fLap.setData(0);
        _fRate.setData(0);
    }

    // Anropas av PunchDetector för varje upptäckt topp.
    function onPunch(f) {
        if (state != WS.RUNNING) {
            return;
        }
        var c = Classifier.classify(_norms, f);
        if (c == Config.CLASS_BG) {
            return; // rörelse som inte är ett slag
        }
        total++;
        lapPunches++;
        if (c >= 0) {
            perClass[c]++;
            _fClass[c].setData(perClass[c]);
        } else {
            unknown++;
        }
        lastClass = c;
        lastPunchAt = System.getTimer();
        _recent.add(lastPunchAt);
        _fTotal.setData(total);
        _fLap.setData(lapPunches);
        WatchUi.requestUpdate();
    }

    // Anropas en gång per sekund från vyn.
    function tick() {
        if (state != WS.RUNNING) {
            return;
        }
        var now = System.getTimer();
        while (_recent.size() > 0 && now - _recent[0] > 60000) {
            _recent.remove(_recent[0]);
        }
        _fRate.setData(_recent.size());
    }

    function rate() {
        return _recent.size();
    }
}
