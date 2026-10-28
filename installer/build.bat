@echo off
rem Builds SurvivorInstaller.exe with the C# compiler that comes with Windows
rem (.NET Framework 4.8). No download, no external package. The icons go in:
rem the S as the exe's own, and the three the tray and taskbar show inside it;
rem the title's font, Cinzel Decorative (SIL OFL, OFL-CinzelDecorative.txt), and the
rem art in art\ (Wenrexa's pack, CC0: art\CREDITS.txt), too.
cd /d "%~dp0"
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /optimize+ ^
  /out:SurvivorInstaller.exe ^
  /win32icon:SurvivorInstaller.ico ^
  /resource:SurvivorInstaller.ico,SurvivorInstaller.ico ^
  /resource:SurvivorUpdate.ico,SurvivorUpdate.ico ^
  /resource:UpdateOverlay.ico,UpdateOverlay.ico ^
  /resource:Logo.png,Logo.png ^
  /resource:CinzelDecorative-Bold.ttf,CinzelDecorative-Bold.ttf ^
  /resource:art\arrow-down.png,art.arrow-down.png ^
  /resource:art\bar-back.png,art.bar-back.png ^
  /resource:art\bar-border.png,art.bar-border.png ^
  /resource:art\bar-green.png,art.bar-green.png ^
  /resource:art\button-red.png,art.button-red.png ^
  /resource:art\button-red-wide.png,art.button-red-wide.png ^
  /resource:art\button-stone.png,art.button-stone.png ^
  /resource:art\card.png,art.card.png ^
  /resource:art\close.png,art.close.png ^
  /resource:art\field.png,art.field.png ^
  /resource:art\frame.png,art.frame.png ^
  /resource:art\gem-blue.png,art.gem-blue.png ^
  /resource:art\gem-green.png,art.gem-green.png ^
  /resource:art\gem-red.png,art.gem-red.png ^
  /resource:art\inset.png,art.inset.png ^
  /resource:art\minimize.png,art.minimize.png ^
  /resource:art\plaque.png,art.plaque.png ^
  /resource:art\scroll-thumb.png,art.scroll-thumb.png ^
  /resource:art\scroll-track.png,art.scroll-track.png ^
  /resource:art\scroll-track-v.png,art.scroll-track-v.png ^
  /resource:art\switch-off.png,art.switch-off.png ^
  /resource:art\switch-on.png,art.switch-on.png ^
  /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ^
  /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll ^
  /reference:System.Web.Extensions.dll ^
  SurvivorInstaller.cs
