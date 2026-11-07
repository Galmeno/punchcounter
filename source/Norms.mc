// Inbyggda normvärden, används för klasser som inte kalibrerats på klockan.
// Den här filen kan genereras om från dina inspelningar med:
//   python3 tools/analyze_log.py SLAGRAKNARE.TXT --write-norms source/Norms.mc
// null = inget inbyggt normvärde (klassen måste kalibreras).
module Norms {
    const DEFAULTS = [null, null, null, null];
}
