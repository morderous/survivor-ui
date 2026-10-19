// Survivor UI Launcher (the installer): installs and updates Survivor UI and Survivor Plates
// from the latest GitHub release, into Azeroth Survivors' AddOns folder.
//
// What it does, and nothing else:
//   - asks GitHub which release is the latest, and shows its notes;
//   - finds the game's AddOns folder (or lets the player pick the game);
//   - on Install, downloads the release's zip, removes the old SurvivorUI and
//     SurvivorPlates folders and unzips the new ones in their place;
//   - Play starts the game (the one by the AddOns folder), and the installer
//     steps into the tray;
//   - minimized or closed, waits in the tray, asking GitHub again every half
//     hour (only the tray's Exit quits it): when
//     a release newer than the one installed is out, a green arrow shows on
//     its tray icon and on its taskbar button, and a note says so once; the
//     tray's "Check for updates now" brings it forward and installs a newer
//     one at once. With the latest installed, a green "Up to date" badge
//     stands where the install button was;
//   - "Start with Windows, in the tray" (a tick in the window and in the
//     tray's menu): a line in the user's own Run key starts it with --tray,
//     in the tray without a window, to look for updates;
//   - two buttons, each with its version: the release (large, gold) and the
//     beta, the test build before a release (GitHub's pre-release), when one
//     newer than the release is out; a warning first, since a beta may have
//     more bugs than usual and updates more often. A beta installed follows
//     the betas (and the release once it is newer); the release's button
//     takes it back. A version with "-beta" stands below its release;
//   - gets the game: with no Azeroth Survivors by the AddOns folder nor in
//     its usual place, or one without its base data, Play turns to "Get the
//     game". It is Aethus' game, taken from his own servers with his ok, each
//     piece only when missing: the site's full package (wow.aethus.pl/
//     download) for the base data, Data\patch.MPQ, which nothing else
//     carries, unpacked by Windows' own tar; the newest exe and the newest
//     data patches, by the indexes the game updates itself by, each checked
//     by its sha256. Asked first, with the sizes; then Survivor UI installed
//     next. A line at the bottom says whose game it is, with a link to his site;
//   - keeps the game current: under the folder, the game's version (read in
//     its exe) against the newest its server lists, asked with each look at
//     GitHub; a newer one out, Play turns to "Update game", which takes the
//     newest exe and data patches the same way, checked (the game would also
//     update itself as it starts), and the tray tells of it once;
//   - updates itself: a release's SurvivorUI-Installer.zip carries its
//     version in the asset's label ("Installer 1.3.0"). At the top right,
//     its version and Check for updates; a newer one lights a green arrow
//     and the button turns to it, in the tray too; with "Update the
//     installer by itself" (on by default) it is taken at once: the running
//     exe renamed aside, the new one put in its place and started.
//
// Built with the C# compiler that comes with Windows (.NET Framework 4.8):
// see build.bat. C# 5, no external packages. Its icons (the addons' S, the S
// with the green arrow, the arrow alone) are built into the exe.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: System.Reflection.AssemblyTitle("Survivor UI Launcher")]
[assembly: System.Reflection.AssemblyProduct("Survivor UI")]
[assembly: System.Reflection.AssemblyVersion("1.4.2.0")]

