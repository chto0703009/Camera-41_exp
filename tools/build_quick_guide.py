"""Create a one-page Swedish release summary. Requires reportlab."""
from pathlib import Path
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from xml.sax.saxutils import escape
ROOT=Path(__file__).resolve().parents[1]
FILE=ROOT/'output/pdf/Camera41_exp_Sammanfattning_SV.pdf'
INK=colors.HexColor('#172d3a');BLUE=colors.HexColor('#246078')
styles={
 'title':ParagraphStyle('title',fontName='Helvetica-Bold',fontSize=24,leading=29,textColor=INK,spaceAfter=8),
 'author':ParagraphStyle('author',fontName='Helvetica-Bold',fontSize=11,leading=15,textColor=BLUE,spaceAfter=15),
 'h':ParagraphStyle('h',fontName='Helvetica-Bold',fontSize=12,leading=16,textColor=BLUE,spaceBefore=9,spaceAfter=5),
 'body':ParagraphStyle('body',fontName='Helvetica',fontSize=10,leading=14,textColor=INK,spaceAfter=7)}
def para(text,style):return Paragraph(escape(text).replace('\n','<br/>'),styles[style])
sections=[
 ('Varför används programmet?', 'Camera-41_exp hjälper dig att ställa in exponeringen när du fotograferar C-41-färgnegativ och svartvita negativ med en digitalkamera i en VALOI-uppställning. Med fast bländare jämför appen RAW-bilder av tom filmbas plus slöja för att hitta en slutartid som ger stark signal med marginal till klippning. För lång exponering kan klippa en sensorkanal. För kort exponering ger svag signal och gör bruset tydligare när bilden ljusas upp.'),
 ('Arbetsgång', '1. Öppna Camera-41_exp från Program.\n2. Använd Add FB+F RAWs… för att läsa in en serie av samma tomma filmprov.\n3. Fyll i Light setup och Film base + fog. Markera Same FB+F sample in all RAWs.\n4. Tryck Analyse RAW images och granska Results och Exposure comparison.\n5. Kontrollera den valda tiden med en ny bild.'),
 ('Område och resultat', 'Appen väljer normalt centrala 70 % av bildens bredd och höjd. Vid oväntad struktur visas en gul ruta för manuell justering. Förhandsvisningen påverkar inte mätvärdena.\nPASS: minst 1/3 EV marginal i alla Bayer-kanaler och ingen underkänd andel vid/över gränsen. REVIEW: för liten marginal. FAIL: för stor andel når eller överskrider gränsen. Läs kanalrapporten; rätt filmprov och område ska kontrolleras innan tiden ändras.'),
 ('Fristående hjälpmedel', 'Camera-41_exp har ingen program- eller filöverföringskoppling till PRE eller NEG och exporterar ingen JSON till dem. Om du använder PRE: ställ in kameran på vald tid, ta aktuell films FB+F och två matchande mörkerbilder och läs in dem direkt i PRE. Brus- och S/N-mätningen görs där, inte i Camera-41_exp.'),
 ('Installation, start och logg', 'Öppna Camera-41_exp-1.0.0-python-macos.dmg. Dra Apple Silicon-appen till Program på en Mac med M-chip. Välj Intel-appen för en Intel-Mac. Lägg till egna filmbasbilder med Add FB+F RAWs…. Open log visar den lokala diagnostikloggen. Avsluta appen innan du ersätter den.')]
story=[para('Camera-41_exp v1.0.0','title'),para('Christer Törnkvist | Sammanfattning','author')]
for h,b in sections:story.extend([para(h,'h'),para(b,'body')])
def footer(c,doc):
 w,h=A4;c.setStrokeColor(colors.HexColor('#d6e1e5'));c.line(54,65,w-54,65);c.setFillColor(BLUE);c.setFont('Helvetica',9)
 email='christer@borgasundsfotografiska.se';url='https://github.com/chto0703009/Camera-41_exp'
 c.drawString(54,49,email);c.linkURL('mailto:'+email,(54,47,54+c.stringWidth(email,'Helvetica',9),59))
 c.drawString(54,35,url);c.linkURL(url,(54,33,54+c.stringWidth(url,'Helvetica',9),45));c.setFont('Helvetica',8);c.drawString(54,20,'v1.0.0 | 13 november 2026 | GPL-3.0-or-later')
SimpleDocTemplate(str(FILE),pagesize=A4,leftMargin=54,rightMargin=54,topMargin=48,bottomMargin=80,
 title='Camera-41_exp v1.0.0 - Sammanfattning',author='Christer Törnkvist').build(story,onFirstPage=footer,onLaterPages=footer)
print(FILE)
