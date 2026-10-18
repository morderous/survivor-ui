@echo off
rem Builds SurvivorInstaller.exe with the C# compiler that comes with Windows
rem (.NET Framework 4.8). No download, no external package. The icons go in:
rem the S as the exe's own, and the three the tray and taskbar show inside it.
cd /d "%~dp0"
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ ^
  /out:SurvivorInstaller.exe ^
  /win32icon:SurvivorInstaller.ico ^
  /resource:SurvivorInstaller.ico,SurvivorInstaller.ico ^
  /resource:SurvivorUpdate.ico,SurvivorUpdate.ico ^
  /resource:UpdateOverlay.ico,UpdateOverlay.ico ^
  /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ^
  /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll ^
  /reference:System.Web.Extensions.dll ^
  SurvivorInstaller.cs
