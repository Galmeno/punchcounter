using Toybox.Application.Storage;

// Gemensamma inställningar och konstanter.
module Config {

    // Slagklasser. Index 3 (Bakgrund) = rörelser som INTE ska räknas som slag
    // (studs, garden, fotarbete). Kalibreras som en egen klass.
    const CLASS_NAMES = ["Rakt", "Krok", "Uppercut", "Bakgrund"];
    const CLASS_SHORT = ["R", "K", "U", "-"];
    const NUM_CLASSES = 4;
    const NUM_PUNCH_CLASSES = 3;
    const CLASS_BG = 3;

    // Känslighet = tröskel för accelerationstoppen i milli-g.
    // Hög känslighet (låg tröskel) för skuggboxning, låg för tung säck.
    const SENS_NAMES = ["Låg", "Medel", "Hög"];
    const SENS_TH = [3200, 2400, 1700];

    const SAMPLE_RATE = 25;   // Hz, begärd accelerometerfrekvens
    const MIN_CALIB = 5;      // minsta antal slag för att spara en kalibrering

    function getSensitivity() {
        var v = Storage.getValue("sens");
        if (v == null || v < 0 || v > 2) {
            return 1;
        }
        return v;
    }

    function setSensitivity(i) {
        Storage.setValue("sens", i);
    }

    function threshold() {
        return SENS_TH[getSensitivity()];
    }
}
