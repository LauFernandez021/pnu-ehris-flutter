#define AppName "HRMS Admin"
#define AppVersion "1.0.1"
#define SourceDir "build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{270555EC-195B-4BFA-858F-EC2F7AE37171}}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\HRMS Admin
DefaultGroupName={#AppName}
CloseApplications=yes
OutputDir=build\installer
OutputBaseFilename=HRMS-Admin-Setup-{#AppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\desktop_admin.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\desktop_admin.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"
