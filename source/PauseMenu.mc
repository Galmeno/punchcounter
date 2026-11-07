using Toybox.WatchUi;

// Pausmeny: Fortsätt / Spara / Ta bort (med bekräftelse).
module PauseMenu {

    function push(workout) {
        var m = new WatchUi.Menu2({:title => "Paus"});
        m.addItem(new WatchUi.MenuItem("Fortsätt", null, :resume, {}));
        m.addItem(new WatchUi.MenuItem("Spara", workout.total.toString() + " slag", :save, {}));
        m.addItem(new WatchUi.MenuItem("Ta bort", null, :discard, {}));
        WatchUi.pushView(m, new PauseMenuDelegate(workout), WatchUi.SLIDE_UP);
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {

    hidden var _w;

    function initialize(workout) {
        Menu2InputDelegate.initialize();
        _w = workout;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :resume) {
            _w.resume();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :save) {
            _w.save();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);               // pausmenyn
            WatchUi.switchToView(new SummaryView(_w), new SummaryDelegate(), WatchUi.SLIDE_LEFT); // ersätter passvyn
        } else if (id == :discard) {
            var c = new WatchUi.Menu2({:title => "Ta bort passet?"});
            c.addItem(new WatchUi.MenuItem("Nej", null, :no, {}));
            c.addItem(new WatchUi.MenuItem("Ja, ta bort", null, :yes, {}));
            WatchUi.switchToView(c, new DiscardConfirmDelegate(_w), WatchUi.SLIDE_LEFT);
        }
    }

    // Tillbaka-knappen i pausmenyn = stanna kvar pausad i passvyn.
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class DiscardConfirmDelegate extends WatchUi.Menu2InputDelegate {

    hidden var _w;

    function initialize(workout) {
        Menu2InputDelegate.initialize();
        _w = workout;
    }

    function onSelect(item) {
        if (item.getId() == :yes) {
            _w.discard();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);   // bekräftelsen
            WatchUi.popView(WatchUi.SLIDE_DOWN);        // passvyn -> huvudmenyn
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);        // tillbaka till pausad passvy
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
