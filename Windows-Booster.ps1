# ============================================================================
#  Windows Booster - GUI para otimizar, limpar e equipar o Windows 10 / 11
#  Baseado nos scripts originais deste repositorio + inteligencia de:
#  Win11Debloat (Raphire), WinUtil (ChrisTitusTech), Windows10Debloater (Sycnex)
#  MIT | Uso por sua conta e risco. Crie um ponto de restauracao!
# ============================================================================
#requires -version 5.1
Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

# --- Auto-elevacao para Administrador ---------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',"`"$PSCommandPath`"")
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms | Out-Null
$ScriptDir = Split-Path -Parent $PSCommandPath
$LogFile   = Join-Path $ScriptDir 'Windows-Booster.log'

# ============================================================================
#  DADOS: TWEAKS (op: reg | regdel | regdelkey | svc | task | cmd | copy)
# ============================================================================
$Tweaks = @(
# ---------- GRUPO A: PRIVACIDADE E TELEMETRIA ----------
@{ Id='a-telemetria'; Group='A'; Checked=$true
   Name='Telemetria basica'
   Desc='AllowTelemetry=1 (so o minimo, mantem o Windows Update saudavel).'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; name='AllowTelemetry'; type='DWord'; value=1}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; name='DoNotShowFeedbackNotifications'; type='DWord'; value=1})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; name='AllowTelemetry'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; name='DoNotShowFeedbackNotifications'}) }
@{ Id='a-diagtrack'; Group='A'; Checked=$true
   Name='Servicos de telemetria (DiagTrack)'
   Desc='Desativa Connected User Experiences e dmwappushservice.'
   Apply=@(@{op='svc'; name='DiagTrack'; startup='Disabled'}
          ,@{op='svc'; name='dmwappushservice'; startup='Disabled'})
   Revert=@(@{op='svc'; name='DiagTrack'; startup='Automatic'}
           ,@{op='svc'; name='dmwappushservice'; startup='Manual'}) }
@{ Id='a-tasks-ceip'; Group='A'; Checked=$true
   Name='Tarefas agendadas de telemetria/CEIP'
   Desc='Compatibility Appraiser, CEIP, Error Reporting, Maps etc.'
   Apply=@(@{op='task'; path='\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'}
          ,@{op='task'; path='\Microsoft\Windows\Application Experience\ProgramDataUpdater'}
          ,@{op='task'; path='\Microsoft\Windows\Autochk\Proxy'}
          ,@{op='task'; path='\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'}
          ,@{op='task'; path='\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'}
          ,@{op='task'; path='\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'}
          ,@{op='task'; path='\Microsoft\Windows\Feedback\Siuf\DmClient'}
          ,@{op='task'; path='\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'}
          ,@{op='task'; path='\Microsoft\Windows\Windows Error Reporting\QueueReporting'}
          ,@{op='task'; path='\Microsoft\Windows\Maps\MapsUpdateTask'}
          ,@{op='task'; path='\Microsoft\Windows\Maps\MapsToastTask'})
   Revert=@(@{op='task'; path='\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Application Experience\ProgramDataUpdater'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Autochk\Proxy'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Feedback\Siuf\DmClient'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Windows Error Reporting\QueueReporting'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Maps\MapsUpdateTask'; enable=$true}
           ,@{op='task'; path='\Microsoft\Windows\Maps\MapsToastTask'; enable=$true}) }
@{ Id='a-anuncios'; Group='A'; Checked=$true
   Name='ID de publicidade e experiencias personalizadas'
   Desc='Desativa anuncios direcionados do Windows.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; name='Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; name='TailoredExperiencesWithDiagnosticDataEnabled'; type='DWord'; value=0})
   Revert=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; name='Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; name='TailoredExperiencesWithDiagnosticDataEnabled'; type='DWord'; value=1}) }
@{ Id='a-feedback'; Group='A'; Checked=$true
   Name='Solicitacoes de feedback do Windows'
   Desc='Para de perguntar "como foi sua experiencia?".'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Siuf\Rules'; name='NumberOfSIUFInPeriod'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Microsoft\Siuf\Rules'; name='NumberOfSIUFInPeriod'}) }
@{ Id='a-atividade'; Group='A'; Checked=$true
   Name='Historico de atividades (repo: disableActivityFeed)'
   Desc='Desativa linha do tempo e sincronizacao de atividades.'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='EnableActivityFeed'; type='DWord'; value=0}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='PublishUserActivities'; type='DWord'; value=0}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='UploadUserActivities'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='EnableActivityFeed'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='PublishUserActivities'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='UploadUserActivities'}) }
@{ Id='a-busca-cortana'; Group='A'; Checked=$true
   Name='Cortana e busca na web no menu iniciar'
   Desc='Busca fica local. Cortana fora. Voz acima do lockscreen desativada (repo).'
   Apply=@(@{op='reg'; path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; name='DisableSearchBoxSuggestions'; type='DWord'; value=1}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; name='AllowCortana'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Speech_OneCore\Preferences'; name='VoiceActivationEnableAboveLockscreen'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; name='DisableSearchBoxSuggestions'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; name='AllowCortana'}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\Speech_OneCore\Preferences'; name='VoiceActivationEnableAboveLockscreen'}) }
@{ Id='a-conteudo'; Group='A'; Checked=$true
   Name='Sugestoes, dicas e apps patrocinados (repo: disableSubscribedContent)'
   Desc='ContentDeliveryManager completo: para ads e auto-instalacao de apps.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338387Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338388Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338389Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338393Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-353694Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-353696Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-353698Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-310093Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SilentInstalledAppsEnabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SystemPaneSuggestionsEnabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SoftLandingEnabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='PreInstalledAppsEnabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='PreInstalledAppsEverEnabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='OemPreInstalledAppsEnabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='FeatureManagementEnabled'; type='DWord'; value=0})
   Revert=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338387Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338388Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338389Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-338393Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-353694Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-353696Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SubscribedContent-353698Enabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SilentInstalledAppsEnabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='SystemPaneSuggestionsEnabled'; type='DWord'; value=1}) }
@{ Id='a-copilot-ia'; Group='A'; Checked=$true
   Name='Copilot, Recall e recursos de IA'
   Desc='Desativa Copilot e analise de dados por IA (intel Win11Debloat).'
   Apply=@(@{op='reg'; path='HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; name='TurnOffWindowsCopilot'; type='DWord'; value=1}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; name='TurnOffWindowsCopilot'; type='DWord'; value=1}
          ,@{op='reg'; path='HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'; name='DisableAIDataAnalysis'; type='DWord'; value=1})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; name='TurnOffWindowsCopilot'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; name='TurnOffWindowsCopilot'}
           ,@{op='regdel'; path='HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'; name='DisableAIDataAnalysis'}) }
@{ Id='a-errorreport'; Group='A'; Checked=$true
   Name='Relatorio de erros (WER)'
   Desc='Para de enviar relatorios de falha para a Microsoft.'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; name='Disabled'; type='DWord'; value=1})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; name='Disabled'}) }
@{ Id='a-input'; Group='A'; Checked=$true
   Name='Personalizacao de teclado/digitacao'
   Desc='Para coleta de texto e tinta para "aprender" sua digitacao.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\InputPersonalization'; name='RestrictImplicitTextCollection'; type='DWord'; value=1}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\InputPersonalization'; name='RestrictImplicitInkCollection'; type='DWord'; value=1}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'; name='HarvestContacts'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Microsoft\InputPersonalization'; name='RestrictImplicitTextCollection'}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\InputPersonalization'; name='RestrictImplicitInkCollection'}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'; name='HarvestContacts'}) }
@{ Id='a-deliveryopt'; Group='A'; Checked=$true
   Name='Delivery Optimization (P2P da Microsoft)'
   Desc='Baixa atualizacoes so da Microsoft, nao compartilha com a internet.'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; name='DODownloadMode'; type='DWord'; value=1})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; name='DODownloadMode'}) }
# ---------- GRUPO B: DESEMPENHO E VISUAL ----------
@{ Id='b-transparencia'; Group='B'; Checked=$true
   Name='Desativar transparencia (repo)'
   Desc='Efeito acrilico consome GPU em maquina fraca.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; name='EnableTransparency'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; name='ColorPrevalence'; type='DWord'; value=0})
   Revert=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; name='EnableTransparency'; type='DWord'; value=1}) }
@{ Id='b-animacoes'; Group='B'; Checked=$true
   Name='Desativar animacoes e sombras (repo)'
   Desc='Explorador rapido: sem Peek, sem minimizar animado, sem sombras na lista.'
   Apply=@(@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='UserPreferencesMask'; type='Binary'; value='90,12,03,80,10,00,00,00'}
          ,@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='DragFullWindows'; type='String'; value='0'}
          ,@{op='reg'; path='HKCU:\Control Panel\Desktop\WindowMetrics'; name='MinAnimate'; type='String'; value='0'}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\DWM'; name='EnableAeroPeek'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\DWM'; name='AlwaysHibernateThumbnails'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='TaskbarAnimations'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ListviewAlphaSelect'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ListviewShadow'; type='DWord'; value=1}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; name='VisualFXSetting'; type='DWord'; value=3})
   Revert=@(@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='UserPreferencesMask'; type='Binary'; value='9E,3E,07,80,12,00,00,00'}
           ,@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='DragFullWindows'; type='String'; value='1'}
           ,@{op='reg'; path='HKCU:\Control Panel\Desktop\WindowMetrics'; name='MinAnimate'; type='String'; value='1'}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\DWM'; name='EnableAeroPeek'; type='DWord'; value=1}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\DWM'; name='AlwaysHibernateThumbnails'}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='TaskbarAnimations'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ListviewAlphaSelect'; type='DWord'; value=1}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ListviewShadow'}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; name='VisualFXSetting'; type='DWord'; value=0}) }
@{ Id='b-menu'; Group='B'; Checked=$true
   Name='Menu mostrar sem atraso'
   Desc='MenuShowDelay 400ms -> 0ms.'
   Apply=@(@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='MenuShowDelay'; type='String'; value='0'})
   Revert=@(@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='MenuShowDelay'; type='String'; value='400'}) }
@{ Id='b-desligar'; Group='B'; Checked=$true
   Name='Desligamento mais rapido'
   Desc='Nao espera processos travados: AutoEndTasks + timeouts curtos.'
   Apply=@(@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='AutoEndTasks'; type='String'; value='1'}
          ,@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='WaitToKillAppTimeout'; type='String'; value='2000'}
          ,@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='HungAppTimeout'; type='String'; value='1000'})
   Revert=@(@{op='regdel'; path='HKCU:\Control Panel\Desktop'; name='AutoEndTasks'}
           ,@{op='regdel'; path='HKCU:\Control Panel\Desktop'; name='WaitToKillAppTimeout'}
           ,@{op='regdel'; path='HKCU:\Control Panel\Desktop'; name='HungAppTimeout'}) }
