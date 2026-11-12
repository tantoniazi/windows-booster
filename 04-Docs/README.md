# Windows Booster

Interface gráfica para otimizar, limpar e equipar o **Windows 10 e 11** — em um único arquivo PowerShell com WPF (a mesma receita do WinUtil do Chris Titus).

---

## 📥 Como baixar e executar (um único comando)

Copie e cole este comando no **PowerShell** (ou no prompt com `powershell -Command "..."`). Ele baixa o script diretamente do GitHub e já abre a interface gráfica:

```powershell
iwr https://raw.githubusercontent.com/SEU-USUARIO/windows-booster/main/Windows-Booster.ps1 -OutFile "$env:TEMP\Windows-Booster.ps1"; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',"$env:TEMP\Windows-Booster.ps1"
```

### O que cada parte faz:

| Parte | O que faz |
|------|----------|
| `iwr https://raw.githubusercontent.com/...` | **Baixa** o arquivo `Windows-Booster.ps1` do GitHub |
| `-OutFile "$env:TEMP\Windows-Booster.ps1"` | **Salva** em `C:\Users\SEU_USUARIO\AppData\Local\Temp\Windows-Booster.ps1` |
| `; Start-Process powershell` | **Abre** um novo PowerShell |
| `-Verb RunAs` | **Pede permissão de administrador** (UAC - clique em "Sim") |
| `-NoProfile` | Ignora seus arquivos de perfil (mais rápido) |
| `-ExecutionPolicy Bypass` | Permite rodar o script though a policy esteja bloqueando |
| `-STA` | Single Threaded Apartment (necessário para a GUI WPF rodar) |
| `-File "..."` | **Roda** o script que acabou de ser baixado |

---

## 📁 Estrutura de Pastas (organizada por execução)

Ao baixar ou clonar o repositório, a estrutura de arquivos está organizada da seguinte forma:

```
windows-booster/
├── 01-Original-Scripts/          # Scripts originais do projeto
│   ├── removeApps.ps1            # Remove apps UWP (bloatware)
│   ├── silent.bat                # Script legado (.reg + remoção + wallpaper)
│   ├── changeWallpaper.reg       # Troca papel de parede padrão
│   ├── cortana-voiceActivationDisableAboveLockscreen.reg
│   ├── defender-disableAntiSpyware.reg
│   ├── disableActivityFeed.reg
│   ├── disableDynamicDaylightTime.reg
│   ├── disableLockScreenReminders.reg
│   ├── disableLogonBackgroundImage.reg
│   ├── disableRotatingLockScreen.reg
│   ├── disableSubscribedContent.reg
│   ├── disableTransparency.reg
│   ├── explorer-disableAnimationsAndShadow.reg
│   ├── explorer-disableRecentAndFrequent.reg
│   ├── explorer-showFileExt.reg
│   ├── startMenu-hideRecentlyAddedApps.reg
│   ├── startMenu-removeTiles.reg
│   ├── taskbar-removeCortanaAndPeopleBand.reg
│   ├── update-ActiveHours.reg
│   ├── update-DisableDoSvc.reg
│   ├── wall.png                  # Papel de parede do projeto
│   └── screen.png                # Captura de tela antiga
├── 02-Launcher/                  # Launchers para execução rápida
│   └── Iniciar-Windows-Booster.bat  # Duplo clique para abrir a GUI (pede admin)
├── 03-GUI/                       # Interface gráfica principal
│   └── Windows-Booster.ps1       # GUI completa (8 abas, PowerShell + WPF)
├── 04-Docs/                      # Documentação
│   └── README.md                 # Esta página
├── 05-Assets/                    # Imagens e ícones
│   └── icon.svg                  # Ícone do projeto
└── .git/                         # Repositório Git
```

### 🛠️ Ordem de Execução Recomendada

1. **Primeira execução:** Rode o comando de download acima (ou dê dois cliques em `02-Launcher\Iniciar-Windows-Booster.bat`)
2. **Na GUI:** Vá na aba **"Início"** e veja o estado do sistema
3. **Aba "Bloatware":** Desmarque o que não quer remover (itens já vêm marcados por padrão, inclusive OneDrive)
4. **Aba "Tweaks":** Deixe os grupos A-D marcados (seguros) e, se souber o que faz, marque algum do grupo E (risco)
5. **Aba "Desenvolvedor":** Marque Git, VS Code, Chrome, Python, 7-Zip (os mais essenciais)
6. **Aba "Limpeza":** Marque os itens básicos (Temporários do Windows, Lixeira, DNS, Prefetch)
7. Clique no botão **"Otimização recomendada (1 clique)"** no topo → faz tudo de uma vez (ponto de restauração + limpeza + remoção de bloatware + tweaks seguros)
8. **Reinicie o PC** quando o log indicar (opcional, mas recomendado para efeitos visuais completos)

---

## ⚠️ Atentos

- **Sempre faça o ponto de restauração** antes de qualquer otimização (botão "Ponto de restauração" na GUI ou o comando `systemprotect` manual)
- **Grupo E (Risco)** contém tweaks que desativam o Defender e o Windows Update — apenas marque se souber o que faz
- **Após grandes atualizações do Windows**, rode os tweats de novo (a Microsoft costuma restaurar algumas configurações)
- **Este script loga tudo** em `Windows-Booster.log` na pasta do programa

---

## 🛠️ Manual Rápido (modo script legado)

Se preferir usar os scripts originais (`.bat` e `.reg`), eles continuam funcionando na pasta raiz:

```cmd
:: Modo script legado (original)
silent.bat /w /d /t /u

Onde:
/w  Troca o plano de fundo
/d  Desativa o Windows Defender
/t  Não desativa o horário de verão
/u  Desativa o Windows Update
```

> **Observação:** Os scripts legados removem apps e aplicam tweaks via registro, mas não têm a interface gráfica, nem a integração com winget para instalação de programas, nem o log centralizado que a nova GUI tem.