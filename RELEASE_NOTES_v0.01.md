# Release Notes - Versão 0.01

**Data de Release:** 2026-01-XX  
**Versão:** 0.01  
**Desenvolvido por:** Pablo Murad (pablomurad@pm.me)

---

## 🎉 Primeira Versão Pública

Esta é a primeira versão pública do **Atualizador de Pacotes Winget**, um aplicativo gráfico para Windows que automatiza a atualização de pacotes instalados via Windows Package Manager (winget).

## ✨ Principais Funcionalidades

### Interface Gráfica Moderna
- Interface intuitiva usando Windows Forms
- Barra de progresso visual com percentual
- Lista de pacotes com status em tempo real
- Informações de versão e créditos exibidas

### Progresso Detalhado
- Progresso individual por pacote
- Status visual: ⏳ Aguardando → → Atualizando → ✓ Concluído / ✗ Erro
- Percentual de conclusão geral
- Atualização em tempo real durante o processo

### Experiência do Usuário
- **UAC solicitado apenas uma vez** ao iniciar o aplicativo
- Atualização silenciosa e não-interativa
- Tratamento robusto de erros
- Mensagens informativas durante todo o processo

### Funcionalidades Técnicas
- Captura automática de pacotes disponíveis para atualização
- Suporte a pacotes com pin e versões desconhecidas
- Atualização individual de cada pacote
- Tratamento especial para pacotes que requerem targeting explícito (ex: Zotero)

## 📦 Conteúdo do Release

### Executável
- `atualizador.exe` - Aplicativo compilado pronto para uso

### Arquivos Fonte
- `atualizador.ps1` - Script principal com interface gráfica
- `build.ps1` - Script de compilação
- `app.manifest` - Manifesto UAC

### Documentação
- `README.md` - Documentação completa
- `CHANGELOG.md` - Histórico de mudanças
- `RELEASE_NOTES_v0.01.md` - Este arquivo

## 🚀 Como Usar

1. **Baixe o executável** `atualizador.exe`
2. **Execute o arquivo** (duplo clique)
3. **Aprove o UAC** quando solicitado (apenas uma vez)
4. **Aguarde** enquanto os pacotes são atualizados
5. **Verifique os resultados** na interface gráfica

## 📋 Requisitos

- Windows 10 ou Windows 11
- PowerShell 7+ (pwsh.exe)
- Windows Package Manager (winget) instalado
- Privilégios de Administrador (solicitados automaticamente)

## 🔧 Compilação a Partir do Código Fonte

Se preferir compilar a partir do código fonte:

```powershell
# Execute o script de build
.\build.ps1
```

O script irá:
- Instalar o módulo PS2EXE automaticamente (se necessário)
- Compilar o script PowerShell em executável
- Embutir o manifesto UAC

## 🐛 Problemas Conhecidos

Nenhum problema conhecido nesta versão inicial.

## 📝 Notas de Versão

- Esta é uma versão inicial e funcional
- O aplicativo foi testado em Windows 10 e Windows 11
- Requer conexão com a internet para atualizar pacotes
- Alguns pacotes podem não aparecer se não tiverem versão detectável

## 🔄 Próximas Versões

Funcionalidades planejadas para versões futuras:
- Log de atualizações
- Opção de selecionar pacotes específicos
- Agendamento de atualizações automáticas
- Notificações de conclusão
- Histórico de atualizações

## 📞 Suporte

Para questões, sugestões ou problemas:
- **Email:** pablomurad@pm.me

## 📄 Licença

Copyright (C) 2026 Pablo Murad

Este projeto é fornecido "como está", sem garantias de qualquer tipo.

---

**Obrigado por usar o Atualizador de Pacotes Winget!**
