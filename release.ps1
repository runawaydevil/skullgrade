# release.ps1 - Script para preparar release da versão
# Versão: 0.01
# Desenvolvido por: Pablo Murad
# Contato: pablomurad@pm.me
# Ano: 2026

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$version = "0.01"
$author = "Pablo Murad"
$contact = "pablomurad@pm.me"
$year = "2026"
$releaseDate = Get-Date -Format "yyyy-MM-dd"

Write-Host "=== Preparação de Release v$version ===" -ForegroundColor Cyan
Write-Host "Desenvolvido por: $author ($contact) - $year" -ForegroundColor Cyan
Write-Host "Data: $releaseDate" -ForegroundColor Cyan
Write-Host ""

# Verificar se estamos em um repositório Git
$isGitRepo = Test-Path ".git"
if ($isGitRepo) {
    Write-Host "✓ Repositório Git detectado" -ForegroundColor Green
} else {
    Write-Host "⚠ Repositório Git não detectado" -ForegroundColor Yellow
}

# Verificar se o executável existe
$exePath = "atualizador.exe"
if (Test-Path $exePath) {
    $exeSize = (Get-Item $exePath).Length / 1MB
    Write-Host "✓ Executável encontrado: $exePath ($([math]::Round($exeSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "⚠ Executável não encontrado. Compilando..." -ForegroundColor Yellow
    Write-Host ""
    
    if (Test-Path "build.ps1") {
        & .\build.ps1
        if (-not (Test-Path $exePath)) {
            Write-Host "ERRO: Falha ao compilar executável!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERRO: Script de build não encontrado!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Verificar arquivos necessários
$requiredFiles = @(
    "atualizador.ps1",
    "build.ps1",
    "app.manifest",
    "README.md",
    "CHANGELOG.md",
    ".gitignore"
)

Write-Host "Verificando arquivos necessários..." -ForegroundColor Cyan
$allFilesExist = $true

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file (FALTANDO)" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "ERRO: Alguns arquivos necessários estão faltando!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Criar diretório de release
$releaseDir = "release"
$versionDir = Join-Path $releaseDir "v$version"

if (Test-Path $versionDir) {
    Write-Host "Removendo diretório de release existente..." -ForegroundColor Yellow
    Remove-Item $versionDir -Recurse -Force
}

New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
Write-Host "✓ Diretório de release criado: $versionDir" -ForegroundColor Green

# Copiar arquivos para release
Write-Host ""
Write-Host "Copiando arquivos para release..." -ForegroundColor Cyan

$filesToCopy = @(
    @{Source = $exePath; Dest = "atualizador.exe"; Description = "Executável"},
    @{Source = "README.md"; Dest = "README.md"; Description = "Documentação"},
    @{Source = "CHANGELOG.md"; Dest = "CHANGELOG.md"; Description = "Changelog"},
    @{Source = "RELEASE_NOTES_v0.01.md"; Dest = "RELEASE_NOTES_v0.01.md"; Description = "Release Notes"}
)

foreach ($file in $filesToCopy) {
    if (Test-Path $file.Source) {
        Copy-Item $file.Source -Destination (Join-Path $versionDir $file.Dest) -Force
        Write-Host "  ✓ $($file.Description): $($file.Dest)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($file.Source) não encontrado" -ForegroundColor Yellow
    }
}

# Criar arquivo de informações da versão
$versionInfo = @"
Versão: $version
Data de Release: $releaseDate
Desenvolvido por: $author
Contato: $contact
Ano: $year

Arquivos incluídos:
- atualizador.exe (Executável principal)
- README.md (Documentação)
- CHANGELOG.md (Histórico de mudanças)
- RELEASE_NOTES_v0.01.md (Notas de release)

Requisitos:
- Windows 10 ou Windows 11
- PowerShell 7+ (pwsh.exe)
- Windows Package Manager (winget)
- Privilégios de Administrador
"@

$versionInfo | Out-File -FilePath (Join-Path $versionDir "VERSION_INFO.txt") -Encoding UTF8
Write-Host "  ✓ VERSION_INFO.txt criado" -ForegroundColor Green

# Criar arquivo ZIP do release
Write-Host ""
Write-Host "Criando arquivo ZIP do release..." -ForegroundColor Cyan

$zipName = "AtualizadorWinget-v$version.zip"
$zipPath = Join-Path $releaseDir $zipName

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Usar Compress-Archive do PowerShell
Compress-Archive -Path "$versionDir\*" -DestinationPath $zipPath -Force

if (Test-Path $zipPath) {
    $zipSize = (Get-Item $zipPath).Length / 1MB
    Write-Host "✓ Arquivo ZIP criado: $zipName ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "⚠ Falha ao criar arquivo ZIP" -ForegroundColor Yellow
}

# Resumo
Write-Host ""
Write-Host "=== Resumo do Release ===" -ForegroundColor Cyan
Write-Host "Versão: $version" -ForegroundColor White
Write-Host "Data: $releaseDate" -ForegroundColor White
Write-Host "Diretório: $versionDir" -ForegroundColor White
if (Test-Path $zipPath) {
    Write-Host "Arquivo ZIP: $zipName" -ForegroundColor White
}
Write-Host ""

# Sugestões para Git
if ($isGitRepo) {
    Write-Host "=== Próximos Passos (Git) ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para criar uma tag de release:" -ForegroundColor Yellow
    Write-Host "  git tag -a v$version -m `"Release v$version`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Para fazer push da tag:" -ForegroundColor Yellow
    Write-Host "  git push origin v$version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Para criar um commit de release:" -ForegroundColor Yellow
    Write-Host "  git add ." -ForegroundColor Gray
    Write-Host "  git commit -m `"Release v$version`"" -ForegroundColor Gray
    Write-Host "  git push" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✓ Release v$version preparado com sucesso!" -ForegroundColor Green
Write-Host ""
