# Slagräknare – Connect IQ-app för Garmin fēnix 6, epix 2 och Forerunner 245

Räknar boxningsslag med klockans accelerometer, försöker skilja på **raka slag, krokar och uppercuts** och sparar passet som en vanlig aktivitet i Garmin Connect (med puls, tid, ronder och slagfält).

## Funktioner

- **Pass:** starta, pausa, fortsätt, spara, ta bort. Ny rond = nytt varv.
- **Slagräkning:** total, per typ, per rond och slagtakt (slag/min) live på skärmen.
- **Kalibrering:** du spelar in dina egna slag per typ direkt på klockan. Klockan räknar fram normvärden (medel + spridning) och använder dem för att klassa slagen.
- **Bakgrund:** en egen "klass" för rörelser som *inte* är slag (studs, garden, pendling). Den filtrerar bort falska slag.
- **Känslighet:** Låg (tung säck) / Medel / Hög (skuggboxning).
- **FIT-fält i Garmin Connect:** slag totalt, raka, krokar, uppercuts (sammanfattning), slag per rond (varv), slagtakt (graf).

## Knappar

| Läge | START | BACK | UPP (håll) |
|---|---|---|---|
| Före start | Starta pass | Tillbaka till menyn | – |
| Pass pågår | Pausa → pausmeny | **Ny rond** | – |
| Pausad | Fortsätt | Pausmeny | Pausmeny |
| Pausmeny | Välj: Fortsätt / Spara / Ta bort | Stanna pausad | |
| Kalibrering | Börja / spara | Avbryt inspelning | |

"Ta bort" frågar alltid "Ta bort passet?" först.

## Bygga och installera

1. Installera **VS Code** + tillägget **Monkey C** (Garmin) och **Connect IQ SDK Manager**. Ladda ner senaste SDK och enheten *fēnix 6S* i SDK Manager.
2. Kör `Monkey C: Generate a Developer Key` i VS Code (en gång).
3. Öppna mappen `punchcount` och kör `Monkey C: Build for Device` → välj `fenix6s` (eller `fenix6spro` om du har Pro/Solar/Sapphire). Du får `punchcount.prg`.
4. Koppla klockan med USB och kopiera `punchcount.prg` till `GARMIN/APPS/`. Koppla ur, så dyker **Slagräknare** upp bland apparna.

**Andra klockor:** byt `-d`/enhet vid bygget. Stödda: `fenix6s`, `fenix6spro`, `fenix6`, `fenix6pro`, `fenix6xpro`, `epix2`, `fr245`, `fr245m`. Varje enhet måste vara nedladdad i SDK Manager. En .prg byggs för en specifik modell. Vill du ha en fil för alla, använd `Monkey C: Export Project` (ger .iq för Connect IQ Store).

På epix 2 ignoreras tryck på pekskärmen under pass och kalibrering, så att träffar mot skärmen inte pausar passet. Kalibrera varje klocka för sig, eftersom sensorer och passform skiljer sig.

> Simulatorn (`Monkey C: Run`) duger för att testa menyer och knappar, men slagdetekteringen måste testas på riktiga klockan.

## Arbetsgång: träningsdataset → normvärden

### 1. Slå på loggning (en gång)
Klockan skriver varje kalibrerat slag till en loggfil, men bara om filen redan finns:

- Skapa en tom textfil som heter **`PUNCHCOUNT.TXT`** (samma namn som .prg-filen) på datorn.
- Kopiera den till `GARMIN/APPS/LOGS/` på klockan. Skapa mappen `LOGS` om den saknas.

### 2. Kalibrera på klockan
Huvudmeny → **Kalibrera slag** → välj typ → START → slå → START för att spara.

- Gör **15–30 slag per typ** med klockarmen, i normalt tempo och med variation.
- **Bakgrund:** studsa, gardera, pendla och gör fotarbete *utan att slå* i ca 30 s.
- Vill du göra om en typ? Välj den igen och tryck START. Den nya inspelningen ersätter den gamla.
- Räknar den för få slag ("För få slag")? Höj känsligheten i huvudmenyn.

Från och med nu klassar passen slagen med dina normvärden.

### 3. (Valfritt) Analysera och baka in normvärdena i appen
Kopiera `GARMIN/APPS/LOGS/PUNCHCOUNT.TXT` till datorn och kör:

```bash
python3 tools/analyze_log.py PUNCHCOUNT.TXT
```

Du får antal slag, medel/std per egenskap, **leave-one-out-träffsäkerhet** och en **förväxlingsmatris** som visar vilka slag som blandas ihop. Är du nöjd:

```bash
python3 tools/analyze_log.py PUNCHCOUNT.TXT --write-norms source/Norms.mc
```

Då byggs normvärdena in som standard, så att appen fungerar även efter "Rensa kalibrering" eller på en annan klocka. Kalibrering på klockan går alltid före de inbyggda värdena.

## Hur detekteringen fungerar

- Accelerometern läses i 25 Hz. För varje sampel räknas `|a| = √(x²+y²+z²)` ut, i vila ≈ 1 g.
- När `|a|` går över tröskeln (Låg 3,2 g / Medel 2,4 g / Hög 1,7 g) följer appen toppen. Ca 120 ms efter toppen räknas ett slag. Sedan är detektorn spärrad ca 300 ms, så att samma slag inte räknas två gånger.
- Varje slag får 10 egenskaper: handledens orientering före slaget (3), riktningen på toppaccelerationen (3), toppens styrka (1) och hur mycket rörelsen sker längs varje axel (3).
- Klassningen väljer den slagtyp vars normvärde ligger närmast, viktat med spridningen per egenskap. Om inget normvärde ligger tillräckligt nära räknas slaget som **Okänt** (det räknas ändå i totalen). Hamnar det närmast **Bakgrund** räknas det inte alls.

Inställbara konstanter: `Config.mc` (trösklar, klassnamn), `PunchDetector.mc` (fönsterlängder), `Classifier.mc` (`SIGMA_FLOOR`, `REJECT`).

## Begränsningar

- Bara slag med **klockarmen** räknas. Bär klockan på den hand du vill mäta.
- Jab och kross skiljs inte åt. Båda är "Rakt" för den hand klockan sitter på.
- Har du klockan på andra handen eller lösare/tightare än vid kalibreringen, kalibrera om.
