# build.ps1 - Script para compilar atualizador.ps1 em atualizador.exe
# Versão: 0.01
# Desenvolvido por: Pablo Murad
# Contato: pablomurad@pm.me
# Ano: 2026

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Build Script - Atualizador Winget ===" -ForegroundColor Cyan
Write-Host "Versão: 0.01 - Pablo Murad (pablomurad@pm.me) - 2026" -ForegroundColor Cyan
Write-Host ""

# Verificar se PS2EXE está instalado
$ps2exeModule = Get-Module -ListAvailable -Name ps2exe

if (-not $ps2exeModule) {
    Write-Host "Módulo PS2EXE não encontrado. Instalando..." -ForegroundColor Yellow
    
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
        Write-Host "Módulo PS2EXE instalado com sucesso!" -ForegroundColor Green
    }
    catch {
        Write-Host "ERRO: Falha ao instalar módulo PS2EXE: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Tente instalar manualmente com:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name ps2exe -Scope CurrentUser -Force" -ForegroundColor Yellow
        exit 1
    }
}

# Importar módulo
Import-Module ps2exe -Force

# Verificar se arquivos necessários existem
$scriptFile = "atualizador.ps1"
$manifestFile = "app.manifest"
$outputFile = "atualizador.exe"

if (-not (Test-Path $scriptFile)) {
    Write-Host "ERRO: Arquivo $scriptFile não encontrado!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $manifestFile)) {
    Write-Host "ERRO: Arquivo $manifestFile não encontrado!" -ForegroundColor Red
    exit 1
}

Write-Host "Arquivos encontrados:" -ForegroundColor Green
Write-Host "  - Script: $scriptFile" -ForegroundColor Gray
Write-Host "  - Manifesto: $manifestFile" -ForegroundColor Gray
Write-Host ""

# Limpar arquivo anterior se existir
if (Test-Path $outputFile) {
    Write-Host "Removendo $outputFile anterior..." -ForegroundColor Yellow
    Remove-Item $outputFile -Force
}

Write-Host "Compilando $scriptFile em $outputFile..." -ForegroundColor Cyan
Write-Host ""

try {
    # Converter PowerShell para EXE usando PS2EXE
    # PS2EXE usa parâmetros posicionais ou nomeados dependendo da versão
    # Vamos usar a sintaxe mais comum
    
    Write-Host "Parâmetros de compilação:" -ForegroundColor Gray
    Write-Host "  - Modo: GUI (sem console)" -ForegroundColor Gray
    Write-Host "  - Requer Admin: Sim (UAC)" -ForegroundColor Gray
    Write-Host "  - Manifesto: $manifestFile" -ForegroundColor Gray
    Write-Host ""
    
    # Verificar versão do PS2EXE para usar sintaxe correta
    $ps2exeVersion = (Get-Module ps2exe).Version
    
    # Tentar usar Invoke-ps2exe (versões mais recentes)
    try {
        Invoke-ps2exe -inputFile $scriptFile `
            -outputFile $outputFile `
            -noConsole `
            -requireAdmin `
            -title "Atualizador de Pacotes Winget v0.01" `
            -description "Atualizador de Pacotes Winget - Desenvolvido por Pablo Murad (pablomurad@pm.me) - 2026" `
            -company "Pablo Murad" `
            -product "Atualizador Winget" `
            -copyright "Copyright (C) 2026 Pablo Murad" `
            -version "0.0.0.1"
    }
    catch {
        # Se Invoke-ps2exe não funcionar, tentar ps2exe.ps1 diretamente
        Write-Host "Tentando método alternativo..." -ForegroundColor Yellow
        
        $ps2exeScript = Join-Path (Get-Module ps2exe).ModuleBase "ps2exe.ps1"
        
        if (Test-Path $ps2exeScript) {
            & $ps2exeScript -inputFile $scriptFile `
                -outputFile $outputFile `
                -noConsole `
                -requireAdmin `
                -title "Atualizador de Pacotes Winget v0.01" `
                -description "Atualizador de Pacotes Winget - Desenvolvido por Pablo Murad (pablomurad@pm.me) - 2026" `
                -company "Pablo Murad" `
                -product "Atualizador Winget" `
                -copyright "Copyright (C) 2026 Pablo Murad" `
                -version "0.0.0.1"
        }
        else {
            throw "Não foi possível encontrar ps2exe.ps1 no módulo PS2EXE"
        }
    }
    
    if (Test-Path $outputFile) {
        Write-Host ""
        Write-Host "✓ Compilação concluída com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Arquivo gerado: $outputFile" -ForegroundColor Cyan
        Write-Host "Tamanho: $((Get-Item $outputFile).Length / 1KB) KB" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Nota: O executável solicitará UAC uma única vez ao iniciar." -ForegroundColor Yellow
        Write-Host ""
        
        # Tentar embutir manifesto manualmente se mt.exe estiver disponível
        $mtPath = Get-Command mt.exe -ErrorAction SilentlyContinue
        if ($mtPath) {
            Write-Host "Embutindo manifesto UAC usando mt.exe..." -ForegroundColor Cyan
            try {
                & mt.exe -manifest $manifestFile -outputresource:"$outputFile;1"
                Write-Host "✓ Manifesto embutido com sucesso!" -ForegroundColor Green
            }
            catch {
                Write-Host "Aviso: Não foi possível embutir manifesto automaticamente." -ForegroundColor Yellow
                Write-Host "O executável ainda solicitará UAC via -requireAdmin do PS2EXE." -ForegroundColor Gray
            }
        }
        else {
            Write-Host "Nota: mt.exe não encontrado. O manifesto será aplicado via -requireAdmin." -ForegroundColor Yellow
            Write-Host "Para embutir manualmente (opcional), instale Windows SDK e execute:" -ForegroundColor Gray
            Write-Host "  mt.exe -manifest app.manifest -outputresource:$outputFile;1" -ForegroundColor Gray
        }
        Write-Host ""
    }
    else {
        Write-Host ""
        Write-Host "ERRO: Arquivo $outputFile não foi gerado!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "ERRO durante compilação: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}

Write-Host "Build concluído!" -ForegroundColor Green
