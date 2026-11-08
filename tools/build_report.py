"""Rebuild the 13-page PDF after running F1_script.R from the project root."""
from pathlib import Path
from xml.sax.saxutils import escape
import csv
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color, white
from reportlab.lib.utils import ImageReader
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / 'outputs' / 'images'
W, H = 1280, 720
BG, PANEL, RED = '#10151C', '#1A232E', '#EE4035'
INK, MUTED = '#F5F7FA', '#AAB8C7'
SOURCE_URL = 'https://www.kaggle.com/datasets/rohanrao/formula-1-world-championship-1950-2020'

def rows(name):
    with (ROOT / 'datasets' / (name + '.csv')).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

results = rows('results')
races = {r['raceId']: r for r in rows('races') if 1950 <= int(r['year']) <= 2024}
results = [r for r in results if r['raceId'] in races]
counts = (len(results), len({r['raceId'] for r in results}), len({r['driverId'] for r in results}))

styles = {
    'body': ParagraphStyle('body', fontName='Helvetica', fontSize=16, leading=24, textColor=HexColor(INK)),
    'small': ParagraphStyle('small', fontName='Helvetica', fontSize=12, leading=18, textColor=HexColor(MUTED)),
    'note': ParagraphStyle('note', fontName='Helvetica', fontSize=15, leading=23, textColor=HexColor(INK)),
}
c = canvas.Canvas(str(ROOT / 'formula_one.pdf'), pagesize=(W,H), pageCompression=1)
c.setTitle('Formula 1 World Championship Analysis | 1950-2024')
c.setAuthor('Irisbaev Nuriddin')
c.setSubject('Revised exploratory analysis using Kaggle dataset version 24')
page_number = 0

def text(x,y,message,size=16,color=INK,font='Helvetica'):
    c.setFillColor(HexColor(color)); c.setFont(font,size); c.drawString(x,y,message)

def para(message,x,top,width,style='body'):
    p=Paragraph(message, styles[style]); _,h=p.wrap(width,H)
    p.drawOn(c,x,top-h)
    return top-h

def rect(x,y,w,h,color,radius=0):
    c.setFillColor(HexColor(color)); c.setStrokeColor(HexColor(color))
    if radius: c.roundRect(x,y,w,h,radius,fill=1,stroke=0)
    else: c.rect(x,y,w,h,fill=1,stroke=0)

def page(title,kicker='FORMULA 1 / EXPLORATORY ANALYSIS'):
    global page_number
    page_number += 1
    rect(0,0,W,H,BG); rect(46,H-109,5,57,RED)
    text(65,H-62,kicker,11,RED,'Helvetica-Bold')
    text(65,H-100,title,30,INK,'Helvetica-Bold')
    rect(46,42,W-92,1,'#344251')
    text(46,23,'Irisbaev Nuriddin  |  Kaggle v24  |  1950-2024',10,MUTED)
    text(W-97,23,f'{page_number:02d} / 13',10,MUTED)

def end(): c.showPage()

def chart(file,x=46,y=83,w=900,h=505):
    path=IMAGES/file
    if not path.exists(): raise FileNotFoundError(f'Run the R analysis first: {path}')
    rect(x,y,w,h,'#FFFFFF',8)
    im=ImageReader(str(path)); iw,ih=im.getSize()
    scale=min((w-20)/iw,(h-20)/ih)
    dw,dh=iw*scale,ih*scale
    c.drawImage(im,x+(w-dw)/2,y+(h-dh)/2,dw,dh,mask='auto')

def notes(items,x=974,top=573,w=250):
    for title,body in items:
        text(x,top,title.upper(),11,RED,'Helvetica-Bold')
        top=para(body,x,top-20,w,'note')-36

page('Formula 1 World Championship', '1950-2024 / REVISED ANALYSIS')
text(66,526,'A system of drivers,',43,INK,'Helvetica-Bold')
text(66,469,'teams and race outcomes.',43,INK,'Helvetica-Bold')
para('An exploratory study of performance, qualifying, pit stops and teammate networks.',68,413,680)
# Original vector motif, replacing the unsourced cover photograph.
c.setStrokeColor(HexColor(RED)); c.setLineWidth(11)
path=c.beginPath(); path.moveTo(854,457); path.curveTo(1000,625,1240,496,1140,370)
path.curveTo(1070,283,918,318,850,204); path.curveTo(781,89,1129,110,1166,215)
c.drawPath(path)
c.setStrokeColor(HexColor('#53657A')); c.setLineWidth(2)
for offset in (22,-22):
    c.saveState(); c.translate(offset,offset/2); c.drawPath(path); c.restoreState()
text(68,222,'PRESENTER',12,RED,'Helvetica-Bold')
text(68,185,'Irisbaev Nuriddin',27,INK,'Helvetica-Bold')
text(68,116,'Source snapshot: Kaggle version 24  |  Analysis reviewed: 08 Nov 2026',12,MUTED)
end()

page('Data, scope and analytical method')
for x,value,label in [(47,f'{counts[0]:,}','RACE-RESULT ROWS'),(450,f'{counts[1]:,}','RACES'),(853,f'{counts[2]:,}','DRIVERS')]:
    rect(x,420,380,158,PANEL,8); text(x+25,499,value,43,INK,'Helvetica-Bold'); text(x+25,455,label,12,RED,'Helvetica-Bold')
