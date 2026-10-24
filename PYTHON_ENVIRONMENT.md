# Enhetlig lokal Pythonmiljö

Varje aktiv programinstallation har en egen `.venv`, med Python **3.13.6** och exakt samma fullständiga paketlista i `requirements.txt`. Miljöerna delar inga paketmappar och kan flyttas eller byggas om oberoende av varandra. Även EXP har miljön för enhetlig installation, trots att dess vanliga RAW-avkodning använder LibRaw direkt.

Kör programmets vanliga startkommando. En saknad eller ogiltig miljö ger dialogen **Förbered för den här datorn**. Ett datorbyte kan kräva ombyggnad; Python 3.13.6 måste vara installerat och första installationen kan behöva internet. Inga externa Pythonmiljöer väljs automatiskt som programruntime.

Gemensamma underhållskommandon från programmets kodmapp:

```matlab
setup_python_environment("check")
setup_python_environment("sync")
setup_python_environment("rebuild")
```

`sync` och `rebuild` skapar en ny miljö med den fullständiga paketlistan. Den gamla sparas som `.venv.backup_*` och återställs om installationen eller verifieringen misslyckas. Egna projekt och mätningar ändras inte. `requirements-tools.txt` och eventuella analys-/rapportfiler hänvisar till samma fullständiga lista.

Verifieringen kontrollerar Pythonversion, paketversioner, extra paket, importernas isolering, kompilerade moduler, PDF-skrivning/läsning och pip check. Camera-41 verifierar även sin befintliga numeriska referens. Resultatet och den installerade paketlistan finns i `local-config/python_environment.json` och `local-config/python-lock.txt`.

Vid paketändringar ska kravfilen, Pythonversionen och installationskontrollen hållas lika i alla aktiva program, följt av respektive programs regressionstester. ArgyllCMS och LibRaw är separata externa/native beroenden och ingår inte i `.venv`.

På Apple Silicon prioriteras ARM-Python framför Intel oberoende av MATLAB/Rosetta. Om Pythoninstallationen är universal görs den lokala miljöns interpreter ARM-specifik. ArgyllCMS väljs i första hand för den fysiska arkitekturen och universalverktyg startas uttryckligen som ARM. På Intel används Intel-versioner.