@{ Id='b-mouse'; Group='B'; Checked=$false
   Name='Desativar aceleracao do mouse'
   Desc='Precision cru - bom para jogos (Enhance Pointer Precision off).'
   Apply=@(@{op='reg'; path='HKCU:\Control Panel\Mouse'; name='MouseSpeed'; type='String'; value='0'}
          ,@{op='reg'; path='HKCU:\Control Panel\Mouse'; name='MouseThreshold1'; type='String'; value='0'}
          ,@{op='reg'; path='HKCU:\Control Panel\Mouse'; name='MouseThreshold2'; type='String'; value='0'})
   Revert=@(@{op='reg'; path='HKCU:\Control Panel\Mouse'; name='MouseSpeed'; type='String'; value='1'}
           ,@{op='reg'; path='HKCU:\Control Panel\Mouse'; name='MouseThreshold1'; type='String'; value='6'}
           ,@{op='reg'; path='HKCU:\Control Panel\Mouse'; name='MouseThreshold2'; type='String'; value='10'}) }
@{ Id='b-sticky'; Group='B'; Checked=$true
   Name='Sem popup de teclas de aderencia'
   Desc='Acaba com o dialogo do 5x Shift.'
   Apply=@(@{op='reg'; path='HKCU:\Control Panel\Accessibility\StickyKeys'; name='Flags'; type='String'; value='506'}
          ,@{op='reg'; path='HKCU:\Control Panel\Accessibility\ToggleKeys'; name='Flags'; type='String'; value='58'}
          ,@{op='reg'; path='HKCU:\Control Panel\Accessibility\Keyboard Response'; name='Flags'; type='String'; value='122'})
   Revert=@(@{op='reg'; path='HKCU:\Control Panel\Accessibility\StickyKeys'; name='Flags'; type='String'; value='510'}
           ,@{op='reg'; path='HKCU:\Control Panel\Accessibility\ToggleKeys'; name='Flags'; type='String'; value='62'}
           ,@{op='reg'; path='HKCU:\Control Panel\Accessibility\Keyboard Response'; name='Flags'; type='String'; value='190'}) }
@{ Id='b-gamedvr'; Group='B'; Checked=$true
   Name='Desativar Game DVR / gravacao de fundo'
   Desc='Xbox Game DVR grava em segundo plano e derruba FPS.'
   Apply=@(@{op='reg'; path='HKCU:\System\GameConfigStore'; name='GameDVR_Enabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; name='AllowGameDVR'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKCU:\System\GameConfigStore'; name='GameDVR_Enabled'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; name='AllowGameDVR'}) }
@{ Id='b-energia'; Group='B'; Checked=$false
   Name='Plano de energia: Desempenho alto'
   Desc='powercfg. Reverte para Equilibrado.'
   Apply=@(@{op='cmd'; line='powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'})
   Revert=@(@{op='cmd'; line='powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e'}) }
# ---------- GRUPO C: EXPLORER, MENU INICIAR E BARRA ----------
@{ Id='c-fileext'; Group='C'; Checked=$true
   Name='Mostrar extensoes de arquivos (repo)'
   Desc='HideFileExt=0 e abrir Este Computador (LaunchTo=1).'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='HideFileExt'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='LaunchTo'; type='DWord'; value=1})
   Revert=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='HideFileExt'; type='DWord'; value=1}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='LaunchTo'}) }
@{ Id='c-recentes'; Group='C'; Checked=$true
   Name='Sem arquivos recentes/frequentes (repo)'
   Desc='Limpa o rastro no Explorer e no Acesso Rapido.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; name='ShowRecent'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; name='ShowFrequent'; type='DWord'; value=0})
   Revert=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; name='ShowRecent'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; name='ShowFrequent'; type='DWord'; value=1}) }
@{ Id='c-recentlyadded'; Group='C'; Checked=$true
   Name='Sem apps recem-adicionados no Iniciar (repo)'
   Desc='Esconde a secao "Adicionados recentemente".'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; name='HideRecentlyAddedApps'; type='DWord'; value=1})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; name='HideRecentlyAddedApps'}) }
@{ Id='c-tiles'; Group='C'; Checked=$true
   Name='Menu iniciar limpo, sem tiles (repo - Win10)'
   Desc='Layout travado vazio via StartLayout.xml (efetivo no Windows 10).'
   Apply=@(@{op='copy'; src='StartLayout.xml'; dst='C:\StartLayout.xml'}
          ,@{op='reg'; path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; name='LockedStartLayout'; type='DWord'; value=1}
          ,@{op='reg'; path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; name='StartLayoutFile'; type='ExpandString'; value='C:\StartLayout.xml'})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; name='LockedStartLayout'}
           ,@{op='regdel'; path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; name='StartLayoutFile'}) }
@{ Id='c-taskbar'; Group='C'; Checked=$true
   Name='Taskbar enxuta (repo)'
   Desc='Sem Cortana, sem People Band, busca so como icone.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People'; name='PeopleBand'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; name='SearchboxTaskbarMode'; type='DWord'; value=1}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ShowCortanaButton'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People'; name='PeopleBand'}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; name='SearchboxTaskbarMode'; type='DWord'; value=2}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ShowCortanaButton'}) }
@{ Id='c-widgets'; Group='C'; Checked=$true
   Name='Desativar Widgets e Chat (Win11)'
   Desc='Tira os botoes de Widgets, Chat e Copilot da barra.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='TaskbarDa'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='TaskbarMn'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ShowCopilotButton'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='TaskbarDa'}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='TaskbarMn'}
           ,@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name='ShowCopilotButton'}) }
@{ Id='c-contextmenu'; Group='C'; Checked=$true
   Name='Menu de contexto classico (Win11)'
   Desc='Restaura o menu "Mostrar mais opcoes" como padrao. Requer reiniciar o Explorer.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; name=''; type='String'; value=''})
   Revert=@(@{op='regdelkey'; path='HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'}) }
# ---------- GRUPO D: TELA DE BLOQUEIO, UPDATE E APARENCIA ----------
@{ Id='d-lockreminders'; Group='D'; Checked=$true
   Name='Sem lembretes acima da tela de bloqueio (repo)'
   Desc='NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK=0.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'; name='NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK'; type='DWord'; value=0})
   Revert=@(@{op='regdel'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'; name='NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK'}) }
@{ Id='d-rotating'; Group='D'; Checked=$true
   Name='Sem rotacao de imagem do lockscreen (repo)'
   Desc='Desativa Spotlight e overlay na tela de bloqueio.'
   Apply=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='RotatingLockScreenEnabled'; type='DWord'; value=0}
          ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='RotatingLockScreenOverlayEnabled'; type='DWord'; value=0})
   Revert=@(@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='RotatingLockScreenEnabled'; type='DWord'; value=1}
           ,@{op='reg'; path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; name='RotatingLockScreenOverlayEnabled'; type='DWord'; value=1}) }
@{ Id='d-logonbg'; Group='D'; Checked=$true
   Name='Sem imagem de fundo do logon (repo)'
   Desc='Tela de login com cor solida (mais leve).'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='DisableLogonBackgroundImage'; type='DWord'; value=1})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; name='DisableLogonBackgroundImage'}) }
@{ Id='d-activehours'; Group='D'; Checked=$true
   Name='Horario ativo 07h-23h (repo)'
   Desc='Windows nao reinicia sozinho nesse intervalo.'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; name='ActiveHoursStart'; type='DWord'; value=7}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; name='ActiveHoursEnd'; type='DWord'; value=23})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; name='ActiveHoursStart'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; name='ActiveHoursEnd'}) }
@{ Id='d-noreboot'; Group='D'; Checked=$true
   Name='Sem reinicio automatico com usuario logado'
   Desc='Windows Update nunca reinicia enquanto voce usa o PC.'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; name='NoAutoRebootWithLoggedOnUsers'; type='DWord'; value=1})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; name='NoAutoRebootWithLoggedOnUsers'}) }
@{ Id='d-wallpaper'; Group='D'; Checked=$false
   Name='Aplicar papel de parede do projeto (repo, /w)'
   Desc='Copia wall.png e aplica como fundo (como o silent.bat /w).'
   Apply=@(@{op='copy'; src='wall.png'; dst='C:\Windows\Web\Wallpaper\Theme2\wall.png'}
          ,@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='WallPaper'; type='String'; value='C:\Windows\Web\Wallpaper\Theme2\wall.png'}
          ,@{op='cmd'; line='rundll32.exe user32.dll,UpdatePerUserSystemParameters'})
   Revert=@(@{op='reg'; path='HKCU:\Control Panel\Desktop'; name='WallPaper'; type='String'; value='C:\Windows\Web\Wallpaper\Windows\img0.jpg'}
           ,@{op='cmd'; line='rundll32.exe user32.dll,UpdatePerUserSystemParameters'}) }
# ---------- GRUPO E: RISCO (DESATIVADO POR PADRAO - LEIA AS DESCricOES) ----------
@{ Id='e-defender'; Group='E'; Checked=$false
   Name='[RISCO] Desativar Windows Defender'
   Desc='Deixa o PC desprotegido se voce nao instalar outro antivirus! O Tamper Protection pode bloquear: desative-o manualmente se falhar.'
   Apply=@(@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; name='DisableAntiSpyware'; type='DWord'; value=1}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; name='DisableRealtimeMonitoring'; type='DWord'; value=1}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'; name='TamperProtection'; type='DWord'; value=0}
          ,@{op='cmd'; line='powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring 1"'})
   Revert=@(@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; name='DisableAntiSpyware'}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; name='DisableRealtimeMonitoring'}
           ,@{op='cmd'; line='powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring 0"'}) }
@{ Id='e-wupdate'; Group='E'; Checked=$false
   Name='[RISCO] Desativar Windows Update'
   Desc='Para wuauserv, bits e DoSvc (repo update-DisableDoSvc). PC sem atualizacoes = inseguro. Use so em kiosco/maquina de teste.'
   Apply=@(@{op='reg'; path='HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc'; name='Start'; type='DWord'; value=4}
          ,@{op='reg'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; name='NoAutoUpdate'; type='DWord'; value=1}
          ,@{op='cmd'; line='sc config bits start= disabled'}
          ,@{op='cmd'; line='sc config wuauserv start= disabled'}
          ,@{op='cmd'; line='sc config dosvc start= disabled'}
          ,@{op='cmd'; line='net stop wuauserv'})
   Revert=@(@{op='reg'; path='HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc'; name='Start'; type='DWord'; value=2}
           ,@{op='regdel'; path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; name='NoAutoUpdate'}
           ,@{op='cmd'; line='sc config bits start= delayed-auto'}
           ,@{op='cmd'; line='sc config wuauserv start= delayed-auto'}) }
