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
