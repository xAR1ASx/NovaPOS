; Script de Inno Setup para generar el instalador de NovaPOS.
;
; Como usarlo (en tu PC de trabajo, una sola vez):
;   1) Descarga e instala Inno Setup 6 (gratis): https://jrsoftware.org/isdl.php
;   2) Compila el ejecutable de la app:          flutter build windows --release
;   3) Compila el instalador (PowerShell):
;        & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" .\installer\NovaPOS_setup.iss
;   4) El instalador queda en:  .\installer\output\NovaPOS-Setup-1.1.0.exe
;
; Ese .exe se lo entregas al cliente: lo instala en Program Files, con acceso
; directo en el Escritorio y en el Menu de Inicio, y desinstalador.

#define MyAppName "NovaPOS"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "NovaPOS"
#define MyAppExeName "NovaPOS.exe"

[Setup]
AppId={{9D3A4E11-B912-0A35-F2C7-C00700000000}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\NovaPOS
DefaultGroupName=NovaPOS
DisableProgramGroupPage=yes
OutputDir={#SourcePath}output
OutputBaseFilename=NovaPOS-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear icono en el Escritorio"; GroupDescription: "Iconos adicionales:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir NovaPOS ahora"; Flags: nowait postinstall skipifsilent

[Code]
var
  ModoInterfazPage: TInputOptionWizardPage;

procedure InitializeWizard();
begin
  ModoInterfazPage := CreateInputOptionPage(
    wpSelectTasks,
    'Tipo de equipo',
    'Elige el modo de interfaz de NovaPOS',
    'Puedes cambiarlo después dentro de la aplicación, en Configuración -> Interfaz.',
    True, False);
  ModoInterfazPage.Add('PC de escritorio (ratón y teclado)');
  ModoInterfazPage.Add('Tablet / pantalla táctil (botones y textos más grandes)');
  ModoInterfazPage.SelectedValueIndex := 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  sModo: string;
  sRuta: string;
begin
  if CurStep = ssPostInstall then begin
    if ModoInterfazPage.SelectedValueIndex = 1 then
      sModo := 'Tablet'
    else
      sModo := 'PC';

    sRuta := ExpandConstant('{localappdata}\NovaPOS');
    if not DirExists(sRuta) then
      ForceDirectories(sRuta);

    SaveStringToFile(ExpandConstant('{localappdata}\NovaPOS\interfaz.txt'),
      sModo, False);
  end;
end;