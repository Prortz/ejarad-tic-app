@echo off
rem Genera las figuras de Scrum y calidad del informe (requiere Python).
cd /d "%~dp0"
python -m pip install --quiet matplotlib
python generar_figuras.py
pause
