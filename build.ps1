# build.ps1 - Script para compilar atualizador.ps1 em atualizador.exe
# Versão: 0.02
# Desenvolvido por: Pablo Murad
# Contato: pablomurad@pm.me
# Ano: 2026

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Build Script - Atualizador Winget ===" -ForegroundColor Cyan
Write-Host "Versão: 0.02 - Pablo Murad (pablomurad@pm.me) - 2026" -ForegroundColor Cyan
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
$iconFile = "images\atualizador.ico"
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
if (Test-Path $iconFile) {
    Write-Host "  - Ícone: $iconFile" -ForegroundColor Gray
} else {
    Write-Host "  - Ícone: $iconFile (não encontrado, usando padrão)" -ForegroundColor Yellow
}
Write-Host ""

# Limpar arquivo anterior se existir
if (Test-Path $outputFile) {
    Write-Host "Removendo $outputFile anterior..." -ForegroundColor Yellow
    Remove-Item $outputFile -Force
}

Write-Host "Compilando $scriptFile em $outputFile..." -ForegroundColor Cyan
Write-Host ""

# Obter informações do módulo
$module = Get-Module ps2exe
$moduleBase = if ($module -is [Array]) { $module[0].ModuleBase } else { $module.ModuleBase }

Write-Host "Módulo PS2EXE encontrado em: $moduleBase" -ForegroundColor Gray
Write-Host ""

# Tentar diferentes métodos em ordem
$compilationSuccess = $false
$methods = @()

# Método 1: Win-PS2EXE.exe (executável direto)
$winPs2exeExe = Join-Path $moduleBase "Win-PS2EXE.exe"
if (Test-Path $winPs2exeExe) {
    $methods += @{
        Name = "Win-PS2EXE.exe"
        Command = $winPs2exeExe
        Type = "Executable"
    }
}

# Método 2: Win-PS2EXE (comando do módulo)
$methods += @{
    Name = "Win-PS2EXE"
    Command = "Win-PS2EXE"
    Type = "Cmdlet"
}

# Método 3: ps2exe.ps1 (script direto)
$ps2exeScript = Join-Path $moduleBase "ps2exe.ps1"
if (Test-Path $ps2exeScript) {
    $methods += @{
        Name = "ps2exe.ps1"
        Command = $ps2exeScript
        Type = "Script"
    }
}