@{ Id='e-daylight'; Group='E'; Checked=$false
   Name='[RISCO] Desativar horario de verao dinamico (repo)'
   Desc='Congela o fuso (DaylightBias=0). So use se o relogio errar sempre.'
   Apply=@(@{op='reg'; path='HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; name='DynamicDaylightTimeDisabled'; type='DWord'; value=1}
          ,@{op='reg'; path='HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; name='DaylightBias'; type='DWord'; value=0}
          ,@{op='reg'; path='HKLM:\SYSTEM\ControlSet001\Control\TimeZoneInformation'; name='DynamicDaylightTimeDisabled'; type='DWord'; value=1}
          ,@{op='reg'; path='HKLM:\SYSTEM\ControlSet001\Control\TimeZoneInformation'; name='DaylightBias'; type='DWord'; value=0})
   Revert=@(@{op='reg'; path='HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; name='DynamicDaylightTimeDisabled'; type='DWord'; value=0}
           ,@{op='reg'; path='HKLM:\SYSTEM\ControlSet001\Control\TimeZoneInformation'; name='DynamicDaylightTimeDisabled'; type='DWord'; value=0}) }
@{ Id='e-sysmain'; Group='E'; Checked=$false
   Name='[RISCO] Desativar SysMain (Superfetch)'
   Desc='Pode ajudar em HD mecanico lento, piora em SSD moderno.'
   Apply=@(@{op='svc'; name='SysMain'; startup='Disabled'})
   Revert=@(@{op='svc'; name='SysMain'; startup='Automatic'}) }
@{ Id='e-xboxsvc'; Group='E'; Checked=$false
   Name='[RISCO] Desativar servicos do Xbox'
   Desc='Quebra Game Bar, capturas Win+G e jogos da Xbox/Store.'
   Apply=@(@{op='svc'; name='XblAuthManager'; startup='Disabled'}
          ,@{op='svc'; name='XblGameSave'; startup='Disabled'}
          ,@{op='svc'; name='XboxNetApiSvc'; startup='Disabled'}
          ,@{op='svc'; name='XboxGipSvc'; startup='Disabled'})
   Revert=@(@{op='svc'; name='XblAuthManager'; startup='Manual'}
           ,@{op='svc'; name='XblGameSave'; startup='Manual'}
           ,@{op='svc'; name='XboxNetApiSvc'; startup='Manual'}
           ,@{op='svc'; name='XboxGipSvc'; startup='Manual'}) }
@{ Id='e-remote'; Group='E'; Checked=$false
   Name='[RISCO] Desativar Area de Trabalho Remota e Remote Registry'
   Desc='Fecha portas de acesso remoto nativas. Nao use se voce depende de RDP.'
   Apply=@(@{op='svc'; name='RemoteRegistry'; startup='Disabled'}
          ,@{op='reg'; path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'; name='fDenyTSConnections'; type='DWord'; value=1})
   Revert=@(@{op='svc'; name='RemoteRegistry'; startup='Disabled'}
           ,@{op='reg'; path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'; name='fDenyTSConnections'; type='DWord'; value=0}) }
)

# ============================================================================
#  DADOS: APPS BLOATWARE (padrao Get-AppxPackage -Name; intel Sycnex + repo)
# ============================================================================
$AppxApps = @(
@{ Patterns=@('CandyCrush','CrashOfCars','Dolby','Facebook','FarmVille','Flipboard','HiddenCity','MarchofEmpires','Netflix','PandoraMedia','Royal Revolt','Sway','Twitter','Wunderlist','Duolingo','EclipseManager','ActiproSoftware','AdobeSystemsIncorporated'); Name='Apps de terceiros OEM (jogos etc.)'; Checked=$true }
@{ Patterns=@('Microsoft.3DBuilder'); Name='3D Builder'; Checked=$true }
@{ Patterns=@('Microsoft.3DViewer'); Name='3D Viewer'; Checked=$true }
@{ Patterns=@('Microsoft.Print3D'); Name='Print 3D'; Checked=$true }
@{ Patterns=@('Microsoft.Microsoft3DViewer'); Name='3D Viewer (variacao)'; Checked=$true }
@{ Patterns=@('Microsoft.BingFinance'); Name='Bing Dinheiro'; Checked=$true }
@{ Patterns=@('Microsoft.BingNews','Microsoft.BingNewsForPhone'); Name='Bing Noticias'; Checked=$true }
@{ Patterns=@('Microsoft.BingSports'); Name='Bing Esportes'; Checked=$true }
@{ Patterns=@('Microsoft.BingWeather'); Name='Bing Clima (repo: Weather)'; Checked=$true }
@{ Patterns=@('Microsoft.BingSearch'); Name='Bing Search (Web Experience)'; Checked=$true }
@{ Patterns=@('Microsoft.Getstarted'); Name='Dicas (repo: Getstarted)'; Checked=$true }
@{ Patterns=@('Microsoft.GetHelp'); Name='Obter Ajuda'; Checked=$true }
@{ Patterns=@('Microsoft.WindowsFeedbackHub'); Name='Feedback Hub (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.Messaging'); Name='Messaging'; Checked=$true }
@{ Patterns=@('Microsoft.Microsoft3DPreview'); Name='3D Preview'; Checked=$true }
@{ Patterns=@('Microsoft.MicrosoftOfficeHub'); Name='Hub do Office (repo: office)'; Checked=$true }
@{ Patterns=@('Microsoft.MicrosoftSolitaireCollection'); Name='Solitario Collection'; Checked=$true }
@{ Patterns=@('Microsoft.MicrosoftStickyNotes'); Name='Sticky Notes (desmarque se usa)'; Checked=$false }
@{ Patterns=@('Microsoft.MixedReality.Portal'); Name='Portal de Realidade Misturada (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.Office.OneNote','Microsoft.OneNote'); Name='OneNote UWP (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.OneConnect'); Name='Paga por uso (repo: OneConnect)'; Checked=$true }
@{ Patterns=@('Microsoft.People'); Name='Pessoas'; Checked=$true }
@{ Patterns=@('Microsoft.Print3D'); Name='Print3D'; Checked=$true }
@{ Patterns=@('Microsoft.SkypeApp'); Name='Skype (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.Todos'); Name='Microsoft To Do'; Checked=$true }
@{ Patterns=@('Microsoft.Wallet'); Name='Wallet'; Checked=$true }
@{ Patterns=@('Microsoft.Windows.Photos'); Name='Fotos (desmarque se usa)'; Checked=$false }
@{ Patterns=@('Microsoft.WindowsAlarms'); Name='Alarmes e Relogio'; Checked=$false }
@{ Patterns=@('Microsoft.windowscommunicationsapps'); Name='Mail e Calendario'; Checked=$false }
@{ Patterns=@('Microsoft.WindowsMaps'); Name='Mapas'; Checked=$true }
@{ Patterns=@('Microsoft.WindowsPhone'); Name='Windows Phone Companion'; Checked=$true }
@{ Patterns=@('Microsoft.WindowsSoundRecorder'); Name='Gravador de Voz'; Checked=$false }
@{ Patterns=@('Microsoft.YourPhone','Microsoft.Windows.CrossDevice'); Name='Vincular ao Celular (repo: Phone)'; Checked=$true }
@{ Patterns=@('Microsoft.ZuneMusic'); Name='Groove Musica / Media'; Checked=$true }
@{ Patterns=@('Microsoft.ZuneVideo'); Name='Filmes e TV (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.549981C3F5F10'); Name='Cortana (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.MixedReality'); Name='MixedReality (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.Office.Desktop'); Name='Office Desktop stub (repo)'; Checked=$true }
@{ Patterns=@('Microsoft.MSPaint'); Name='Paint 3D (repo: MSPaint)'; Checked=$true }
@{ Patterns=@('Microsoft.PowerAutomateDesktop'); Name='Power Automate Desktop'; Checked=$true }
@{ Patterns=@('MicrosoftTeams','MSTeams'); Name='Teams pessoal (consumidor)'; Checked=$true }
@{ Patterns=@('Microsoft.MicrosoftTeams'); Name='Teams (variacao)'; Checked=$true }
@{ Patterns=@('Microsoft.Family'); Name='Family Safety'; Checked=$true }
@{ Patterns=@('Microsoft.GamingApp'); Name='Xbox Console Companion (repo: xbox)'; Checked=$true }
@{ Patterns=@('Microsoft.XboxApp'); Name='Xbox (repo: xbox)'; Checked=$true }
@{ Patterns=@('Microsoft.XboxGamingOverlay'); Name='Xbox Game Bar (Win+G - desmarque se usa captura)'; Checked=$false }
@{ Patterns=@('Microsoft.XboxIdentityProvider'); Name='Xbox Identity (jogos precisam - desmarque se joga)'; Checked=$false }
@{ Patterns=@('Microsoft.XboxSpeechToTextOverlay'); Name='Xbox Speech Overlay'; Checked=$true }
@{ Patterns=@('Microsoft.Xbox.TCUI'); Name='Xbox TCUI (jogos precisam - desmarque se joga)'; Checked=$false }
@{ Patterns=@('SpotifyAB.SpotifyMusic'); Name='Spotify (repo)'; Checked=$true }
@{ Patterns=@('king.com.*'); Name='Jogos King (Candy Crush friends)'; Checked=$true }
@{ Patterns=@('Microsoft.Windows.DevHome'); Name='Dev Home (Win11)'; Checked=$true }
@{ Patterns=@('Microsoft.OutlookForWindows'); Name='Novo Outlook (Win11)'; Checked=$true }
@{ Patterns=@('Microsoft.Copilot'); Name='App Copilot (Win11)'; Checked=$true }
@{ Patterns=@('Clipchamp.Clipchamp'); Name='Clipchamp (Win11)'; Checked=$true }
@{ Patterns=@('Microsoft.Whiteboard'); Name='Whiteboard'; Checked=$true }
@{ Patterns=@('Microsoft.MicrosoftJournal'); Name='Microsoft Journal'; Checked=$true }
)
# ============================================================================
#  DADOS: LIMPEZA
# ============================================================================
$CleanTasks = @(
@{ Id='temp'; Name='Temporarios do usuario (%TEMP%)'; Checked=$true }
@{ Id='witemp'; Name='Temporarios do Windows (C:\Windows\Temp)'; Checked=$true }
@{ Id='wu'; Name='Cache do Windows Update (SoftwareDistribution\Download)'; Checked=$true }
@{ Id='recycle'; Name='Esvaziar Lixeira'; Checked=$true }
@{ Id='prefetch'; Name='Prefetch (recria sozinho)'; Checked=$true }
@{ Id='thumbs'; Name='Cache de miniaturas'; Checked=$true }
@{ Id='dns'; Name='Limpar cache DNS (flushdns)'; Checked=$true }
@{ Id='dumps'; Name='Dumps de memoria e erros (Minidump/MEMORY.DMP)'; Checked=$true }
@{ Id='edgelog'; Name='Cache/logs do Edge e Chrome (nao toca em senhas)'; Checked=$false }
@{ Id='caps'; Name='Recursos opcionais inuteis (WordPad, IE, Steps Recorder, Quick Assist)'; Checked=$false }
@{ Id='windowsold'; Name='[RISCO] Windows.old / instalacoes antigas'; Checked=$false }
@{ Id='dism'; Name='[LENT0] DISM StartComponentCleanup (WinSxS, demora minutos)'; Checked=$false }
)
# ============================================================================
#  DADOS: CATALOGOS WINGET
# ============================================================================
$DevApps = @(
@{ Id='Git.Git'; Name='Git'; Checked=$true }
@{ Id='Microsoft.VisualStudioCode'; Name='VS Code'; Checked=$true }
@{ Id='Google.Chrome'; Name='Google Chrome'; Checked=$true }
@{ Id='Python.Python.3.12'; Name='Python 3.12'; Checked=$true }
@{ Id='7zip.7zip'; Name='7-Zip'; Checked=$true }
@{ Id='OpenJS.NodeJS.LTS'; Name='Node.js LTS'; Checked=$false }
@{ Id='Microsoft.PowerShell'; Name='PowerShell 7'; Checked=$false }
@{ Id='Microsoft.WindowsTerminal'; Name='Windows Terminal'; Checked=$false }
@{ Id='Microsoft.PowerToys'; Name='PowerToys'; Checked=$false }
@{ Id='Notepad++.Notepad++'; Name='Notepad++'; Checked=$false }
@{ Id='Docker.DockerDesktop'; Name='Docker Desktop (pede WSL2)'; Checked=$false }
@{ Id='Microsoft.VisualStudio.2022.Community'; Name='Visual Studio 2022 Community (grande)'; Checked=$false }
@{ Id='Microsoft.dotnet'; Name='.NET SDK'; Checked=$false }
@{ Id='GoLang.Go'; Name='Go'; Checked=$false }
@{ Id='JetBrains.Toolbox'; Name='JetBrains Toolbox'; Checked=$false }
@{ Id='Microsoft.SQLServerManagementStudio'; Name='SQL Server Management Studio'; Checked=$false }
)
$DevFeatures = @(
@{ Id='wsl'; Name='WSL2 (Ubuntu) - dism + wsl --install'; Checked=$false }
@{ Id='hyperv'; Name='Hyper-V - dism /all /norestart'; Checked=$false }
@{ Id='net35'; Name='.NET Framework 3.5 - dism /all /norestart'; Checked=$false }
)
$IobitApps = @(
@{ Id='IObit.Uninstaller'; Name='IObit Uninstaller'; Checked=$true }
@{ Id='IObit.DriverBooster'; Name='IObit Driver Booster'; Checked=$true }
@{ Id='IObit.AdvancedSystemCare'; Name='IObit Advanced SystemCare'; Checked=$true }
)
$DriverApps = @(
@{ Id='Dell.CommandUpdate'; Name='Dell Command Update (drivers/firmware Dell)'; Checked=$false }
@{ Id='Dell.SupportAssistAgent'; Name='Dell SupportAssist'; Checked=$false }
@{ Id='Lenovo.SystemUpdate'; Name='Lenovo System Update (ThinkCentre/ThinkPad)'; Checked=$false }
)
$AvApps = @(
@{ Id='Avast.Antivirus'; Name='Avast Free Antivirus'; Checked=$false }
@{ Id='AVG.Antivirus'; Name='AVG AntiVirus Free'; Checked=$false }
@{ Id='Bitdefender.Bitdefender'; Name='Bitdefender (agente, Free Edition)'; Checked=$false }
@{ Id='Malwarebytes.Malwarebytes'; Name='Malwarebytes (scanner sob demanda, free)'; Checked=$false }
@{ Id='Kaspersky.SecurityCloud'; Name='Kaspersky Security Cloud (free)'; Checked=$false }
)
# ============================================================================
#  MOTOR: roda as tarefas em runspace separado (GUI nao trava)
# ============================================================================
$WorkerCode = {
    param($sync, $Task)
    $sync.Busy = $true
    try {
        # ---------- helpers ----------
        function W-Log {
            param([string]$msg, [string]$lvl = 'INFO')
            $sync.LogQ.Enqueue($lvl + '|' + $msg) | Out-Null
            try { Add-Content -Path $sync.LogFile -Value ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] [" + $lvl + "] " + $msg) -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
        }
        function W-Status([string]$s) { $sync.Status = $s }
        function W-Ind { $sync.ProgressMode = 'ind' }
        function W-Pct([int]$p) { $sync.ProgressMode = 'pct'; $sync.ProgressValue = [Math]::Min(100, [Math]::Max(0, $p)) }
        function Ensure-RegPath([string]$path) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null }
        }
        function Invoke-Op {
            param($op)
            switch ($op.op) {
                'reg' {
                    Ensure-RegPath $op.path
                    $val = $op.value
                    $pt  = switch ($op.type) { 'DWord' {'DWord'} 'QWord' {'QWord'} 'ExpandString' {'ExpandString'} 'Binary' {'Binary'} default {'String'} }
                    if ($op.type -eq 'Binary' -and $val -is [string]) {
                        $val = ($val -split ',') | ForEach-Object { [byte]($_.Trim()) }
                    }
                    New-ItemProperty -Path $op.path -Name $op.name -PropertyType $pt -Value $val -Force -ErrorAction Stop | Out-Null
                }
                'regdel'    { Remove-ItemProperty -Path $op.path -Name $op.name -ErrorAction SilentlyContinue }
                'regdelkey' { if (Test-Path $op.path) { Remove-Item -Path $op.path -Recurse -Force -ErrorAction SilentlyContinue } }
                'svc' {
                    $svc = Get-Service -Name $op.name -ErrorAction SilentlyContinue
                    if (-not $svc) { W-Log ("Servico inexistente, ignorado: " + $op.name) 'WARN'; return }
                    if ($op.startup -eq 'Disabled') {
                        Stop-Service -Name $op.name -Force -ErrorAction SilentlyContinue
                        Set-Service -Name $op.name -StartupType Disabled -ErrorAction Stop
                    } else {
                        Set-Service -Name $op.name -StartupType $op.startup -ErrorAction Stop
                    }
                }
                'task' {
                    $parts = $op.path.TrimEnd('\').Split('\')
                    $tname = $parts[-1]
                    $tpath = ($parts[0..($parts.Count - 2)] -join '\') + '\'
                    $t = Get-ScheduledTask -TaskName $tname -TaskPath $tpath -ErrorAction SilentlyContinue
                    if (-not $t) { W-Log ("Tarefa inexistente, ignorada: " + $op.path) 'WARN'; return }
                    if ($op.enable) { Enable-ScheduledTask -TaskName $tname -TaskPath $tpath -ErrorAction SilentlyContinue | Out-Null }
                    else { Disable-ScheduledTask -TaskName $tname -TaskPath $tpath -ErrorAction SilentlyContinue | Out-Null }
                }
                'cmd' {
                    $out = cmd.exe /c $op.line 2>&1
                    if ($LASTEXITCODE -ne 0) { throw ("cmd falhou (" + $LASTEXITCODE + "): " + $op.line) }
                }
                'copy' {
                    $src = Join-Path $sync.ScriptDir $op.src
                    if (-not (Test-Path $src)) { throw ("Arquivo nao encontrado: " + $src) }
                    $dstdir = Split-Path -Parent $op.dst
                    if (-not (Test-Path $dstdir)) { New-Item -Path $dstdir -Force -ErrorAction SilentlyContinue | Out-Null }
                    Copy-Item -Path $src -Destination $op.dst -Force -ErrorAction Stop
                }
            }
        }
        function Get-SizeMB([string]$pattern) {
            try {
                $items = Get-Item -Path $pattern -Force -ErrorAction SilentlyContinue
                if (-not $items) { return 0 }
                $sum = 0
                foreach ($i in $items) {
                    if ($i.PSIsContainer) {
                        $sum += (Get-ChildItem -Path $i.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    } else { $sum += $i.Length }
                }
                return [Math]::Round(($sum / 1MB), 1)
            } catch { return 0 }
        }
        # ---------- tarefas ----------
        switch ($Task.Kind) {
            'apply' {
                $list = $sync.Data.Tweaks | Where-Object { $Task.Ids -contains $_.Id }
                W-Log ("==== Aplicar " + $list.Count + " tweak(s) ====") 'HEAD'
                $n = 0
                foreach ($tw in $list) {
                    W-Status ("Tweak: " + $tw.Name)
                    W-Log (">> " + $tw.Name) 'INFO'
                    $ok = 0; $fail = 0
                    foreach ($op in $tw.Apply) {
                        try { Invoke-Op $op; $ok++ } catch { $fail++; W-Log ("   falhou: " + $_.Exception.Message) 'ERR' }
                    }
                    if ($fail -eq 0) { W-Log ("   OK (" + $ok + " operacoes)") 'OK' }
                    else { W-Log ("   concluido com " + $fail + " falha(s)") 'WARN' }
                    $n++; W-Pct ([int](100 * $n / $list.Count))
                }
                W-Log "Concluido. Reinicie o Explorer para efeitos visuais imediatos (botao no topo)." 'HEAD'
            }
            'revert' {
                $list = $sync.Data.Tweaks | Where-Object { $Task.Ids -contains $_.Id }
                W-Log ("==== Reverter " + $list.Count + " tweak(s) ====") 'HEAD'
                $n = 0
                foreach ($tw in $list) {
                    W-Status ("Revertendo: " + $tw.Name)
                    W-Log ("<< " + $tw.Name) 'INFO'
                    foreach ($op in $tw.Revert) {
                        try { Invoke-Op $op } catch { W-Log ("   falhou: " + $_.Exception.Message) 'ERR' }
                    }
                    $n++; W-Pct ([int](100 * $n / $list.Count))
                }
                W-Log "Reversao concluida." 'HEAD'
            }
            'appx' {
                $all = [bool]$Task.AllUsers
                W-Log ("==== Remocao de bloatware (todos os usuarios: " + $all + ") ====") 'HEAD'
                $list = $sync.Data.AppxApps | Where-Object { $Task.Ids -contains $_.Name }
                $n = 0
                foreach ($app in $list) {
                    W-Status ("Removendo: " + $app.Name)
                    $removed = 0
                    foreach ($pat in $app.Patterns) {
                        try {
                            if ($all) { $pkgs = Get-AppxPackage -AllUsers -Name $pat -ErrorAction SilentlyContinue }
                            else      { $pkgs = Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue }
                            foreach ($p in $pkgs) {
                                try {
                                    if ($all) { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop }
                                    else      { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop }
                                    $removed++
                                } catch {
                                    try { Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction Stop; $removed++ } catch {}
                                }
                            }
                            $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pat }
                            foreach ($pp in $prov) {
                                try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop; $removed++ } catch {}
                            }
                        } catch { W-Log ("   " + $pat + ": " + $_.Exception.Message) 'ERR' }
                    }
                    if ($removed -gt 0) { W-Log ("   [OK] " + $app.Name + " (" + $removed + " pacote(s))") 'OK' }
                    else { W-Log ("   nao estava instalado: " + $app.Name) 'WARN' }
                    $n++; W-Pct ([int](100 * $n / $list.Count))
                }
                # OneDrive
                if ($Task.Ids -contains '__onedrive__') {
                    W-Status 'Removendo OneDrive...'
                    W-Log ">> OneDrive" 'INFO'
                    try {
                        Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 1
                        $setup = "$env:windir\SysWOW64\OneDriveSetup.exe"
                        if (-not (Test-Path $setup)) { $setup = "$env:windir\System32\OneDriveSetup.exe" }
                        if (Test-Path $setup) { Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait }
                        W-Log '   [OK] OneDrive removido' 'OK'
                    } catch { W-Log ("   OneDrive: " + $_.Exception.Message) 'ERR' }
                    $n++
                }
                W-Log "Bloatware concluido." 'HEAD'
            }
            'clean' {
                W-Log '==== Limpeza ====' 'HEAD'
                $list = $sync.Data.CleanTasks | Where-Object { $Task.Ids -contains $_.Id }
                $n = 0; $total = 0.0
                foreach ($ct in $list) {
                    W-Status ("Limpando: " + $ct.Name)
                    W-Log (">> " + $ct.Name) 'INFO'
                    W-Ind
                    switch ($ct.Id) {
                        'temp' {
                            $b = Get-SizeMB "$env:LOCALAPPDATA\Temp\*"
                            Get-ChildItem "$env:LOCALAPPDATA\Temp" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            $a = Get-SizeMB "$env:LOCALAPPDATA\Temp\*"; $total += ($b - $a); W-Log ("   liberado " + [Math]::Round($b - $a, 1) + " MB") 'OK'
                        }
                        'witemp' {
                            $b = Get-SizeMB "$env:windir\Temp\*"
                            Get-ChildItem "$env:windir\Temp" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            $a = Get-SizeMB "$env:windir\Temp\*"; $total += ($b - $a); W-Log ("   liberado " + [Math]::Round($b - $a, 1) + " MB") 'OK'
                        }
                        'wu' {
                            $wuRun = (Get-Service wuauserv).Status -eq 'Running'
                            Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
                            $b = Get-SizeMB "$env:windir\SoftwareDistribution\Download\*"
                            Get-ChildItem "$env:windir\SoftwareDistribution\Download" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            $a = Get-SizeMB "$env:windir\SoftwareDistribution\Download\*"
                            if ($wuRun) { Start-Service wuauserv -ErrorAction SilentlyContinue }
                            $total += ($b - $a); W-Log ("   liberado " + [Math]::Round($b - $a, 1) + " MB") 'OK'
                        }
                        'recycle' { try { Clear-RecycleBin -Force -ErrorAction Stop; W-Log '   [OK] Lixeira esvaziada' 'OK' } catch { W-Log '   Lixeira ja vazia' 'WARN' } }
                        'prefetch' {
                            $b = Get-SizeMB "$env:windir\Prefetch\*"
                            Get-ChildItem "$env:windir\Prefetch" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            $a = Get-SizeMB "$env:windir\Prefetch\*"; $total += ($b - $a); W-Log ("   liberado " + [Math]::Round($b - $a, 1) + " MB") 'OK'
                        }
                        'thumbs' {
                            $b = (Get-SizeMB "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*.db") + (Get-SizeMB "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*.db")
                            Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache*.db' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                            Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'iconcache*.db'  -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                            $total += $b; W-Log ("   liberado " + [Math]::Round($b, 1) + " MB (miniaturas recriam ao abrir pastas)") 'OK'
                        }
                        'dns' { $null = ipconfig /flushdns; W-Log '   [OK] cache DNS limpo' 'OK' }
                        'dumps' {
                            $b = (Get-SizeMB "$env:windir\Minidump\*") + (Get-SizeMB "$env:windir\MEMORY.DMP") + (Get-SizeMB "$env:LOCALAPPDATA\CrashDumps\*")
                            Get-ChildItem "$env:windir\Minidump" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                            Remove-Item "$env:windir\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
                            Get-ChildItem "$env:LOCALAPPDATA\CrashDumps" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                            $total += $b; W-Log ("   liberado " + [Math]::Round($b, 1) + " MB") 'OK'
                        }
                        'edgelog' {
                            $paths = @("$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache\*"
                                      ,"$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache\*"
                                      ,"$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache\*"
                                      ,"$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache\*")
                            $b = 0.0
                            foreach ($pp in $paths) { $b += Get-SizeMB $pp; Get-Item $pp -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
                            $total += $b; W-Log ("   liberado " + [Math]::Round($b, 1) + " MB (so cache, senhas/historico intactos)") 'OK'
                        }
                        'caps' {
                            $pats = 'Microsoft.Windows.WordPad','App.StepsRecorder','App.Support.QuickAssist','Browser.InternetExplorer','Media.WindowsMediaPlayer','MathRecognizer','MathInputs'
                            foreach ($pt in $pats) {
                                Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ($pt + '*') -and $_.State -eq 'Installed' } | ForEach-Object {
                                    try { Remove-WindowsCapability -Online -Name $_.Name -ErrorAction Stop | Out-Null; W-Log ("   removido: " + $_.Name) 'OK' }
                                    catch { W-Log ("   falhou " + $_.Name + ": " + $_.Exception.Message) 'ERR' }
                                }
                            }
                        }
                        'windowsold' {
                            if (Test-Path 'C:\Windows.old') {
                                W-Ind; $b = Get-SizeMB 'C:\Windows.old'
                                Remove-Item 'C:\Windows.old' -Recurse -Force -ErrorAction SilentlyContinue
                                if (Test-Path 'C:\Windows.old') { W-Log '   [ERRO] Use Limpeza de Disco -> Limpar arquivos do sistema para remover o resto' 'ERR' }
                                else { $total += $b; W-Log ("   liberado " + [Math]::Round($b, 1) + " MB") 'OK' }
                            } else { W-Log '   Windows.old nao existe' 'WARN' }
                        }
                        'dism' {
                            W-Ind; W-Log '   DISM em andamento, pode demorar 5-20 min...' 'WARN'
                            $out = dism /online /cleanup-image /startcomponentcleanup 2>&1
                            if ($LASTEXITCODE -eq 0) { W-Log '   [OK] StartComponentCleanup concluido' 'OK' }
                            else { W-Log ('   DISM falhou (' + $LASTEXITCODE + ')') 'ERR' }
                        }
                    }
                    $n++; W-Pct ([int](100 * $n / $list.Count))
                }
                W-Log ("==== Limpeza concluida. Total liberado nesta sessao: " + [Math]::Round($total, 1) + " MB ====") 'HEAD'
            }
            'winget' {
                $apps = $Task.Apps
                W-Log ("==== Instalacao via winget (" + $apps.Count + ") ====") 'HEAD'
                if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                    W-Log 'winget NAO encontrado! Abra a Microsoft Store e instale "Instalador de Aplicativo" (App Installer), depois reabra o Windows Booster.' 'ERR'
                    return
                }
                $n = 0
                foreach ($a in $apps) {
                    W-Status ("Instalando: " + $a.Name)
                    W-Log (">> " + $a.Name + "  [winget id: " + $a.Id + "]") 'INFO'
                    W-Ind
                    if ($a.Id -like 'feat:*') {
                        $fid = $a.Id.Substring(5)
                        try {
                            switch ($fid) {
                                'wsl' {
                                    $null = cmd.exe /c 'dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart' 2>&1
                                    $null = cmd.exe /c 'dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart' 2>&1
                                    $null = & wsl --install -d Ubuntu 2>&1
                                    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) { W-Log '   [OK] WSL2 + Ubuntu preparados (reinicie o PC)' 'OK' }
                                    else { W-Log ('   wsl --install retornou ' + $LASTEXITCODE + ' - rode "wsl --install" manualmente apos reiniciar') 'WARN' }
                                }
                                'hyperv' {
                                    $null = cmd.exe /c 'dism /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart' 2>&1
                                    W-Log '   [OK] Hyper-V habilitado (reinicie o PC)' 'OK'
                                }
                                'net35' {
                                    $null = cmd.exe /c 'dism /online /enable-feature /featurename:NetFx3 /all /norestart' 2>&1
                                    W-Log '   [OK] .NET 3.5 habilitado' 'OK'
                                }
                            }
                        } catch { W-Log ('   ' + $fid + ': ' + $_.Exception.Message) 'ERR' }
                        $n++; W-Pct ([int](100 * $n / $apps.Count))
                        continue
                    }
                    $have = $false
                    try { $null = & winget list --id $a.Id --exact --accept-source-agreements 2>$null; $have = ($LASTEXITCODE -eq 0) } catch {}
                    if ($have) { W-Log '   ja instalado, pulando' 'WARN' }
                    else {
                        $lines = & winget install --id $a.Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
                        if ($LASTEXITCODE -eq 0) { W-Log ("   [OK] instalado: " + $a.Name) 'OK' }
                        elseif ($LASTEXITCODE -eq -1978335189) { W-Log '   ja instalado (versao igual/mais nova)' 'WARN' }
                        else {
                            W-Log ("   [ERRO] winget saiu com codigo " + $LASTEXITCODE) 'ERR'
                            $tail = @($lines | Where-Object { $_ -and ($_ -is [string]) }) | Select-Object -Last 3
                            foreach ($l in $tail) { W-Log ('   ' + $l.ToString().Trim()) 'ERR' }
                        }
                    }
                    $n++; W-Pct ([int](100 * $n / $apps.Count))
                }
                W-Log 'Instalacoes concluidas.' 'HEAD'
            }
            'restorepoint' {
                W-Status 'Criando ponto de restauracao...'
                W-Ind
                W-Log '==== Ponto de restauracao ====' 'HEAD'
                try {
                    Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
                    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
                    $sr = [WMIClass]'\\.\root\default:SystemRestore'
                    $r  = $sr.CreateRestorePoint('Windows Booster', 12, 100)
                    if ($r.ReturnValue -eq 0) { W-Log '[OK] Ponto de restauracao criado com sucesso.' 'OK' }
                    else { W-Log ('CreateRestorePoint retornou ' + $r.ReturnValue + ' (tente pela Protecao do Sistema)') 'WARN' }
                } catch {
                    W-Log ('Falhou: ' + $_.Exception.Message + ' - ative a Protecao do Sistema em Painel de Controle -> Recuperacao.') 'ERR'
                }
            }
            'preset' {
                W-Log '==== OTIMIZACAO RECOMENDADA (1 clique) ====' 'HEAD'
                & { # restaura ponto
                    W-Status 'Ponto de restauracao...'
                    try {
                        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
                        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
                        ([WMIClass]'\\.\root\default:SystemRestore').CreateRestorePoint('Windows Booster', 12, 100) | Out-Null
                        W-Log '[OK] Ponto de restauracao criado' 'OK'
                    } catch { W-Log ('Ponto de restauracao falhou (seguindo mesmo assim): ' + $_.Exception.Message) 'WARN' }
                }
                W-Pct 15
                # limpeza basica
                W-Status 'Limpando temporarios...'
                foreach ($d in @("$env:LOCALAPPDATA\Temp", "$env:windir\Temp")) {
                    Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
                $null = ipconfig /flushdns
                try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
                W-Log '[OK] Limpeza basica' 'OK'
                W-Pct 35
                # bloatware padrao (apps marcados por padrao + OneDrive)
                W-Status 'Removendo bloatware padrao...'
                foreach ($app in ($sync.Data.AppxApps | Where-Object { $_.Checked })) {
                    foreach ($pat in $app.Patterns) {
                        try {
                            if ($Task.AllUsers) { Get-AppxPackage -AllUsers -Name $pat -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue }
                            else { Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue }
                            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pat } | ForEach-Object {
                                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                            }
                        } catch {}
                    }
                    W-Log ('[OK] ' + $app.Name) 'OK'
                }
                try {
                    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
                    $setup = "$env:windir\SysWOW64\OneDriveSetup.exe"; if (-not (Test-Path $setup)) { $setup = "$env:windir\System32\OneDriveSetup.exe" }
                    if (Test-Path $setup) { Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait }
                    W-Log '[OK] OneDrive' 'OK'
                } catch {}
                W-Pct 60
                # tweaks seguros (grupos A-D marcados)
                W-Status 'Aplicando tweaks de privacidade e desempenho...'
                $safeIds = @($sync.Data.Tweaks | Where-Object { $_.Group -ne 'E' -and $_.Checked } | ForEach-Object { $_.Id })
                $twlist = $sync.Data.Tweaks | Where-Object { $safeIds -contains $_.Id }
                $i = 0
                foreach ($tw in $twlist) {
                    W-Log ('[TWEAK] ' + $tw.Name) 'INFO'
                    foreach ($op in $tw.Apply) { try { Invoke-Op $op } catch { W-Log ('   falhou: ' + $_.Exception.Message) 'ERR' } }
                    $i++; W-Pct ([int](60 + 40 * $i / $twlist.Count))
                }
                W-Log '==== OTIMIZACAO RECOMENDADA CONCLUIDA! Reinicie o PC para tudo valer. ====' 'HEAD'
            }
            'defender-enable' {
                W-Log '==== Reativando Microsoft Defender ====' 'HEAD'
                $tw = $sync.Data.Tweaks | Where-Object { $_.Id -eq 'e-defender' }
                foreach ($op in $tw.Revert) { try { Invoke-Op $op } catch { W-Log ('   falhou: ' + $_.Exception.Message) 'ERR' } }
                try {
                    Remove-MpPreference -DisableRealtimeMonitoring -ErrorAction SilentlyContinue
                    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
                } catch {}
                W-Log '[OK] Defender reativado. Se o Tamper Protection estiver ligado, ele ja protege.' 'OK'
            }
            'explore' {
                W-Log 'Reiniciando o Explorer...' 'INFO'
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
                W-Log '[OK] Explorer reiniciado' 'OK'
            }
        }
    } catch {
        try { $sync.LogQ.Enqueue('ERR|ERRO INESPERADO: ' + $_.Exception.Message) } catch {}
    } finally {
        $sync.Status = 'Pronto'
        $sync.ProgressMode = 'pct'
        $sync.ProgressValue = 100
        Start-Sleep -Milliseconds 600
        $sync.Busy = $false
    }
}
# ============================================================================
#  INTERFACE (WPF, tema escuro)
# ============================================================================
function Brush([string]$hex) {
    $b = New-Object System.Windows.Media.SolidColorBrush
    $b.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    return $b
}
function New-Chk {
    param([string]$label, [string]$tag, [bool]$checked, [string]$tip)
    $c = New-Object System.Windows.Controls.CheckBox
    $c.Content = $label; $c.Tag = $tag; $c.IsChecked = $checked; $c.Margin = '4,3,16,3'
    if ($tip) { $c.ToolTip = $tip }
    return $c
}
function New-Rb {
    param([string]$label, [string]$tag, [string]$tip)
    $c = New-Object System.Windows.Controls.RadioButton
    $c.Content = $label; $c.Tag = $tag; $c.GroupName = 'av'; $c.Margin = '4,3,16,3'
    if ($tip) { $c.ToolTip = $tip }
    return $c
}
function Add-Section {
    param($parent, [string]$title, [string]$desc, [bool]$danger = $false)
    $bd = New-Object System.Windows.Controls.Border
    $bd.Background = (Brush '#222428'); $bd.CornerRadius = '8'; $bd.Padding = '12,10'; $bd.Margin = '0,0,0,10'
    if ($danger) { $bd.BorderBrush = (Brush '#8C3A3A'); $bd.BorderThickness = '1' }
    $sp  = New-Object System.Windows.Controls.StackPanel
    $tb  = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $title; $tb.FontWeight = 'Bold'; $tb.FontSize = 13.5
    $tb.Foreground = (Brush $(if ($danger) { '#F28B82' } else { '#FFFFFF' }))
    $ds = New-Object System.Windows.Controls.TextBlock
    $ds.Text = $desc; $ds.Foreground = (Brush '#9AA0A6'); $ds.FontSize = 11
    $ds.Margin = '0,2,0,8'; $ds.TextWrapping = 'Wrap'
    $sp.Children.Add($tb) | Out-Null; $sp.Children.Add($ds) | Out-Null
    $bd.Child = $sp
    $parent.Children.Add($bd) | Out-Null
    return $sp
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Booster - Windows 10/11" Height="780" Width="1120"
        MinWidth="960" MinHeight="640" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" FontSize="12" Background="#1B1D21">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#E8EAED"/>
      <Setter Property="Background" Value="#2B2E34"/>
      <Setter Property="BorderBrush" Value="#44474D"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#353941"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Background" Value="#40444B"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="PrimaryBtn" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#0F6CBD"/>
      <Setter Property="BorderBrush" Value="#2B88D8"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E8EAED"/>
      <Setter Property="Margin" Value="4,3,16,3"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>
    <Style TargetType="RadioButton">
      <Setter Property="Foreground" Value="#E8EAED"/>
      <Setter Property="Margin" Value="4,3,16,3"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>
    <Style TargetType="TabControl">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#C7CACF"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="bd" Background="Transparent" CornerRadius="6,6,0,0" Padding="{TemplateBinding Padding}" Margin="0,0,2,0" BorderThickness="0,0,0,2" BorderBrush="Transparent">
              <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#2B2E34"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#60CDFF"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#24262A"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#121316"/>
      <Setter Property="Foreground" Value="#D0D3D8"/>
      <Setter Property="BorderBrush" Value="#3C4043"/>
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="CaretBrush" Value="#D0D3D8"/>
    </Style>
  </Window.Resources>
  <Grid Margin="14,12,14,10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="150"/>
    </Grid.RowDefinitions>
    <DockPanel Grid.Row="0">
      <StackPanel DockPanel.Dock="Left">
        <TextBlock Text="Windows Booster" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF"/>
        <TextBlock Text="Otimizar, limpar e equipar o Windows 10 e 11 - com inteligencia de Win11Debloat, WinUtil e Windows10Debloater" Foreground="#9AA0A6" FontSize="11" Margin="0,2,0,0"/>
      </StackPanel>
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
        <Button x:Name="BtnPreset" Content="Otimizacao recomendada (1 clique)" Style="{StaticResource PrimaryBtn}" MinWidth="250"/>
        <Button x:Name="BtnRestorePoint" Content="Ponto de restauracao" MinWidth="170" Margin="8,0,0,0"/>
        <Button x:Name="BtnExplorer" Content="Reiniciar Explorer" MinWidth="150" Margin="8,0,0,0"/>
      </StackPanel>
    </DockPanel>
    <TabControl Grid.Row="1" Margin="0,12,0,0">
      <TabItem Header="Inicio">
        <Grid Margin="4,10,4,4">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpHome" Margin="0,0,6,0">
              <Border Background="#222428" CornerRadius="8" Padding="12,10" Margin="0,0,0,10">
                <StackPanel>
                  <TextBlock Text="Estado do sistema" FontWeight="Bold" FontSize="13.5" Foreground="#FFFFFF"/>
                  <TextBlock x:Name="TxtInfo" Foreground="#D0D3D8" Margin="0,6,0,0" Text="Coletando informacoes..." TextWrapping="Wrap"/>
                </StackPanel>
              </Border>
              <Border Background="#222428" CornerRadius="8" Padding="12,10" Margin="0,0,0,10">
                <StackPanel>
                  <TextBlock Text="Como usar" FontWeight="Bold" FontSize="13.5" Foreground="#FFFFFF"/>
                  <TextBlock Foreground="#9AA0A6" Margin="0,6,0,0" TextWrapping="Wrap"
                     Text="1. Ponto de restauracao primeiro (botao no topo ou dentro da Otimizacao recomendada).&#x0a;2. Otimizacao recomendada: limpa, remove bloatware padrao e aplica tweaks seguros (A-D) em um clique.&#x0a;3. Aba Bloatware: escolha os apps a remover (desmarque o que voce usa!).&#x0a;4. Aba Tweaks: privacidade, desempenho, Explorer e itens de risco (E). Tudo reversivel pelo botao Reverter.&#x0a;5. Aba Limpeza: temporarios, cache de update, lixeira, DNS e mais.&#x0a;6. Abas de instalacao: Desenvolvedor, IObit, Drivers e Antivirus via winget (silencioso)."/>
                </StackPanel>
              </Border>
              <Border Background="#222428" CornerRadius="8" Padding="12,10" Margin="0,0,0,10">
                <StackPanel>
                  <TextBlock Text="Avisos" FontWeight="Bold" FontSize="13.5" Foreground="#FDD663"/>
                  <TextBlock Foreground="#9AA0A6" Margin="0,6,0,0" TextWrapping="Wrap"
                     Text="- Grupo E contem tweaks de risco (Defender off, Windows Update off). Padrao: desligado.&#x0a;- Apos grandes atualizacoes do Windows, a Microsoft pode restaurar coisas: rode os tweaks de novo.&#x0a;- Este arquivo loga tudo em Windows-Booster.log na pasta do programa.&#x0a;- O arquivo .reg e o silent.bat antigos continuam na pasta e funcionam igual (modo script)."/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>
        </Grid>
      </TabItem>
      <TabItem Header="Bloatware">
        <Grid Margin="4,10,4,4">
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpBloat" Margin="0,0,6,0"/>
          </ScrollViewer>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,8,0,0">
            <Button x:Name="BtnRemoveBloat" Content="Remover selecionados" Style="{StaticResource PrimaryBtn}" MinWidth="200"/>
            <CheckBox x:Name="ChkAllUsers" Content="Todos os usuarios + bloquear reinstalacao (provisionado)" IsChecked="True" Margin="14,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="Limpeza">
        <Grid Margin="4,10,4,4">
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpClean" Margin="0,0,6,0"/>
          </ScrollViewer>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,8,0,0">
            <Button x:Name="BtnRunClean" Content="Limpar selecionados" Style="{StaticResource PrimaryBtn}" MinWidth="200"/>
            <TextBlock Text="O total liberado aparece no log." Foreground="#9AA0A6" VerticalAlignment="Center" Margin="12,0,0,0"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="Tweaks">
        <Grid Margin="4,10,4,4">
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpTweaks" Margin="0,0,6,0"/>
          </ScrollViewer>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,8,0,0">
            <Button x:Name="BtnApplyTweaks" Content="Aplicar selecionados" Style="{StaticResource PrimaryBtn}" MinWidth="200"/>
            <Button x:Name="BtnRevertTweaks" Content="Reverter selecionados" MinWidth="200" Margin="10,0,0,0"/>
            <TextBlock Text="Reinicie o Explorer (topo) para efeitos visuais." Foreground="#9AA0A6" VerticalAlignment="Center" Margin="12,0,0,0"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="Desenvolvedor">
        <Grid Margin="4,10,4,4">
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpDev" Margin="0,0,6,0"/>
          </ScrollViewer>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,8,0,0">
            <Button x:Name="BtnInstallDev" Content="Instalar selecionados" Style="{StaticResource PrimaryBtn}" MinWidth="200"/>
            <TextBlock Text="Winget silencioso. Ja instalados sao pulados. Recursos do Windows pedem reinicio." Foreground="#9AA0A6" VerticalAlignment="Center" Margin="12,0,0,0" TextWrapping="Wrap"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="IObit">
        <Grid Margin="4,10,4,4">
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpIObit" Margin="0,0,6,0"/>
          </ScrollViewer>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,8,0,0">
            <Button x:Name="BtnInstallIObit" Content="Instalar selecionados" Style="{StaticResource PrimaryBtn}" MinWidth="200"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="Drivers">
        <Grid Margin="4,10,4,4">
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpDrivers" Margin="0,0,6,0"/>
          </ScrollViewer>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,8,0,0">
            <Button x:Name="BtnInstallDrivers" Content="Instalar selecionados" Style="{StaticResource PrimaryBtn}" MinWidth="200"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="Antivirus">
        <Grid Margin="4,10,4,4">
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel x:Name="SpAV" Margin="0,0,6,0"/>
          </ScrollViewer>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,8,0,0">
            <Button x:Name="BtnInstallAV" Content="Instalar o escolhido" Style="{StaticResource PrimaryBtn}" MinWidth="200"/>
            <Button x:Name="BtnEnableDefender" Content="Reativar Microsoft Defender" MinWidth="200" Margin="10,0,0,0"/>
          </StackPanel>
        </Grid>
      </TabItem>
    </TabControl>
    <DockPanel Grid.Row="2" Margin="0,10,0,0">
      <TextBlock x:Name="TxtStatus" DockPanel.Dock="Left" Foreground="#9AA0A6" VerticalAlignment="Center" Text="Pronto"/>
      <ProgressBar x:Name="pbProgress" DockPanel.Dock="Right" Width="340" Height="8" Minimum="0" Maximum="100" Value="0"
                   HorizontalAlignment="Right" VerticalAlignment="Center" Background="#26272B" Foreground="#60CDFF" BorderThickness="0"/>
    </DockPanel>
    <TextBlock Grid.Row="3" Text="Log" Foreground="#9AA0A6" Margin="0,10,0,4"/>
    <Border Grid.Row="4" Background="#121316" BorderBrush="#3C4043" BorderThickness="1" CornerRadius="6">
      <RichTextBox x:Name="TxtLog" Background="Transparent" Foreground="#D0D3D8" BorderThickness="0"
                   FontFamily="Consolas" FontSize="11.5" IsReadOnly="True" VerticalScrollBarVisibility="Auto" Padding="6"/>
    </Border>
  </Grid>
</Window>
'@

$win = [System.Windows.Markup.XamlReader]::Parse($xaml)
$win.Title = 'Windows Booster - Windows 10/11'

$TxtInfo   = $win.FindName('TxtInfo')
$SpHome    = $win.FindName('SpHome')
$SpBloat   = $win.FindName('SpBloat')
$SpClean   = $win.FindName('SpClean')
$SpTweaks  = $win.FindName('SpTweaks')
$SpDev     = $win.FindName('SpDev')
$SpIObit   = $win.FindName('SpIObit')
$SpDrivers = $win.FindName('SpDrivers')
$SpAV      = $win.FindName('SpAV')
$ChkAllUsers = $win.FindName('ChkAllUsers')
$TxtStatus = $win.FindName('TxtStatus')
$pbProgress = $win.FindName('pbProgress')
$TxtLog    = $win.FindName('TxtLog')

# ---------------- preencher abas ----------------
# Bloatware
$sp = Add-Section $SpBloat 'Aplicativos pre-instalados (bloatware)' 'Lista do removeApps.ps1 deste projeto + inteligencia Win11Debloat/Windows10Debloater. Passe o mouse sobre cada item para ver o padrao interno. Desmarque o que voce usa!'
$wp = New-Object System.Windows.Controls.WrapPanel
$wp.Children.Add((New-Chk 'OneDrive (desinstalar)' '__onedrive__' $true 'Desinstala o OneDrive, como o silent.bat original')) | Out-Null
foreach ($app in $AppxApps) { $wp.Children.Add((New-Chk $app.Name $app.Name $app.Checked ($app.Patterns -join ', '))) | Out-Null }
$sp.Children.Add($wp) | Out-Null

# Limpeza
$sp = Add-Section $SpClean 'Sujeira do Windows' 'Cada item mostra no log quantos MB liberou. Itens marcados [RISCO]/[LENT0] leia antes de marcar.'
$wp = New-Object System.Windows.Controls.WrapPanel
foreach ($ct in $CleanTasks) { $wp.Children.Add((New-Chk $ct.Name $ct.Id $ct.Checked $null)) | Out-Null }
$sp.Children.Add($wp) | Out-Null

# Tweaks
$tweakGroups = @(
  @{ Id='A'; Title='A - Privacidade e Telemetria'; Desc='Para coleta de dados, anuncios, Cortana na web, Copilot/IA, CEIP. Tudo reversivel pelo botao Reverter.' }
  @{ Id='B'; Title='B - Desempenho e Visual'; Desc='Transparencia, animacoes, menus, desligamento rapido, Game DVR, plano de energia.' }
  @{ Id='C'; Title='C - Explorer, Menu Iniciar e Barra'; Desc='Porta os .reg do projeto (extensoes, recentes, tiles, taskbar) + extras do Win11.' }
  @{ Id='D'; Title='D - Tela de Bloqueio, Update e Aparencia'; Desc='Lockscreen, horario ativo, sem reinicio automatico, wallpaper do projeto.' }
  @{ Id='E'; Title='E - [RISCO] Avancado'; Desc='Defender off, Windows Update off, SysMain, servicos Xbox, area remota. Padrao desligado. So marque se souber o que faz!' ; Danger=$true }
)
foreach ($g in $tweakGroups) {
    $sp = Add-Section $SpTweaks $g.Title $g.Desc $g.Danger
    $wp = New-Object System.Windows.Controls.WrapPanel
    foreach ($tw in ($Tweaks | Where-Object { $_.Group -eq $g.Id })) {
        $wp.Children.Add((New-Chk $tw.Name $tw.Id $tw.Checked $tw.Desc)) | Out-Null
    }
    $sp.Children.Add($wp) | Out-Null
}

# Desenvolvedor
$sp = Add-Section $SpDev 'Programas (winget)' 'Instalacao silenciosa. Marcados = kit basico sugerido (Git, VS Code, Chrome, Python, 7-Zip).'
$wp = New-Object System.Windows.Controls.WrapPanel
foreach ($d in $DevApps) { $wp.Children.Add((New-Chk $d.Name $d.Id $d.Checked $d.Id)) | Out-Null }
$sp.Children.Add($wp) | Out-Null
$sp = Add-Section $SpDev 'Recursos do Windows (DISM)' 'WSL2/Hyper-V/.NET 3.5. Podem pedir reinicio.'
$wp = New-Object System.Windows.Controls.WrapPanel
foreach ($f in $DevFeatures) { $wp.Children.Add((New-Chk $f.Name ('feat:' + $f.Id) $f.Checked $null)) | Out-Null }
$sp.Children.Add($wp) | Out-Null
$sp = Add-Section $SpDev 'IDs extras do winget (opcional)' 'Cole IDs do winget separados por espaco ou virgula. Ex: Obsidian.Obsidian Zoom.Zoom'
$TxtCustomIds = New-Object System.Windows.Controls.TextBox
$TxtCustomIds.Height = 28; $TxtCustomIds.Margin = '0,2,0,0'
$sp.Children.Add($TxtCustomIds) | Out-Null

# IObit
$sp = Add-Section $SpIObit 'Ferramentas IObit (winget)' 'Uninstaller, Driver Booster e Advanced SystemCare.'
$wp = New-Object System.Windows.Controls.WrapPanel
foreach ($d in $IobitApps) { $wp.Children.Add((New-Chk $d.Name $d.Id $d.Checked $d.Id)) | Out-Null }
$sp.Children.Add($wp) | Out-Null
$sp = Add-Section $SpIObit 'Atencao' 'O instalador da IObit pode oferecer softwares extras mesmo em modo silencioso - revise na primeira execucao. O Advanced SystemCare e o Driver Booster tem versoes PRO pagas; o que instala aqui e a free.'
$dummy = New-Object System.Windows.Controls.TextBlock

# Drivers
$sp = Add-Section $SpDrivers 'Ferramentas de driver do fabricante' 'Dell: Command Update (OptiPlex/Latitude/Precision) e SupportAssist (Inspiron/Vostro/XPS). Lenovo: System Update (ThinkPad/ThinkCentre) - o Vantage para consumidores vem da Microsoft Store ( Lenovo Vantage ). HP: use o HP Support Assistant do site.'
$wp = New-Object System.Windows.Controls.WrapPanel
foreach ($d in $DriverApps) { $wp.Children.Add((New-Chk $d.Name $d.Id $d.Checked $d.Id)) | Out-Null }
$sp.Children.Add($wp) | Out-Null

# Antivirus
$sp = Add-Section $SpAV 'Escolha UM antivrus (ou fique no Defender)' 'Instale apenas um - dois antivirus brigam entre si e deixam o PC lento. O Microsoft Defender nativo e excelente: os tweaks de risco (grupo E) desativam ele; use o botao abaixo para reativar.'
$wp = New-Object System.Windows.Controls.WrapPanel
$wp.Children.Add((New-Rb 'Avast Free Antivirus' 'Avast.Antivirus' 'Free, popular; desativa o Defender automaticamente')) | Out-Null
$wp.Children.Add((New-Rb 'AVG AntiVirus Free' 'AVG.Antivirus' 'Free, do mesmo grupo do Avast')) | Out-Null
$wp.Children.Add((New-Rb 'Bitdefender Free (agente)' 'Bitdefender.Bitdefender' 'Agente oficial; dentro do app escolha Free')) | Out-Null
$wp.Children.Add((New-Rb 'Malwarebytes Free' 'Malwarebytes.Malwarebytes' 'Melhor como scanner sob demanda junto do Defender')) | Out-Null
$wp.Children.Add((New-Rb 'Kaspersky Security Cloud Free' 'Kaspersky.SecurityCloud' 'Free com recursos extras')) | Out-Null
$sp.Children.Add($wp) | Out-Null

# ---------------- estado compartilhado + worker ----------------
$sync = [hashtable]::Synchronized(@{})
$sync.LogQ = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
$sync.Busy = $false
$sync.Status = 'Pronto'
$sync.ProgressMode = 'pct'
$sync.ProgressValue = 0
$sync.ScriptDir = $ScriptDir
$sync.LogFile = $LogFile
$sync.Data = @{ Tweaks = $Tweaks; AppxApps = $AppxApps; CleanTasks = $CleanTasks; DevApps = $DevApps; DevFeatures = $DevFeatures; IobitApps = $IobitApps; DriverApps = $DriverApps; AvApps = $AvApps }

$script:Busy = $false
$script:Workers = New-Object System.Collections.ArrayList

function Start-Task {
    param([string]$kind, [hashtable]$payload)
    if ($sync.Busy -or $script:Busy) {
        [System.Windows.MessageBox]::Show('Uma tarefa ja esta em execucao. Olhe o log e aguarde terminar.', 'Windows Booster', 'OK', 'Information') | Out-Null
        return
    }
    $script:Busy = $true
    $task = @{ Kind = $kind }
    foreach ($k in $payload.Keys) { $task[$k] = $payload[$k] }
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($WorkerCode.ToString()).AddArgument($sync).AddArgument($task)
    [void]$ps.BeginInvoke()
    [void]$script:Workers.Add($ps)
}

function Get-SelectedTags {
    param($panel)
    @($panel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked } | ForEach-Object { [string]$_.Tag })
}

