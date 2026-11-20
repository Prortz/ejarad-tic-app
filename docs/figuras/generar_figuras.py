"""Genera las cuatro figuras de Scrum y calidad del informe (velocidad, burn-up,
resultados de calidad y tiempos de respuesta).

Uso (CMD o PowerShell, desde esta carpeta):
    python generar_figuras.py            -> guarda los PNG junto al script
    python generar_figuras.py C:\\ruta   -> guarda los PNG en otra carpeta

Requiere:  pip install matplotlib
Los datos están en la sección DATOS; si cambia una cifra, edítela ahí y vuelva
a ejecutar. Salida: FIG41_velocidad.png, FIG42_burnup.png,
FIG43_resultados_calidad.png y FIG44_tiempos_respuesta.png (1920 x 1080 px).
"""
import os
import sys

import matplotlib

matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

# ═══════════════════════════ DATOS (editar aquí) ═══════════════════════════
SPRINTS = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6']
CIERRES = ['18/09', '02/10', '16/10', '30/10', '13/11', '27/11']
SP_PLANIFICADOS = [5, 13, 15, 11, 8, 8]
SP_TERMINADOS = [5, 13, 15, 11, 8, 8]
INICIO = '07/09'
ALCANCE_INICIAL = 55          # SP del Product Backlog al empezar
ALCANCE_FINAL = 60            # tras sumar HU-13 (5 SP) en el refinamiento del S2
SPRINT_QUE_AMPLIA = 2         # el alcance sube en este Sprint

CALIDAD = [  # etiqueta, obtenido %, umbral %, texto interno, color
    ('Sincronización\noffline (RNF-05)', 100, 95, '20/20 evidencias\n0 duplicados', 'teal'),
    ('Reducción de\nfotos (RNF-06)', 90, 70, 'promedio de\n10 fotos', 'teal'),
    ('Cobertura motor\nTIA-568 (RNF-03)', 100, 80, '33/33 líneas\n14 pruebas', 'corp'),
    ('Lectura QR\nen baja luz (R-02)', 100, None, '10/10\netiquetas', 'corp'),
]
DISPOSITIVO = 'Dispositivo: ABR-NX3 · Android 16'

TIEMPOS = [  # etiqueta, segundos, color
    ('Detalle de proyecto\nantes de la mejora', 2.45, 'naranja'),
    ('Detalle de proyecto\ndespués de la mejora', 1.08, 'verde'),
    ('Carga del dashboard\n(en dispositivo)', 1.50, 'verde'),
]
UMBRAL_S = 2.0
# ═══════════════════════════════════════════════════════════════════════════

NAVY, CORP, CYAN, TEAL = '#061B38', '#003B70', '#00D5E8', '#00A99D'
GREY, STEEL, ORANGE, GREEN, RED = '#DCE3EA', '#64748B', '#F59E0B', '#18B97B', '#EF4444'
plt.rcParams['font.family'] = ['Segoe UI', 'Arial', 'DejaVu Sans']
COLOR = {'teal': TEAL, 'corp': CORP, 'naranja': ORANGE, 'verde': GREEN}


def lienzo(titulo, subtitulo, pie, eje=(0.08, 0.16, 0.86, 0.66), grid='y'):
    fig = plt.figure(figsize=(19.2, 10.8), dpi=100)
    fig.patch.set_facecolor('white')
    fig.add_artist(Rectangle((0, 0.87), 1, 0.13, transform=fig.transFigure, color=NAVY))
    fig.add_artist(Rectangle((0, 0.866), 1, 0.004, transform=fig.transFigure, color=CYAN))
    fig.text(0.035, 0.935, 'EJARAD TIC', color='white', fontsize=26, weight='bold', va='center')
    fig.text(0.035, 0.895, 'S.I.E.I.R.L.', color='white', fontsize=15, va='center')
    fig.add_artist(Rectangle((0.2, 0.89), 0.002, 0.09, transform=fig.transFigure, color=CYAN))
    fig.text(0.5, 0.94, titulo, color='white', fontsize=36, weight='bold', ha='center', va='center')
    fig.text(0.5, 0.895, subtitulo, color=CYAN, fontsize=19, style='italic', ha='center', va='center')
    fig.add_artist(Rectangle((0, 0), 1, 0.075, transform=fig.transFigure, color=NAVY))
    fig.text(0.5, 0.037, pie, color='white', fontsize=16, ha='center', va='center')
    ax = fig.add_axes(list(eje))
    ax.set_facecolor('white')
    for s in ('top', 'right'):
        ax.spines[s].set_visible(False)
    for s in ('left', 'bottom'):
        ax.spines[s].set_color(STEEL)
    ax.tick_params(colors=NAVY, labelsize=16)
    ax.grid(axis=grid, color=GREY, linewidth=1)
    ax.set_axisbelow(True)
    return fig, ax