para('Eight CSV tables connect drivers, constructors, races, circuits, outcomes, qualifying and pit stops. The study uses races from 1950 through 2024.',48,367,1140)
para('<b>Method:</b> validate IDs; join lookup tables without changing result-row counts; calculate descriptive summaries; build unique teammate edges; export plots; check output invariants.',48,280,1140)
para('<b>Boundaries:</b> no causal inference, no inference from surnames, and no street/permanent classification inferred from countries. An optional reviewed circuit-ID mapping can enable those comparisons.',48,179,1140)
end()

page('How do race-result entries end?')
chart('F1_Race_Result_Distribution.png')
notes([('Definition','Categories are an analytical grouping of recorded result statuses.'),
       ('Scope','This pie excludes Other. It describes only the four displayed categories.'),
       ('Correction','A generic Retired status is grouped as Other; it is not evidence of an accident.')])
end()

page('Which outcome dominates each season?')
chart('F1_Status_Popularity.png',w=1185,h=414,y=164)
para('Each bar reports the count for a season\'s most frequent category; ties can produce multiple bars. Counts are not rates and are affected by the number of races and entries.',48,132,1150,'note')
end()

page('Where do race winners come from?')
chart('F1_Wins_Map.png')
notes([('Measure','Wins grouped by the recorded nationality of each winning driver.'),
       ('Interpretation','The map describes accumulated wins, not a country\'s causal influence on performance.'),
       ('Limit','Historical nationality labels and country-map matching affect geographic coverage.')])
end()

page('Drivers connected through shared teams')
chart('f1_barchart.png')
notes([('Identity','Driver IDs distinguish different people who share a surname.'),
       ('Measure','A pairing is a distinct teammate, not the number of races the pair contested together.'),
       ('Display','The top 30 drivers are shown. Historic shared-car and team-entry records affect the definition.')])
end()

page('The teammate network')
chart('F1_Teammate_Network.png')
notes([('Full graph','815 connected drivers and 5,006 unique undirected edges.'),
       ('Displayed graph','Only drivers with at least 15 distinct teammates in the full graph are displayed. Labels are omitted for clarity; IDs and names are available in the node table.'),
       ('Boundary','46 drivers have no teammate edge under this definition and are absent from the graph. This filter does not remove Indianapolis 500 entries.')])
end()

page('Recorded pit-stop durations')
chart('F1_PitStop_Duration.png')
notes([('Selection','The 12 constructors with the most recorded stops are compared after filtering durations below 120 seconds.'),
       ('Uncertainty','Bars show means; error bars show one standard deviation, not confidence intervals.'),
       ('Caution','The measurement is the dataset\'s recorded duration. Do not equate it with stationary wheel-change time.')])
end()

page('Qualifying: Q1 to Q3 time change')
chart('F1_Qualifying_Improvement.png')
notes([('Definition','Improvement = Q1 lap time minus Q3 lap time. Positive values mean a faster Q3 time.'),
       ('Population','Only records with both Q1 and Q3 times are included. This is a selected group of qualifying participants.'),
       ('Interpretation','The smooth curve summarizes the observed sample. Format, track and weather changes limit historical comparisons.')])
end()

page('Wins across drivers and circuits')
chart('F1_Driver_Circuit_Heatmap.png')
notes([('Selection','The top 10 drivers by wins and the 15 most frequent winning circuits are selected from the input data.'),
       ('Reading','Each filled cell counts wins. Blank cells indicate no winning observation for that selected pairing.'),
       ('Limit','Totals reflect opportunity as well as performance; they are not normalized for starts or career length.')])
end()

page('How often does pole become a win?')
chart('F1_Pole_Win_Conversion.png')
notes([('Definition','Wins from grid position 1 divided by the number of observed races at each circuit.'),
       ('Selection','Circuits with at least 10 races; the 20 highest percentages are shown.'),
       ('Boundary','This is an observed historical proportion, not a causal effect or a forecast. Starting-grid exceptions affect interpretation.')])
end()

page('Starting and finishing positions across eras')
chart('Heatmap_Hybrid_Era__2014_2021_.png',x=46,y=178,w=580,h=410)
chart('Heatmap_Ground_Effect__2022_2024_.png',x=654,y=178,w=580,h=410)
para('Cells count result rows by starting and finishing position (positions 1-20). These panels show two selected eras; the script exports all six. Raw counts depend on era length, calendar size and field size.',48,142,1145,'note')
end()

page('Findings, limitations and sources')
for y,title,body in [
    (573,'Performance is multidimensional','The plots describe outcomes, geography, qualifying, pit stops and team connectivity. No single summary measures overall driver quality.'),
    (447,'Validation checks consistency','The revised run preserves all 26,759 result rows and checks ID uniqueness, graph endpoints, degree totals, outcome totals and numeric bounds.'),
    (321,'Historical comparisons need context','Rule changes, shared-car records, career length and measurement conventions remain relevant. Optional circuit-type charts require an explicit mapping.')]:
    text(49,y,title,19,INK,'Helvetica-Bold'); para(body,49,y-25,1155,'body')
para('<b>Data:</b> Rohan Rao, <i>Formula 1 World Championship (1950-2024)</i>, Kaggle version 24, updated 29 Jan 2025; retrieved 08 Nov 2026. Kaggle lists the data as CC0.',49,191,1155,'small')
text(49,113,SOURCE_URL,11,MUTED)
c.linkURL(SOURCE_URL,(49,108,1200,125),relative=0)
text(49,74,'Charts regenerated from the revised R script. Cover artwork is original vector geometry. Presenter: Irisbaev Nuriddin.',11,MUTED)
end()

assert page_number == 13
c.save()
print(f'Created {ROOT / "formula_one.pdf"} ({page_number} pages)')
