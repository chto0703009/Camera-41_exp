"""Create a one-page English release summary. Requires reportlab."""
from pathlib import Path
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from xml.sax.saxutils import escape
ROOT=Path(__file__).resolve().parents[1]
FILE=ROOT/'output/pdf/Camera41_Exposure_Summary_EN.pdf'
INK=colors.HexColor('#172d3a');BLUE=colors.HexColor('#246078')
styles={
 'title':ParagraphStyle('title',fontName='Helvetica-Bold',fontSize=24,leading=29,textColor=INK,spaceAfter=8),
 'author':ParagraphStyle('author',fontName='Helvetica-Bold',fontSize=11,leading=15,textColor=BLUE,spaceAfter=15),
 'h':ParagraphStyle('h',fontName='Helvetica-Bold',fontSize=12,leading=16,textColor=BLUE,spaceBefore=9,spaceAfter=5),
 'body':ParagraphStyle('body',fontName='Helvetica',fontSize=10,leading=14,textColor=INK,spaceAfter=7)}
def para(text,style):return Paragraph(escape(text).replace('\n','<br/>'),styles[style])
sections=[
 ('Why use Exposure?', 'Camera-41 Exposure helps choose the digital-camera shutter time for photographing negatives at a fixed selected aperture. Empty film base plus fog (FB+F) provides a reference for the bright end of the film signal. Excessive exposure can cause clipping or loss of linearity in a colour channel. Making the preview darker cannot restore lost information.'),
 ('Workflow', '1. Open start.m in MATLAB and press Run.\n2. Add RAWs of the same empty FB+F sample at different shutter times. Keep camera, ISO, aperture and lighting fixed.\n3. Describe the light and sample. Confirm the same sample appears in every file.\n4. Press Analyse RAW images and inspect Exposure comparison.\n5. Select a measured passing time and confirm it with a fresh capture.'),
 ('Measurement area and results', 'The app normally uses the central 70% of image width and height. Unexpected structure triggers a yellow rectangle for inspection and manual adjustment. Preview brightness does not affect measurements.\nPASS: at least 1/3 EV margin in all Bayer channels and no failing fraction at/above the limit. REVIEW: insufficient margin. FAIL: too many values reach or exceed the limit. Read the channel report and check the film sample and area before changing shutter time.'),
 ('Independent tool', 'Exposure has no software or file-transfer connection to PRE or NEG and exports no JSON to them. If using PRE, set the chosen time, capture the current film\'s FB+F and two matched dark frames, then load those directly in PRE. Noise and S/N are measured there, not in Exposure.'),
 ('Installation, startup and log', 'Download the macOS ZIP from GitHub > Releases > v0.1.0. Extract the complete package into a local writable folder. Open start.m in MATLAB and press Run, or select the app folder as Current Folder and run startCamera41_exposure;. Python and venv are not required. Log: Log > Open complete log. The latest RAW folder is remembered. Original RAWs are unchanged. MATLAB is required, with Image Processing Toolbox for region editing. Verified on macOS Apple Silicon with MATLAB R2025b; physical Intel operation is not fully tested. GPL-3.0-or-later; third-party licences are included.')]

story=[para('Camera-41 Exposure v0.1.0','title'),para('Christer Törnkvist | Summary','author')]
for h,b in sections:story.extend([para(h,'h'),para(b,'body')])
def footer(c,doc):
 w,h=A4;c.setStrokeColor(colors.HexColor('#d6e1e5'));c.line(54,65,w-54,65);c.setFillColor(BLUE);c.setFont('Helvetica',9)
 email='christer@borgasundsfotografiska.se';url='https://github.com/chto0703009/camera-41_exposure'
 c.drawString(54,49,email);c.linkURL('mailto:'+email,(54,47,54+c.stringWidth(email,'Helvetica',9),59))
 c.drawString(54,35,url);c.linkURL(url,(54,33,54+c.stringWidth(url,'Helvetica',9),45));c.setFont('Helvetica',8);c.drawString(54,20,'v0.1.0 | 19 October 2026 | GPL-3.0-or-later')
SimpleDocTemplate(str(FILE),pagesize=A4,leftMargin=54,rightMargin=54,topMargin=48,bottomMargin=80,
 title='Camera-41 Exposure v0.1.0 - Summary',author='Christer Törnkvist').build(story,onFirstPage=footer,onLaterPages=footer)
print(FILE)