def fig41(salida):
    prom = sum(SP_TERMINADOS) / len(SP_TERMINADOS)
    cumpl = 100 * sum(SP_TERMINADOS) / sum(SP_PLANIFICADOS)
    fig, ax = lienzo('VELOCIDAD DEL EQUIPO SCRUM', 'Story Points planificados frente a terminados por Sprint',
                     f'Velocidad promedio: {prom:g} SP por Sprint  ·  Cumplimiento: '
                     f'{sum(SP_TERMINADOS)} de {sum(SP_PLANIFICADOS)} SP ({cumpl:.0f} %)')
    x = range(len(SPRINTS))
    w = 0.36
    b1 = ax.bar([i - w / 2 for i in x], SP_PLANIFICADOS, w, color=GREY, edgecolor=STEEL, label='SP planificados')
    b2 = ax.bar([i + w / 2 for i in x], SP_TERMINADOS, w, color=CORP, edgecolor=NAVY, label='SP terminados')
    for barras, color in ((b1, STEEL), (b2, CORP)):
        for r in barras:
            ax.text(r.get_x() + r.get_width() / 2, r.get_height() + 0.3, f'{r.get_height():g}',
                    ha='center', fontsize=17, weight='bold', color=color)
    ax.axhline(prom, color=TEAL, linestyle='--', linewidth=3)
    ax.text(len(SPRINTS) - 0.45, prom + 0.35, f'Promedio: {prom:g} SP', ha='right', fontsize=17,
            weight='bold', color=TEAL)
    ax.set_xticks(list(x))
    ax.set_xticklabels([f'{s}\ncierre {c}' for s, c in zip(SPRINTS, CIERRES)])
    ax.set_ylim(0, max(SP_PLANIFICADOS) * 1.17)
    ax.set_ylabel('Story Points', fontsize=18, color=NAVY)
    ax.legend(loc='upper right', fontsize=17, frameon=False)
    fig.savefig(os.path.join(salida, 'FIG41_velocidad.png'), facecolor='white')


def fig42(salida):
    acum = [0]
    for v in SP_TERMINADOS:
        acum.append(acum[-1] + v)
    etiquetas = [f'Inicio\n{INICIO}'] + [f'{s}\n{c}' for s, c in zip(SPRINTS, CIERRES)]
    fig, ax = lienzo('BURN-UP DEL PRODUCT BACKLOG', 'Story Points terminados acumulados frente al alcance total',
                     f'Alcance final: 13 historias de usuario · {ALCANCE_FINAL} SP  ·  '
                     f'Terminado al cierre del Sprint {len(SPRINTS)} ({CIERRES[-1]}/2026)')
    x = list(range(len(acum)))
    alcance = [ALCANCE_INICIAL if i < SPRINT_QUE_AMPLIA else ALCANCE_FINAL for i in x]
    ax.step(x, alcance, where='post', color=ORANGE, linewidth=4, label='Alcance total (SP)')
    ax.fill_between(x, acum, color='#E8F3F9')
    ax.plot(x, acum, color=CORP, linewidth=5, marker='o', markersize=13, markerfacecolor=CYAN,
            markeredgecolor=NAVY, markeredgewidth=2, label='SP terminados acumulados')
    for i, v in enumerate(acum):
        if i:
            ax.text(i, v - 3.6, f'{v}', ha='center', fontsize=19, weight='bold', color=CORP)
    ax.annotate(f'+ HU-13 ({ALCANCE_FINAL - ALCANCE_INICIAL} SP)\nrefinamiento del S{SPRINT_QUE_AMPLIA}',
                xy=(SPRINT_QUE_AMPLIA, ALCANCE_FINAL), xytext=(SPRINT_QUE_AMPLIA + 0.15, 44),
                fontsize=15, weight='bold', color=ORANGE,
                arrowprops=dict(arrowstyle='->', color=ORANGE, linewidth=2))
    ax.annotate('Alcance completado', xy=(len(acum) - 1, acum[-1]), xytext=(len(acum) - 2.3, acum[-1] + 5),
                fontsize=15, weight='bold', color=GREEN,
                arrowprops=dict(arrowstyle='->', color=GREEN, linewidth=2))
    ax.set_xticks(x)
    ax.set_xticklabels(etiquetas)
    ax.set_ylim(0, ALCANCE_FINAL * 1.17)
    ax.set_xlim(-0.2, len(acum) - 0.7)
    ax.set_ylabel('Story Points', fontsize=18, color=NAVY)
    ax.legend(loc='upper left', fontsize=17, frameon=False)
    fig.savefig(os.path.join(salida, 'FIG42_burnup.png'), facecolor='white')


