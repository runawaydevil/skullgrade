# atualizador.ps1 - PowerShell 7+
# Versão: 0.01
# Desenvolvido por: Pablo Murad
# Contato: pablomurad@pm.me
# Ano: 2026

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Informações da versão
$script:Version = "0.01"
$script:Author = "Pablo Murad"
$script:Contact = "pablomurad@pm.me"
$script:Year = "2026"

# Carregar assemblies do Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Detectar se está rodando como EXE compilado
function Test-IsCompiledExe {
    try {
        # Quando compilado, $PSCommandPath aponta para o .exe, não para .ps1
        $isExe = $PSCommandPath -like "*.exe" -or 
                 (Get-Command $PSCommandPath -ErrorAction SilentlyContinue) -eq $null
        return $isExe
    }
    catch {
        return $false
    }
}

$script:IsCompiledExe = Test-IsCompiledExe

# Obter caminho do PowerShell
function Get-PowerShellPath {
    if ($script:IsCompiledExe) {
        # Quando compilado, tentar encontrar pwsh.exe no PATH
        $pwshPath = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if ($pwshPath) {
            return $pwshPath.Source
        }
        # Fallback para powershell.exe
        $psPath = Get-Command powershell.exe -ErrorAction SilentlyContinue
        if ($psPath) {
            return $psPath.Source
        }
        return "pwsh.exe"
    }
    else {
        # Quando rodando como script, usar o executável atual
        return "pwsh.exe"
    }
}

