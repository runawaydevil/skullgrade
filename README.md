# Atualizador de Pacotes Winget

<div align="center">
  <img src="images/atualizador.png" alt="Logo" width="64" height="64">
</div>

**Versão:** 0.02  
**Desenvolvido por:** Pablo Murad  
**Contato:** pablomurad@pm.me  
**Ano:** 2026

## Descrição

Aplicativo gráfico avançado para Windows que automatiza a atualização de pacotes instalados via **Windows Package Manager (winget)**. O aplicativo oferece uma interface gráfica moderna, totalmente responsiva, com funcionalidades avançadas de gerenciamento, logs detalhados e notificações do sistema.

## Características

### Interface e Usabilidade
- ✅ Interface gráfica moderna e totalmente responsiva (janela arrastável e redimensionável)
- ✅ ListView com colunas detalhadas (Nome, Versão Atual, Versão Nova, Status, Progresso)
- ✅ Progresso visual individual por pacote
- ✅ Barra de progresso global com percentual
- ✅ Cores visuais por status (verde=sucesso, vermelho=erro, azul=atualizando)
- ✅ Painel de logs expansível/collapsável
- ✅ Painel de título profissional

### Funcionalidades de Controle
- ✅ Botão "Atualizar Tudo" para iniciar atualizações
- ✅ Botão "Pausar/Retomar" para controlar o processo
- ✅ Botão "Cancelar" para interromper atualizações
- ✅ Seleção individual de pacotes (checkbox)
- ✅ Filtros de visualização

### Operações e Performance
- ✅ Operações assíncronas usando Runspaces (UI nunca trava)
- ✅ Thread-safe para atualizações seguras da interface
- ✅ Solicitação de UAC única (via manifesto embutido)
- ✅ Atualização silenciosa e não-interativa
- ✅ Suporte a pacotes com pin e versões desconhecidas

### Confiabilidade
- ✅ Tratamento de erros robusto com retry automático
- ✅ Retry com backoff exponencial (3 tentativas por padrão)
- ✅ Timeout configurável por operação
- ✅ Detecção e tratamento de pacotes problemáticos
- ✅ Mensagens de erro claras e acionáveis

### Sistema de Logs
- ✅ Logs detalhados em arquivo (um arquivo por dia)
- ✅ Visualização de logs na interface
- ✅ Histórico completo de atualizações (sucesso/falha)
- ✅ Timestamps em todas as entradas de log

### Configuração
- ✅ Sistema de configuração via arquivo JSON (`config.json`)
- ✅ Lista de pacotes excluídos (blacklist)
- ✅ Timeouts configuráveis
- ✅ Número de tentativas configurável
- ✅ Modo silencioso/verboso

### Notificações
- ✅ Notificações toast do Windows quando atualizações disponíveis
- ✅ Notificação ao concluir todas atualizações
- ✅ Alertas de erros críticos
- ✅ Fallback para balões do sistema se toast não disponível

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
3. **Aguarde** enquanto o aplicativo obtém a lista de pacotes disponíveis para atualização
4. **Revise a lista** de pacotes encontrados na interface
5. **Clique em "Atualizar Tudo"** para iniciar o processo de atualização
6. **Monitore o progresso** em tempo real:
   - ✓ = Concluído com sucesso (fundo verde)
   - ✗ = Erro durante atualização (fundo vermelho)
   - → = Atualizando no momento (fundo azul)
   - ⏳ = Aguardando atualização
7. **Use os controles**:
   - **Pausar/Retomar**: Pausa ou retoma o processo de atualização
   - **Cancelar**: Interrompe todas as atualizações pendentes
   - **Mostrar Logs**: Expande/oculta o painel de logs detalhados
8. **Receba notificações** do sistema quando:
   - Atualizações são encontradas
   - Todas as atualizações são concluídas
   - Ocorrem erros críticos

## Estrutura do Projeto

