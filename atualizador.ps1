# atualizador.ps1 - PowerShell 7+
# Versão: 0.02
# Desenvolvido por: Pablo Murad
# Contato: pablomurad@pm.me
# Ano: 2026

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Informações da versão
$script:Version = "0.02"
$script:Author = "Pablo Murad"
$script:Contact = "pablomurad@pm.me"
$script:Year = "2026"

# Carregar assemblies do Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime

# Detectar se está rodando como EXE compilado
function Test-IsCompiledExe {
    try {
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
        $pwshPath = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if ($pwshPath) {
            return $pwshPath.Source
        }
        $psPath = Get-Command powershell.exe -ErrorAction SilentlyContinue
        if ($psPath) {
            return $psPath.Source
        }
        return "pwsh.exe"
    }
    else {
        return "pwsh.exe"
    }
}

function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        if ($script:IsCompiledExe) {
            [System.Windows.Forms.MessageBox]::Show(
                "Este aplicativo requer privilégios de administrador.`nPor favor, execute como Administrador.",
                "Elevação de Privilégios",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            exit 1
        }
        
        [System.Windows.Forms.MessageBox]::Show(
            "Este aplicativo requer privilégios de administrador.`nReabrindo como Administrador...",
            "Elevação de Privilégios",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        $psPath = Get-PowerShellPath
        $scriptPath = $PSCommandPath

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

# Função para invocar código na thread da UI de forma thread-safe
function Invoke-UIThread {
    param(
        [System.Windows.Forms.Control]$Control,
        [scriptblock]$ScriptBlock
    )
    
    if ($Control.InvokeRequired) {
        $Control.Invoke($ScriptBlock)
    }
    else {
        & $ScriptBlock
    }
}

# Função para exibir notificações toast do Windows
function Show-ToastNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Info"  # Info, Success, Warning, Error
    )
    
    try {
        # Tentar usar Windows.UI.Notifications (Windows 10+)
        try {
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            
            # Criar XML do toast
            $toastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default" />
</toast>
"@
            
            $toastXmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
            $toastXmlDoc.LoadXml($toastXml)
            
            $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXmlDoc)
            $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)
            
            $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Atualizador Winget")
            $notifier.Show($toast)
            
            return $true
        }
        catch {
            # Fallback: usar balão de notificação do sistema
            $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
            $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
            $notifyIcon.BalloonTipTitle = $Title
            $notifyIcon.BalloonTipText = $Message
            
            switch ($Type) {
                "Success" { $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info }
                "Warning" { $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning }
                "Error" { $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error }
                default { $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info }
            }
            
            $notifyIcon.Visible = $true
            $notifyIcon.ShowBalloonTip(5000)
            
            # Limpar após 6 segundos
            Start-Job -ScriptBlock {
                param($icon)
                Start-Sleep -Seconds 6
                $icon.Visible = $false
                $icon.Dispose()
            } -ArgumentList $notifyIcon | Out-Null
            
            return $true
        }
    }
    catch {
        Write-Log "Não foi possível exibir notificação: $_" "Warning"
        return $false
    }
}

# Função para carregar configuração
function Get-Config {
    $configPath = Join-Path $PSScriptRoot "config.json"
    
    if (Test-Path $configPath) {
        try {
            $content = Get-Content $configPath -Raw | ConvertFrom-Json
            return $content
        }
        catch {
            Write-Warning "Erro ao carregar configuração: $_"
        }
    }
    
    # Configuração padrão
    return @{
        ExcludedPackages = @()
        TimeoutSeconds = 300
        SilentMode = $false
        RetryAttempts = 3
        RetryDelaySeconds = 5
        LogLevel = "Info"
    } | ConvertTo-Json | ConvertFrom-Json
}

# Função para salvar configuração
function Save-Config {
    param([object]$Config)
    
    $configPath = Join-Path $PSScriptRoot "config.json"
    $Config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

# Função para escrever log
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $logDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $logFile = Join-Path $logDir "atualizador_$(Get-Date -Format 'yyyy-MM-dd').log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    
    # Retornar entrada de log para exibição na UI
    return $logEntry
}

