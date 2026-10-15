@echo off
rem Builds SurvivorInstaller.exe with the C# compiler that comes with Windows
rem (.NET Framework 4.8). No download, no external package.
cd /d "%~dp0"
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ ^
  /out:SurvivorInstaller.exe ^
  /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ^
  /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll ^
  /reference:System.Web.Extensions.dll ^
  SurvivorInstaller.cs
