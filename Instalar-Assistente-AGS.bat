@echo off
title Assistente do AGS - Instalador Automatico
color 0A
cls
echo.
echo  ========================================================
echo    ⚡ ASSISTENTE DO AGS - CONFIGURACAO AUTOMATICA
echo  ========================================================
echo.
echo   Configurando o monitoramento do Antigravity nesta maquina...
echo   Por favor, aguarde alguns segundos.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://antigravity-gmail-switcher.vercel.app/setup.ps1 | iex"

echo.
echo  ========================================================
echo    ✅ INSTALACAO CONCLUIDA COM SUCESSO!
echo  ========================================================
echo.
echo   O Assistente do AGS ja esta ativo e rodando silenciosamente.
echo   Voce ja pode fechar esta janela e recarregar seu painel.
echo.
timeout /t 5