# ---------------- timer: log + progresso ----------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(250)
$timer.Add_Tick({
    try {
        while ($sync.LogQ.Count -gt 0) {
            $item = [string]$sync.LogQ.Dequeue()
            $idx = $item.IndexOf('|')
            if ($idx -lt 0) { $idx = 4; $item = 'INFO|' + $item }
            $lvl = $item.Substring(0, $idx)
            $msg = $item.Substring($idx + 1)
            $hex = switch ($lvl) { 'OK' {'#6CCB5F'} 'ERR' {'#F28B82'} 'WARN' {'#FDD663'} 'HEAD' {'#8AB4F8'} default {'#D0D3D8'} }
            $p = New-Object System.Windows.Documents.Paragraph
            $p.Margin = '0,0,0,1'
            $r = New-Object System.Windows.Documents.Run($msg)
            $r.Foreground = (Brush $hex)
            if ($lvl -eq 'HEAD') { $r.FontWeight = [System.Windows.FontWeights]::Bold }
            $p.Inlines.Add($r) | Out-Null
            $TxtLog.Document.Blocks.Add($p) | Out-Null
        }
        while ($TxtLog.Document.Blocks.Count -gt 400) { $TxtLog.Document.Blocks.Remove($TxtLog.Document.Blocks.FirstBlock) | Out-Null }
        $TxtLog.ScrollToEnd()
        $TxtStatus.Text = [string]$sync.Status
        if ($sync.ProgressMode -eq 'ind') { $pbProgress.IsIndeterminate = $true }
        else { $pbProgress.IsIndeterminate = $false; $pbProgress.Value = [double]$sync.ProgressValue }
        $script:Busy = [bool]$sync.Busy
    } catch {}
})
$timer.Start()

