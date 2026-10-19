# Camera-41 Exposure

Öppna `start.m` i MATLAB och tryck **Run**. Ett separat appfönster öppnas. Du kan också köra `startCamera41_exposure` från den här mappen.

1. Lägg till RAW-bilder av samma filmbas + slöja. Behåll kamera, ISO, bländare och ljus. Variera bara exponeringstiden.
2. Ange ljusuppställning och filmprov. Bekräfta att bilderna visar samma prov.
3. Välj en RAW-bild, förhandsvisa den och rita ett rent mätområde, minst 20 × 20 sensorpixlar.
4. Tryck **Analyse RAW images**. Under **Exposure comparison** visas RAW-signalen och klippningsmarginalen för R/G1/G2/B mot exponeringstiden. Tabellen visar varje bilds mätresultat. **RAW preview** visar vald bild.
5. Välj en uppmätt godkänd tid i listan längst ned. Appens rekommendation är förvald.
6. Tryck **Save selected time as JSON**. Filen innehåller ditt val, ursprunglig rekommendation, mätningar, kamera-/ljusuppgifter, ROI och källornas SHA-256.
7. Importera JSON-filen i PRE, flik **7. Digital-camera exposure**. Den följer filmkarakteriseringens export till NEG och visas där med **Digitising-camera exposure result**.

Valet gäller digitalkamerans exponering vid negativinläsning. Verifiera tiden med en ny bild. Testet mäter inte tidsmässigt brus och skapar inte en fullständig produktionskvalificering. Originalbilderna ändras inte. Inställningar återställs inte efter stängning. JSON-filen är fristående och behöver ingen tillfällig analysmapp.

MATLAB och den medföljande LibRaw-proben krävs. Apple Silicon-proben är verifierad på denna dator. Vid flytt kan proben behöva byggas om med `tools/build_raw_probe.sh` och installerat LibRaw/pkg-config. Programmet har GPL-3.0-or-later-licens; se LICENSE och third_party/licenses.

Vid FAIL visar rapporten vilka kanaler som överskrider gränsen, signal i koder, marginal i EV och andel pixlar vid/över gränsen. **Save report** sparar mätningar och förklaringar även utan en godkänd tid. En enda RAW kan bedömas, men flera exponeringstider behövs för jämförelse och proportionalitetskontroll. Standardområdet i övre vänstra hörnet ska ersättas med en representativ ren filmbasregion.

RAW-filväljaren öppnas direkt i senast använda RAW-mapp. Mappen sparas i MATLAB-inställningarna och återanvänds även efter omstart av appen. Avbryt ändrar inte mappen. Första gången används hemmappen.

## Logg

Hela appens händelselogg finns i `logs/camera41_exposure.jsonl`. Menyn **Log → Open complete log** öppnar den i MATLAB. Varje rad har UTC-tidsstämpel, process-ID, händelse och detaljer. Start, mappkontroll, filval, filer, inställningar, förhandsvisning, mätområde, analys per RAW, resultat, sparande, fel med stack och stängning loggas. Varaktigheter anges i sekunder. Filväljarens tid omfattar både systemets väntetid och tiden användaren väljer filer; MATLAB ger ingen separat signal när den inbyggda filväljaren blivit synlig. Loggen är lokal och ignoreras av Git.

## Automatiskt mätområde

**Automatic area** är förvalt. Analysen använder centrala 70 % av den synliga RAW-bredden och höjden (15 % marginal på varje sida), med samma område i hela exponeringsserien. Appen söker inte efter den mest gynnsamma lilla fläcken. En rutnätskontroll för varje CFA-kanal skiljer jämn ljusvariation från tydlig struktur. Signifikanta avvikelser (95:e percentilen av residualen över 0,18 EV efter en jämn andragradsyta, eller mer än 1 EV spridning över rutmedianerna) eller för låg signal begär manuell granskning. Detta är en heuristisk kontroll av jämnhet, ingen säker identifiering av filminnehåll. Klippning bedöms separat även om bilden är jämn.

Vid varning öppnas den berörda RAW-bilden automatiskt med det föreslagna området markerat i gult. Förklaringen visas och användaren justerar den befintliga rutan innan analysen fortsätter. Området begränsas till sensorns synliga pixlar. Förhandsvisning visar också den automatiska rutan vid normala bilder. En manuellt vald region är ett uttryckligt användarval och redovisas som manuellt i JSON-resultatet.
