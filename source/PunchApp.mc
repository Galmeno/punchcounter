using Toybox.Application;
using Toybox.WatchUi;

// Slagräknare - boxningsapp för Garmin fenix 6S.
// Startvy: huvudmenyn (MainMenu.mc).
class PunchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
        // Släpp accelerometern om appen stängs mitt i något.
        Sensors.stop();
    }

    function getInitialView() {
        return [MainMenu.build(), new MainMenuDelegate()];
    }
}