# ---------------- botoes ----------------
$win.FindName('BtnPreset').Add_Click({
    $ans = [System.Windows.MessageBox]::Show("A Otimizacao recomendada vai:`n1. Criar ponto de restauracao`n2. Limpar temporarios, lixeira e DNS`n3. Remover o bloatware padrao (itens marcados por padrao + OneDrive)`n4. Aplicar os tweaks seguros (grupos A-D marcados)`n`nContinuar?", 'Otimizacao recomendada', 'YesNo', 'Information')
    if ($ans -ne 'Yes') { return }
    Start-Task 'preset' @{ AllUsers = [bool]$ChkAllUsers.IsChecked }
})
$win.FindName('BtnRestorePoint').Add_Click({ Start-Task 'restorepoint' @{} })
$win.FindName('BtnExplorer').Add_Click({ Start-Task 'explore' @{} })
$win.FindName('BtnRemoveBloat').Add_Click({
    $ids = Get-SelectedTags $SpBloat
    if ($ids.Count -eq 0) { [System.Windows.MessageBox]::Show('Selecione pelo menos um item.', 'Windows Booster') | Out-Null; return }
    $ans = [System.Windows.MessageBox]::Show(("Remover " + $ids.Count + " item(ns)?`nApps da Store podem ser reinstalados depois pela loja."), 'Confirmar remocao', 'YesNo', 'Warning')
    if ($ans -ne 'Yes') { return }
    Start-Task 'appx' @{ Ids = $ids; AllUsers = [bool]$ChkAllUsers.IsChecked }
})
$win.FindName('BtnRunClean').Add_Click({
    $ids = Get-SelectedTags $SpClean
    if ($ids.Count -eq 0) { [System.Windows.MessageBox]::Show('Selecione pelo menos um item.', 'Windows Booster') | Out-Null; return }
    Start-Task 'clean' @{ Ids = $ids }
})
$win.FindName('BtnApplyTweaks').Add_Click({
    $ids = Get-SelectedTags $SpTweaks
    if ($ids.Count -eq 0) { [System.Windows.MessageBox]::Show('Selecione pelo menos um tweak.', 'Windows Booster') | Out-Null; return }
    $danger = @($ids | Where-Object { $_ -like 'e-*' })
    if ($danger.Count -gt 0) {
        $ans = [System.Windows.MessageBox]::Show(("Sua selecao inclui " + $danger.Count + " tweak(s) de RISCO do grupo E (Defender/Update/servicos).`nTem certeza?"), 'ATENCAO - risco', 'YesNo', 'Warning')
        if ($ans -ne 'Yes') { return }
    }
    Start-Task 'apply' @{ Ids = $ids }
})
$win.FindName('BtnRevertTweaks').Add_Click({
    $ids = Get-SelectedTags $SpTweaks
    if ($ids.Count -eq 0) { [System.Windows.MessageBox]::Show('Selecione pelo menos um tweak para reverter.', 'Windows Booster') | Out-Null; return }
    Start-Task 'revert' @{ Ids = $ids }
})
$win.FindName('BtnInstallDev').Add_Click({
    $list = @()
    foreach ($c in $SpDev.Children) {
        if ($c -is [System.Windows.Controls.WrapPanel]) {
            foreach ($cb in $c.Children) {
                if ($cb -is [System.Windows.Controls.CheckBox] -and $cb.IsChecked) {
                    $list += @{ Id = [string]$cb.Tag; Name = [string]$cb.Content }
                }
            }
        }
    }
    $custom = @($TxtCustomIds.Text -split '[ ,;]+' | Where-Object { $_ })
    foreach ($cid in $custom) { $list += @{ Id = [string]$cid; Name = ('Personalizado: ' + $cid) } }
    if ($list.Count -eq 0) { [System.Windows.MessageBox]::Show('Selecione algo para instalar.', 'Windows Booster') | Out-Null; return }
    Start-Task 'winget' @{ Apps = $list }
})
$win.FindName('BtnInstallIObit').Add_Click({
    $list = @()
    foreach ($c in $SpIObit.Children) {
        if ($c -is [System.Windows.Controls.WrapPanel]) {
            foreach ($cb in $c.Children) {
                if ($cb -is [System.Windows.Controls.CheckBox] -and $cb.IsChecked) {
                    $list += @{ Id = [string]$cb.Tag; Name = [string]$cb.Content }
                }
            }
        }
    }
    if ($list.Count -eq 0) { [System.Windows.MessageBox]::Show('Selecione pelo menos uma ferramenta.', 'Windows Booster') | Out-Null; return }
    Start-Task 'winget' @{ Apps = $list }
})
$win.FindName('BtnInstallDrivers').Add_Click({
    $list = @()
    foreach ($c in $SpDrivers.Children) {
        if ($c -is [System.Windows.Controls.WrapPanel]) {
            foreach ($cb in $c.Children) {
                if ($cb -is [System.Windows.Controls.CheckBox] -and $cb.IsChecked) {
                    $list += @{ Id = [string]$cb.Tag; Name = [string]$cb.Content }
                }
            }
        }
    }
    if ($list.Count -eq 0) { [System.Windows.MessageBox]::Show('Selecione a ferramenta do fabricante do seu PC.', 'Windows Booster') | Out-Null; return }
    Start-Task 'winget' @{ Apps = $list }
})
$win.FindName('BtnInstallAV').Add_Click({
    $sel = $null
    foreach ($c in $SpAV.Children) {
        if ($c -is [System.Windows.Controls.WrapPanel]) {
            foreach ($rb in $c.Children) { if ($rb -is [System.Windows.Controls.RadioButton] -and $rb.IsChecked) { $sel = $rb } }
        }
    }
    if (-not $sel) { [System.Windows.MessageBox]::Show('Escolha um antivirus na lista (radio).', 'Windows Booster') | Out-Null; return }
    $ans = [System.Windows.MessageBox]::Show("Instale apenas UM antivirus (dois brigam e travam o PC).`n`nInstalar: " + $sel.Content + "?", 'Confirmar', 'YesNo', 'Warning')
    if ($ans -ne 'Yes') { return }
    Start-Task 'winget' @{ Apps = @(@{ Id = [string]$sel.Tag; Name = [string]$sel.Content }) }
})
$win.FindName('BtnEnableDefender').Add_Click({ Start-Task 'defender-enable' @{} })

# ---------------- info inicial ----------------
try {
    $os   = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $disk = Get-PSDrive C -ErrorAction SilentlyContinue
    $wg   = Get-Command winget -ErrorAction SilentlyContinue
    $wgTxt = 'NAO ENCONTRADO - abra a Microsoft Store e instale "Instalador de Aplicativo" (App Installer)'
    if ($wg) { $wgTxt = & winget --version 2>$null }
    $ramGB  = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $freeGB = [Math]::Round($disk.Free / 1GB, 1)
    $TxtInfo.Text = "Sistema: $($os.Caption)  (build $($os.BuildNumber))`nMemoria: $ramGB GB  |  Livre em C: $freeGB GB`nwinget: $wgTxt`nExecutando como: Administrador"
} catch {
    $TxtInfo.Text = 'Nao foi possivel coletar informacoes do sistema.'
}

$win.Add_Closed({
    try { $timer.Stop() } catch {}
    foreach ($w in $script:Workers) { try { $w.Dispose() } catch {} }
})

[void]$win.ShowDialog()
