// Survivor UI Installer: installs and updates Survivor UI and Survivor Plates
// from the latest GitHub release, into Azeroth Survivors' AddOns folder.
//
// What it does, and nothing else:
//   - asks GitHub which release is the latest, and shows its notes;
//   - finds the game's AddOns folder (or lets the player pick the game);
//   - on Install, downloads the release's zip, removes the old SurvivorUI and
//     SurvivorPlates folders and unzips the new ones in their place;
//   - minimized, waits in the tray, asking GitHub again every half hour: when
//     a release newer than the one installed is out, a green arrow shows on
//     its tray icon and on its taskbar button, and a note says so once; the
//     tray's "Check for updates now" brings it forward and installs a newer
//     one at once. With the latest installed, a green "Up to date" badge
//     stands where the install button was;
//   - "Start with Windows, in the tray" (a tick in the window and in the
//     tray's menu): a line in the user's own Run key starts it with --tray,
//     in the tray without a window, to look for updates.
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

[assembly: System.Reflection.AssemblyTitle("Survivor UI Installer")]
[assembly: System.Reflection.AssemblyProduct("Survivor UI")]
[assembly: System.Reflection.AssemblyVersion("1.1.0.0")]

namespace SurvivorInstaller
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            // Started with Windows: in the tray, no window.
            bool inTray = Array.Exists(args, delegate (string arg) { return arg == "--tray"; });
            // One at a time: opened again while it waits in the tray, the one
            // running comes forward instead.
            bool first;
            using (Mutex single = new Mutex(true, "SurvivorUIInstaller.Single", out first))
            {
                if (!first)
                {
                    if (!inTray) Native.PostMessage(Native.HWND_BROADCAST, Native.ShowMe, IntPtr.Zero, IntPtr.Zero);
                    return;
                }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainForm(inTray));
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

        readonly Label installedLabel = new Label();
        readonly Label latestLabel = new Label();
        readonly TextBox folderBox = new TextBox();
        readonly TextBox notesBox = new TextBox();
        readonly Button installButton = new Button();
        readonly Button browseButton = new Button();
        readonly Label statusLabel = new Label();
        readonly Label upToDate = new Label();
        readonly CheckBox startBox = new CheckBox();
        readonly LinkLabel openLink = new LinkLabel();

        Release latest;

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

        public MainForm(bool inTray)
        {
            startHidden = inTray;
            this.Text = "Survivor UI Installer";
            ClientSize = new Size(560, 460);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Back;
            ForeColor = TextColor;
            Font = new Font("Segoe UI", 9.5f);
            LoadIcons();
            if (appIcon != null) Icon = appIcon;

            Label title = new Label();
            title.Text = "Survivor UI";
            title.Font = new Font("Segoe UI", 15f, FontStyle.Bold);
            title.ForeColor = Gold;
            title.AutoSize = true;
            title.Location = new Point(18, 14);
            Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "The interface for Azeroth Survivors";
            subtitle.ForeColor = Muted;
            subtitle.AutoSize = true;
            subtitle.Location = new Point(20, 48);
            Controls.Add(subtitle);

            installedLabel.AutoSize = true;
            installedLabel.Location = new Point(20, 80);
            Controls.Add(installedLabel);

            latestLabel.AutoSize = true;
            latestLabel.Location = new Point(280, 80);
            Controls.Add(latestLabel);

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

            // Where the game should be, under the box.
            Label hint = new Label();
            hint.Text = "Recommended: " + GameExe + " inside the game's benilla-config folder, usually\n" + CommonGameFolder;
            hint.Font = new Font("Segoe UI", 8f);
            hint.ForeColor = Muted;
            hint.AutoSize = true;
            hint.Location = new Point(20, 158);
            Controls.Add(hint);

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

            Style(installButton, "Install / Update");
            installButton.Location = new Point(20, 396);
            installButton.Size = new Size(160, 36);
            installButton.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
            installButton.Enabled = false;
            installButton.Click += delegate { Install(); };
            Controls.Add(installButton);

            // In the install button's place while the latest is installed.
            upToDate.Location = installButton.Location;
            upToDate.Size = installButton.Size;
            upToDate.TextAlign = ContentAlignment.MiddleCenter;
            upToDate.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
            upToDate.ForeColor = Color.FromArgb(110, 225, 125);
            upToDate.BackColor = Color.FromArgb(22, 44, 28);
            upToDate.BorderStyle = BorderStyle.FixedSingle;
            upToDate.Visible = false;
            Controls.Add(upToDate);

            // Start with Windows: beside the install button, the same tick as
            // the tray's menu.
            startBox.Text = "Start with Windows, in the tray";
            startBox.AutoSize = true;
            startBox.Location = new Point(300, 405);
            startBox.ForeColor = TextColor;
            startBox.FlatStyle = FlatStyle.Flat;
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

            statusLabel.Location = new Point(20, 438);
            statusLabel.Size = new Size(520, 20);
            statusLabel.ForeColor = Muted;
            Controls.Add(statusLabel);

            SetUpTray();

            folderBox.Text = FindAddonsFolder() ?? "";
            if (folderBox.Text == "") Status("Click \"Find game...\" and pick " + GameExe + ".");
            ShowInstalled();

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
            tray.Text = "Survivor UI Installer";
            ContextMenuStrip menu = new ContextMenuStrip();
            menu.Items.Add("Open", null, delegate { FromTray(); });
            menu.Items.Add("Check for updates now", null, delegate
            {
                FromTray();
                installWhenNewer = true;
                Status("Asking GitHub for the latest release...");
                CheckNow();
            });
            installItem.Enabled = false;
            installItem.Click += delegate { FromTray(); Install(); };
            menu.Items.Add(installItem);
            startItem.CheckOnClick = false;
            startItem.Checked = StartsWithWindows();
            startItem.Click += delegate { startBox.Checked = !startBox.Checked; };
            menu.Items.Add(startItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Exit", null, delegate { Close(); });
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
                Hide();
                if (!toldOfTray && !updateWaiting)
                {
                    toldOfTray = true;
                    tray.ShowBalloonTip(4000, "Survivor UI Installer",
                        "Still here, in the tray. A green arrow shows when an update is out.", ToolTipIcon.Info);
                }
            };
            FormClosed += delegate
            {
                tray.Visible = false;
                tray.Dispose();
            };
        }

        void FromTray()
        {
            Show();
            if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal;
            Activate();
            ShowOverlay();
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
            notesWindow.ShowNotes("What's new in Survivor UI " + latest.Tag, latest.Notes);
            if (!notesWindow.Visible) notesWindow.Show(this);
            notesWindow.Activate();
        }

        void CheckNow()
        {
            new Thread(FetchLatest) { IsBackground = true }.Start();
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
            bool known = latest != null && latest.ZipUrl != null;
            updateWaiting = known && installed != null && Newer(latest.Tag, installed);
            bool current = known && installed != null && !updateWaiting;
            tray.Icon = updateWaiting ? (trayUpdateIcon ?? tray.Icon) : (trayIcon ?? tray.Icon);
            tray.Text = updateWaiting ? Trim("Survivor UI " + latest.Tag + " is out: click to update", 63)
                : current ? "Survivor UI Installer: up to date" : "Survivor UI Installer";
            installItem.Enabled = updateWaiting && !installing;
            installItem.Text = updateWaiting ? "Install " + latest.Tag : current ? "Up to date (" + latest.Tag + ")" : "Install the update";
            latestLabel.ForeColor = updateWaiting ? Color.FromArgb(90, 220, 110) : Gold;
            installButton.Text = installed == null ? "Install" : updateWaiting ? "Update to " + latest.Tag : "Install / Update";
            installButton.Visible = !current;
            upToDate.Text = current ? "\u2713  Up to date" : "";
            upToDate.Visible = current;
            ShowOverlay();
            // Asked from the tray: a newer one installed at once, or said so.
            if (installWhenNewer && latest != null)
            {
                installWhenNewer = false;
                if (updateWaiting && !installing)
                {
                    Install();
                    return;
                }
                if (current) Status("Survivor UI " + latest.Tag + " is the latest: up to date.");
            }
            if (updateWaiting && toldOf != latest.Tag)
            {
                toldOf = latest.Tag;
                tray.ShowBalloonTip(6000, "Survivor UI " + latest.Tag + " is out",
                    "Click to see what's new and update.", ToolTipIcon.Info);
            }
        }

        static string Trim(string text, int most)
        {
            return text.Length <= most ? text : text.Substring(0, most);
        }

        // "v3.0.2" against "3.0.1": number by number, a missing one as 0.
        static bool Newer(string tag, string installed)
        {
            MatchCollection a = Regex.Matches(tag ?? "", @"\d+");
            MatchCollection b = Regex.Matches(installed ?? "", @"\d+");
            for (int i = 0; i < Math.Max(a.Count, b.Count); i++)
            {
                int x = i < a.Count ? int.Parse(a[i].Value) : 0;
                int y = i < b.Count ? int.Parse(b[i].Value) : 0;
                if (x != y) return x > y;
            }
            return false;
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
            string version = InstalledVersion(folderBox.Text);
            installedLabel.Text = "Installed:  " + (version != null ? "v" + version : "not installed");
            installedLabel.ForeColor = version != null ? TextColor : Muted;
            ShowUpdateState();
        }

        void FetchLatest()
        {
            try
            {
                string json = Download("https://api.github.com/repos/" + Repo + "/releases/latest");
                Dictionary<string, object> data = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(json);
                Release release = new Release();
                release.Tag = (string)data["tag_name"];
                release.Notes = data.ContainsKey("body") ? (string)data["body"] : "";
                foreach (object asset in (System.Collections.ArrayList)data["assets"])
                {
                    Dictionary<string, object> a = (Dictionary<string, object>)asset;
                    string name = (string)a["name"];
                    // The addons' zip, "SurvivorUI-v2.4.zip", not the installer's own.
                    if (Regex.IsMatch(name, @"^SurvivorUI-v[\d.]+\.zip$", RegexOptions.IgnoreCase))
                    {
                        release.ZipName = name;
                        release.ZipUrl = (string)a["browser_download_url"];
                        break;
                    }
                }
                BeginInvoke(new Action<Release>(ShowLatest), release);
            }
            catch (Exception error)
            {
                BeginInvoke(new Action(delegate
                {
                    installWhenNewer = false;
                    // Known already: kept, and asked again in half an hour.
                    if (latest != null)
                    {
                        Status("Could not reach GitHub just now; it will ask again later.");
                        return;
                    }
                    notesBox.Text = "Could not reach GitHub: " + error.Message + "\r\n\r\nCheck your internet connection; it will ask again in half an hour.";
                    latestLabel.Text = "Latest:  unknown";
                }));
            }
        }

        void ShowLatest(Release release)
        {
            latest = release;
            latestLabel.Text = "Latest:  " + release.Tag;
            notesBox.Text = Plain(release.Notes);
            installButton.Enabled = release.ZipUrl != null;
            if (release.ZipUrl == null) Status("The latest release has no zip to install.");
            ShowUpdateState();
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

        // --- Install ----------------------------------------------------------

        void Install()
        {
            string addons = folderBox.Text.Trim();
            if (addons == "" || latest == null) { Status("Pick the game first."); return; }
            if (!Directory.Exists(Path.GetDirectoryName(addons.TrimEnd('\\'))))
            {
                MessageBox.Show(this, "That folder does not look like the game's: " + addons, "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (installing) return;
            installing = true;
            installButton.Enabled = false;
            browseButton.Enabled = false;
            installItem.Enabled = false;
            Status("Downloading " + latest.ZipName + "...");
            Release release = latest;
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
                        // Only inside the AddOns folder, only the addon folders.
                        if (!target.StartsWith(root, StringComparison.OrdinalIgnoreCase)) continue;
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
                    installButton.Enabled = true;
                    browseButton.Enabled = true;
                    ShowUpdateState();
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
