using Toybox.WatchUi;

var gMainMenu = null;

module MainMenu {

    function calibSubLabel() {
        var done = 0;
        for (var c = 0; c < Config.NUM_CLASSES; c++) {
            if (Classifier.isCalibrated(c)) {
                done++;
            }
        }
        return done.toString() + "/" + Config.NUM_CLASSES + " klara";
    }

    function build() {
        var m = new WatchUi.Menu2({:title => "Slagräknare"});
        m.addItem(new WatchUi.MenuItem("Starta pass", null, :workout, {}));
        m.addItem(new WatchUi.MenuItem("Kalibrera slag", calibSubLabel(), :calib, {}));
        m.addItem(new WatchUi.MenuItem("Känslighet", Config.SENS_NAMES[Config.getSensitivity()], :sens, {}));
        m.addItem(new WatchUi.MenuItem("Rensa kalibrering", null, :clear, {}));
        $.gMainMenu = m;
        return m;
    }

    // Uppdatera underrubriker efter ändringar.
    function refresh() {
        var m = $.gMainMenu;
        if (m == null) {
            return;
        }
        var i = m.findItemById(:calib);
        if (i >= 0) {
            m.getItem(i).setSubLabel(calibSubLabel());
        }
        i = m.findItemById(:sens);
        if (i >= 0) {
            m.getItem(i).setSubLabel(Config.SENS_NAMES[Config.getSensitivity()]);
        }
        WatchUi.requestUpdate();
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :workout) {
            var w = new Workout();
            WatchUi.pushView(new WorkoutView(w), new WorkoutDelegate(w), WatchUi.SLIDE_LEFT);
        } else if (id == :calib) {
            CalibMenu.push();
        } else if (id == :sens) {
            var m = new WatchUi.Menu2({:title => "Känslighet"});
            m.addItem(new WatchUi.MenuItem("Låg", "Tung säck, hårda slag", 0, {}));
            m.addItem(new WatchUi.MenuItem("Medel", "Säck / mitts", 1, {}));
            m.addItem(new WatchUi.MenuItem("Hög", "Skuggboxning", 2, {}));
            m.setFocus(Config.getSensitivity());
            WatchUi.pushView(m, new SensMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :clear) {
            var c = new WatchUi.Menu2({:title => "Rensa allt?"});
            c.addItem(new WatchUi.MenuItem("Nej", null, :no, {}));
            c.addItem(new WatchUi.MenuItem("Ja, rensa", "Alla slagtyper", :yes, {}));
            WatchUi.pushView(c, new ClearConfirmDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT); // avslutar appen
    }
}

class SensMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        Config.setSensitivity(item.getId());
        MainMenu.refresh();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class ClearConfirmDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        if (item.getId() == :yes) {
            Classifier.clearAll();
            MainMenu.refresh();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
