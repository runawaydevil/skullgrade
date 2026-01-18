# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [0.01] - 2026-01-XX

### Adicionado
- Interface gráfica moderna usando Windows Forms
- Barra de progresso visual com percentual de conclusão
- Lista de pacotes com status em tempo real (Aguardando → Atualizando → Concluído/Erro)
- Captura automática de pacotes disponíveis para atualização via winget
- Suporte a formato JSON e texto para listagem de pacotes
- Atualização individual de pacotes com progresso detalhado
- Tratamento especial para pacote Zotero (requer targeting explícito)
- Manifesto UAC embutido para solicitação única de privilégios de administrador
- Script de build automatizado (`build.ps1`) para compilação em executável
- Suporte a pacotes com pin e versões desconhecidas
- Flags de atualização silenciosa e não-interativa
- Tratamento robusto de erros com mensagens informativas
- Informações de versão e créditos exibidas na interface
- Documentação completa (README.md)
- Arquivo .gitignore configurado

### Características Técnicas
- Compilação para executável usando PS2EXE
- Aplicação GUI (sem console)
- Requer privilégios de administrador
- Compatível com Windows 10 e Windows 11
- Requer PowerShell 7+ e Windows Package Manager (winget)

### Arquivos Incluídos
- `atualizador.ps1` - Script principal com interface gráfica
- `build.ps1` - Script de compilação para executável
- `app.manifest` - Manifesto UAC para elevação de privilégios
- `README.md` - Documentação completa do projeto
- `.gitignore` - Configuração de arquivos ignorados pelo Git
- `CHANGELOG.md` - Este arquivo

### Notas de Release
Esta é a versão inicial do Atualizador de Pacotes Winget. O aplicativo está funcional e pronto para uso, fornecendo uma interface gráfica intuitiva para atualização de pacotes instalados via winget.

---

**Desenvolvido por:** Pablo Murad  
**Contato:** pablomurad@pm.me  
**Ano:** 2026