# Função para obter pacotes para atualizar (melhorada)
function Get-PackagesToUpgrade {
    param(
        [string]$WingetExe,
        [int]$TimeoutSeconds = 60
    )
    
    $packages = @()
    
    try {
        Write-Log "Iniciando obtenção de lista de pacotes..." "Info"
        
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
                                $currentVersion = if ($upgrade.InstalledVersion) { $upgrade.InstalledVersion } else { "Desconhecida" }
                                $availableVersion = if ($upgrade.AvailableVersion) { $upgrade.AvailableVersion } else { "Desconhecida" }
                                
                                if ($packageId -and $packageId -notmatch "^-+$") {
                                    $packages += @{
                                        Id = $packageId
                                        Name = $packageName
                                        CurrentVersion = $currentVersion
                                        AvailableVersion = $availableVersion
                                        Status = "Aguardando"
                                        Progress = 0
                                        ErrorMessage = $null
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Write-Log "Lista de pacotes obtida via JSON: $($packages.Count) pacotes encontrados" "Info"
        }
        catch {
            Write-Log "Falha ao obter lista via JSON, tentando parsing de texto: $_" "Warning"
            
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
                    $lines = $output -split "`n"
                    $inTable = $false
                    $headerFound = $false
                    
                    foreach ($line in $lines) {
                        if ($line -match "Nome\s+Id\s+Versão" -or $line -match "Name\s+Id\s+Version") {
                            $headerFound = $true
                            continue
                        }
                        
                        if ($line -match "^-+$" -and $headerFound) {
                            $inTable = $true
                            continue
                        }
                        
                        if ($inTable -and $line.Trim() -ne "" -and $line -notmatch "^-+$") {
                            if ($line -match "(\S+)\s+([A-Za-z0-9\.\-]+\.[A-Za-z0-9\.\-]+)\s+") {
                                $packageName = $matches[1].Trim()
                                $packageId = $matches[2].Trim()
                                
                                if ($packageId -and $packageId -ne "Id" -and $packageId -notmatch "^-+$") {
                                    $packages += @{
                                        Id = $packageId
                                        Name = $packageName
                                        CurrentVersion = "Desconhecida"
                                        AvailableVersion = "Desconhecida"
                                        Status = "Aguardando"
                                        Progress = 0
                                        ErrorMessage = $null
                                    }
                                }
                            }
                            else {
                                $parts = $line -split "\s{2,}" | Where-Object { $_.Trim() -ne "" }
                                
                                if ($parts.Count -ge 2) {
                                    $packageName = $parts[0].Trim()
                                    $packageId = $parts[1].Trim()
                                    
                                    if ($packageId -and $packageId -ne "Id" -and $packageId -notmatch "^-+$" -and $packageId -match "\.") {
                                        $packages += @{
                                            Id = $packageId
                                            Name = $packageName
                                            CurrentVersion = "Desconhecida"
                                            AvailableVersion = "Desconhecida"
                                            Status = "Aguardando"
                                            Progress = 0
                                            ErrorMessage = $null
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Write-Log "Lista de pacotes obtida via texto: $($packages.Count) pacotes encontrados" "Info"
            }
            catch {
                Write-Log "Erro ao parsear output de texto: $_" "Error"
            }
        }
    }
    catch {
        Write-Log "Erro geral ao obter lista de pacotes: $_" "Error"
    }
    
    return $packages
}

# Função para atualizar pacote com retry
function Update-PackageWithRetry {
    param(
        [string]$WingetExe,
        [hashtable]$Package,
        [object]$Config,
        [System.Collections.Hashtable]$SharedState
    )
    
    $maxRetries = $Config.RetryAttempts
    $retryDelay = $Config.RetryDelaySeconds
    $timeout = $Config.TimeoutSeconds
    
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            Write-Log "Tentativa $attempt de $maxRetries para atualizar $($Package.Name)" "Info"
            
            $wingetArgs = @(
                "upgrade",
                "--id", $Package.Id,
                "--silent",
                "--disable-interactivity",
                "--accept-package-agreements",
                "--accept-source-agreements",
                "--include-unknown",
                "--include-pinned"
            )
            
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $WingetExe
            $processInfo.Arguments = ($wingetArgs -join " ")
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            
            $process.Start() | Out-Null
            $finished = $process.WaitForExit($timeout * 1000)
            
            if (-not $finished) {
                $process.Kill()
                throw "Timeout ao atualizar pacote"
            }
            
            if ($process.ExitCode -eq 0) {
                Write-Log "Pacote $($Package.Name) atualizado com sucesso" "Info"
                $Package.Status = "Concluído"
                $Package.Progress = 100
                return $true
            }
            else {
                $errorOutput = $process.StandardError.ReadToEnd()
                Write-Log "Erro ao atualizar $($Package.Name): ExitCode $($process.ExitCode)" "Warning"
                
                if ($attempt -lt $maxRetries) {
                    $delay = $retryDelay * $attempt  # Backoff exponencial
                    Write-Log "Aguardando $delay segundos antes de tentar novamente..." "Info"
                    Start-Sleep -Seconds $delay
                }
                else {
                    $Package.Status = "Erro"
                    $Package.ErrorMessage = "ExitCode: $($process.ExitCode)"
                    return $false
                }
            }
        }
        catch {
            Write-Log "Exceção ao atualizar $($Package.Name): $_" "Error"
            
            if ($attempt -lt $maxRetries) {
                $delay = $retryDelay * $attempt
                Write-Log "Aguardando $delay segundos antes de tentar novamente..." "Info"
                Start-Sleep -Seconds $delay
            }
            else {
                $Package.Status = "Erro"
                $Package.ErrorMessage = $_.Exception.Message
                return $false
            }
        }
    }
    
    return $false
}

# Função principal da GUI
function Show-UpdaterGUI {
    param([string]$WingetExe)
    
    # Carregar configuração
    $config = Get-Config
    
    # Criar formulário principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Atualizador de Pacotes Winget v$script:Version"
    $form.Size = New-Object System.Drawing.Size(900, 700)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "Sizable"  # Permite arrastar e redimensionar
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.MinimumSize = New-Object System.Drawing.Size(700, 500)
    
    # Painel de título
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Location = New-Object System.Drawing.Point(0, 0)
    $titlePanel.Size = New-Object System.Drawing.Size(900, 50)
    $titlePanel.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $titlePanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $form.Controls.Add($titlePanel)
    
    # Label de título
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Atualizador de Pacotes Winget"
    $titleLabel.Location = New-Object System.Drawing.Point(15, 10)
    $titleLabel.Size = New-Object System.Drawing.Size(600, 20)
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $titlePanel.Controls.Add($titleLabel)
    
    # Label de versão
    $versionLabel = New-Object System.Windows.Forms.Label
    $versionLabel.Text = "v$script:Version - $script:Author"
    $versionLabel.Location = New-Object System.Drawing.Point(15, 30)
    $versionLabel.Size = New-Object System.Drawing.Size(600, 15)
    $versionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $versionLabel.ForeColor = [System.Drawing.Color]::Gray
    $titlePanel.Controls.Add($versionLabel)
    
    # Painel de controles
    $controlPanel = New-Object System.Windows.Forms.Panel
    $controlPanel.Location = New-Object System.Drawing.Point(10, 60)
    $controlPanel.Size = New-Object System.Drawing.Size(870, 50)
    $controlPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($controlPanel)
    
    # Botão Atualizar Tudo
    $updateAllButton = New-Object System.Windows.Forms.Button
    $updateAllButton.Text = "Atualizar Tudo"
    $updateAllButton.Location = New-Object System.Drawing.Point(10, 10)
    $updateAllButton.Size = New-Object System.Drawing.Size(120, 30)
    $updateAllButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $controlPanel.Controls.Add($updateAllButton)
    
    # Botão Pausar/Retomar
    $pauseButton = New-Object System.Windows.Forms.Button
    $pauseButton.Text = "Pausar"
    $pauseButton.Location = New-Object System.Drawing.Point(140, 10)
    $pauseButton.Size = New-Object System.Drawing.Size(100, 30)
    $pauseButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $pauseButton.Enabled = $false
    $controlPanel.Controls.Add($pauseButton)
    
    # Botão Cancelar
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancelar"
    $cancelButton.Location = New-Object System.Drawing.Point(250, 10)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $cancelButton.Enabled = $false
    $controlPanel.Controls.Add($cancelButton)
    
    # Checkbox para seleção individual
    $selectCheckBox = New-Object System.Windows.Forms.CheckBox
    $selectCheckBox.Text = "Permitir seleção individual"
    $selectCheckBox.Location = New-Object System.Drawing.Point(360, 15)
    $selectCheckBox.Size = New-Object System.Drawing.Size(180, 20)
    $selectCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $controlPanel.Controls.Add($selectCheckBox)
    
    # Label de status
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Preparando..."
    $statusLabel.Location = New-Object System.Drawing.Point(10, 120)
    $statusLabel.Size = New-Object System.Drawing.Size(870, 20)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $statusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($statusLabel)
    
    # Barra de progresso global
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 145)
    $progressBar.Size = New-Object System.Drawing.Size(870, 23)
    $progressBar.Style = "Continuous"
    $progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($progressBar)
    
    # Label de percentual
    $percentLabel = New-Object System.Windows.Forms.Label
    $percentLabel.Text = "0%"
    $percentLabel.Location = New-Object System.Drawing.Point(10, 170)
    $percentLabel.Size = New-Object System.Drawing.Size(870, 20)
    $percentLabel.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
    $percentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $percentLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($percentLabel)
    
    # ListView de pacotes
    $packageListView = New-Object System.Windows.Forms.ListView
    $packageListView.Location = New-Object System.Drawing.Point(10, 195)
    $packageListView.Size = New-Object System.Drawing.Size(870, 400)
    $packageListView.View = [System.Windows.Forms.View]::Details
    $packageListView.FullRowSelect = $true
    $packageListView.GridLines = $true
    $packageListView.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $packageListView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    # Adicionar colunas
    $packageListView.Columns.Add("Selecionado", 80) | Out-Null
    $packageListView.Columns.Add("Nome", 250) | Out-Null
    $packageListView.Columns.Add("Versão Atual", 120) | Out-Null
    $packageListView.Columns.Add("Versão Nova", 120) | Out-Null
    $packageListView.Columns.Add("Status", 150) | Out-Null
    $packageListView.Columns.Add("Progresso", 100) | Out-Null
    
    $form.Controls.Add($packageListView)
    
    # Painel de logs (expansível)
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Location = New-Object System.Drawing.Point(10, 600)
    $logPanel.Size = New-Object System.Drawing.Size(870, 0)
    $logPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $logPanel.Visible = $false
    $form.Controls.Add($logPanel)
    
    # TextBox de logs
    $logTextBox = New-Object System.Windows.Forms.TextBox
    $logTextBox.Multiline = $true
    $logTextBox.ScrollBars = "Vertical"
    $logTextBox.ReadOnly = $true
    $logTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $logTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $logPanel.Controls.Add($logTextBox)
    
    # Botão para mostrar/ocultar logs
    $toggleLogsButton = New-Object System.Windows.Forms.Button
    $toggleLogsButton.Text = "Mostrar Logs"
    $toggleLogsButton.Location = New-Object System.Drawing.Point(750, 10)
    $toggleLogsButton.Size = New-Object System.Drawing.Size(100, 30)
    $toggleLogsButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $controlPanel.Controls.Add($toggleLogsButton)
    
    # Variáveis de estado compartilhadas (thread-safe)
    $sharedState = [hashtable]::Synchronized(@{
        Packages = @()
        IsProcessing = $false
        IsPaused = $false
        ShouldCancel = $false
        CurrentIndex = 0
        TotalPackages = 0
        Logs = [System.Collections.ArrayList]::Synchronized(@())
    })
    
    # Função para atualizar UI de forma thread-safe
    $updateUI = {
        param($control, $action)
        if ($control.InvokeRequired) {
            $control.Invoke($action)
        }
        else {
            & $action
        }
    }
    
    # Função para adicionar log à UI
    $addLogToUI = {
        param($message)
        Invoke-UIThread -Control $logTextBox -ScriptBlock {
            $logTextBox.AppendText("$message`r`n")
            $logTextBox.SelectionStart = $logTextBox.Text.Length
            $logTextBox.ScrollToCaret()
        }
    }
    
    # Função para atualizar item na ListView
    $updateListViewItem = {
        param($package)
        
        Invoke-UIThread -Control $packageListView -ScriptBlock {
            $items = $packageListView.Items
            $found = $false
            
            foreach ($item in $items) {
                if ($item.Tag -eq $package.Id) {
                    $found = $true
                    $item.SubItems[1].Text = $package.Name
                    $item.SubItems[2].Text = $package.CurrentVersion
                    $item.SubItems[3].Text = $package.AvailableVersion
                    
                    # Atualizar status com ícone
                    $statusText = switch ($package.Status) {
                        "Aguardando" { "⏳ Aguardando" }
                        "Atualizando" { "→ Atualizando..." }
                        "Concluído" { "✓ Concluído" }
                        "Erro" { "✗ Erro: $($package.ErrorMessage)" }
                        default { $package.Status }
                    }
                    $item.SubItems[4].Text = $statusText
                    $item.SubItems[5].Text = "$($package.Progress)%"
                    
                    # Cores por status
                    if ($package.Status -eq "Concluído") {
                        $item.BackColor = [System.Drawing.Color]::FromArgb(200, 255, 200)
                    }
                    elseif ($package.Status -eq "Erro") {
                        $item.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
                    }
                    elseif ($package.Status -eq "Atualizando") {
                        $item.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
                    }
                    
                    break
                }
            }
            
            if (-not $found) {
                $item = New-Object System.Windows.Forms.ListViewItem("")
                $item.Tag = $package.Id
                $item.Checked = $true
                $item.SubItems.Add($package.Name) | Out-Null
                $item.SubItems.Add($package.CurrentVersion) | Out-Null
                $item.SubItems.Add($package.AvailableVersion) | Out-Null
                
                $statusText = switch ($package.Status) {
                    "Aguardando" { "⏳ Aguardando" }
                    "Atualizando" { "→ Atualizando..." }
                    "Concluído" { "✓ Concluído" }
                    "Erro" { "✗ Erro" }
                    default { $package.Status }
                }
                $item.SubItems.Add($statusText) | Out-Null
                $item.SubItems.Add("0%") | Out-Null
                
                $packageListView.Items.Add($item) | Out-Null
            }
        }
    }
    
    # Runspace para obter lista de pacotes
    $getPackagesRunspace = {
        param($wingetExe, $sharedState, $updateUI, $statusLabel, $addLogToUI, $updateListViewItem)
        
        try {
            Invoke-UIThread -Control $statusLabel -ScriptBlock {
                $statusLabel.Text = "Obtendo lista de pacotes..."
            }
            
            & $addLogToUI "Iniciando busca de pacotes para atualização..."
            
            $packages = Get-PackagesToUpgrade -WingetExe $wingetExe -TimeoutSeconds 60
            
            # Adicionar Zotero explicitamente se não estiver na lista
            $zoteroFound = $false
            foreach ($pkg in $packages) {
                if ($pkg.Id -eq "DigitalScholar.Zotero") {
                    $zoteroFound = $true
                    break
                }
            }
            
            if (-not $zoteroFound) {
                $packages += @{
                    Id = "DigitalScholar.Zotero"
                    Name = "Zotero"
                    CurrentVersion = "Desconhecida"
                    AvailableVersion = "Desconhecida"
                    Status = "Aguardando"
                    Progress = 0
                    ErrorMessage = $null
                }
            }
            
            # Filtrar pacotes excluídos
            $config = Get-Config
            if ($config.ExcludedPackages) {
                $packages = $packages | Where-Object { $_.Id -notin $config.ExcludedPackages }
            }
            
            $sharedState.Packages = $packages
            $sharedState.TotalPackages = $packages.Count
            
            & $addLogToUI "Encontrados $($packages.Count) pacotes para atualização"
            
            # Atualizar ListView
            foreach ($pkg in $packages) {
                & $updateListViewItem $pkg
            }
            
            Invoke-UIThread -Control $statusLabel -ScriptBlock {
                if ($packages.Count -eq 0) {
                    $statusLabel.Text = "Nenhum pacote encontrado para atualizar."
                }
                else {
                    $statusLabel.Text = "$($packages.Count) pacotes encontrados. Clique em 'Atualizar Tudo' para começar."
                }
            }
            
            Invoke-UIThread -Control $updateAllButton -ScriptBlock {
                $updateAllButton.Enabled = $true
            }
            
            # Notificação toast quando atualizações são encontradas
            if ($packages.Count -gt 0) {
                Show-ToastNotification -Title "Atualizações Disponíveis" -Message "$($packages.Count) pacotes podem ser atualizados" -Type "Info"
            }
        }
        catch {
            & $addLogToUI "ERRO ao obter lista: $($_.Exception.Message)"
            Invoke-UIThread -Control $statusLabel -ScriptBlock {
                $statusLabel.Text = "ERRO: $($_.Exception.Message)"
                $statusLabel.ForeColor = [System.Drawing.Color]::Red
            }
            
            # Notificação de erro crítico
            Show-ToastNotification -Title "Erro ao Buscar Atualizações" -Message $_.Exception.Message -Type "Error"
        }
    }
    
    # Runspace para atualizar pacotes
    $updatePackagesRunspace = {
        param($wingetExe, $sharedState, $config, $updateUI, $statusLabel, $progressBar, $percentLabel, $addLogToUI, $updateListViewItem, $updateAllButton, $pauseButton, $cancelButton)
        
        try {
            $sharedState.IsProcessing = $true
            $sharedState.IsPaused = $false
            $sharedState.ShouldCancel = $false
            $sharedState.CurrentIndex = 0
            
            $packages = $sharedState.Packages | Where-Object { $_.Status -eq "Aguardando" }
            $total = $packages.Count
            $current = 0
            
            if ($total -eq 0) {
                & $addLogToUI "Nenhum pacote pendente para atualização"
                $sharedState.IsProcessing = $false
                return
            }
            
            & $addLogToUI "Iniciando atualização de $total pacotes..."
            
            foreach ($pkg in $packages) {
                if ($sharedState.ShouldCancel) {
                    & $addLogToUI "Atualização cancelada pelo usuário"
                    break
                }
                
                # Aguardar se pausado
                while ($sharedState.IsPaused -and -not $sharedState.ShouldCancel) {
                    Start-Sleep -Milliseconds 500
                }
                
                if ($sharedState.ShouldCancel) {
                    break
                }
                
                $current++
                $sharedState.CurrentIndex = $current
                
                # Atualizar status
                $pkg.Status = "Atualizando"
                $pkg.Progress = 0
                & $updateListViewItem $pkg
                
                Invoke-UIThread -Control $statusLabel -ScriptBlock {
                    $statusLabel.Text = "Atualizando: $($pkg.Name)... ($current de $total)"
                }
                
                & $addLogToUI "Atualizando $($pkg.Name) ($current/$total)..."
                
                # Atualizar pacote
                $success = Update-PackageWithRetry -WingetExe $wingetExe -Package $pkg -Config $config -SharedState $sharedState
                
                if ($success) {
                    $pkg.Progress = 100
                    & $addLogToUI "✓ $($pkg.Name) atualizado com sucesso"
                }
                else {
                    & $addLogToUI "✗ Falha ao atualizar $($pkg.Name): $($pkg.ErrorMessage)"
                }
                
                & $updateListViewItem $pkg
                
                # Atualizar progresso global
                $progressPercent = [int](($current / $total) * 100)
                Invoke-UIThread -Control $progressBar -ScriptBlock {
                    $progressBar.Value = $progressPercent
                }
                Invoke-UIThread -Control $percentLabel -ScriptBlock {
                    $percentLabel.Text = "$progressPercent%"
                }
            }
            
            # Concluído
            $completed = ($sharedState.Packages | Where-Object { $_.Status -eq "Concluído" }).Count
            $errors = ($sharedState.Packages | Where-Object { $_.Status -eq "Erro" }).Count
            
            & $addLogToUI "Atualização concluída: $completed sucesso, $errors erros"
            
            Invoke-UIThread -Control $statusLabel -ScriptBlock {
                $statusLabel.Text = "Concluído! $completed sucesso, $errors erros."
            }
            Invoke-UIThread -Control $progressBar -ScriptBlock {
                $progressBar.Value = 100
            }
            Invoke-UIThread -Control $percentLabel -ScriptBlock {
                $percentLabel.Text = "100%"
            }
            Invoke-UIThread -Control $updateAllButton -ScriptBlock {
                $updateAllButton.Enabled = $true
            }
            Invoke-UIThread -Control $pauseButton -ScriptBlock {
                $pauseButton.Enabled = $false
                $pauseButton.Text = "Pausar"
            }
            Invoke-UIThread -Control $cancelButton -ScriptBlock {
                $cancelButton.Enabled = $false
            }
            
            # Notificação toast ao concluir
            if ($errors -eq 0) {
                Show-ToastNotification -Title "Atualização Concluída" -Message "$completed pacotes atualizados com sucesso!" -Type "Success"
            }
            elseif ($completed -gt 0) {
                Show-ToastNotification -Title "Atualização Concluída com Erros" -Message "$completed sucesso, $errors erros" -Type "Warning"
            }
            else {
                Show-ToastNotification -Title "Falha na Atualização" -Message "Nenhum pacote foi atualizado. $errors erros encontrados." -Type "Error"
            }
            
            $sharedState.IsProcessing = $false
        }
        catch {
            & $addLogToUI "ERRO na atualização: $($_.Exception.Message)"
            
            # Notificação de erro crítico
            Show-ToastNotification -Title "Erro Crítico na Atualização" -Message $_.Exception.Message -Type "Error"
            
            $sharedState.IsProcessing = $false
        }
    }
    
    # Event handlers
    $updateAllButton.Add_Click({
        if (-not $sharedState.IsProcessing) {
            $updateAllButton.Enabled = $false
            $pauseButton.Enabled = $true
            $cancelButton.Enabled = $true
            
            $runspace = [runspacefactory]::CreateRunspace()
            $runspace.ApartmentState = "STA"
            $runspace.ThreadOptions = "ReuseThread"
            $runspace.Open()
            
            $ps = [PowerShell]::Create().AddScript($updatePackagesRunspace)
            $ps.Runspace = $runspace
            $ps.AddArgument($WingetExe)
            $ps.AddArgument($sharedState)
            $ps.AddArgument($config)
            $ps.AddArgument($updateUI)
            $ps.AddArgument($statusLabel)
            $ps.AddArgument($progressBar)
            $ps.AddArgument($percentLabel)
            $ps.AddArgument($addLogToUI)
            $ps.AddArgument($updateListViewItem)
            $ps.AddArgument($updateAllButton)
            $ps.AddArgument($pauseButton)
            $ps.AddArgument($cancelButton)
            
            $handle = $ps.BeginInvoke()
            
            # Monitorar conclusão
            $timer = New-Object System.Windows.Forms.Timer
            $timer.Interval = 500
            $timer.Add_Tick({
                if ($handle.IsCompleted) {
                    $timer.Stop()
                    $timer.Dispose()
                    $ps.EndInvoke($handle)
                    $ps.Dispose()
                    $runspace.Close()
                    $runspace.Dispose()
                }
            })
            $timer.Start()
        }
    })
    
    $pauseButton.Add_Click({
        if ($sharedState.IsPaused) {
            $sharedState.IsPaused = $false
            $pauseButton.Text = "Pausar"
            & $addLogToUI "Atualização retomada"
        }
        else {
            $sharedState.IsPaused = $true
            $pauseButton.Text = "Retomar"
            & $addLogToUI "Atualização pausada"
        }
    })
    
    $cancelButton.Add_Click({
        $sharedState.ShouldCancel = $true
        $sharedState.IsPaused = $false
        $cancelButton.Enabled = $false
        $pauseButton.Enabled = $false
        & $addLogToUI "Cancelamento solicitado..."
    })
    
    $toggleLogsButton.Add_Click({
        if ($logPanel.Visible) {
            $logPanel.Visible = $false
            $logPanel.Height = 0
            $toggleLogsButton.Text = "Mostrar Logs"
            $form.Height = 700
        }
        else {
            $logPanel.Visible = $true
            $logPanel.Height = 100
            $toggleLogsButton.Text = "Ocultar Logs"
            $form.Height = 800
        }
    })
    
    # Iniciar obtenção de pacotes ao carregar
    $form.Add_Shown({
        $form.Activate()
        
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions = "ReuseThread"
        $runspace.Open()
        
        $ps = [PowerShell]::Create().AddScript($getPackagesRunspace)
        $ps.Runspace = $runspace
        $ps.AddArgument($WingetExe)
        $ps.AddArgument($sharedState)
        $ps.AddArgument($updateUI)
        $ps.AddArgument($statusLabel)
        $ps.AddArgument($addLogToUI)
        $ps.AddArgument($updateListViewItem)
        
        $handle = $ps.BeginInvoke()
        
        # Monitorar conclusão
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 500
        $timer.Add_Tick({
            if ($handle.IsCompleted) {
                $timer.Stop()
                $timer.Dispose()
                $ps.EndInvoke($handle)
                $ps.Dispose()
                $runspace.Close()
                $runspace.Dispose()
            }
        })
        $timer.Start()
    })
    
    # Limpar ao fechar
    $form.Add_FormClosing({
        $sharedState.ShouldCancel = $true
    })
    
    # Mostrar formulário (não bloqueante)
    $form.Show()
    [System.Windows.Forms.Application]::Run($form)
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