```
skullgrade/
├── atualizador.ps1      # Script principal com interface gráfica moderna
├── build.ps1            # Script de compilação para EXE
├── release.ps1          # Script para preparar releases
├── app.manifest         # Manifesto UAC para elevação de privilégios
├── config.json          # Arquivo de configuração (criado automaticamente)
├── logs/                # Diretório de logs (criado automaticamente)
│   └── atualizador_YYYY-MM-DD.log
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

## Configuração

O aplicativo cria automaticamente um arquivo `config.json` na primeira execução. Você pode editá-lo para personalizar o comportamento:

```json
{
  "ExcludedPackages": [
    "Publisher.PackageName"
  ],
  "TimeoutSeconds": 300,
  "SilentMode": false,
  "RetryAttempts": 3,
  "RetryDelaySeconds": 5,
  "LogLevel": "Info"
}
```

### Opções de Configuração

- **ExcludedPackages**: Lista de IDs de pacotes que devem ser excluídos das atualizações
- **TimeoutSeconds**: Tempo máximo (em segundos) para cada operação de atualização (padrão: 300)
- **SilentMode**: Se `true`, reduz a verbosidade dos logs (padrão: `false`)
- **RetryAttempts**: Número de tentativas em caso de falha (padrão: 3)
- **RetryDelaySeconds**: Delay base entre tentativas, com backoff exponencial (padrão: 5)
- **LogLevel**: Nível de log (Info, Warning, Error) - atualmente todos os níveis são registrados

### Logs

Os logs são salvos automaticamente no diretório `logs/` com o formato `atualizador_YYYY-MM-DD.log`. Cada entrada inclui:
- Timestamp completo
- Nível de log (Info, Warning, Error)
- Mensagem detalhada

Os logs também podem ser visualizados na interface do aplicativo através do botão "Mostrar Logs".

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

### Antivírus bloqueando o executável

**Este é um falso positivo comum** com executáveis compilados a partir de scripts PowerShell. O aplicativo é seguro e não contém malware.

#### Por que isso acontece?

- Executáveis gerados por PS2EXE podem ser detectados como suspeitos por alguns antivírus
- Isso ocorre porque o código PowerShell é empacotado dentro do executável
- É um problema conhecido com ferramentas de compilação de scripts

#### Soluções:

1. **Adicionar exceção no antivírus:**
   - Adicione o arquivo `atualizador.exe` à lista de exceções do seu antivírus
   - Ou adicione a pasta onde o executável está localizado

2. **Verificar integridade:**
   - Após compilar, o script gera um arquivo `atualizador.exe.sha256` com o hash SHA256
   - Você pode verificar a integridade do arquivo executando:
     ```powershell
     Get-FileHash -Path atualizador.exe -Algorithm SHA256
     ```
   - Compare com o hash no arquivo `.sha256`

3. **Executar o script diretamente:**
   - Se preferir, você pode executar o script PowerShell diretamente:
     ```powershell
     pwsh -NoProfile -ExecutionPolicy Bypass -File .\atualizador.ps1
     ```

4. **Reportar falso positivo:**
   - Se o seu antivírus continuar bloqueando, considere reportar como falso positivo
   - Isso ajuda a melhorar a detecção do antivírus

#### Metadados do Executável

O executável inclui metadados completos para identificação:
- **Produto:** Atualizador de Pacotes Winget
- **Empresa:** Pablo Murad
- **Versão:** 0.0.0.1
- **Copyright:** Copyright (C) 2026 Pablo Murad
- **Descrição:** Aplicativo gráfico para atualização automática de pacotes instalados via Windows Package Manager (winget)

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

### v0.02 (2026)
- **MAJOR**: Interface completamente refatorada e modernizada
- **FIX**: Janela agora é totalmente arrastável e responsiva (corrigido problema de janela estática)
- **NEW**: Sistema de runspaces para operações assíncronas (UI nunca trava)
- **NEW**: ListView moderna com colunas detalhadas (Nome, Versão Atual, Versão Nova, Status, Progresso)
- **NEW**: Controles avançados (Pausar/Retomar, Cancelar, Seleção individual)
- **NEW**: Sistema de logs detalhado com arquivos diários
- **NEW**: Visualização de logs na interface (expansível/collapsável)
- **NEW**: Notificações toast do Windows
- **NEW**: Sistema de configuração via JSON
- **NEW**: Retry automático com backoff exponencial
- **NEW**: Cores visuais por status (verde=sucesso, vermelho=erro, azul=atualizando)
- **NEW**: Painel de título profissional
- **IMPROVED**: Parsing melhorado de pacotes (JSON prioritário, fallback robusto)
- **IMPROVED**: Tratamento de erros mais robusto
- **IMPROVED**: Thread-safe para todas operações de UI

### v0.01 (2026)
- Versão inicial
- Interface gráfica com Windows Forms
- Progresso por pacote individual
- Compilação para executável com PS2EXE
- Manifesto UAC embutido
- Suporte a pacotes com pin e versões desconhecidas
