# Atualizador de Pacotes Winget

**Versão:** 0.01  
**Desenvolvido por:** Pablo Murad  
**Contato:** pablomurad@pm.me  
**Ano:** 2026

## Descrição

Aplicativo gráfico para Windows que automatiza a atualização de pacotes instalados via **Windows Package Manager (winget)**. O aplicativo exibe uma interface gráfica moderna com progresso detalhado por pacote e solicita privilégios de administrador apenas uma vez ao iniciar.

## Características

- ✅ Interface gráfica moderna (Windows Forms)
- ✅ Progresso visual por pacote individual
- ✅ Barra de progresso com percentual
- ✅ Lista de pacotes com status em tempo real
- ✅ Solicitação de UAC única (via manifesto embutido)
- ✅ Atualização silenciosa e não-interativa
- ✅ Suporte a pacotes com pin e versões desconhecidas
- ✅ Tratamento de erros robusto

## Requisitos

- **Windows 10** ou **Windows 11**
- **PowerShell 7+** (pwsh.exe)
- **Windows Package Manager (winget)** instalado
- **Privilégios de Administrador** (solicitados automaticamente)

## Instalação

### Opção 1: Usar o Executável (Recomendado)

1. Execute o script de build para compilar o executável:
   ```powershell
   .\build.ps1
   ```

2. O script irá:
   - Instalar o módulo PS2EXE automaticamente (se necessário)
   - Compilar `atualizador.ps1` em `atualizador.exe`
   - Embutir o manifesto UAC

3. Execute `atualizador.exe` - o UAC será solicitado uma única vez.

### Opção 2: Executar o Script Diretamente

Execute o script PowerShell diretamente:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\atualizador.ps1
```

## Uso

1. **Execute o aplicativo** (`atualizador.exe` ou `atualizador.ps1`)
2. **Aprove o UAC** quando solicitado (apenas na primeira execução)
3. **Aguarde** enquanto o aplicativo:
   - Obtém a lista de pacotes disponíveis para atualização
   - Atualiza cada pacote individualmente
   - Exibe o progresso em tempo real
4. **Verifique os resultados** na lista de pacotes:
   - ✓ = Concluído com sucesso
   - ✗ = Erro durante atualização
   - → = Atualizando no momento
   - ⏳ = Aguardando atualização

## Estrutura do Projeto

```
Scripts/
├── atualizador.ps1      # Script principal com interface gráfica
├── build.ps1            # Script de compilação para EXE
├── app.manifest         # Manifesto UAC para elevação de privilégios
├── instrução.txt        # Instruções de execução (legado)
└── README.md           # Este arquivo
```

## Compilação

Para compilar o executável, execute:

```powershell
.\build.ps1
```

O script de build:
- Verifica e instala o módulo PS2EXE se necessário
- Compila o script PowerShell em executável
- Configura o aplicativo como GUI (sem console)
- Embuti o manifesto UAC (se mt.exe estiver disponível)
- Adiciona metadados (versão, autor, copyright)

### Dependências de Compilação

- **Módulo PS2EXE**: Instalado automaticamente pelo `build.ps1`
- **mt.exe** (opcional): Para embutir manifesto manualmente (Windows SDK)

## Funcionalidades Técnicas

### Captura de Pacotes

O aplicativo utiliza duas estratégias para obter a lista de pacotes:

1. **Formato JSON** (preferencial): Mais confiável e estruturado
2. **Formato de texto** (fallback): Parse do output tabular do winget

### Atualização de Pacotes

Cada pacote é atualizado individualmente com as seguintes flags:

- `--silent`: Instalação silenciosa
- `--disable-interactivity`: Evita prompts interativos
- `--accept-package-agreements`: Aceita acordos automaticamente
- `--accept-source-agreements`: Aceita acordos de fontes
- `--include-unknown`: Inclui pacotes sem versão detectável
- `--include-pinned`: Inclui pacotes com pin

### Pacotes Especiais

O aplicativo sempre tenta atualizar o **Zotero** explicitamente, mesmo que não apareça na lista geral (requer targeting explícito).

## Solução de Problemas

### O executável não solicita UAC

- Verifique se o manifesto foi embutido corretamente
- Execute `mt.exe -manifest app.manifest -outputresource:atualizador.exe;1` manualmente
- Certifique-se de que o PS2EXE foi compilado com `-requireAdmin`

### Nenhum pacote é encontrado

- Verifique se o winget está instalado: `winget --version`
- Execute `winget upgrade` manualmente para verificar se há atualizações
- Alguns pacotes podem não aparecer se não tiverem versão detectável

### Erro ao compilar

- Certifique-se de que o PowerShell 7+ está instalado
- Verifique se há conexão com a internet (para instalar PS2EXE)
- Execute como administrador se necessário

### Interface não aparece

- Verifique se o PowerShell 7+ está instalado
- Certifique-se de que está executando em Windows (não Linux/Mac)
- Verifique os logs de erro no console (se executar o .ps1 diretamente)

## Desenvolvimento

### Estrutura do Código

- **Funções principais:**
  - `Ensure-Admin`: Verifica e eleva privilégios
  - `Get-WingetPath`: Localiza o executável do winget
  - `Get-PackagesToUpgrade`: Obtém lista de pacotes para atualizar
  - `Update-Package`: Atualiza um pacote individual
  - `Show-UpdaterGUI`: Cria e gerencia a interface gráfica

### Personalização

Para modificar o comportamento:

- **Flags do winget**: Edite o array `$common` na função `Show-UpdaterGUI`
- **Pacotes especiais**: Modifique a lógica de adição do Zotero
- **Interface**: Ajuste os controles Windows Forms na função `Show-UpdaterGUI`

## Licença

Copyright (C) 2026 Pablo Murad

Este projeto é fornecido "como está", sem garantias de qualquer tipo.

## Contribuições

Para questões, sugestões ou problemas, entre em contato:
- **Email:** pablomurad@pm.me

## Changelog

### v0.01 (2026)
- Versão inicial
- Interface gráfica com Windows Forms
- Progresso por pacote individual
- Compilação para executável com PS2EXE
- Manifesto UAC embutido
- Suporte a pacotes com pin e versões desconhecidas