function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        # Se compilado como EXE com -requireAdmin, não tentar relançar
        if ($script:IsCompiledExe) {
            [System.Windows.Forms.MessageBox]::Show(
                "Este aplicativo requer privilégios de administrador.`nPor favor, execute como Administrador.",
                "Elevação de Privilégios",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            exit 1
        }
        
        # Quando rodando como script, tentar elevar
        [System.Windows.Forms.MessageBox]::Show(
            "Este aplicativo requer privilégios de administrador.`nReabrindo como Administrador...",
            "Elevação de Privilégios",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        $psPath = Get-PowerShellPath
        $scriptPath = if ($script:IsCompiledExe) { $PSCommandPath } else { $PSCommandPath }

        Start-Process -FilePath $psPath -Verb RunAs -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-NoExit",
            "-File", "`"$scriptPath`""
        )
        exit
    }
}

function Get-WingetPath {
    try {
        $cmd = Get-Command winget -ErrorAction Stop
        return $cmd.Source
    }
    catch {
        throw "winget não encontrado. Certifique-se de que o Windows Package Manager está instalado."
    }
}

function Get-PackagesToUpgrade {
    param(
        [string]$WingetExe,
        [int]$TimeoutSeconds = 60
    )
    
    $packages = @()
    
    try {
        # Tentar primeiro com formato JSON (mais confiável)
        try {
            $job = Start-Job -ScriptBlock {
                param($exe)
                & $exe upgrade --all --include-unknown --include-pinned --output json 2>&1 | Out-String
            } -ArgumentList $WingetExe
            
            $jsonOutput = $null
            if (Wait-Job -Job $job -Timeout $TimeoutSeconds) {
                $jsonOutput = Receive-Job -Job $job
            }
            else {
                Stop-Job -Job $job
                throw "Timeout ao obter lista de pacotes"
            }
            Remove-Job -Job $job
            
            if ($jsonOutput) {
                $jsonData = $jsonOutput | ConvertFrom-Json -ErrorAction Stop
                
                if ($jsonData -and $jsonData.Sources) {
                    foreach ($source in $jsonData.Sources) {
                        if ($source.Upgrades) {
                            foreach ($upgrade in $source.Upgrades) {
                                $packageId = $upgrade.Id
                                $packageName = if ($upgrade.Name) { $upgrade.Name } else { $packageId }
                                
                                if ($packageId -and $packageId -notmatch "^-+$") {
                                    $packages += @{
                                        Id = $packageId
                                        Name = $packageName
                                        Status = "Aguardando"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        catch {
            # Se JSON falhar, tentar parsear output de texto
            try {
                $job = Start-Job -ScriptBlock {
                    param($exe)
                    & $exe upgrade --all --include-unknown --include-pinned 2>&1 | Out-String
                } -ArgumentList $WingetExe
                
                $output = $null
                if (Wait-Job -Job $job -Timeout $TimeoutSeconds) {
                    $output = Receive-Job -Job $job
                }
                else {
                    Stop-Job -Job $job
                    throw "Timeout ao obter lista de pacotes"
                }
                Remove-Job -Job $job
                
                if ($output) {
                    # Parsear output do winget para extrair pacotes
                    $lines = $output -split "`n"
                    $inTable = $false
                    $headerFound = $false
                    
                    foreach ($line in $lines) {
                        # Detectar início da tabela
                        if ($line -match "Nome\s+Id\s+Versão" -or $line -match "Name\s+Id\s+Version") {
                            $headerFound = $true
                            continue
                        }
                        
                        if ($line -match "^-+$" -and $headerFound) {
                            $inTable = $true
                            continue
                        }
                        
                        if ($inTable -and $line.Trim() -ne "" -and $line -notmatch "^-+$") {
                            # Formato típico: Nome    Id    Versão    Disponível    Fonte
                            if ($line -match "(\S+)\s+([A-Za-z0-9\.\-]+\.[A-Za-z0-9\.\-]+)\s+") {
                                $packageName = $matches[1].Trim()
                                $packageId = $matches[2].Trim()
                                
                                if ($packageId -and $packageId -ne "Id" -and $packageId -notmatch "^-+$") {
                                    $packages += @{
                                        Id = $packageId
                                        Name = $packageName
                                        Status = "Aguardando"
                                    }
                                }
                            }
                            else {
                                # Fallback: dividir por espaços múltiplos
                                $parts = $line -split "\s{2,}" | Where-Object { $_.Trim() -ne "" }
                                
                                if ($parts.Count -ge 2) {
                                    $packageName = $parts[0].Trim()
                                    $packageId = $parts[1].Trim()
                                    
                                    if ($packageId -and $packageId -ne "Id" -and $packageId -notmatch "^-+$" -and $packageId -match "\.") {
                                        $packages += @{
                                            Id = $packageId
                                            Name = $packageName
                                            Status = "Aguardando"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch {
                # Se tudo falhar, retornar lista vazia
            }
        }
    }
    catch {
        # Se tudo falhar, retornar lista vazia
    }
    
    return $packages
}

function Update-Package {
    param(
        [string]$WingetExe,
        [string[]]$WingetArgs,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.ListBox]$PackageList,
        [System.Windows.Forms.Label]$StatusLabel,
        [System.Windows.Forms.Label]$PercentLabel,
        [hashtable]$Package,
        [int]$CurrentIndex,
        [int]$TotalPackages,
        [int]$TimeoutSeconds = 300
    )
    
    try {
        # Atualizar status na lista
        $packageIndex = $PackageList.Items.IndexOf("⏳ $($Package.Name) - Aguardando")
        if ($packageIndex -ge 0) {
            $PackageList.Items[$packageIndex] = "→ $($Package.Name) - Atualizando..."
            $Package.Status = "Atualizando"
        }
        
        # Atualizar label de status
        $StatusLabel.Text = "Atualizando: $($Package.Name)... ($CurrentIndex de $TotalPackages)"
        
        # Atualizar barra de progresso e percentual
        $progressPercent = [int](($CurrentIndex / $TotalPackages) * 100)
        $ProgressBar.Value = $progressPercent
        $PercentLabel.Text = "$progressPercent%"
        
        # Processar eventos da UI
        [System.Windows.Forms.Application]::DoEvents()
        
        # Executar atualização com timeout
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $WingetExe
        $processInfo.Arguments = ($WingetArgs -join " ")
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        $process.Start() | Out-Null
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $finished) {
            $process.Kill()
            throw "Timeout ao atualizar pacote"
        }
        
        # Atualizar status baseado no resultado
        if ($process.ExitCode -eq 0) {
            if ($packageIndex -ge 0) {
                $PackageList.Items[$packageIndex] = "✓ $($Package.Name) - Concluído"
                $Package.Status = "Concluído"
            }
        }
        else {
            if ($packageIndex -ge 0) {
                $PackageList.Items[$packageIndex] = "✗ $($Package.Name) - Erro (ExitCode: $($process.ExitCode))"
                $Package.Status = "Erro"
            }
        }
    }
    catch {
        if ($packageIndex -ge 0) {
            $PackageList.Items[$packageIndex] = "✗ $($Package.Name) - Erro: $($_.Exception.Message)"
            $Package.Status = "Erro"
        }
    }
    finally {
        # Processar eventos da UI novamente
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Show-UpdaterGUI {
    param([string]$WingetExe)
    
    # Criar formulário principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Atualizador de Pacotes Winget"
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Label de título com versão
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Atualizador de Pacotes Winget`nv$script:Version - $script:Author ($script:Contact) - $script:Year"
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $titleLabel.Size = New-Object System.Drawing.Size(560, 40)
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
    $form.Controls.Add($titleLabel)
    
    # Label de status
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Preparando..."
    $statusLabel.Location = New-Object System.Drawing.Point(10, 60)
    $statusLabel.Size = New-Object System.Drawing.Size(560, 20)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($statusLabel)
    
    # Barra de progresso
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 85)
    $progressBar.Size = New-Object System.Drawing.Size(560, 23)
    $progressBar.Style = "Continuous"
    $form.Controls.Add($progressBar)
    
    # Label de percentual
    $percentLabel = New-Object System.Windows.Forms.Label
    $percentLabel.Text = "0%"
    $percentLabel.Location = New-Object System.Drawing.Point(10, 110)
    $percentLabel.Size = New-Object System.Drawing.Size(560, 20)
    $percentLabel.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
    $percentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($percentLabel)
    
    # Lista de pacotes
    $packageList = New-Object System.Windows.Forms.ListBox
    $packageList.Location = New-Object System.Drawing.Point(10, 135)
    $packageList.Size = New-Object System.Drawing.Size(560, 280)
    $packageList.Font = New-Object System.Drawing.Font("Consolas", 9)
    $packageList.HorizontalScrollbar = $true
    $form.Controls.Add($packageList)
    
    # Botão Fechar
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Fechar"
    $closeButton.Location = New-Object System.Drawing.Point(250, 425)
    $closeButton.Size = New-Object System.Drawing.Size(100, 30)
    $closeButton.Enabled = $false
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($closeButton)
    
    # Flags comuns para winget
    $common = @(
        "--silent",
        "--disable-interactivity",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--include-unknown",
        "--include-pinned"
    )
    
    # Variáveis de estado
    $script:packages = @()
    $script:currentPackageIndex = 0
    $script:isProcessing = $false
    $script:hasError = $false
    
    # Timer para executar operações de forma assíncrona
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 100
    $timerStep = 0
    
    $timer.Add_Tick({
        try {
            switch ($timerStep) {
                0 {
                    # Passo 0: Obter lista de pacotes
                    $statusLabel.Text = "Obtendo lista de pacotes..."
                    [System.Windows.Forms.Application]::DoEvents()
                    
                    try {
                        $script:packages = Get-PackagesToUpgrade -WingetExe $WingetExe -TimeoutSeconds 60
                        
                        # Adicionar Zotero explicitamente se não estiver na lista
                        $zoteroFound = $false
                        foreach ($pkg in $script:packages) {
                            if ($pkg.Id -eq "DigitalScholar.Zotero") {
                                $zoteroFound = $true
                                break
                            }
                        }
                        
                        if (-not $zoteroFound) {
                            $script:packages += @{
                                Id = "DigitalScholar.Zotero"
                                Name = "Zotero"
                                Status = "Aguardando"
                            }
                        }
                        
                        # Adicionar pacotes à lista
                        foreach ($pkg in $script:packages) {
                            $packageList.Items.Add("⏳ $($pkg.Name) - Aguardando")
                        }
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        if ($script:packages.Count -eq 0) {
                            $statusLabel.Text = "Nenhum pacote encontrado para atualizar."
                            $progressBar.Value = 100
                            $percentLabel.Text = "100%"
                            $closeButton.Enabled = $true
                            $timer.Stop()
                            return
                        }
                        
                        $timerStep = 1
                        $script:currentPackageIndex = 0
                        $script:isProcessing = $true
                    }
                    catch {
                        $statusLabel.Text = "ERRO ao obter lista: $($_.Exception.Message)"
                        $statusLabel.ForeColor = [System.Drawing.Color]::Red
                        $closeButton.Enabled = $true
                        $script:hasError = $true
                        $timer.Stop()
                    }
                }
                
                1 {
                    # Passo 1: Processar cada pacote
                    if ($script:currentPackageIndex -lt $script:packages.Count) {
                        $pkg = $script:packages[$script:currentPackageIndex]
                        $current = $script:currentPackageIndex + 1
                        $total = $script:packages.Count
                        
                        $wingetArgs = @("upgrade", "--id", $pkg.Id) + $common
                        
                        Update-Package -WingetExe $WingetExe `
                            -WingetArgs $wingetArgs `
                            -ProgressBar $progressBar `
                            -PackageList $packageList `
                            -StatusLabel $statusLabel `
                            -PercentLabel $percentLabel `
                            -Package $pkg `
                            -CurrentIndex $current `
                            -TotalPackages $total `
                            -TimeoutSeconds 300
                        
                        $script:currentPackageIndex++
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                    else {
                        # Concluído
                        $statusLabel.Text = "Concluído! Todos os pacotes foram processados."
                        $progressBar.Value = 100
                        $percentLabel.Text = "100%"
                        $closeButton.Enabled = $true
                        $script:isProcessing = $false
                        $timer.Stop()
                    }
                }
            }
        }
        catch {
            $statusLabel.Text = "ERRO: $($_.Exception.Message)"
            $statusLabel.ForeColor = [System.Drawing.Color]::Red
            $closeButton.Enabled = $true
            $script:hasError = $true
            $script:isProcessing = $false
            $timer.Stop()
        }
    })
    
    # Iniciar processamento quando o formulário for exibido
    $form.Add_Shown({
        $form.Activate()
        $timer.Start()
    })
    
    # Parar timer quando fechar
    $form.Add_FormClosing({
        if ($timer.Enabled) {
            $timer.Stop()
        }
        $timer.Dispose()
    })
    
    # Mostrar formulário
    [void]$form.ShowDialog()
    $form.Dispose()
}

try {
    Ensure-Admin
    $wingetExe = Get-WingetPath
    
    Show-UpdaterGUI -WingetExe $wingetExe
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "ERRO: $($_.Exception.Message)`n`n$($_.ScriptStackTrace)",
        "Erro",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}