namespace SurvivorInstaller
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            // Started with Windows: in the tray, no window.
            bool inTray = Array.Exists(args, delegate (string arg) { return arg == "--tray"; });
            // Started by the installer it replaces: that one is closing.
            bool updated = Array.Exists(args, delegate (string arg) { return arg == "--updated"; });
            // One at a time: opened again while it waits in the tray, the one
            // running comes forward instead; just updated, it waits for the old
            // one to let go.
            using (Mutex single = new Mutex(false, "SurvivorUIInstaller.Single"))
            {
                bool owned;
                try { owned = single.WaitOne(updated ? 20000 : 0, false); }
                catch (AbandonedMutexException) { owned = true; }
                if (!owned)
                {
                    if (!inTray) Native.PostMessage(Native.HWND_BROADCAST, Native.ShowMe, IntPtr.Zero, IntPtr.Zero);
                    return;
                }
                try
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    Application.Run(new MainForm(inTray, updated));
                }
                finally
                {
                    single.ReleaseMutex();
                }
            }
        }
    }

    // Windows' own calls: the messages that bring the installer forward and
    // tell that its taskbar button is up, and the taskbar's corner icon.
    static class Native
    {
        public static readonly IntPtr HWND_BROADCAST = (IntPtr)0xffff;
        public static readonly int ShowMe = RegisterWindowMessage("SurvivorUIInstaller.ShowMe");
        public static readonly int TaskbarButtonCreated = RegisterWindowMessage("TaskbarButtonCreated");

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int RegisterWindowMessage(string message);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool PostMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam);
    }

    [ComImport, Guid("ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ITaskbarList3
    {
        // ITaskbarList
        void HrInit();
        void AddTab(IntPtr hwnd);
        void DeleteTab(IntPtr hwnd);
        void ActivateTab(IntPtr hwnd);
        void SetActiveAlt(IntPtr hwnd);
        // ITaskbarList2
        void MarkFullscreenWindow(IntPtr hwnd, [MarshalAs(UnmanagedType.Bool)] bool fullscreen);
        // ITaskbarList3
        void SetProgressValue(IntPtr hwnd, ulong completed, ulong total);
        void SetProgressState(IntPtr hwnd, int flags);
        void RegisterTab(IntPtr tab, IntPtr mdi);
        void UnregisterTab(IntPtr tab);
        void SetTabOrder(IntPtr tab, IntPtr insertBefore);
        void SetTabActive(IntPtr tab, IntPtr mdi, uint reserved);
        void ThumbBarAddButtons(IntPtr hwnd, uint count, IntPtr buttons);
        void ThumbBarUpdateButtons(IntPtr hwnd, uint count, IntPtr buttons);
        void ThumbBarSetImageList(IntPtr hwnd, IntPtr imageList);
        void SetOverlayIcon(IntPtr hwnd, IntPtr icon, [MarshalAs(UnmanagedType.LPWStr)] string description);
        void SetThumbnailTooltip(IntPtr hwnd, [MarshalAs(UnmanagedType.LPWStr)] string tip);
        void SetThumbnailClip(IntPtr hwnd, IntPtr clip);
    }

    [ComImport, Guid("56FDF344-FD6D-11d0-958A-006097C9A090"), ClassInterface(ClassInterfaceType.None)]
    class TaskbarList { }

    class Release
    {
        public string Tag;
        public string Notes;
        public string ZipUrl;
        public string ZipName;
        public bool Beta;           // a pre-release on GitHub
        public string InstallerUrl; // its SurvivorUI-Installer.zip, with a version
        public Version InstallerVersion;
    }

    class MainForm : Form
    {
        const string Repo = "morderous/survivor-ui";
        const string GameExe = "AzerothSurvivors.exe";
        // Where the game usually is: its exe inside the benilla-config folder.
        const string CommonGameFolder = @"C:\Git\wenilla\benilla-config";
        static readonly string[] AddonFolders = { "SurvivorUI", "SurvivorPlates" };

        static readonly Color Back = Color.FromArgb(18, 18, 24);
        static readonly Color Panel = Color.FromArgb(28, 28, 36);
        static readonly Color Gold = Color.FromArgb(255, 209, 0);
        static readonly Color TextColor = Color.FromArgb(230, 230, 230);
        static readonly Color Muted = Color.FromArgb(150, 150, 160);
        static readonly Color BetaColor = Color.FromArgb(196, 168, 255);   // the betas' lavender
        static readonly Color TickText = Color.FromArgb(232, 206, 128);    // the ticks' words and marks, gold
        static readonly Color TickEdge = Color.FromArgb(150, 124, 48);
        static readonly Color StableFill = Color.FromArgb(178, 128, 10);
        static readonly Color StableText = Color.FromArgb(255, 248, 228);
        static readonly Color LauncherDim = Color.FromArgb(28, 120, 52);
        static readonly Color LauncherLit = Color.FromArgb(58, 190, 88);

        readonly Label addonLabel = new Label();    // Survivor UI's version, under the launcher's
        readonly TextBox folderBox = new TextBox();
        readonly TextBox notesBox = new TextBox();
        readonly Button installButton = new Button();
        readonly Button browseButton = new Button();
        readonly Button playButton = new Button();
        readonly Label statusLabel = new Label();
        readonly Label upToDate = new Label();
        readonly CheckBox startBox = new CheckBox();
        readonly LinkLabel openLink = new LinkLabel();
        readonly Button betaButton = new Button();
        readonly CheckBox selfBox = new CheckBox();
        readonly Label versionLabel = new Label();
        readonly Button selfButton = new Button();
        readonly Panel arrowMark = new Panel();
        readonly ToolTip tips = new ToolTip();
        Release updatingTo;         // the installer being downloaded, while it is
        bool checkingByHand;        // Check for updates clicked: the answer said

        Release stable, pre;        // the newest release and the newest beta
        Release latest;             // the one followed: the release, or a newer beta once one is installed

        // The tray, and the half hourly look at GitHub.
        const int CheckEvery = 30 * 60 * 1000;
        readonly NotifyIcon tray = new NotifyIcon();
        readonly ToolStripMenuItem installItem = new ToolStripMenuItem("Install the update");
        readonly System.Windows.Forms.Timer checkTimer = new System.Windows.Forms.Timer();
        Icon appIcon, trayIcon, trayUpdateIcon, overlayIcon;
        ITaskbarList3 taskbar;
        bool updateWaiting;
        string toldOf;              // the release the tray's note last told of
        bool toldOfTray;            // the note that the installer waits in the tray, once
        bool installWhenNewer;      // asked from the tray: a newer release is installed at once
        bool installing;
        bool startHidden;           // started with Windows: the window stays away until asked for
        readonly ToolStripMenuItem startItem = new ToolStripMenuItem("Start with Windows");
        readonly ToolStripMenuItem playItem = new ToolStripMenuItem("Play");
        bool exiting;               // the tray's Exit: the window closes for good
        readonly ToolStripMenuItem selfItem = new ToolStripMenuItem("Update the launcher");
        static readonly Version OwnVersion = Assembly.GetExecutingAssembly().GetName().Version;
        Release selfRelease;        // the release with a newer installer, while one is out
        bool selfUpdating;
        bool gettingGame;           // the game being asked for or downloaded
        readonly Label gameLabel = new Label();
        readonly Button gameCheckButton = new Button();
        GameState game;             // the game as last looked at, against the newest on its server
        bool checkingGame;
        bool gameByHand;            // Check version clicked: the answer said in the status line
        string playNote = "";       // under Play's words: the game's version, or from which to which
        string toldOfGame;          // the game version the tray's note last told of
        readonly LinkLabel creditLink = new LinkLabel();
        string toldOfSelf;          // the installer version the tray's note last told of

        // Starting with Windows: a line of the user's own Run key, the exe's
        // path with --tray. Nothing else is written.
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        const string RunName = "SurvivorUIInstaller";

        static bool StartsWithWindows()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RunKey))
                    return key != null && key.GetValue(RunName) != null;
            }
            catch { return false; }
        }

        static void SetStartWithWindows(bool on)
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.CreateSubKey(RunKey))
                {
                    if (on) key.SetValue(RunName, "\"" + Application.ExecutablePath + "\" --tray");
                    else key.DeleteValue(RunName, false);
                }
            }
            catch { }
        }

        static string ConfigPath
        {
            get
            {
                string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "SurvivorUIInstaller");
                Directory.CreateDirectory(dir);
                return Path.Combine(dir, "addons-folder.txt");
            }
        }

        // Up to 1.3 the beta channel was a tick, kept as this file; a beta
        // installed now says it.
        static void ForgetBetaTick()
        {
            try
            {
                string old = Path.Combine(Path.GetDirectoryName(ConfigPath), "beta-channel.txt");
                if (File.Exists(old)) File.Delete(old);
            }
            catch { }
        }

        // The installer updates itself unless this file is there.
        static string SelfOffPath
        {
            get { return Path.Combine(Path.GetDirectoryName(ConfigPath), "self-update-off.txt"); }
        }

        static bool SelfAuto()
        {
            try { return !File.Exists(SelfOffPath); }
            catch { return true; }
        }

        static void SetSelfAuto(bool on)
        {
            try
            {
                if (on) { if (File.Exists(SelfOffPath)) File.Delete(SelfOffPath); }
                else File.WriteAllText(SelfOffPath, "The launcher does not update itself while this file is here.");
            }
            catch { }
        }

        public MainForm(bool inTray, bool updated)
        {
            startHidden = inTray;
            this.Text = "Survivor UI Launcher";
            ClientSize = new Size(560, 542);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Back;
            ForeColor = TextColor;
            Font = new Font("Segoe UI", 9.5f);
            LoadIcons();
            if (appIcon != null) Icon = appIcon;

            // The emblem, the shield with the S, beside the name.
            PictureBox logo = new PictureBox();
            logo.Location = new Point(16, 12);
            logo.Size = new Size(48, 48);
            logo.SizeMode = PictureBoxSizeMode.Zoom;
            logo.Image = EmbeddedImage("Logo.png");
            Controls.Add(logo);

            Label title = new Label();
            title.Text = "Survivor UI Launcher";
            title.Font = new Font("Segoe UI", 15f, FontStyle.Bold);
            title.ForeColor = Gold;
            title.AutoSize = true;
            title.Location = new Point(68, 12);
            Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "Play Azeroth Survivors with Survivor UI";
            subtitle.UseMnemonic = false;
            subtitle.ForeColor = Muted;
            subtitle.AutoSize = true;
            subtitle.Location = new Point(70, 44);
            Controls.Add(subtitle);

            // At the top right, the versions together, the launcher's and Survivor
            // UI's, Check for updates under them; a newer launcher out: a green
            // arrow by its version, and the button turns to it, green, breathing
            // so it is seen.
            arrowMark.Location = new Point(360, 10);
            arrowMark.Size = new Size(16, 18);
            arrowMark.Visible = false;
            arrowMark.Paint += delegate (object sender, PaintEventArgs e)
            {
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                float w = arrowMark.Width - 1, h = arrowMark.Height - 1;
                PointF[] shape = {
                    new PointF(w * 0.32f, 0.5f), new PointF(w * 0.68f, 0.5f), new PointF(w * 0.68f, h * 0.44f),
                    new PointF(w * 0.98f, h * 0.44f), new PointF(w * 0.5f, h), new PointF(w * 0.02f, h * 0.44f),
                    new PointF(w * 0.32f, h * 0.44f) };
                using (Brush fill = new SolidBrush(Color.FromArgb(58, 214, 92))) e.Graphics.FillPolygon(fill, shape);
                using (Pen edge = new Pen(Color.FromArgb(6, 32, 12), 1f)) e.Graphics.DrawPolygon(edge, shape);
            };
            Controls.Add(arrowMark);

            versionLabel.AutoSize = false;
            versionLabel.Location = new Point(380, 10);
            versionLabel.Size = new Size(170, 18);
            versionLabel.Font = new Font("Segoe UI", 9f);
            versionLabel.TextAlign = ContentAlignment.MiddleLeft;
            Controls.Add(versionLabel);

            addonLabel.AutoSize = false;
            addonLabel.Location = new Point(380, 28);
            addonLabel.Size = new Size(170, 18);
            addonLabel.Font = new Font("Segoe UI", 9f);
            addonLabel.TextAlign = ContentAlignment.MiddleLeft;
            addonLabel.ForeColor = Muted;
            Controls.Add(addonLabel);

            selfButton.FlatStyle = FlatStyle.Flat;
            selfButton.Cursor = Cursors.Hand;
            selfButton.Location = new Point(380, 50);
            selfButton.Size = new Size(160, 26);
            selfButton.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            selfButton.Click += delegate
            {
                if (selfRelease != null)
                {
                    UpdateSelf();
                    return;
                }
                checkingByHand = true;
                ShowOwnVersion();
                Status("Asking GitHub for updates...");
                CheckNow();
            };
            Controls.Add(selfButton);
            System.Windows.Forms.Timer breathe = new System.Windows.Forms.Timer();
            breathe.Interval = 50;
            double breath = 0;
            breathe.Tick += delegate
            {
                if (selfRelease == null || selfUpdating) return;
                breath += 0.12;
                double t = (Math.Sin(breath) + 1) / 2;
                selfButton.BackColor = Color.FromArgb(
                    (int)(LauncherDim.R + (LauncherLit.R - LauncherDim.R) * t),
                    (int)(LauncherDim.G + (LauncherLit.G - LauncherDim.G) * t),
                    (int)(LauncherDim.B + (LauncherLit.B - LauncherDim.B) * t));
            };
            breathe.Start();
            ShowOwnVersion();

            Label folderLabel = new Label();
            folderLabel.Text = "Game's AddOns folder";
            folderLabel.ForeColor = Muted;
            folderLabel.AutoSize = true;
            folderLabel.Location = new Point(20, 110);
            Controls.Add(folderLabel);

            folderBox.Location = new Point(20, 130);
            folderBox.Size = new Size(420, 24);
            folderBox.BackColor = Panel;
            folderBox.ForeColor = TextColor;
            folderBox.BorderStyle = BorderStyle.FixedSingle;
            folderBox.TextChanged += delegate { ShowInstalled(); };
            Controls.Add(folderBox);

            Style(browseButton, "Find game...");
            browseButton.Location = new Point(448, 129);
            browseButton.Size = new Size(92, 26);
            browseButton.Click += delegate { BrowseForGame(); };
            Controls.Add(browseButton);

            // Under the box: the game found, its version against the newest;
            // none found, where it should be (ShowGameLine).
            gameLabel.Font = new Font("Segoe UI", 8f);
            gameLabel.ForeColor = Muted;
            gameLabel.AutoSize = true;
            gameLabel.Location = new Point(20, 158);
            Controls.Add(gameLabel);

            // Check version: wow.aethus.pl asked again, now; the line beside it
            // and the status line say whether a newer game is out.
            Style(gameCheckButton, "Check version");
            gameCheckButton.Font = new Font("Segoe UI", 7.5f, FontStyle.Bold);
            gameCheckButton.Location = new Point(20, 157);
            gameCheckButton.Size = new Size(92, 20);
            gameCheckButton.Visible = false;
            gameCheckButton.Click += delegate
            {
                if (checkingGame) return;
                gameByHand = true;
                CheckGame();
            };
            tips.SetToolTip(gameCheckButton, "Asks wow.aethus.pl now whether a newer Azeroth Survivors is out.");
            Controls.Add(gameCheckButton);

            // The folder itself, opened: under Find game..., by the box.
            openLink.Text = "Open folder";
            openLink.AutoSize = false;
            openLink.Location = new Point(448, 160);
            openLink.Size = new Size(92, 18);
            openLink.TextAlign = ContentAlignment.MiddleCenter;
            openLink.LinkColor = Gold;
            openLink.ActiveLinkColor = Color.White;
            openLink.VisitedLinkColor = Gold;
            openLink.LinkBehavior = LinkBehavior.HoverUnderline;
            openLink.LinkClicked += delegate
            {
                if (Directory.Exists(folderBox.Text)) Process.Start("explorer.exe", "\"" + folderBox.Text + "\"");
                else Status("That folder is not there yet: pick the game first.");
            };
            Controls.Add(openLink);

            Label notesLabel = new Label();
            notesLabel.Text = "What's new";
            notesLabel.ForeColor = Muted;
            notesLabel.AutoSize = true;
            notesLabel.Location = new Point(20, 194);
            Controls.Add(notesLabel);

            // The notes in a large window, quietly by "What's new".
            LinkLabel readLink = new LinkLabel();
            readLink.Text = "Read larger";
            readLink.AutoSize = false;
            readLink.Location = new Point(400, 194);
            readLink.Size = new Size(140, 18);
            readLink.TextAlign = ContentAlignment.MiddleRight;
            readLink.LinkColor = Gold;
            readLink.ActiveLinkColor = Color.White;
            readLink.VisitedLinkColor = Gold;
            readLink.LinkBehavior = LinkBehavior.HoverUnderline;
            readLink.LinkClicked += delegate { ShowNotesWindow(); };
            Controls.Add(readLink);

            notesBox.Location = new Point(20, 214);
            notesBox.Size = new Size(520, 168);
            notesBox.Multiline = true;
            notesBox.ReadOnly = true;
            notesBox.ScrollBars = ScrollBars.Vertical;
            notesBox.BackColor = Panel;
            notesBox.ForeColor = TextColor;
            notesBox.BorderStyle = BorderStyle.FixedSingle;
            notesBox.Text = "Asking GitHub for the latest release...";
            Controls.Add(notesBox);

            // The release: large and gold, its version on it; the badge in its
            // place while it is the one installed.
            installButton.Text = "Install";
            installButton.FlatStyle = FlatStyle.Flat;
            installButton.FlatAppearance.BorderColor = Color.FromArgb(255, 226, 120);
            installButton.BackColor = StableFill;
            installButton.ForeColor = StableText;
            installButton.Cursor = Cursors.Hand;
            installButton.Location = new Point(20, 394);
            installButton.Size = new Size(260, 40);
            installButton.Font = new Font("Segoe UI", 11f, FontStyle.Bold);
            Active(installButton, false, StableText);
            installButton.Click += delegate { if (IsActive(installButton) && stable != null) Install(stable); };
            Controls.Add(installButton);

            upToDate.Location = installButton.Location;
            upToDate.Size = installButton.Size;
            upToDate.TextAlign = ContentAlignment.MiddleCenter;
            upToDate.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
            upToDate.ForeColor = Color.FromArgb(110, 225, 125);
            upToDate.BackColor = Color.FromArgb(22, 44, 28);
            upToDate.BorderStyle = BorderStyle.FixedSingle;
            upToDate.Visible = false;
            Controls.Add(upToDate);

            // The beta: smaller, orange, its version on it; a warning first.
            betaButton.Text = "No beta right now";
            betaButton.FlatStyle = FlatStyle.Flat;
            betaButton.FlatAppearance.BorderColor = Color.FromArgb(112, 86, 176);
            betaButton.BackColor = Color.FromArgb(34, 26, 58);
            betaButton.ForeColor = BetaColor;
            betaButton.Cursor = Cursors.Hand;
            betaButton.Location = new Point(20, 442);
            betaButton.Size = new Size(260, 28);
            betaButton.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            Active(betaButton, false, BetaColor);
            betaButton.Click += delegate { if (IsActive(betaButton)) InstallBeta(); };
            Controls.Add(betaButton);

            Label betaNote = new Label();
            betaNote.Text = "Betas come before a release: more bugs than usual, updated more often.";
            betaNote.Font = new Font("Segoe UI", 8f);
            betaNote.ForeColor = Muted;
            betaNote.AutoSize = false;
            betaNote.Location = new Point(20, 473);
            betaNote.Size = new Size(270, 30);
            Controls.Add(betaNote);

            // Play: the game by the AddOns folder, started; the installer steps
            // into the tray.
            playButton.Text = "\u25B6  Play";
            playButton.FlatStyle = FlatStyle.Flat;
            playButton.FlatAppearance.BorderColor = Color.FromArgb(70, 150, 85);
            playButton.BackColor = Color.FromArgb(24, 52, 30);
            playButton.ForeColor = Color.FromArgb(125, 232, 140);
            playButton.Cursor = Cursors.Hand;
            playButton.Location = new Point(380, 394);
            playButton.Size = new Size(160, 40);
            playButton.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
            playButton.Click += delegate { if (GameMissing() || GameBehind()) GetGame(); else Play(); };
            // The game's version, small, at the bottom inside it (playNote).
            playButton.Paint += delegate (object sender, PaintEventArgs e)
            {
                if (playNote == "") return;
                using (Font small = new Font("Segoe UI", 7.5f))
                    TextRenderer.DrawText(e.Graphics, playNote, small,
                        new Rectangle(0, playButton.Height - 17, playButton.Width, 14),
                        playButton.Enabled ? Color.FromArgb(165, 222, 175) : Muted,
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding);
            };
            Controls.Add(playButton);

            // Start with Windows: under the install button, the same tick as
            // the tray's menu.
            startBox.Text = "Start with Windows, in the tray";
            startBox.AutoSize = true;
            startBox.Location = new Point(300, 446);
            startBox.ForeColor = TickText;
            startBox.FlatStyle = FlatStyle.Flat;
            startBox.FlatAppearance.BorderColor = TickEdge;
            startBox.Cursor = Cursors.Hand;
            startBox.Checked = StartsWithWindows();
            startBox.CheckedChanged += delegate
            {
                SetStartWithWindows(startBox.Checked);
                startItem.Checked = startBox.Checked;
                Status(startBox.Checked
                    ? "It will start with Windows, in the tray, and tell you of updates."
                    : "It will no longer start with Windows.");
            };
            Controls.Add(startBox);
            // Moved since it was set: the line follows the exe.
            if (startBox.Checked) SetStartWithWindows(true);

            // Its own updates: taken by itself unless unticked.
            selfBox.Text = "Update the launcher by itself";
            selfBox.AutoSize = true;
            selfBox.Location = new Point(300, 472);
            selfBox.ForeColor = TickText;
            selfBox.FlatStyle = FlatStyle.Flat;
            selfBox.FlatAppearance.BorderColor = TickEdge;
            selfBox.Cursor = Cursors.Hand;
            selfBox.Checked = SelfAuto();
            selfBox.CheckedChanged += delegate
            {
                SetSelfAuto(selfBox.Checked);
                Status(selfBox.Checked
                    ? "The launcher will update itself when a new one is out."
                    : "The launcher will only tell you when a new one is out.");
                if (selfBox.Checked && selfRelease != null) UpdateSelf();
            };
            Controls.Add(selfBox);
            TickLook(startBox);
            TickLook(selfBox);

            statusLabel.Location = new Point(20, 502);
            statusLabel.Size = new Size(520, 20);
            statusLabel.ForeColor = Muted;
            Controls.Add(statusLabel);

            // Whose game it is, at the bottom left; his site in the other corner.
            Label credit = new Label();
            credit.Text = "Azeroth Survivors is a game by Aethus";
            credit.Font = new Font("Segoe UI", 8f);
            credit.AutoSize = false;
            credit.Location = new Point(20, 522);
            credit.Size = new Size(320, 18);
            credit.ForeColor = Muted;
            credit.TextAlign = ContentAlignment.MiddleLeft;
            Controls.Add(credit);

            creditLink.Text = "wow.aethus.pl";
            creditLink.Font = new Font("Segoe UI", 8f);
            creditLink.AutoSize = false;
            creditLink.Location = new Point(380, 522);
            creditLink.Size = new Size(160, 18);
            creditLink.TextAlign = ContentAlignment.MiddleRight;
            creditLink.LinkColor = Gold;
            creditLink.ActiveLinkColor = Color.White;
            creditLink.VisitedLinkColor = Gold;
            creditLink.LinkBehavior = LinkBehavior.HoverUnderline;
            creditLink.LinkClicked += delegate
            {
                try { Process.Start(GameSite); } catch { }
            };
            Controls.Add(creditLink);

            SetUpTray();
            ForgetBetaTick();

            folderBox.Text = FindAddonsFolder() ?? "";
            // No game found, or one without its data: the way to it, Get the game
            // first (the game elsewhere: Find game...).
            if (GameExePath() == null)
                Status("No game found: click \"Get the game\", or \"Find game...\" if yours is somewhere else.");
            else if (GameMissing())
                Status("The game's data is missing: click \"Get the game\" to fill it in.");
            ShowInstalled();

            // Just updated: the old exe, set aside, goes once it has closed.
            if (updated) Status("The launcher is now " + Short(OwnVersion) + ".");
            CleanUpOld(updated);

            Shown += delegate { CheckNow(); };
            checkTimer.Interval = CheckEvery;
            checkTimer.Tick += delegate { CheckNow(); };
            checkTimer.Start();
        }

        // --- The tray ---------------------------------------------------------

        // The icons built into the exe (build.bat): the S, the S with the green
        // arrow, the arrow alone; each at the size it is shown.
        void LoadIcons()
        {
            appIcon = Embedded("SurvivorInstaller.ico", new Size(32, 32));
            trayIcon = Embedded("SurvivorInstaller.ico", SystemInformation.SmallIconSize);
            trayUpdateIcon = Embedded("SurvivorUpdate.ico", SystemInformation.SmallIconSize);
            overlayIcon = Embedded("UpdateOverlay.ico", SystemInformation.SmallIconSize);
        }

        // A picture built into the exe (build.bat), whole.
        static Image EmbeddedImage(string name)
        {
            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
                {
                    if (stream == null) return null;
                    using (Image image = Image.FromStream(stream))
                        return new Bitmap(image);
                }
            }
            catch { return null; }
        }

        static Icon Embedded(string name, Size size)
        {
            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
                    return stream == null ? null : new Icon(stream, size);
            }
            catch { return null; }
        }

        void SetUpTray()
        {
            tray.Icon = trayIcon ?? SystemIcons.Application;
            tray.Text = "Survivor UI Launcher";
            ContextMenuStrip menu = new ContextMenuStrip();
            menu.Items.Add("Open", null, delegate { FromTray(); });
            playItem.Click += delegate { Play(); };
            menu.Items.Add(playItem);
            menu.Items.Add("Check for updates now", null, delegate
            {
                FromTray();
                installWhenNewer = true;
                Status("Asking GitHub for the latest release...");
                CheckNow();
            });
            installItem.Enabled = false;
            installItem.Click += delegate { FromTray(); if (latest != null) Install(latest); };
            menu.Items.Add(installItem);
            selfItem.Visible = false;
            selfItem.Click += delegate { UpdateSelf(); };
            menu.Items.Add(selfItem);
            startItem.CheckOnClick = false;
            startItem.Checked = StartsWithWindows();
            startItem.Click += delegate { startBox.Checked = !startBox.Checked; };
            menu.Items.Add(startItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Exit", null, delegate { exiting = true; Close(); });
            tray.ContextMenuStrip = menu;
            tray.MouseClick += delegate (object sender, MouseEventArgs e)
            {
                if (e.Button == MouseButtons.Left) FromTray();
            };
            tray.BalloonTipClicked += delegate { FromTray(); };
            tray.Visible = true;

            // Minimized, it waits in the tray instead of the taskbar.
            Resize += delegate
            {
                if (WindowState != FormWindowState.Minimized) return;
                ToTray();
            };
            FormClosed += delegate
            {
                tray.Visible = false;
                tray.Dispose();
            };
        }

        // Into the tray, saying so the first time.
        void ToTray()
        {
            Hide();
            if (!toldOfTray && !updateWaiting)
            {
                toldOfTray = true;
                tray.ShowBalloonTip(5000, "Survivor UI Launcher",
                    "Still here, in the tray: a green arrow shows when an update is out. To quit it, right click this icon and choose Exit.", ToolTipIcon.Info);
            }
        }

        // The window's close button: into the tray. Only the tray's Exit (or
        // Windows shutting down) closes it for good.
        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!exiting && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                ToTray();
                return;
            }
            base.OnFormClosing(e);
        }

        // --- Play -------------------------------------------------------------

        // The game for an AddOns folder: its exe in benilla-config (the folder
        // holding AddOns), or one folder up.
        static string GameFor(string addons)
        {
            try
            {
                string config = Path.GetDirectoryName((addons ?? "").Trim().TrimEnd('\\'));
                foreach (string dir in new[] { config, config == null ? null : Path.GetDirectoryName(config) })
                {
                    if (string.IsNullOrEmpty(dir)) continue;
                    string exe = Path.Combine(dir, GameExe);
                    if (File.Exists(exe)) return exe;
                }
            }
            catch { }
            return null;
        }

        static bool GameRunning()
        {
            return Process.GetProcessesByName(Path.GetFileNameWithoutExtension(GameExe)).Length > 0;
        }

        void Play()
        {
            string exe = GameFor(folderBox.Text);
            if (exe == null)
            {
                FromTray();
                Status("The game is not found by that AddOns folder: click \"Find game...\".");
                return;
            }
            if (GameMissing())
            {
                FromTray();
                Status("The game's data is missing: click \"Get the game\".");
                return;
            }
            if (GameRunning())
            {
                Status("The game is already open.");
                return;
            }
            try
            {
                ProcessStartInfo info = new ProcessStartInfo(exe);
                info.WorkingDirectory = Path.GetDirectoryName(exe);
                info.UseShellExecute = true;
                Process.Start(info);
                Status("Starting the game...");
                if (Visible) ToTray();
            }
            catch (Exception error)
            {
                FromTray();
                Status("Could not start the game: " + error.Message);
            }
        }

        void FromTray()
        {
            Show();
            if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal;
            Activate();
            ShowOverlay();
        }

        // The beta's button: a warning, then the beta installed; from then on
        // the installer follows the betas.
        void InstallBeta()
        {
            if (pre == null || pre.ZipUrl == null) return;
            DialogResult go = MessageBox.Show(this,
                "Beta builds come before a release, to be tested: they may have more bugs than usual, and they update more often.\n\n" +
                "Install " + pre.Tag + "? From then on the launcher follows the betas; the release's button takes you back.",
                "Survivor UI beta", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (go == DialogResult.Yes) Install(pre);
        }

        // --- The notes, larger ------------------------------------------------

        NotesForm notesWindow;

        void ShowNotesWindow()
        {
            if (latest == null)
            {
                Status("The notes come with the latest release: wait for GitHub's answer.");
                return;
            }
            if (notesWindow == null || notesWindow.IsDisposed)
                notesWindow = new NotesForm(appIcon);
            notesWindow.ShowNotes("What's new in Survivor UI " + latest.Tag + (latest.Beta ? " (beta)" : ""), latest.Notes);
            if (!notesWindow.Visible) notesWindow.Show(this);
            notesWindow.Activate();
        }

        void CheckNow()
        {
            new Thread(FetchLatest) { IsBackground = true }.Start();
            CheckGame();
        }

        protected override void SetVisibleCore(bool value)
        {
            if (startHidden)
            {
                startHidden = false;
                toldOfTray = true;
                if (!IsHandleCreated) CreateHandle();
                value = false;
                CheckNow();
            }
            base.SetVisibleCore(value);
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == Native.ShowMe)
            {
                FromTray();
                return;
            }
            base.WndProc(ref m);
            // The taskbar button made (again): its corner arrow put back on.
            if (m.Msg == Native.TaskbarButtonCreated) ShowOverlay();
        }

        // The green arrow on the taskbar button's corner while an update waits.
        void ShowOverlay()
        {
            // Only with a taskbar button: none while it waits in the tray.
            if (!IsHandleCreated || !Visible) return;
            try
            {
                if (taskbar == null)
                {
                    taskbar = (ITaskbarList3)new TaskbarList();
                    taskbar.HrInit();
                }
                bool on = updateWaiting && overlayIcon != null;
                taskbar.SetOverlayIcon(Handle, on ? overlayIcon.Handle : IntPtr.Zero, on ? "Update available" : null);
            }
            catch
            {
                // No corner icons on this Windows: the window's own icon tells instead.
                Icon icon = updateWaiting ? Embedded("SurvivorUpdate.ico", new Size(32, 32)) : appIcon;
                if (icon != null) Icon = icon;
            }
        }

        // A release newer than the one installed: the arrows on, the menu's
        // install item, and the note once per release. The latest installed:
        // the "Up to date" badge in the install button's place.
        void ShowUpdateState()
        {
            string installed = InstalledVersion(folderBox.Text);
            // A beta installed follows the betas, the release once it is newer.
            bool betaOut = pre != null && pre.ZipUrl != null && (stable == null || Newer(pre.Tag, stable.Tag));
            latest = installed != null && IsBeta(installed) && betaOut ? pre : (stable ?? (betaOut ? pre : null));
            bool known = latest != null && latest.ZipUrl != null;
            updateWaiting = known && installed != null && Newer(latest.Tag, installed);
            bool current = known && installed != null && !updateWaiting;
            tray.Icon = updateWaiting ? (trayUpdateIcon ?? tray.Icon) : (trayIcon ?? tray.Icon);
            tray.Text = updateWaiting ? Trim("Survivor UI " + latest.Tag + " is out: click to update", 63)
                : current ? "Survivor UI Launcher: up to date" : "Survivor UI Launcher";
            installItem.Enabled = updateWaiting && !installing;
            // Play, or Get the game while there is none: by the AddOns folder,
            // nor in its usual place.
            bool missing = GameMissing();
            bool behind = !missing && GameBehind();
            bool playable = !installing && !gettingGame && GameFor(folderBox.Text) != null;
            playButton.Text = missing ? "\u2193  Get the game" : behind ? "\u2191  Update game" : "\u25B6  Play";
            playButton.Enabled = missing || behind ? !installing && !gettingGame : playable;
            tips.SetToolTip(playButton, missing
                ? "Download Azeroth Survivors, Aethus' game, from his own servers (wow.aethus.pl)."
                : behind ? "Azeroth Survivors " + game.Latest + " is out: download it from wow.aethus.pl, checked. (The game would also update itself as it starts.)"
                : "Start the game; the launcher steps into the tray.");
            playItem.Enabled = playable && !missing;
            // Under its words, small: the game's version; an update out, from
            // which to which (the newer data alone: its version and "new data").
            string note = "";
            if (!missing && game != null && game.Exe == GameExePath() && game.Version != null)
            {
                if (!behind) note = "Ver. " + game.Version;
                else if (game.Latest != game.Version) note = "Ver. " + game.Version + " → " + game.Latest;
                else note = "Ver. " + game.Version + "  ·  new data";
            }
            if (note != playNote)
            {
                playNote = note;
                playButton.Padding = note != "" ? new Padding(0, 0, 0, 12) : Padding.Empty;
                playButton.Invalidate();
            }
            ShowGameLine();
            if (behind && toldOfGame != game.Latest)
            {
                toldOfGame = game.Latest;
                tray.ShowBalloonTip(6000, "Azeroth Survivors " + game.Latest + " is out",
                    "Click Update game in the launcher, or play: the game updates itself as it starts.", ToolTipIcon.Info);
            }
            installItem.Text = updateWaiting ? "Install " + latest.Tag : current ? "Up to date (" + latest.Tag + ")" : "Install the update";
            // Survivor UI's version under the launcher's, and the newer one out.
            addonLabel.Text = installed == null ? "Survivor UI not installed"
                : "Survivor UI ver. " + installed + (updateWaiting ? " → " + latest.Tag.TrimStart('v', 'V') : "");
            addonLabel.ForeColor = updateWaiting ? Color.FromArgb(110, 225, 125) : Muted;
            tips.SetToolTip(addonLabel, stable != null ? "Latest release on GitHub: " + stable.Tag : "GitHub not asked yet.");

            // The release's button: its version, and what installing it does.
            bool stableKnown = stable != null && stable.ZipUrl != null;
            bool onStable = stableKnown && installed != null && Same(stable.Tag, installed);
            installButton.Text = !stableKnown ? "Install"
                : installed == null ? "Install " + stable.Tag
                : Newer(stable.Tag, installed) ? "Update to " + stable.Tag
                : IsBeta(installed) ? "Back to stable " + stable.Tag
                : "Install " + stable.Tag;
            installButton.Visible = !onStable;
            Active(installButton, stableKnown && !installing, StableText);
            upToDate.Text = onStable ? "\u2713  Up to date  \u00B7  " + stable.Tag : "";
            upToDate.Visible = onStable;

            // The beta's button: its version, or none newer than the release.
            bool onBeta = betaOut && installed != null && Same(pre.Tag, installed);
            betaButton.Text = !betaOut ? "No beta right now" : onBeta ? "\u2713  Beta " + pre.Tag + " installed" : "Install beta " + pre.Tag;
            Active(betaButton, betaOut && !onBeta && !installing, BetaColor);
            ShowOverlay();
            // Asked from the tray: a newer one installed at once, or said so.
            if (installWhenNewer && latest != null)
            {
                installWhenNewer = false;
                if (updateWaiting && !installing)
                {
                    Install(latest);
                    return;
                }
                if (current) Status("Survivor UI " + latest.Tag + " is the latest: up to date.");
            }
            if (updateWaiting && toldOf != latest.Tag)
            {
                toldOf = latest.Tag;
                tray.ShowBalloonTip(6000, "Survivor UI " + latest.Tag + " is out",
                    (latest.Beta ? "A beta build: more bugs than usual. " : "") + "Click to see what's new and update.", ToolTipIcon.Info);
            }
        }

        // The same version: neither newer than the other.
        static bool Same(string a, string b)
        {
            return !Newer(a, b) && !Newer(b, a);
        }

        static string Trim(string text, int most)
        {
            return text.Length <= most ? text : text.Substring(0, most);
        }

        // "v3.0.5-beta.2" against "3.0.5": the numbers before any "-beta", one
        // by one, a missing one as 0; the same numbers, the release stands
        // above any beta, and a later beta above an earlier one.
        static bool Newer(string tag, string installed)
        {
            MatchCollection a = Regex.Matches(Numbers(tag), @"\d+");
            MatchCollection b = Regex.Matches(Numbers(installed), @"\d+");
            for (int i = 0; i < Math.Max(a.Count, b.Count); i++)
            {
                int x = i < a.Count ? int.Parse(a[i].Value) : 0;
                int y = i < b.Count ? int.Parse(b[i].Value) : 0;
                if (x != y) return x > y;
            }
            return BetaNumber(tag) > BetaNumber(installed);
        }

        // The version's numbers: what comes before any "-".
        static string Numbers(string version)
        {
            version = version ?? "";
            int dash = version.IndexOf('-');
            return dash < 0 ? version : version.Substring(0, dash);
        }

        static bool IsBeta(string version)
        {
            return Regex.IsMatch(version ?? "", @"-beta", RegexOptions.IgnoreCase);
        }

        // A beta's number ("-beta.2": 2, "-beta": 0); a release stands above them all.
        static int BetaNumber(string version)
        {
            Match match = Regex.Match(version ?? "", @"-beta\.?(\d*)", RegexOptions.IgnoreCase);
            if (!match.Success) return int.MaxValue;
            return match.Groups[1].Value == "" ? 0 : int.Parse(match.Groups[1].Value);
        }

        // A button on or off by its look alone: a disabled button's words go the
        // system's dark grey, unreadable on these colors. Off, its words fade
        // into its own color, no hand nor hover, and a click does nothing.
        static void Active(Button button, bool on, Color text)
        {
            button.Tag = on;
            Color back = button.BackColor;
            button.ForeColor = on ? text
                : Color.FromArgb((text.R + back.R * 2) / 3, (text.G + back.G * 2) / 3, (text.B + back.B * 2) / 3);
            button.Cursor = on ? Cursors.Hand : Cursors.Default;
            button.FlatAppearance.MouseOverBackColor = on ? Color.Empty : back;
            button.FlatAppearance.MouseDownBackColor = on ? Color.Empty : back;
        }

        static bool IsActive(Button button)
        {
            return button.Tag is bool && (bool)button.Tag;
        }

        // A tick told at a glance: on, a box filled gold with a dark check and
        // its words in gold; off, an empty dark box with a grey edge and its
        // words grey. The box is drawn over the system's own; the mouse on it
        // lightens its edge.
        void TickLook(CheckBox box)
        {
            bool hot = false;
            Action words = delegate { box.ForeColor = box.Checked ? TickText : Muted; };
            words();
            box.CheckedChanged += delegate { words(); box.Invalidate(); };
            box.MouseEnter += delegate { hot = true; box.Invalidate(); };
            box.MouseLeave += delegate { hot = false; box.Invalidate(); };
            box.Paint += delegate (object sender, PaintEventArgs e)
            {
                int size = 14;
                Rectangle square = new Rectangle(0, (box.Height - size) / 2, size, size);
                using (Brush cover = new SolidBrush(box.BackColor))
                    e.Graphics.FillRectangle(cover, new Rectangle(0, 0, size + 2, box.Height));
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                if (box.Checked)
                {
                    using (Brush fill = new SolidBrush(hot ? Color.FromArgb(255, 222, 96) : Color.FromArgb(236, 188, 40)))
                        e.Graphics.FillRectangle(fill, square);
                    using (Pen check = new Pen(Color.FromArgb(28, 20, 4), 2.2f))
                        e.Graphics.DrawLines(check, new PointF[] {
                            new PointF(square.X + 3f, square.Y + 7.5f),
                            new PointF(square.X + 6f, square.Y + 10.5f),
                            new PointF(square.X + 11f, square.Y + 3.5f) });
                }
                else
                {
                    using (Brush fill = new SolidBrush(Color.FromArgb(22, 22, 28)))
                        e.Graphics.FillRectangle(fill, square);
                    using (Pen edge = new Pen(hot ? Color.FromArgb(200, 200, 210) : Color.FromArgb(110, 110, 122), 1f))
                        e.Graphics.DrawRectangle(edge, square.X, square.Y, size - 1, size - 1);
                }
            };
        }

        static void Style(Button button, string text)
        {
            button.Text = text;
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderColor = Color.FromArgb(90, 80, 40);
            button.BackColor = Color.FromArgb(40, 36, 24);
            button.ForeColor = Gold;
            button.Cursor = Cursors.Hand;
        }

        void Status(string text)
        {
            if (InvokeRequired) { BeginInvoke(new Action<string>(Status), text); return; }
            statusLabel.Text = text;
        }

        // --- The game's AddOns folder -----------------------------------------

        // The AddOns folder for a game executable: benilla-config\AddOns next to
        // it, or AddOns next to it when the executable sits in benilla-config.
        static string AddonsFor(string exePath)
        {
            string dir = Path.GetDirectoryName(exePath);
            if (string.Equals(Path.GetFileName(dir), "benilla-config", StringComparison.OrdinalIgnoreCase))
                return Path.Combine(dir, "AddOns");
            return Path.Combine(dir, "benilla-config", "AddOns");
        }

        static string FindAddonsFolder()
        {
            try
            {
                if (File.Exists(ConfigPath))
                {
                    string saved = File.ReadAllText(ConfigPath).Trim();
                    if (Directory.Exists(saved)) return saved;
                }
            }
            catch { }

            // The installer placed next to the game, or in its folders.
            string here = AppDomain.CurrentDomain.BaseDirectory;
            foreach (string dir in new[] { here, Path.Combine(here, "benilla-config"), Path.GetDirectoryName(here.TrimEnd('\\')) ?? here })
            {
                string exe = Path.Combine(dir, GameExe);
                if (File.Exists(exe)) return AddonsFor(exe);
            }
            // The game where it usually is.
            string usual = Path.Combine(CommonGameFolder, GameExe);
            if (File.Exists(usual)) return AddonsFor(usual);
            return null;
        }

        void BrowseForGame()
        {
            using (OpenFileDialog dialog = new OpenFileDialog())
            {
                dialog.Title = "Pick the game: " + GameExe;
                dialog.Filter = "Azeroth Survivors|" + GameExe + "|Programs|*.exe";
                if (Directory.Exists(CommonGameFolder)) dialog.InitialDirectory = CommonGameFolder;
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                // The game belongs in its benilla-config folder; anywhere else, ask first.
                string picked = Path.GetFileName(Path.GetDirectoryName(dialog.FileName));
                if (!string.Equals(picked, "benilla-config", StringComparison.OrdinalIgnoreCase))
                {
                    DialogResult go = MessageBox.Show(this,
                        "It is recommended that " + GameExe + " be inside the game's benilla-config folder, usually:\n\n" +
                        CommonGameFolder + "\n\nThe addons would go to:\n" + AddonsFor(dialog.FileName) +
                        "\n\nUse this place anyway?",
                        "Survivor UI", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
                    if (go != DialogResult.Yes) return;
                }
                folderBox.Text = AddonsFor(dialog.FileName);
                try { File.WriteAllText(ConfigPath, folderBox.Text); } catch { }
                Status("AddOns folder set.");
            }
        }

        // --- Versions ---------------------------------------------------------

        static string InstalledVersion(string addons)
        {
            try
            {
                string toc = Path.Combine(addons, "SurvivorUI", "SurvivorUI.toc");
                if (!File.Exists(toc)) return null;
                Match match = Regex.Match(File.ReadAllText(toc), @"##\s*Version:\s*(\S+)");
                return match.Success ? match.Groups[1].Value : "?";
            }
            catch { return null; }
        }

        void ShowInstalled()
        {
            ShowUpdateState();
        }

        void FetchLatest()
        {
            try
            {
                // GitHub's releases, newest first: the newest release and the
                // newest beta (a pre-release). The beta channel takes the newer
                // of the two; off it, the release alone.
                string json = Download("https://api.github.com/repos/" + Repo + "/releases?per_page=20");
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                serializer.MaxJsonLength = int.MaxValue;
                System.Collections.IEnumerable list = (System.Collections.IEnumerable)serializer.DeserializeObject(json);
                Release stable = null, pre = null;
                foreach (object item in list)
                {
                    Dictionary<string, object> data = (Dictionary<string, object>)item;
                    if (data.ContainsKey("draft") && (bool)data["draft"]) continue;
                    bool isPre = data.ContainsKey("prerelease") && (bool)data["prerelease"];
                    if (isPre ? pre != null : stable != null) continue;
                    Release release = Read(data, isPre);
                    if (isPre) pre = release; else stable = release;
                    if (stable != null && pre != null) break;
                }
                if (stable == null && pre == null) throw new Exception("GitHub lists no release");
                BeginInvoke(new Action<Release, Release>(ShowReleases), stable, pre);
            }
            catch (Exception error)
            {
                BeginInvoke(new Action(delegate
                {
                    installWhenNewer = false;
                    if (checkingByHand)
                    {
                        checkingByHand = false;
                        ShowOwnVersion();
                    }
                    // Known already: kept, and asked again in half an hour.
                    if (latest != null)
                    {
                        Status("Could not reach GitHub just now; it will ask again later.");
                        return;
                    }
                    notesBox.Text = "Could not reach GitHub: " + error.Message + "\r\n\r\nCheck your internet connection; it will ask again in half an hour.";
                }));
            }
        }

        // One release as GitHub gives it: its tag, its notes and its addons' zip.
        static Release Read(Dictionary<string, object> data, bool isPre)
        {
            Release release = new Release();
            release.Tag = (string)data["tag_name"];
            release.Beta = isPre;
            release.Notes = data.ContainsKey("body") ? (string)data["body"] : "";
            foreach (object asset in (System.Collections.IEnumerable)data["assets"])
            {
                Dictionary<string, object> a = (Dictionary<string, object>)asset;
                string name = (string)a["name"];
                // The addons' zip, "SurvivorUI-v2.4.zip" or "SurvivorUI-v3.0.5-beta.1.zip".
                if (release.ZipUrl == null && Regex.IsMatch(name, @"^SurvivorUI-v[\d.]+(-beta[\d.]*)?\.zip$", RegexOptions.IgnoreCase))
                {
                    release.ZipName = name;
                    release.ZipUrl = (string)a["browser_download_url"];
                }
                // The installer's own, its version in the asset's label.
                else if (string.Equals(name, "SurvivorUI-Installer.zip", StringComparison.OrdinalIgnoreCase))
                {
                    Version version = ParseVersion(a.ContainsKey("label") ? a["label"] as string : null);
                    if (version != null)
                    {
                        release.InstallerUrl = (string)a["browser_download_url"];
                        release.InstallerVersion = version;
                    }
                }
            }
            return release;
        }

        // GitHub's answer: the buttons, the notes of the one followed, and the
        // newest launcher among the releases it follows.
        void ShowReleases(Release newStable, Release newPre)
        {
            stable = newStable;
            pre = newPre;
            ShowUpdateState();
            if (latest != null)
            {
                ShowNotes();
                if (latest.ZipUrl == null) Status("The latest release has no zip to install.");
            }
            Release newestInstaller = null;
            foreach (Release candidate in new Release[] { stable, latest != null && latest.Beta ? pre : null })
            {
                if (candidate == null || candidate.InstallerVersion == null) continue;
                if (newestInstaller == null || candidate.InstallerVersion > newestInstaller.InstallerVersion)
                    newestInstaller = candidate;
            }
            bool byHand = checkingByHand;
            checkingByHand = false;
            ShowSelfUpdate(newestInstaller);
            // Asked by hand: the answer said, for the launcher and the addons.
            if (byHand && selfRelease == null && !selfUpdating)
                Status("The launcher " + Short(OwnVersion) + " is up to date; " +
                    (updateWaiting ? "Survivor UI " + latest.Tag + " is out." : "so is Survivor UI."));
        }

        // GitHub's markdown, readable as plain text.
        static string Plain(string markdown)
        {
            string text = (markdown ?? "").Replace("\r\n", "\n");
            text = Regex.Replace(text, @"\*\*(.+?)\*\*", "$1");
            text = text.Replace("`", "");
            text = Regex.Replace(text, @"^- ", "  • ", RegexOptions.Multiline);
            return text.Replace("\n", "\r\n");
        }

        static string Download(string url)
        {
            using (WebClient client = Client())
                return client.DownloadString(url);
        }

        static WebClient Client()
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            WebClient client = new WebClient();
            client.Headers.Add("User-Agent", "SurvivorUI-Installer");
            client.Encoding = System.Text.Encoding.UTF8;
            return client;
        }

        // --- Its own update -----------------------------------------------------

        // "Installer 1.3.0" -> 1.3.0.0; missing parts as 0.
        static Version ParseVersion(string text)
        {
            Match match = Regex.Match(text ?? "", @"(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?");
            if (!match.Success) return null;
            int[] parts = new int[4];
            for (int i = 0; i < 4; i++)
                parts[i] = match.Groups[i + 1].Success ? int.Parse(match.Groups[i + 1].Value) : 0;
            return new Version(parts[0], parts[1], parts[2], parts[3]);
        }

        // 1.3.0.0 as "1.3", 1.3.1.0 as "1.3.1".
        static string Short(Version version)
        {
            return version.Build > 0 ? version.Major + "." + version.Minor + "." + version.Build : version.Major + "." + version.Minor;
        }

        // The top right: the launcher's version, a green arrow by it while a
        // newer one is out (or being taken), and the button: Check for
        // updates, or the update itself.
        void ShowOwnVersion()
        {
            Release pending = selfUpdating ? updatingTo : selfRelease;
            arrowMark.Visible = pending != null;
            versionLabel.Text = "Launcher ver. " + Short(OwnVersion) + (pending != null ? " \u2192 " + Short(pending.InstallerVersion) : "");
            versionLabel.ForeColor = pending != null ? Color.FromArgb(110, 225, 125) : Muted;
            if (pending != null)
            {
                selfButton.Text = selfUpdating ? "Updating..." : "Update to " + Short(pending.InstallerVersion);
                selfButton.Enabled = !selfUpdating;
                selfButton.ForeColor = Color.White;
                selfButton.FlatAppearance.BorderColor = Color.FromArgb(150, 240, 160);
                if (selfUpdating) selfButton.BackColor = LauncherDim;
                tips.SetToolTip(selfButton, "Launcher " + Short(pending.InstallerVersion) + " is out: click to update it. It starts again by itself.");
            }
            else
            {
                selfButton.Text = checkingByHand ? "Checking..." : "Check for updates";
                selfButton.Enabled = !checkingByHand;
                selfButton.ForeColor = Gold;
                selfButton.BackColor = Color.FromArgb(40, 36, 24);
                selfButton.FlatAppearance.BorderColor = Color.FromArgb(90, 80, 40);
                tips.SetToolTip(selfButton, "Asks GitHub now for a new launcher and a new Survivor UI.");
            }
        }

        // A newer installer out: offered, or taken at once when it updates itself.
        void ShowSelfUpdate(Release release)
        {
            selfRelease = release != null && release.InstallerVersion > OwnVersion ? release : null;
            bool available = selfRelease != null;
            selfItem.Visible = available;
            selfItem.Enabled = available && !selfUpdating;
            if (available) selfItem.Text = "Update the launcher to " + Short(selfRelease.InstallerVersion);
            ShowOwnVersion();
            if (!available) return;
            if (selfBox.Checked)
            {
                UpdateSelf();
                return;
            }
            string version = selfRelease.InstallerVersion.ToString();
            if (toldOfSelf != version)
            {
                toldOfSelf = version;
                tray.ShowBalloonTip(6000, "Survivor UI Launcher " + Short(selfRelease.InstallerVersion) + " is out",
                    "Click \"Update to " + Short(selfRelease.InstallerVersion) + "\" at the top of the window, or in the tray's menu.", ToolTipIcon.Info);
            }
        }

        void UpdateSelf()
        {
            if (selfRelease == null || selfUpdating) return;
            // Not in the middle of installing the addons: after it.
            if (installing)
            {
                Status("The launcher updates itself once the addons are installed.");
                return;
            }
            selfUpdating = true;
            selfItem.Enabled = false;
            Release release = selfRelease;
            updatingTo = release;
            selfRelease = null;
            ShowOwnVersion();
            Status("Downloading the launcher " + Short(release.InstallerVersion) + "...");
            new Thread(delegate () { DoUpdateSelf(release); }) { IsBackground = true }.Start();
        }

        static string OldPath
        {
            get
            {
                string exe = Application.ExecutablePath;
                return Path.Combine(Path.GetDirectoryName(exe), Path.GetFileNameWithoutExtension(exe) + ".old.exe");
            }
        }

        void DoUpdateSelf(Release release)
        {
            string exe = Application.ExecutablePath;
            string fresh = exe + ".new";
            string zip = Path.Combine(Path.GetTempPath(), "SurvivorUI-Installer-" + Short(release.InstallerVersion) + ".zip");
            try
            {
                using (WebClient client = Client())
                    client.DownloadFile(release.InstallerUrl, zip);
                using (ZipArchive archive = ZipFile.OpenRead(zip))
                {
                    ZipArchiveEntry entry = archive.GetEntry("SurvivorInstaller.exe");
                    if (entry == null) throw new Exception("the zip holds no SurvivorInstaller.exe");
                    entry.ExtractToFile(fresh, true);
                }
                // The one downloaded is the one announced, and newer than this.
                Version got = AssemblyName.GetAssemblyName(fresh).Version;
                if (got <= OwnVersion) throw new Exception("the download is not newer (" + got + ")");
                // A running exe can be renamed, not overwritten: this one aside,
                // the new one in its place.
                if (File.Exists(OldPath)) File.Delete(OldPath);
                File.Move(exe, OldPath);
                try { File.Move(fresh, exe); }
                catch { File.Move(OldPath, exe); throw; }
                BeginInvoke(new Action(delegate
                {
                    ProcessStartInfo info = new ProcessStartInfo(exe, "--updated" + (Visible ? "" : " --tray"));
                    info.WorkingDirectory = Path.GetDirectoryName(exe);
                    info.UseShellExecute = false;
                    Process.Start(info);
                    exiting = true;
                    Close();
                }));
            }
            catch (Exception error)
            {
                try { if (File.Exists(fresh)) File.Delete(fresh); } catch { }
                BeginInvoke(new Action(delegate
                {
                    selfUpdating = false;
                    updatingTo = null;
                    selfRelease = release;
                    selfItem.Enabled = true;
                    ShowOwnVersion();
                    Status("The launcher could not update itself: " + error.Message + ". Download it again from GitHub.");
                }));
            }
            finally
            {
                try { File.Delete(zip); } catch { }
            }
        }

        // The old exe set aside by an update: deleted once its process is gone,
        // tried every second for a while; and said so, once, from the tray.
        void CleanUpOld(bool updated)
        {
            System.Windows.Forms.Timer cleanup = new System.Windows.Forms.Timer();
            cleanup.Interval = 1000;
            int tries = 0;
            cleanup.Tick += delegate
            {
                tries++;
                if (updated && tries == 1 && !Visible)
                    tray.ShowBalloonTip(5000, "Survivor UI Launcher", "Updated to " + Short(OwnVersion) + ".", ToolTipIcon.Info);
                bool gone = true;
                try { if (File.Exists(OldPath)) File.Delete(OldPath); }
                catch { gone = false; }
                if (gone || tries > 30) cleanup.Stop();
            };
            cleanup.Start();
        }

        // --- The game itself --------------------------------------------------

        // Azeroth Survivors, by Aethus, from his own servers, with his ok. Three
        // pieces, each only when missing: the full package his site offers, for
        // the game's base data (Data\patch.MPQ, which nothing else carries), a
        // RAR unpacked by Windows' own tar (libarchive reads RAR5); the newest
        // exe and the newest data patches, by the indexes the game updates
        // itself by (exe/latest.json, exe/data/patches.json: each file a gzip
        // cut in parts, with its size and sha256).
        const string GameServer = "https://wow.aethus.pl/exe/";
        const string GameSite = "https://wow.aethus.pl";
        const string GamePackage = "https://wow.aethus.pl/download";

        // One file of an index: its name, size, sha256 and parts.
        class GameFile
        {
            public string Name, Sha256;
            public long Size, Download;
            public readonly List<string> Urls = new List<string>();
        }

        // What getting the game takes: where it goes, and each piece missing.
        class GamePlan
        {
            public string Folder, Version;
            public long PackageSize;            // 0: the base data is there
            public GameFile Exe;                // null: the exe is there
            public readonly List<GameFile> Patches = new List<GameFile>();
            public long PatchesDownload
            {
                get
                {
                    long total = 0;
                    foreach (GameFile patch in Patches) total += patch.Download;
                    return total;
                }
            }
            public long Download
            {
                get { return PackageSize + (Exe != null ? Exe.Download : 0) + PatchesDownload; }
            }
        }

        // The game's exe: by the AddOns folder, or where it usually is.
        string GameExePath()
        {
            string exe = GameFor(folderBox.Text);
            if (exe != null) return exe;
            string usual = Path.Combine(CommonGameFolder, GameExe);
            return File.Exists(usual) ? usual : null;
        }

        static string BaseData(string folder)
        {
            return Path.Combine(Path.Combine(folder, "Data"), "patch.MPQ");
        }

        // No game, or a game without its base data (an exe alone): Get the game.
        bool GameMissing()
        {
            string exe = GameExePath();
            return exe == null || !File.Exists(BaseData(Path.GetDirectoryName(exe)));
        }

        // The game as last looked at: its exe's version and sha256 (read once
        // per file, by its size and time), against the newest exe its server
        // lists; and whether the server has data patches it lacks.
        class GameState
        {
            public string Exe, Version, Sha256, Latest, LatestSha256, Notes;
            public long Size;
            public DateTime Written;
            public bool PatchesBehind;
            public bool Behind
            {
                get { return Latest != null && (PatchesBehind || (LatestSha256 != null && Sha256 != null && Sha256 != LatestSha256)); }
            }
        }

        // What's new: while a newer game is out, its own notes first (Aethus',
        // from the game's server), then the latest Survivor UI's. Set only when
        // it changes, so a look every half hour leaves it scrolled as it was.
        void ShowNotes()
        {
            string text = latest == null ? "" : (latest.Beta
                ? "BETA BUILD, before a release: more bugs than usual may be in it, and it updates more often. The release's button takes you back.\r\n\r\n"
                : "") + Plain(latest.Notes);
            if (GameBehind() && !string.IsNullOrEmpty(game.Notes))
            {
                string notes = game.Notes.Trim().Replace("\r\n", "\n").Replace("\n", "\r\n");
                text = "AZEROTH SURVIVORS " + game.Latest + " IS OUT, the game by Aethus:\r\n" + notes +
                    "\r\n\r\nClick Update game to get it." +
                    (text != "" ? "\r\n\r\n\u2014\u2014\u2014\r\n\r\n" + text : "");
            }
            if (text != "" && text != notesBox.Text) notesBox.Text = text;
        }

        // A newer game out than the one by the AddOns folder.
        bool GameBehind()
        {
            return game != null && game.Behind && game.Exe == GameExePath();
        }

        // Under the folder box: the game's version and whether a newer one is
        // out; with none found, where it should be.
        void ShowGameLine()
        {
            string exe = GameExePath();
            bool found = exe != null && !GameMissing();
            // Check version by the line while there is a game to check.
            gameCheckButton.Visible = found;
            gameLabel.Location = found ? new Point(118, 160) : new Point(20, 158);
            if (exe == null)
            {
                gameLabel.Text = "Recommended: the game's " + GameExe + " in its benilla-config folder,\nusually " + CommonGameFolder;
                gameLabel.ForeColor = Muted;
                return;
            }
            if (!found)
            {
                gameLabel.Text = "Azeroth Survivors found, without its data: click Get the game.";
                gameLabel.ForeColor = Muted;
                return;
            }
            if (checkingGame)
            {
                gameLabel.Text = "Asking wow.aethus.pl for the game's newest version...";
                gameLabel.ForeColor = Muted;
                return;
            }
            GameState state = game != null && game.Exe == exe ? game : null;
            string name = "Azeroth Survivors" + (state != null && state.Version != null ? " " + state.Version : "");
            if (state == null)
            {
                // Not looked at yet (or another game picked): asked now.
                gameLabel.Text = name + "  ·  asking wow.aethus.pl...";
                gameLabel.ForeColor = Muted;
                CheckGame();
            }
            else if (state.Behind)
            {
                bool sameExe = state.LatestSha256 == state.Sha256;
                gameLabel.Text = name + "  ·  " + (sameExe ? "new game data is out" : state.Latest + " is out") + ": click Update game";
                gameLabel.ForeColor = Color.FromArgb(90, 220, 110);
            }
            else if (state.Latest != null)
            {
                gameLabel.Text = name + "  ·  up to date";
                gameLabel.ForeColor = Muted;
            }
            else
            {
                gameLabel.Text = name + "  ·  could not reach wow.aethus.pl";
                gameLabel.ForeColor = Muted;
            }
        }

        // What the game writes just before its version in its exe ("0.101.0A
        // new version is out!").
        static readonly byte[] VersionMark = System.Text.Encoding.ASCII.GetBytes("A new version is out!");

        // An exe's sha256, and its version as the game writes it (null when
        // not found), in one read.
        static void ReadExe(string path, out string sha, out string version)
        {
            version = null;
            using (FileStream input = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (System.Security.Cryptography.SHA256 hash = System.Security.Cryptography.SHA256.Create())
            {
                byte[] buffer = new byte[1 << 20];
                byte[] tail = new byte[0];
                int read;
                while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
                {
                    hash.TransformBlock(buffer, 0, read, null, 0);
                    if (version != null) continue;
                    // The last read's end before this one: a mark across the cut is found.
                    byte[] window = new byte[tail.Length + read];
                    Buffer.BlockCopy(tail, 0, window, 0, tail.Length);
                    Buffer.BlockCopy(buffer, 0, window, tail.Length, read);
                    version = VersionIn(window);
                    int keep = Math.Min(window.Length, VersionMark.Length + 24);
                    tail = new byte[keep];
                    Buffer.BlockCopy(window, window.Length - keep, tail, 0, keep);
                }
                hash.TransformFinalBlock(new byte[0], 0, 0);
                sha = BitConverter.ToString(hash.Hash).Replace("-", "").ToLowerInvariant();
            }
        }

        static string VersionIn(byte[] data)
        {
            byte first = VersionMark[0];
            for (int i = 1; i + VersionMark.Length <= data.Length; i++)
            {
                if (data[i] != first) continue;
                int k = 1;
                while (k < VersionMark.Length && data[i + k] == VersionMark[k]) k++;
                if (k < VersionMark.Length) continue;
                int start = Math.Max(0, i - 24);
                Match match = Regex.Match(System.Text.Encoding.ASCII.GetString(data, start, i - start), @"(\d+\.\d+\.\d+)$");
                if (match.Success) return match.Groups[1].Value;
            }
            return null;
        }

        // The game against the newest on its server, in the background: at the
        // start, with each look at GitHub, after an update.
        void CheckGame()
        {
            // No window handle yet (the constructor, a start in the tray): the
            // answer would have nowhere to go; CheckNow asks once there is one.
            if (checkingGame || gettingGame || !IsHandleCreated || GameMissing())
            {
                gameByHand = false;
                return;
            }
            string exe = GameExePath();
            GameState known = game != null && game.Exe == exe ? game : null;
            checkingGame = true;
            gameCheckButton.Enabled = false;
            gameCheckButton.Text = "Checking...";
            ShowGameLine();
            new Thread(delegate ()
            {
                GameState state = new GameState();
                state.Exe = exe;
                try
                {
                    FileInfo info = new FileInfo(exe);
                    state.Size = info.Length;
                    state.Written = info.LastWriteTimeUtc;
                    if (known != null && known.Size == state.Size && known.Written == state.Written)
                    {
                        state.Sha256 = known.Sha256;
                        state.Version = known.Version;
                    }
                    else ReadExe(exe, out state.Sha256, out state.Version);
                }
                catch { }
                try
                {
                    JavaScriptSerializer serializer = new JavaScriptSerializer();
                    serializer.MaxJsonLength = int.MaxValue;
                    Dictionary<string, object> latest = (Dictionary<string, object>)serializer.DeserializeObject(Download(GameServer + "latest.json"));
                    GameFile newest = ReadGameFile(latest, GameServer, GameExe);
                    Dictionary<string, object> patches = (Dictionary<string, object>)serializer.DeserializeObject(Download(GameServer + "data/patches.json"));
                    string data = Path.Combine(Path.GetDirectoryName(exe), "Data");
                    bool patchesBehind = false;
                    foreach (object item in (System.Collections.IEnumerable)patches["patches"])
                    {
                        GameFile patch = ReadGameFile((Dictionary<string, object>)item, GameServer + "data/", null);
                        string target = Path.Combine(data, patch.Name);
                        if (!File.Exists(target) || new FileInfo(target).Length != patch.Size) patchesBehind = true;
                    }
                    state.Latest = Convert.ToString(latest["version"]);
                    state.Notes = latest.ContainsKey("notes") ? Convert.ToString(latest["notes"]) : null;
                    state.LatestSha256 = newest.Sha256;
                    state.PatchesBehind = patchesBehind;
                }
                catch { }
                if (IsDisposed) return;
                BeginInvoke(new Action(delegate
                {
                    game = state;
                    checkingGame = false;
                    gameCheckButton.Enabled = true;
                    gameCheckButton.Text = "Check version";
                    ShowUpdateState();
                    ShowNotes();
                    // Asked by hand: the answer in the status line too.
                    if (gameByHand)
                    {
                        gameByHand = false;
                        string name = "Azeroth Survivors" + (state.Version != null ? " " + state.Version : "");
                        Status(state.Latest == null ? "Could not reach wow.aethus.pl just now: try again later."
                            : state.Behind ? (state.Latest != state.Version ? "Azeroth Survivors " + state.Latest + " is out" : "New game data is out")
                                + ": click Update game."
                            : name + " is the newest: up to date.");
                    }
                }));
            }) { IsBackground = true }.Start();
        }

        static GameFile ReadGameFile(Dictionary<string, object> data, string server, string name)
        {
            GameFile file = new GameFile();
            file.Name = data.ContainsKey("name") ? Convert.ToString(data["name"]) : name;
            if (file.Name.Contains("\\") || file.Name.Contains("/") || file.Name.Contains(".."))
                throw new Exception("the game's index lists an odd file: " + file.Name);
            file.Sha256 = Convert.ToString(data["sha256"]).ToLowerInvariant();
            file.Size = Convert.ToInt64(data["size"]);
            foreach (object item in (System.Collections.IEnumerable)data["parts"])
            {
                Dictionary<string, object> part = (Dictionary<string, object>)item;
                string url = Convert.ToString(part["url"]);
                // A piece of the game's own folder on its server, nothing else.
                if (url.Contains("..") || url.Contains(":")) throw new Exception("the game's index lists an odd part: " + url);
                file.Urls.Add(server + url);
                file.Download += Convert.ToInt64(part["size"]);
            }
            if (file.Urls.Count == 0 || file.Sha256.Length != 64 || file.Size <= 0)
                throw new Exception("the game's index holds no " + file.Name);
            return file;
        }

        // The size of the site's full package, asked without taking it.
        static long PackageSize()
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(GamePackage);
            request.Method = "HEAD";
            request.UserAgent = "SurvivorUI-Installer";
            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                return Math.Max(1, response.ContentLength);
        }

        // What is missing in the game's folder: asked of the indexes and the site.
        static GamePlan MakePlan(string folder)
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            serializer.MaxJsonLength = int.MaxValue;
            GamePlan plan = new GamePlan();
            plan.Folder = folder;
            Dictionary<string, object> latest = (Dictionary<string, object>)serializer.DeserializeObject(Download(GameServer + "latest.json"));
            plan.Version = Convert.ToString(latest["version"]);
            string exe = Path.Combine(folder, GameExe);
            GameFile newest = ReadGameFile(latest, GameServer, GameExe);
            if (!File.Exists(exe)) plan.Exe = newest;
            else
            {
                // An older exe than the newest: the newest in its place.
                string sha, version;
                ReadExe(exe, out sha, out version);
                if (sha != newest.Sha256) plan.Exe = newest;
            }
            Dictionary<string, object> patches = (Dictionary<string, object>)serializer.DeserializeObject(Download(GameServer + "data/patches.json"));
            foreach (object item in (System.Collections.IEnumerable)patches["patches"])
            {
                GameFile patch = ReadGameFile((Dictionary<string, object>)item, GameServer + "data/", null);
                string target = Path.Combine(Path.Combine(folder, "Data"), patch.Name);
                if (!File.Exists(target) || new FileInfo(target).Length != patch.Size) plan.Patches.Add(patch);
            }
            if (!File.Exists(BaseData(folder))) plan.PackageSize = PackageSize();
            return plan;
        }

        static string Megabytes(long bytes)
        {
            return Math.Max(0, (int)Math.Round(bytes / 1048576.0)).ToString();
        }

        static string Gigabytes(long bytes)
        {
            return (bytes / 1073741824.0).ToString("0.0", System.Globalization.CultureInfo.InvariantCulture);
        }

        // Room it takes on the disk while it works: the package and its
        // unpacking (some 3.5 times the package), and each file twice.
        static long RoomNeeded(GamePlan plan)
        {
            long room = plan.PackageSize * 4 + (plan.Exe != null ? plan.Exe.Size * 2 : 0);
            foreach (GameFile patch in plan.Patches) room += patch.Size * 2;
            return room + 100L * 1048576;
        }

        // Asked for: what is missing and its sizes, then a question.
        void GetGame()
        {
            if (gettingGame || installing) return;
            bool update = !GameMissing();
            if (GameRunning())
            {
                Status(update ? "The game is open: close it, then Update game." : "The game is open: close it, then Get the game.");
                return;
            }
            string exe = GameExePath();
            string folder = exe != null ? Path.GetDirectoryName(exe) : CommonGameFolder;
            gettingGame = true;
            ShowUpdateState();
            Status("Asking wow.aethus.pl for the game...");
            new Thread(delegate ()
            {
                GamePlan plan = null;
                string problem = null;
                try { plan = MakePlan(folder); }
                catch (Exception error) { problem = error.Message; }
                BeginInvoke(new Action(delegate
                {
                    gettingGame = false;
                    ShowUpdateState();
                    if (plan == null)
                    {
                        Status("Could not reach wow.aethus.pl: " + problem);
                        return;
                    }
                    if (plan.Download == 0)
                    {
                        Status(update ? "The game is up to date: " + plan.Version + "." : "The game is all there.");
                        CheckGame();
                        return;
                    }
                    string pieces = "";
                    if (plan.PackageSize > 0) pieces += "\n  \u2022  the game's data, from its full package: " + Megabytes(plan.PackageSize) + " MB";
                    if (plan.Exe != null) pieces += "\n  \u2022  the newest game, " + plan.Version + ": " + Megabytes(plan.Exe.Download) + " MB";
                    if (plan.Patches.Count > 0) pieces += "\n  \u2022  its newest updates: " + Megabytes(plan.PatchesDownload) + " MB";
                    DialogResult go = MessageBox.Show(this,
                        (update ? "Update Azeroth Survivors to " + plan.Version + " (about " + Megabytes(plan.Download) + " MB)?\n\n"
                            : "Download Azeroth Survivors (about " + Megabytes(plan.Download) + " MB in all)?\n\n") +
                        "Azeroth Survivors is Aethus' game. The launcher takes it from his own servers (wow.aethus.pl) and checks it:" +
                        pieces + "\n\nInto: " + plan.Folder + "\nIt needs about " + Gigabytes(RoomNeeded(plan)) + " GB free while it works." +
                        (update ? "" : " Then it installs Survivor UI."),
                        "Azeroth Survivors", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                    if (go != DialogResult.Yes)
                    {
                        Status("");
                        return;
                    }
                    gettingGame = true;
                    ShowUpdateState();
                    new Thread(delegate () { DoGetGame(plan); }) { IsBackground = true }.Start();
                }));
            }) { IsBackground = true }.Start();
        }

        // The download's progress, in the status line and on the taskbar
        // button; done below 0 clears it.
        void GameProgress(long done, long total, string what)
        {
            if (InvokeRequired) { BeginInvoke(new Action<long, long, string>(GameProgress), done, total, what); return; }
            try
            {
                if (taskbar != null && IsHandleCreated)
                {
                    if (done < 0) taskbar.SetProgressState(Handle, 0);
                    else
                    {
                        taskbar.SetProgressState(Handle, 2);
                        taskbar.SetProgressValue(Handle, (ulong)done, (ulong)Math.Max(1, total));
                    }
                }
            }
            catch { }
            if (done >= 0)
                Status("Downloading " + what + ": " + Megabytes(done) + " of " + Megabytes(total) + " MB (" + (total > 0 ? done * 100 / total : 0) + "%)");
        }

        // One download into a file, its progress told along the whole; the
        // bytes done after it come back.
        long Fetch(string url, Stream output, long done, long total, string what)
        {
            long shown = -1;
            using (WebClient client = Client())
            using (Stream input = client.OpenRead(url))
            {
                byte[] buffer = new byte[81920];
                int read;
                while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
                {
                    output.Write(buffer, 0, read);
                    done += read;
                    long percent = total > 0 ? done * 100 / total : 0;
                    if (percent != shown)
                    {
                        shown = percent;
                        GameProgress(done, total, what);
                    }
                }
            }
            return done;
        }

        // A file of an index: its parts into one gzip, unpacked, checked
        // against its size and sha256, and put in place of any older one.
        long FetchGameFile(GameFile file, string target, long done, long total, string what)
        {
            string packed = target + ".gz";
            string fresh = target + ".download";
            try
            {
                using (FileStream output = File.Create(packed))
                    foreach (string url in file.Urls)
                        done = Fetch(url, output, done, total, what);
                using (FileStream input = File.OpenRead(packed))
                using (GZipStream unpack = new GZipStream(input, CompressionMode.Decompress))
                using (FileStream output = File.Create(fresh))
                    unpack.CopyTo(output);
                string sha;
                using (FileStream input = File.OpenRead(fresh))
                using (System.Security.Cryptography.SHA256 hash = System.Security.Cryptography.SHA256.Create())
                    sha = BitConverter.ToString(hash.ComputeHash(input)).Replace("-", "").ToLowerInvariant();
                if (new FileInfo(fresh).Length != file.Size || sha != file.Sha256)
                    throw new Exception(file.Name + " does not match the game's own check (sha256). Try again");
                if (File.Exists(target)) File.Delete(target);
                File.Move(fresh, target);
            }
            finally
            {
                try { if (File.Exists(packed)) File.Delete(packed); } catch { }
                try { if (File.Exists(fresh)) File.Delete(fresh); } catch { }
            }
            return done;
        }

        // The full package unpacked by Windows' own tar.
        static void Unpack(string package, string into)
        {
            string tar = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "tar.exe");
            if (!File.Exists(tar)) tar = "tar.exe";
            ProcessStartInfo info = new ProcessStartInfo(tar, "-xf \"" + package + "\" -C \"" + into + "\"");
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            info.RedirectStandardError = true;
            using (Process process = Process.Start(info))
            {
                string errors = process.StandardError.ReadToEnd();
                process.WaitForExit();
                if (process.ExitCode != 0)
                    throw new Exception("Windows could not unpack the game's package (" + errors.Trim() + "). " +
                        "Download it from wow.aethus.pl/download and unpack its Data folder next to the game");
            }
        }

        // Each piece missing, in turn: the base data from the full package, the
        // newest exe, the newest patches; then Survivor UI.
        void DoGetGame(GamePlan plan)
        {
            string folder = plan.Folder;
            string data = Path.Combine(folder, "Data");
            string staging = Path.Combine(folder, "_get-the-game");
            long total = plan.Download, done = 0;
            try
            {
                Directory.CreateDirectory(data);
                DriveInfo drive = new DriveInfo(Path.GetPathRoot(Path.GetFullPath(folder)));
                if (drive.AvailableFreeSpace < RoomNeeded(plan))
                    throw new Exception("not enough room on " + drive.Name + ": " + Gigabytes(drive.AvailableFreeSpace) +
                        " GB free, about " + Gigabytes(RoomNeeded(plan)) + " GB needed");
                if (plan.PackageSize > 0)
                {
                    if (Directory.Exists(staging)) Directory.Delete(staging, true);
                    Directory.CreateDirectory(staging);
                    string package = Path.Combine(staging, "AzerothSurvivors.rar");
                    using (FileStream output = File.Create(package))
                        done = Fetch(GamePackage, output, done, total, "the game's data");
                    Status("Unpacking the game's data (a minute or two)...");
                    Unpack(package, staging);
                    File.Delete(package);
                    string[] found = Directory.GetFiles(staging, "patch.MPQ", SearchOption.AllDirectories);
                    if (found.Length == 0) throw new Exception("the game's package holds no Data\\patch.MPQ");
                    foreach (string file in Directory.GetFiles(Path.GetDirectoryName(found[0]), "*.MPQ"))
                    {
                        string target = Path.Combine(data, Path.GetFileName(file));
                        if (!File.Exists(target)) File.Move(file, target);
                    }
                    Directory.Delete(staging, true);
                }
                if (plan.Exe != null)
                    done = FetchGameFile(plan.Exe, Path.Combine(folder, GameExe), done, total, "the game");
                // The patches still missing, or not as the index has them (the
                // package may have brought some).
                foreach (GameFile patch in plan.Patches)
                {
                    string target = Path.Combine(data, patch.Name);
                    if (File.Exists(target) && new FileInfo(target).Length == patch.Size)
                    {
                        done += patch.Download;
                        continue;
                    }
                    done = FetchGameFile(patch, target, done, total, "the game's updates");
                }
                string addons = AddonsFor(Path.Combine(folder, GameExe));
                Directory.CreateDirectory(addons);
                BeginInvoke(new Action(delegate
                {
                    GameProgress(-1, 0, null);
                    folderBox.Text = addons;
                    try { File.WriteAllText(ConfigPath, addons); } catch { }
                    Status("Azeroth Survivors " + plan.Version + " is ready.");
                    // Survivor UI next, unless it is there already.
                    if (stable != null && stable.ZipUrl != null && InstalledVersion(addons) == null) Install(stable);
                    else MessageBox.Show(this,
                        "Azeroth Survivors " + plan.Version + " is ready.\n\nClick Play.",
                        "Azeroth Survivors", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }));
            }
            catch (Exception error)
            {
                try { if (Directory.Exists(staging)) Directory.Delete(staging, true); } catch { }
                BeginInvoke(new Action(delegate
                {
                    GameProgress(-1, 0, null);
                    Status("Could not get the game: " + error.Message);
                    MessageBox.Show(this, "Could not get the game:\n\n" + error.Message + ".", "Azeroth Survivors", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }));
            }
            finally
            {
                BeginInvoke(new Action(delegate
                {
                    gettingGame = false;
                    ShowUpdateState();
                    // The exe may have changed: its version read again.
                    CheckGame();
                }));
            }
        }

        // --- Install ----------------------------------------------------------

        void Install(Release release)
        {
            string addons = folderBox.Text.Trim();
            if (addons == "" || release == null) { Status("Pick the game first."); return; }
            if (!Directory.Exists(Path.GetDirectoryName(addons.TrimEnd('\\'))))
            {
                MessageBox.Show(this, "That folder does not look like the game's: " + addons, "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (installing) return;
            installing = true;
            Active(installButton, false, StableText);
            Active(betaButton, false, BetaColor);
            browseButton.Enabled = false;
            installItem.Enabled = false;
            playButton.Enabled = false;
            playItem.Enabled = false;
            Status("Downloading " + release.ZipName + "...");
            new Thread(delegate () { DoInstall(addons, release); }) { IsBackground = true }.Start();
        }

        void DoInstall(string addons, Release release)
        {
            string zip = Path.Combine(Path.GetTempPath(), release.ZipName);
            try
            {
                using (WebClient client = Client())
                    client.DownloadFile(release.ZipUrl, zip);

                Status("Installing...");
                Directory.CreateDirectory(addons);
                // The old folders go first, so no file from an earlier version stays behind.
                foreach (string folder in AddonFolders)
                {
                    string old = Path.Combine(addons, folder);
                    if (Directory.Exists(old)) Directory.Delete(old, true);
                }
                using (ZipArchive archive = ZipFile.OpenRead(zip))
                {
                    string root = Path.GetFullPath(addons);
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        string target = Path.GetFullPath(Path.Combine(root, entry.FullName));
                        // Only inside the AddOns folder, only the addon folders: the
                        // zip's own files at its top (the license) stay out.
                        if (!target.StartsWith(root, StringComparison.OrdinalIgnoreCase)) continue;
                        string[] parts = entry.FullName.Split('/', '\\');
                        if (parts.Length < 2 || Array.IndexOf(AddonFolders, parts[0]) < 0) continue;
                        if (entry.Name == "") { Directory.CreateDirectory(target); continue; }
                        Directory.CreateDirectory(Path.GetDirectoryName(target));
                        entry.ExtractToFile(target, true);
                    }
                }
                try { File.WriteAllText(ConfigPath, addons); } catch { }

                bool running = Process.GetProcessesByName(Path.GetFileNameWithoutExtension(GameExe)).Length > 0;
                BeginInvoke(new Action(delegate
                {
                    ShowInstalled();
                    Status("Installed " + release.Tag + ".");
                    MessageBox.Show(this,
                        "Survivor UI " + release.Tag + " is installed.\n\n" +
                        (release.Beta ? "A beta build: more bugs than usual may be in it, and it updates more often. Tell what you find on Discord.\n\n" : "") +
                        (running ? "The game is open: restart it to load the new version." : "Start the game and enjoy!") +
                        "\n\nType /sui in the game for every command.",
                        "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }));
            }
            catch (Exception error)
            {
                Status("Install failed: " + error.Message);
                BeginInvoke(new Action(delegate
                {
                    MessageBox.Show(this, "The install failed:\n\n" + error.Message +
                        "\n\nIf the game is open, close it and try again.", "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }));
            }
            finally
            {
                try { File.Delete(zip); } catch { }
                BeginInvoke(new Action(delegate
                {
                    installing = false;
                    browseButton.Enabled = true;
                    ShowUpdateState();
                    if (selfRelease != null && selfBox.Checked) UpdateSelf();
                }));
            }
        }
    }

    // The latest release's notes in a window that reads well: large type, the
    // headings in gold, a bullet for each item with its lines kept under it,
    // bold and code set apart; GitHub's markdown read for that.
    class NotesForm : Form
    {
        static readonly Color Back = Color.FromArgb(18, 18, 24);
        static readonly Color Panel = Color.FromArgb(24, 24, 31);
        static readonly Color Gold = Color.FromArgb(255, 209, 0);
        static readonly Color TextColor = Color.FromArgb(232, 232, 236);
        static readonly Color Muted = Color.FromArgb(160, 160, 172);
        static readonly Color Code = Color.FromArgb(255, 214, 140);
        static readonly Color Link = Color.FromArgb(120, 190, 255);

        readonly Label heading = new Label();
        readonly RichTextBox box = new RichTextBox();
        readonly Font body = new Font("Segoe UI", 11.5f);
        readonly Font headFont = new Font("Segoe UI Semibold", 14f);
        readonly Font quoteFont = new Font("Segoe UI", 10.5f, FontStyle.Italic);
        readonly Font codeFont = new Font("Consolas", 11f);

        public NotesForm(Icon icon)
        {
            Text = "Survivor UI: what's new";
            ClientSize = new Size(760, 660);
            MinimumSize = new Size(480, 360);
            StartPosition = FormStartPosition.CenterParent;
            BackColor = Back;
            ForeColor = TextColor;
            if (icon != null) Icon = icon;

            heading.Dock = DockStyle.Top;
            heading.Height = 54;
            heading.Padding = new Padding(22, 16, 22, 0);
            heading.Font = new Font("Segoe UI", 16f, FontStyle.Bold);
            heading.ForeColor = Gold;

            Panel frame = new Panel();
            frame.Dock = DockStyle.Fill;
            frame.Padding = new Padding(22, 6, 14, 18);
            frame.BackColor = Back;
            box.Dock = DockStyle.Fill;
            box.ReadOnly = true;
            box.BorderStyle = BorderStyle.None;
            box.BackColor = Back;
            box.ForeColor = TextColor;
            box.Font = body;
            box.DetectUrls = false;
            box.ScrollBars = RichTextBoxScrollBars.Vertical;
            frame.Controls.Add(box);

            Controls.Add(frame);
            Controls.Add(heading);
        }

        public void ShowNotes(string title, string markdown)
        {
            heading.Text = title;
            box.Clear();
            string[] lines = (markdown ?? "").Replace("\r\n", "\n").Split('\n');
            foreach (string raw in lines)
            {
                string line = raw.TrimEnd();
                Match bold = Regex.Match(line, @"^\*\*(.+)\*\*$");
                Match hash = Regex.Match(line, @"^#{1,6}\s+(.+)$");
                if (line == "")
                {
                    Paragraph(0, 0);
                    Add("\n", body, TextColor);
                }
                else if (bold.Success || hash.Success)
                {
                    // A heading: gold, larger, with room over it.
                    Paragraph(0, 0);
                    Add((bold.Success ? bold.Groups[1].Value : hash.Groups[1].Value) + "\n", headFont, Gold);
                }
                else if (line.StartsWith("> "))
                {
                    Paragraph(0, 0);
                    Inline(line.Substring(2), quoteFont, Muted);
                    Add("\n", quoteFont, Muted);
                }
                else if (line.StartsWith("- ") || line.StartsWith("* "))
                {
                    // A bullet, its wrapped lines kept under its words.
                    Paragraph(10, 18);
                    Add("\u2022  ", body, Gold);
                    Inline(line.Substring(2), body, TextColor);
                    Add("\n", body, TextColor);
                }
                else
                {
                    Paragraph(0, 0);
                    Inline(line, body, TextColor);
                    Add("\n", body, TextColor);
                }
            }
            box.SelectionStart = 0;
            box.ScrollToCaret();
        }

        void Paragraph(int indent, int hanging)
        {
            box.SelectionStart = box.TextLength;
            box.SelectionLength = 0;
            box.SelectionIndent = indent;
            box.SelectionHangingIndent = hanging;
        }

        // **bold**, `code` and [text](link) inside a line.
        void Inline(string text, Font font, Color color)
        {
            int at = 0;
            foreach (Match part in Regex.Matches(text, @"\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)]+)\)"))
            {
                if (part.Index > at) Add(text.Substring(at, part.Index - at), font, color);
                if (part.Groups[1].Success) Add(part.Groups[1].Value, new Font(font, font.Style | FontStyle.Bold), color);
                else if (part.Groups[2].Success) Add(part.Groups[2].Value, codeFont, Code);
                else Add(part.Groups[3].Value, font, Link);
                at = part.Index + part.Length;
            }
            if (at < text.Length) Add(text.Substring(at), font, color);
        }

        void Add(string text, Font font, Color color)
        {
            box.SelectionStart = box.TextLength;
            box.SelectionLength = 0;
            box.SelectionFont = font;
            box.SelectionColor = color;
            box.SelectedText = text;
        }
    }
}