# Tentar cada método
foreach ($method in $methods) {
    if ($compilationSuccess) { break }
    
    Write-Host "Tentando método: $($method.Name)..." -ForegroundColor Cyan
    
    try {
        $ErrorActionPreference = "Continue"
        $output = @()
        $errors = @()
        
        # Preparar metadados completos para tornar o executável mais seguro e legítimo
        $metadata = @{
            inputFile = $scriptFile
            outputFile = $outputFile
            noConsole = $true
            requireAdmin = $true
            title = "Atualizador de Pacotes Winget"
            description = "Aplicativo gráfico moderno para atualização automática de pacotes instalados via Windows Package Manager (winget). Desenvolvido por Pablo Murad (pablomurad@pm.me)."
            company = "Pablo Murad"
            product = "Atualizador de Pacotes Winget"
            copyright = "Copyright (C) 2026 Pablo Murad. Todos os direitos reservados."
            version = "0.0.0.2"
            fileVersion = "0.0.0.2"
            productVersion = "0.0.0.2"
        }
        
        # Adicionar ícone se disponível
        if (Test-Path $iconFile) {
            $metadata.icon = $iconFile
        }
        
        # Executar com metadados completos
        if ($method.Type -eq "Executable") {
            # Executável direto
            $args = "-inputFile `"$($metadata.inputFile)`" -outputFile `"$($metadata.outputFile)`" -noConsole -requireAdmin -title `"$($metadata.title)`" -description `"$($metadata.description)`" -company `"$($metadata.company)`" -product `"$($metadata.product)`" -copyright `"$($metadata.copyright)`" -version `"$($metadata.version)`""
            if ($metadata.icon) {
                $args += " -icon `"$($metadata.icon)`""
            }
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $method.Command
            $processInfo.Arguments = $args
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            
            $output = $process.StandardOutput.ReadToEnd()
            $errors = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }
        elseif ($method.Type -eq "Cmdlet") {
            # Comando do módulo com metadados completos
            $cmdletArgs = @(
                "-inputFile", $metadata.inputFile,
                "-outputFile", $metadata.outputFile,
                "-noConsole",
                "-requireAdmin",
                "-title", $metadata.title,
                "-description", $metadata.description,
                "-company", $metadata.company,
                "-product", $metadata.product,
                "-copyright", $metadata.copyright,
                "-version", $metadata.version
            )
            if ($metadata.icon) {
                $cmdletArgs += "-icon", $metadata.icon
            }
            $output = & $method.Command @cmdletArgs 2>&1
            $exitCode = $LASTEXITCODE
        }
        else {
            # Script PowerShell com metadados completos
            $scriptArgs = @(
                "-inputFile", $metadata.inputFile,
                "-outputFile", $metadata.outputFile,
                "-noConsole",
                "-requireAdmin",
                "-title", $metadata.title,
                "-description", $metadata.description,
                "-company", $metadata.company,
                "-product", $metadata.product,
                "-copyright", $metadata.copyright,
                "-version", $metadata.version
            )
            if ($metadata.icon) {
                $scriptArgs += "-icon", $metadata.icon
            }
            $output = & $method.Command @scriptArgs 2>&1
            $exitCode = $LASTEXITCODE
        }
        
        # Mostrar saída
        if ($output) {
            foreach ($line in $output) {
                if ($line -is [System.Management.Automation.ErrorRecord]) {
                    Write-Host $line.ToString() -ForegroundColor Red
                } else {
                    Write-Host $line -ForegroundColor Gray
                }
            }
        }
        
        if ($errors) {
            Write-Host $errors -ForegroundColor Red
        }
        
        if ($exitCode -ne 0 -and $exitCode -ne $null) {
            Write-Host "Exit code: $exitCode" -ForegroundColor Yellow
        }
        
        # Aguardar e verificar se arquivo foi criado
        Start-Sleep -Milliseconds 1500
        
        if (Test-Path $outputFile) {
            $compilationSuccess = $true
            Write-Host ""
            Write-Host "✓ Compilação concluída com sucesso usando $($method.Name)!" -ForegroundColor Green
            break
        } else {
            Write-Host "Método $($method.Name) não gerou o arquivo." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Erro ao executar $($method.Name): $_" -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host "Erro interno: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
    }
    finally {
        $ErrorActionPreference = "Stop"
    }
    
    Write-Host ""
}

    if ($compilationSuccess) {
        Write-Host "Arquivo gerado: $outputFile" -ForegroundColor Cyan
        $fileSize = (Get-Item $outputFile).Length / 1KB
        Write-Host "Tamanho: $([math]::Round($fileSize, 2)) KB" -ForegroundColor Gray
        Write-Host ""
        
        # Calcular hash SHA256 para verificação
        Write-Host "Calculando hash SHA256 para verificação..." -ForegroundColor Cyan
        try {
            $hash = Get-FileHash -Path $outputFile -Algorithm SHA256
            Write-Host "Hash SHA256: $($hash.Hash)" -ForegroundColor Green
            Write-Host ""
            
            # Salvar hash em arquivo
            $hashFile = "$outputFile.sha256"
            $hash.Hash | Out-File -FilePath $hashFile -Encoding ASCII -NoNewline
            Write-Host "Hash salvo em: $hashFile" -ForegroundColor Gray
            Write-Host ""
        }
        catch {
            Write-Host "Aviso: Não foi possível calcular hash SHA256" -ForegroundColor Yellow
        }
        
        Write-Host "Nota: O executável solicitará UAC uma única vez ao iniciar." -ForegroundColor Yellow
        Write-Host ""
        
        # Verificações de segurança e legitimidade
        Write-Host "=== Verificações de Segurança ===" -ForegroundColor Cyan
        Write-Host "Verificando metadados do executável..." -ForegroundColor Gray
        
        try {
            $fileInfo = Get-Item $outputFile
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($outputFile)
            
            Write-Host "  ✓ Arquivo criado: $($fileInfo.Length) bytes" -ForegroundColor Green
            Write-Host "  ✓ Produto: $($versionInfo.ProductName)" -ForegroundColor Green
            Write-Host "  ✓ Empresa: $($versionInfo.CompanyName)" -ForegroundColor Green
            Write-Host "  ✓ Versão: $($versionInfo.FileVersion)" -ForegroundColor Green
            Write-Host "  ✓ Descrição: $($versionInfo.FileDescription)" -ForegroundColor Green
            
            if ([string]::IsNullOrWhiteSpace($versionInfo.ProductName)) {
                Write-Host "  ⚠ AVISO: Nome do produto vazio - pode causar detecção de antivírus" -ForegroundColor Yellow
            }
            if ([string]::IsNullOrWhiteSpace($versionInfo.CompanyName)) {
                Write-Host "  ⚠ AVISO: Nome da empresa vazio - pode causar detecção de antivírus" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ⚠ Não foi possível verificar metadados: $_" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "=== Recomendações para Reduzir Falsos Positivos ===" -ForegroundColor Cyan
        Write-Host "1. Assinar digitalmente o executável com certificado de código (Code Signing)" -ForegroundColor Gray
        Write-Host "2. Testar em VirusTotal antes de distribuir" -ForegroundColor Gray
        Write-Host "3. Distribuir através de canais confiáveis (site oficial, GitHub Releases)" -ForegroundColor Gray
        Write-Host "4. Manter metadados completos e atualizados (já implementado)" -ForegroundColor Green
        Write-Host "5. Evitar ofuscação ou compressão excessiva" -ForegroundColor Gray
        Write-Host ""
    
    # Tentar embutir manifesto manualmente se mt.exe estiver disponível
    $mtPath = Get-Command mt.exe -ErrorAction SilentlyContinue
    if ($mtPath) {
        Write-Host "Embutindo manifesto UAC usando mt.exe..." -ForegroundColor Cyan
        try {
            $mtProcess = Start-Process -FilePath "mt.exe" -ArgumentList "-manifest", $manifestFile, "-outputresource:`"$outputFile;1`"" -NoNewWindow -Wait -PassThru
            if ($mtProcess.ExitCode -eq 0) {
                Write-Host "✓ Manifesto embutido com sucesso!" -ForegroundColor Green
            } else {
                Write-Host "Aviso: Não foi possível embutir manifesto (mt.exe exit code: $($mtProcess.ExitCode))" -ForegroundColor Yellow
                Write-Host "O executável ainda solicitará UAC via -requireAdmin do PS2EXE." -ForegroundColor Gray
            }
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
    Write-Host "Build concluído!" -ForegroundColor Green
}
else {
    Write-Host "ERRO: Todos os métodos de compilação falharam!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Métodos tentados:" -ForegroundColor Yellow
    foreach ($method in $methods) {
        Write-Host "  - $($method.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Sugestões:" -ForegroundColor Yellow
    Write-Host "  1. Verifique se o PowerShell 7+ está instalado" -ForegroundColor Gray
    Write-Host "  2. Tente executar manualmente: Win-PS2EXE -inputFile atualizador.ps1 -outputFile atualizador.exe -noConsole -requireAdmin" -ForegroundColor Gray
    Write-Host "  3. Verifique os logs de erro acima" -ForegroundColor Gray
    exit 1
}
