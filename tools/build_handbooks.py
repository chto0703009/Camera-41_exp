"""Build the Swedish and English Exposure handbooks from editable JSON sources.
Requires reportlab. Run: python tools/build_handbooks.py
"""
from pathlib import Path
import json
from xml.sax.saxutils import escape
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, KeepInFrame
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/pdf'
OUT.mkdir(parents=True,exist_ok=True)
INK=colors.HexColor('#172d3a');BLUE=colors.HexColor('#246078');GRAY=colors.HexColor('#586772')
styles={
 'kicker':ParagraphStyle('kicker',fontName='Helvetica-Bold',fontSize=9,leading=12,textColor=BLUE,spaceAfter=7),
 'title':ParagraphStyle('title',fontName='Helvetica-Bold',fontSize=23,leading=27,textColor=INK,spaceAfter=14),
 'intro':ParagraphStyle('intro',fontName='Helvetica',fontSize=11,leading=15.5,textColor=INK,spaceAfter=16),
 'h':ParagraphStyle('h',fontName='Helvetica-Bold',fontSize=12,leading=16,textColor=BLUE,spaceBefore=8,spaceAfter=5),
 'body':ParagraphStyle('body',fontName='Helvetica',fontSize=10.3,leading=14.2,textColor=INK,spaceAfter=7),
}
def p(text,style):return Paragraph(escape(text).replace('\n','<br/>'),styles[style])
def build(data):
 path=OUT/f'Camera41_Exposure_Handbook_{data["language"]}.pdf'
 def chrome(c,doc):
  w,h=A4;c.setStrokeColor(colors.HexColor('#d6e1e5'));c.setLineWidth(.7);c.line(54,h-47,w-54,h-47)
  c.setFont('Helvetica-Bold',9);c.setFillColor(INK);c.drawString(54,h-33,'CAMERA-41 EXPOSURE')
  c.setFont('Helvetica',8);c.setFillColor(GRAY);c.drawRightString(w-54,h-33,f'{data["title"]} | v{data["version"]} | {data["language"]}')
  c.line(54,42,w-54,42);c.setFont('Helvetica',8);c.drawString(54,28,'v'+data['version']+' | '+data['date']+' | GPL-3.0-or-later')
  c.drawRightString(w-54,28,f'{doc.page} / {len(data["pages"])}')
 story=[]
 for i,page in enumerate(data['pages']):
  items=[p(data['subtitle'],'kicker'),p(page['title'],'title'),p(page['intro'],'intro')]
  for heading,body in page['sections']:items += [p(heading,'h'),p(body,'body')]
  story.append(KeepInFrame(A4[0]-108,A4[1]-130,items,mode='shrink',hAlign='LEFT',vAlign='TOP'))
  if i<len(data['pages'])-1:story.append(PageBreak())
 doc=SimpleDocTemplate(str(path),pagesize=A4,rightMargin=54,leftMargin=54,topMargin=68,bottomMargin=54,
  title='Camera-41 Exposure - '+data['title'],author='Christer Törnkvist',subject=data['subtitle'])
 doc.build(story,onFirstPage=chrome,onLaterPages=chrome)
 print(path)
if __name__=='__main__':
 for language in ['sv','en']:build(json.loads((ROOT/f'docs/handbook/handbook_{language}.json').read_text()))