def fig43(salida):
    fig, ax = lienzo('RESULTADOS DE CALIDAD', 'Valor obtenido frente al umbral de aceptación (ISO/IEC 25010)',
                     f'Todas las métricas superan su umbral  ·  {DISPOSITIVO}')
    x = range(len(CALIDAD))
    bars = ax.bar(x, [c[1] for c in CALIDAD], 0.6, color=[COLOR[c[4]] for c in CALIDAD], edgecolor=NAVY)
    for i, (b, c) in enumerate(zip(bars, CALIDAD)):
        ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1.5, f'{c[1]} %',
                ha='center', fontsize=20, weight='bold', color=NAVY)
        if c[2] is not None:
            ax.hlines(c[2], b.get_x() - 0.06, b.get_x() + b.get_width() + 0.06, colors=ORANGE, linewidth=4)
            ax.text(b.get_x() + b.get_width() + 0.08, c[2], f'umbral {c[2]} %', va='center',
                    fontsize=14, color=ORANGE, weight='bold')
        ax.text(i, 5, c[3], ha='center', fontsize=15, color='white', weight='bold')
    ax.set_xticks(list(x))
    ax.set_xticklabels([c[0] for c in CALIDAD])
    ax.set_ylim(0, 112)
    ax.set_xlim(-0.6, len(CALIDAD) - 0.1)
    ax.set_ylabel('Porcentaje (%)', fontsize=18, color=NAVY)
    fig.savefig(os.path.join(salida, 'FIG43_resultados_calidad.png'), facecolor='white')


def fig44(salida):
    antes, despues = TIEMPOS[0][1], TIEMPOS[1][1]
    mejora = 100 * (antes - despues) / antes
    fig, ax = lienzo('TIEMPOS DE RESPUESTA', f'Pantallas con datos remotos frente al umbral de {UMBRAL_S:g} s (RNF-01)',
                     f'Servidor Supabase en us-east-1  ·  Mejora: consultas en paralelo (−{mejora:.0f} %)',
                     eje=(0.2, 0.16, 0.74, 0.66), grid='x')
    y = list(range(len(TIEMPOS)))[::-1]
    ax.barh(y, [t[1] for t in TIEMPOS], 0.5, color=[COLOR[t[2]] for t in TIEMPOS], edgecolor=NAVY)
    for yi, t in zip(y, TIEMPOS):
        ax.text(t[1] + 0.04, yi, f'{t[1]:.2f} s'.replace('.', ','), va='center', fontsize=21,
                weight='bold', color=NAVY)
    ax.axvline(UMBRAL_S, color=RED, linestyle='--', linewidth=3.5)
    ax.text(UMBRAL_S + 0.03, 1.005, f'Umbral {UMBRAL_S:g} s', color=RED, fontsize=16, weight='bold',
            va='bottom', transform=ax.get_xaxis_transform())
    ax.set_yticks(y)
    ax.set_yticklabels([t[0] for t in TIEMPOS])
    ax.set_xlim(0, 3.0)
    ax.set_xlabel('Segundos', fontsize=18, color=NAVY)
    fig.savefig(os.path.join(salida, 'FIG44_tiempos_respuesta.png'), facecolor='white')


if __name__ == '__main__':
    carpeta = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    os.makedirs(carpeta, exist_ok=True)
    for f in (fig41, fig42, fig43, fig44):
        f(carpeta)
        print('listo:', f.__name__)
    print('Figuras guardadas en', carpeta)
