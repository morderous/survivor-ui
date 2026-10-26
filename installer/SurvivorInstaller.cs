// Azeroth SurvivorUI Launcher (the installer): installs and updates Survivor UI and Survivor Plates
// from the latest GitHub release, into Azeroth Survivors' AddOns folder.
//
// What it does, and nothing else:
//   - asks GitHub which release is the latest, and shows its notes;
//   - finds the game's AddOns folder (or lets the player pick the game);
//   - on Install, downloads the release's zip, removes the old SurvivorUI and
//     SurvivorPlates folders and unzips the new ones in their place;
//   - Play starts the game (the one by the AddOns folder), and the installer
//     steps into the tray;
//   - keeps to the game's own folder: the game keeps its AddOns, saved
//     settings and options where its exe says (0.112.0 to 0.112.4 in the
//     folder they were built from, a worktree on Aethus' PC; from 0.112.5 a
//     benilla-config folder beside the exe, which the game fills from the
//     older ones the first time it starts), so the addons go there; "Check folder and move if necessary", under
//     the folder (green while needed), moves the player's things from an
//     older folder of the game into it, what was there set aside, nothing
//     deleted;
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
//   - in five tabs: Play, Survivor UI, Savegame, Statistics, Run History;
//   - each addon on or off for the game (Survivor UI tab), in the game's own
//     list (AddOns\account.txt): nothing deleted, so the launcher serves a
//     player without the addons too;
//   - keeps the game's save (Savegame tab): "Back up now" zips the heroes,
//     their gear, talents and unlocks (%APPDATA%\wenilla-rogue) with the
//     game's settings and the addons' (key bindings, chat windows, camera,
//     layout, Run History), to the Desktop, a USB drive or a folder, to keep
//     or to take to another PC; "Restore save..." puts one back, the save as
//     it was kept on the Desktop first, the settings only when asked; after
//     each game session it sees end, a backup by itself when asked, the last
//     few kept (and on a USB drive too). Only with the game closed;
//   - counts the playtime it sees (the game's process watched), for Play's
//     numbers and Statistics;
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
using System.Drawing.Drawing2D;
using System.Drawing.Text;
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

[assembly: System.Reflection.AssemblyTitle("Azeroth SurvivorUI Launcher")]
[assembly: System.Reflection.AssemblyProduct("Survivor UI")]
[assembly: System.Reflection.AssemblyVersion("1.5.0.0")]

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

        [DllImport("user32.dll", EntryPoint = "SendMessage")]
        public static extern IntPtr Send(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct ScrollInfo
        {
            public int cbSize, fMask, nMin, nMax, nPage, nPos, nTrackPos;
        }

        [DllImport("user32.dll")]
        public static extern bool GetScrollInfo(IntPtr hwnd, int bar, ref ScrollInfo info);
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

        static readonly Color Back = Color.FromArgb(19, 19, 18);     // the pack's panel
        static readonly Color Panel = Color.FromArgb(19, 19, 18);
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
        readonly Button foldersButton = new Button();
        readonly ToolTip folderTip = new ToolTip();
        // The folders' button: steel blue, green while a move is needed.
        static readonly Color FolderFill = Color.FromArgb(22, 48, 66);
        static readonly Color FolderEdge = Color.FromArgb(72, 140, 182);
        static readonly Color FolderText = Color.FromArgb(178, 222, 255);
        static readonly Color MoveFill = Color.FromArgb(28, 112, 50);
        static readonly Color MoveEdge = Color.FromArgb(96, 222, 120);
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
        // This launcher is a beta: said by its version and in its window's title.
        const string Stage = " (beta)";
        Release selfRelease;        // the release with a newer installer, while one is out
        bool selfUpdating;
        bool gettingGame;           // the game being asked for or downloaded
        readonly Button saveButton = new Button();
        readonly Button restoreButton = new Button();
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

        // The window: the header (the emblem, the versions, Check for updates),
        // five tabs under it, and the status line and Aethus' credit under
        // every tab:
        //   Play         the game: its version, Find game, Play (Get the game,
        //                Update game), the player's numbers, the game's news,
        //                the launcher's own ticks;
        //   Survivor UI  the addons: each on or off, the AddOns folder,
        //                install, the beta, what's new, the links;
        //   Savegame     the save: backed up to the Desktop, a USB drive or a
        //                folder, put back, backed up by itself after each
        //                session, the backups made;
        //   Statistics   the playtime the launcher saw and the account's
        //                numbers from the save (read, never written): totals,
        //                the newest achievements, each class's zones beaten
        //                and talent points, the collection;
        //   Run History  Survivor UI's runs, read from its saved settings: a
        //                list to filter, and the one picked in detail.
        static readonly string[] TabNames = { "Play", "Survivor UI", "Savegame", "Statistics", "Run History" };
        const int PageTop = 124, PageHeight = 432;
        readonly List<Panel> pages = new List<Panel>();
        readonly List<Button> tabButtons = new List<Button>();
        readonly Panel tabMark = new Panel();
        int currentTab = -1;

        // The window's scale: 1 while it is built in its old units, then up to
        // 1.4 as the screen allows (ScaleWindow). S and SF turn an old size into
        // the window's; the canvases draw in old units (Txt, W, H).
        float ui = 1f;
        static readonly Font BaseFont = new Font("Segoe UI", 9.5f);
        readonly Dictionary<string, Font> paintFonts = new Dictionary<string, Font>();

        int S(int value)
        {
            return (int)Math.Round(value * ui);
        }

        float SF(float value)
        {
            return value * ui;
        }

        Font Scaled(Font font)
        {
            if (ui == 1f) return font;
            string key = font.Name + "|" + font.Size + "|" + (int)font.Style;
            Font scaled;
            if (!paintFonts.TryGetValue(key, out scaled))
            {
                scaled = new Font(font.FontFamily, font.Size * ui, font.Style);
                paintFonts[key] = scaled;
            }
            return scaled;
        }

        // A canvas's size in old units.
        int W(Control canvas)
        {
            return (int)(canvas.Width / ui);
        }

        int H(Control canvas)
        {
            return (int)(canvas.Height / ui);
        }

        // Words on a canvas drawn in old units: placed and sized for the
        // window's scale, outside the scale transform.
        // (Placed through the canvas's whole transform, its scale and any
        // move, then drawn without it.)
        void Txt(Graphics g, string text, Font font, Rectangle box, Color color, TextFormatFlags flags)
        {
            PointF[] corners = { new PointF(box.X, box.Y), new PointF(box.Right, box.Bottom) };
            using (System.Drawing.Drawing2D.Matrix placed = g.Transform) placed.TransformPoints(corners);
            System.Drawing.Drawing2D.GraphicsState state = g.Save();
            g.ResetTransform();
            TextRenderer.DrawText(g, text, Scaled(font), new Rectangle((int)Math.Round(corners[0].X), (int)Math.Round(corners[0].Y),
                (int)Math.Round(corners[1].X - corners[0].X), (int)Math.Round(corners[1].Y - corners[0].Y)), color,
                flags);
            g.Restore(state);
        }

        void Txt(Graphics g, string text, Font font, Point at, Color color, TextFormatFlags flags)
        {
            PointF[] point = { new PointF(at.X, at.Y) };
            using (System.Drawing.Drawing2D.Matrix placed = g.Transform) placed.TransformPoints(point);
            System.Drawing.Drawing2D.GraphicsState state = g.Save();
            g.ResetTransform();
            TextRenderer.DrawText(g, text, Scaled(font), new Point((int)Math.Round(point[0].X), (int)Math.Round(point[0].Y)), color,
                flags);
            g.Restore(state);
        }

        int MeasureW(Graphics g, string text, Font font, TextFormatFlags flags)
        {
            return (int)Math.Ceiling(TextRenderer.MeasureText(g, text, Scaled(font), Size.Empty, flags).Width / ui);
        }

        // Once built: the window up to 40% larger, as the screen where it opens
        // allows (its working area, the taskbar left out), never smaller.
        static float PlannedScale(Size client)
        {
            Rectangle area = Screen.FromPoint(Cursor.Position).WorkingArea;
            float fit = Math.Min((area.Width - 24f) / client.Width, (area.Height - 64f) / client.Height);
            float factor = Math.Max(1f, Math.Min(1.4f, fit));
            return factor < 1.02f ? 1f : factor;
        }

        static float planned = 1f;  // the scale the window will take, known before it is built

        void ScaleWindow()
        {
            float factor = planned;
            if (factor == 1f) return;
            List<KeyValuePair<Control, Font>> fonts = new List<KeyValuePair<Control, Font>>();
            RememberFonts(this, fonts);
            Size client = ClientSize;
            SuspendLayout();
            Scale(new SizeF(factor, factor));
            ui = factor;
            foreach (KeyValuePair<Control, Font> pair in fonts)
                pair.Key.Font = new Font(pair.Value.FontFamily, pair.Value.Size * factor, pair.Value.Style);
            ScaleInside(this, factor);
            ClientSize = new Size((int)Math.Round(client.Width * factor), (int)Math.Round(client.Height * factor));
            ResumeLayout(true);
        }

        static void RememberFonts(Control parent, List<KeyValuePair<Control, Font>> fonts)
        {
            fonts.Add(new KeyValuePair<Control, Font>(parent, parent.Font));
            foreach (Control child in parent.Controls) RememberFonts(child, fonts);
        }

        // What Control.Scale leaves: the lists' columns. (The drop-downs' rows
        // are made at the planned scale already: a row height changed once the
        // drop-down exists turns it back to the system's white.)
        static void ScaleInside(Control parent, float factor)
        {
            foreach (Control child in parent.Controls)
            {
                ListView list = child as ListView;
                if (list != null)
                    foreach (ColumnHeader column in list.Columns) column.Width = (int)Math.Round(column.Width * factor);
                ScaleInside(child, factor);
            }
        }

        public MainForm(bool inTray, bool updated)
        {
            startHidden = inTray;
            this.Text = "Azeroth SurvivorUI Launcher" + Stage;
            ClientSize = new Size(760, 618);
            planned = PlannedScale(ClientSize);
            FormBorderStyle = FormBorderStyle.None;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Back;
            ForeColor = TextColor;
            Font = new Font("Segoe UI", 9.5f);
            LoadIcons();
            if (appIcon != null) Icon = appIcon;
            DoubleBuffered = true;
            Paint += PaintWindow;

            // The emblem, the shield with the S, beside the name.
            PictureBox logo = new PictureBox();
            logo.Location = new Point(14, 9);
            logo.Size = new Size(48, 48);
            logo.SizeMode = PictureBoxSizeMode.Zoom;
            logo.Image = EmbeddedImage("Logo.png");
            logo.BackColor = Color.Transparent;
            Controls.Add(logo);
            // The title is drawn on the stone (PaintTitle).

            Label subtitle = new Label();
            subtitle.Text = "Play Azeroth Survivors with Survivor UI";
            subtitle.UseMnemonic = false;
            subtitle.ForeColor = Color.FromArgb(200, 190, 170);
            subtitle.BackColor = Color.Transparent;
            subtitle.AutoSize = true;
            subtitle.Location = new Point(104, 62);
            subtitle.Font = new Font("Segoe UI", 8.5f);
            Controls.Add(subtitle);

            // At the top right, the versions together, the launcher's and Survivor
            // UI's, Check for updates under them; a newer launcher out: a green
            // arrow by its version, and the button turns to it, green, breathing
            // so it is seen.
            arrowMark.Location = new Point(560, 10);
            arrowMark.Size = new Size(16, 18);
            arrowMark.Visible = false;
            arrowMark.BackColor = Color.Transparent;
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
            versionLabel.Location = new Point(582, 9);
            versionLabel.Size = new Size(126, 18);
            versionLabel.Font = new Font("Segoe UI", 9f);
            versionLabel.TextAlign = ContentAlignment.MiddleLeft;
            versionLabel.BackColor = Color.Transparent;
            Controls.Add(versionLabel);

            addonLabel.AutoSize = false;
            addonLabel.Location = new Point(582, 27);
            addonLabel.Size = new Size(124, 18);
            addonLabel.Font = new Font("Segoe UI", 9f);
            addonLabel.TextAlign = ContentAlignment.MiddleLeft;
            addonLabel.ForeColor = VersionYellow;
            addonLabel.BackColor = Color.Transparent;
            Controls.Add(addonLabel);

            selfButton.FlatStyle = FlatStyle.Flat;
            selfButton.Cursor = Cursors.Hand;
            selfButton.Location = new Point(580, 50);
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
            Forge(selfButton);
            Wear(selfButton, "stone");
            BuildCoffee();
            BuildWindowButtons();
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

            // The tabs along the top, the one open in gold over a gold line.
            int tabX = 16;
            for (int i = 0; i < TabNames.Length; i++)
            {
                Button tab = new Button();
                tab.Text = TabNames[i];
                tab.FlatStyle = FlatStyle.Flat;
                tab.FlatAppearance.BorderSize = 0;
                tab.FlatAppearance.MouseOverBackColor = Panel;
                tab.FlatAppearance.MouseDownBackColor = Panel;
                tab.BackColor = Back;
                tab.ForeColor = Muted;
                tab.Font = new Font("Segoe UI", 10f, FontStyle.Bold);
                tab.Cursor = Cursors.Hand;
                int width = TextRenderer.MeasureText(TabNames[i], tab.Font).Width + 28;
                tab.Location = new Point(tabX, 88);
                tab.Size = new Size(width, 30);
                int which = i;
                tab.Click += delegate { ShowTab(which); };
                tabX += width + 2;
                Controls.Add(tab);
                tabButtons.Add(tab);
            }
            Panel tabLine = new Panel();
            tabLine.Location = new Point(5, 119);
            tabLine.Size = new Size(ClientSize.Width - 10, 1);
            tabLine.BackColor = Color.FromArgb(48, 48, 60);
            Controls.Add(tabLine);
            tabMark.BackColor = Gold;
            tabMark.Visible = false;
            Controls.Add(tabMark);
            SkinTabs();

            BuildPlayPage(NewPage());
            BuildAddonPage(NewPage());
            BuildSavePage(NewPage());
            BuildStatsPage(NewPage());
            BuildRunsPage(NewPage());

            statusLabel.Location = new Point(20, 562);
            statusLabel.BackColor = Color.Transparent;
            statusLabel.Size = new Size(720, 20);
            statusLabel.ForeColor = Muted;
            Controls.Add(statusLabel);

            // Whose game it is, at the bottom left; his site in the other corner.
            Label credit = new Label();
            credit.Text = "Azeroth Survivors is a game by Aethus";
            credit.Font = new Font("Segoe UI", 8f);
            credit.AutoSize = false;
            credit.Location = new Point(20, 584);
            credit.BackColor = Color.Transparent;
            credit.Size = new Size(320, 18);
            credit.ForeColor = Muted;
            credit.TextAlign = ContentAlignment.MiddleLeft;
            Controls.Add(credit);

            creditLink.Text = "wow.aethus.pl";
            creditLink.Font = new Font("Segoe UI", 8f);
            creditLink.AutoSize = false;
            creditLink.Location = new Point(580, 584);
            creditLink.BackColor = Color.Transparent;
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

            int lastTab;
            ShowTab(int.TryParse(Setting("tab", "0"), out lastTab) && lastTab >= 0 && lastTab < TabNames.Length ? lastTab : 0);
            WatchGame();

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
            ShowSwitches();
            SeedPlaytime();
            ShowStrip();
            NoteFolders(true);
            SkinPages();
            ScaleWindow();
            FitRunColumns();
            SkinTips(tips);
            SkinTips(folderTip);
            BuildAlert();
            foreach (Control scrolled in new Control[] { gameNews, notesBox, backupList, runList })
                new ArtScroll(this, scrolled);
            ShowTab(currentTab, true);

            // Just updated: the old exe, set aside, goes once it has closed.
            if (updated) Status("The launcher is now " + Short(OwnVersion) + ".");
            CleanUpOld(updated);

            Shown += delegate { CheckNow(); };
            checkTimer.Interval = CheckEvery;
            checkTimer.Tick += delegate { CheckNow(); };
            checkTimer.Start();
        }

        // --- Our look ---------------------------------------------------------------

        // The launcher's art: Wenrexa's "UI RPG Game Interface" (CC0, art\ in
        // this folder, credited in art\CREDITS.txt), inside the exe. Frames,
        // buttons, tabs, switches and the title's plaque are its pieces, drawn
        // by slices (corners kept, edges and middles stretched) at the
        // window's scale; the stone of the header, the coffee cup and the
        // charts are drawn here in its colours. The title in Cinzel Decorative
        // (SIL Open Font License, OFL-CinzelDecorative.txt beside this source).
        static readonly Color RedFill = Color.FromArgb(112, 16, 10);
        static readonly Color RedEdge = Color.FromArgb(200, 152, 58);
        static readonly Color RuleColor = Color.FromArgb(96, 84, 58);
        static readonly Color StoneText = Color.FromArgb(236, 222, 178);
        static readonly Color StoneFill = Color.FromArgb(60, 58, 52);
        static readonly Color VersionYellow = Color.FromArgb(255, 218, 64);
        static PrivateFontCollection titleFonts;
        static FontFamily titleFamily;
        Bitmap headerStone;         // made once for the window's width

        // Cinzel Decorative, from the exe's own resources; Segoe UI without it.
        static FontFamily TitleFamily()
        {
            if (titleFamily != null) return titleFamily;
            titleFamily = new FontFamily("Segoe UI");
            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("CinzelDecorative-Bold.ttf"))
                {
                    if (stream == null) return titleFamily;
                    byte[] data = new byte[stream.Length];
                    int read = 0;
                    while (read < data.Length)
                    {
                        int got = stream.Read(data, read, data.Length - read);
                        if (got <= 0) break;
                        read += got;
                    }
                    // Kept for the program's life: the collection reads the font there.
                    IntPtr memory = Marshal.AllocCoTaskMem(data.Length);
                    Marshal.Copy(data, 0, memory, data.Length);
                    titleFonts = new PrivateFontCollection();
                    titleFonts.AddMemoryFont(memory, data.Length);
                    titleFamily = titleFonts.Families[0];
                }
            }
            catch { }
            return titleFamily;
        }

        static FontStyle TitleStyle(FontFamily family)
        {
            return family.IsStyleAvailable(FontStyle.Bold) ? FontStyle.Bold : FontStyle.Regular;
        }

        static Color Shade(Color color, float amount)
        {
            if (amount >= 0)
                return Color.FromArgb(color.R + (int)((255 - color.R) * amount), color.G + (int)((255 - color.G) * amount),
                    color.B + (int)((255 - color.B) * amount));
            float keep = 1 + amount;
            return Color.FromArgb((int)(color.R * keep), (int)(color.G * keep), (int)(color.B * keep));
        }

        static Color Mix(Color a, Color b, float t)
        {
            return Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));
        }

        static bool Live(Button button)
        {
            return button.Enabled && (!(button.Tag is bool) || (bool)button.Tag);
        }

        // --- The pack's pieces ---------------------------------------------------------

        static readonly Dictionary<string, Bitmap> artCache = new Dictionary<string, Bitmap>();

        // A piece by its name in art\ (null when the exe was built without it).
        static Bitmap Art(string name)
        {
            Bitmap art;
            if (artCache.TryGetValue(name, out art)) return art;
            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("art." + name + ".png"))
                    if (stream != null)
                        using (Bitmap read = new Bitmap(stream)) art = new Bitmap(read);
            }
            catch { art = null; }
            artCache[name] = art;
            return art;
        }

        // A piece lit (under the mouse), darkened (pressed) or greyed (off).
        static Bitmap ArtAs(string name, string how)
        {
            if (how == null) return Art(name);
            string key = name + "|" + how;
            Bitmap art;
            if (artCache.TryGetValue(key, out art)) return art;
            Bitmap source = Art(name);
            if (source == null) return null;
            float[][] matrix;
            float dim = how.EndsWith("-dim") ? 0.55f : 1f;
            if (how.StartsWith("green"))
                matrix = new float[][] {
                    new float[] { 0.25f * dim, 0.95f * dim, 0.2f * dim, 0, 0 }, new float[] { 0.25f * dim, 0.25f * dim, 0, 0, 0 },
                    new float[] { 0, 0, 0.3f * dim, 0, 0 }, new float[] { 0, 0, 0, 1, 0 }, new float[] { 0, 0, 0, 0, 1 } };
            else if (how.StartsWith("purple"))
                matrix = new float[][] {
                    new float[] { 0.75f * dim, 0.15f * dim, 0.95f * dim, 0, 0 }, new float[] { 0.1f * dim, 0.35f * dim, 0.05f * dim, 0, 0 },
                    new float[] { 0, 0, 0.3f * dim, 0, 0 }, new float[] { 0, 0, 0, 1, 0 }, new float[] { 0, 0, 0, 0, 1 } };
            else if (how == "grey")
                matrix = new float[][] {
                    new float[] { 0.2f, 0.2f, 0.2f, 0, 0 }, new float[] { 0.39f, 0.39f, 0.39f, 0, 0 },
                    new float[] { 0.08f, 0.08f, 0.08f, 0, 0 }, new float[] { 0, 0, 0, 1, 0 }, new float[] { 0.02f, 0.02f, 0.02f, 0, 1 } };
            else
            {
                float k = how == "hot" ? 1.25f : 0.72f, add = how == "hot" ? 0.03f : 0f;
                matrix = new float[][] {
                    new float[] { k, 0, 0, 0, 0 }, new float[] { 0, k, 0, 0, 0 }, new float[] { 0, 0, k, 0, 0 },
                    new float[] { 0, 0, 0, 1, 0 }, new float[] { add, add, add, 0, 1 } };
            }
            art = new Bitmap(source.Width, source.Height);
            using (Graphics g = Graphics.FromImage(art))
            using (System.Drawing.Imaging.ImageAttributes paint = new System.Drawing.Imaging.ImageAttributes())
            {
                paint.SetColorMatrix(new System.Drawing.Imaging.ColorMatrix(matrix));
                g.DrawImage(source, new Rectangle(0, 0, source.Width, source.Height), 0, 0, source.Width, source.Height, GraphicsUnit.Pixel, paint);
            }
            artCache[key] = art;
            return art;
        }

        // A piece drawn into a rectangle by nine slices: its corners (l, t, r
        // and b pixels of the piece) at the scale given, its edges stretched
        // along, its middle both ways (or left out). Corners too big for the
        // rectangle shrink to fit.
        static void Slice9(Graphics g, Bitmap art, Rectangle to, int l, int t, int r, int b, float scale, bool middle)
        {
            if (art == null || to.Width <= 0 || to.Height <= 0) return;
            int L = (int)Math.Round(l * scale), T = (int)Math.Round(t * scale), R = (int)Math.Round(r * scale), B = (int)Math.Round(b * scale);
            if (L + R > to.Width && L + R > 0)
            {
                float fit = (float)to.Width / (L + R);
                L = (int)(L * fit);
                R = to.Width - L;
            }
            if (T + B > to.Height && T + B > 0)
            {
                float fit = (float)to.Height / (T + B);
                T = (int)(T * fit);
                B = to.Height - T;
            }
            int w = art.Width, h = art.Height;
            Rectangle[] from = {
                new Rectangle(0, 0, l, t), new Rectangle(l, 0, w - l - r, t), new Rectangle(w - r, 0, r, t),
                new Rectangle(0, t, l, h - t - b), new Rectangle(l, t, w - l - r, h - t - b), new Rectangle(w - r, t, r, h - t - b),
                new Rectangle(0, h - b, l, b), new Rectangle(l, h - b, w - l - r, b), new Rectangle(w - r, h - b, r, b) };
            int x1 = to.X + L, x2 = to.Right - R, y1 = to.Y + T, y2 = to.Bottom - B;
            Rectangle[] into = {
                new Rectangle(to.X, to.Y, L, T), new Rectangle(x1, to.Y, x2 - x1, T), new Rectangle(x2, to.Y, R, T),
                new Rectangle(to.X, y1, L, y2 - y1), new Rectangle(x1, y1, x2 - x1, y2 - y1), new Rectangle(x2, y1, R, y2 - y1),
                new Rectangle(to.X, y2, L, B), new Rectangle(x1, y2, x2 - x1, B), new Rectangle(x2, y2, R, B) };
            InterpolationMode interpolation = g.InterpolationMode;
            PixelOffsetMode offset = g.PixelOffsetMode;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            using (System.Drawing.Imaging.ImageAttributes edges = new System.Drawing.Imaging.ImageAttributes())
            {
                edges.SetWrapMode(WrapMode.TileFlipXY);
                for (int i = 0; i < 9; i++)
                {
                    if (i == 4 && !middle) continue;
                    if (from[i].Width <= 0 || from[i].Height <= 0 || into[i].Width <= 0 || into[i].Height <= 0) continue;
                    g.DrawImage(art, into[i], from[i].X, from[i].Y, from[i].Width, from[i].Height, GraphicsUnit.Pixel, edges);
                }
            }
            g.InterpolationMode = interpolation;
            g.PixelOffsetMode = offset;
        }

        // A frame whose corner pieces run further along its top and bottom
        // than its sides are thick (the pack's panels): its top and bottom
        // rows cut at corner pixels from each end, its sides only l and r
        // pixels thick, all at the scale given; the middle left out or not.
        static void SliceFrame(Graphics g, Bitmap art, Rectangle to, int l, int t, int r, int b, int corner, float scale, bool middle)
        {
            if (art == null || to.Width <= 0 || to.Height <= 0) return;
            int L = (int)Math.Round(l * scale), T = (int)Math.Round(t * scale), R = (int)Math.Round(r * scale), B = (int)Math.Round(b * scale);
            int C = (int)Math.Round(corner * scale);
            if (2 * C > to.Width) C = to.Width / 2;
            int w = art.Width, h = art.Height;
            List<KeyValuePair<Rectangle, Rectangle>> pieces = new List<KeyValuePair<Rectangle, Rectangle>>();
            // The top and bottom rows: corner, stretched middle, corner.
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(0, 0, corner, t), new Rectangle(to.X, to.Y, C, T)));
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(corner, 0, w - 2 * corner, t), new Rectangle(to.X + C, to.Y, to.Width - 2 * C, T)));
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(w - corner, 0, corner, t), new Rectangle(to.Right - C, to.Y, C, T)));
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(0, h - b, corner, b), new Rectangle(to.X, to.Bottom - B, C, B)));
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(corner, h - b, w - 2 * corner, b), new Rectangle(to.X + C, to.Bottom - B, to.Width - 2 * C, B)));
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(w - corner, h - b, corner, b), new Rectangle(to.Right - C, to.Bottom - B, C, B)));
            // The sides, only as thick as the rim; the middle.
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(0, t, l, h - t - b), new Rectangle(to.X, to.Y + T, L, to.Height - T - B)));
            pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(w - r, t, r, h - t - b), new Rectangle(to.Right - R, to.Y + T, R, to.Height - T - B)));
            if (middle)
                pieces.Add(new KeyValuePair<Rectangle, Rectangle>(new Rectangle(l, t, w - l - r, h - t - b), new Rectangle(to.X + L, to.Y + T, to.Width - L - R, to.Height - T - B)));
            InterpolationMode interpolation = g.InterpolationMode;
            PixelOffsetMode offset = g.PixelOffsetMode;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            using (System.Drawing.Imaging.ImageAttributes edges = new System.Drawing.Imaging.ImageAttributes())
            {
                edges.SetWrapMode(WrapMode.TileFlipXY);
                foreach (KeyValuePair<Rectangle, Rectangle> piece in pieces)
                {
                    Rectangle from = piece.Key, into = piece.Value;
                    if (from.Width <= 0 || from.Height <= 0 || into.Width <= 0 || into.Height <= 0) continue;
                    g.DrawImage(art, into, from.X, from.Y, from.Width, from.Height, GraphicsUnit.Pixel, edges);
                }
            }
            g.InterpolationMode = interpolation;
            g.PixelOffsetMode = offset;
        }

        // A piece across a rectangle: its ends kept (at the rectangle's
        // height), its middle stretched.
        static void Slice3(Graphics g, Bitmap art, Rectangle to, int l, int r)
        {
            if (art == null) return;
            Slice9(g, art, to, l, 0, r, 0, (float)to.Height / art.Height, true);
        }

        static void DrawArt(Graphics g, Bitmap art, Rectangle to)
        {
            if (art == null) return;
            InterpolationMode interpolation = g.InterpolationMode;
            PixelOffsetMode offset = g.PixelOffsetMode;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(art, to);
            g.InterpolationMode = interpolation;
            g.PixelOffsetMode = offset;
        }

        // --- Buttons ---------------------------------------------------------------------

        // Which piece a button wears: "red" (the pack's red plate, the actions)
        // or "stone" (its stone plate, the rest). Red unless said.
        static readonly Dictionary<Button, string> buttonArt = new Dictionary<Button, string>();
        // A second, small line under a button's words (Play's version).
        static readonly Dictionary<Button, Func<string>> subLines = new Dictionary<Button, Func<string>>();

        static void Wear(Button button, string kind)
        {
            buttonArt[button] = kind;
            if (kind == "stone" && button.BackColor == RedFill) button.BackColor = StoneFill;
            button.Invalidate();
        }

        // Our button: the piece in its state (lit under the mouse, darker when
        // pressed, grey while off), the parent's own face behind its round
        // ends, its words with a shadow; a state of the button's own (the
        // folders to move, a new launcher) washes its colour over the plate.
        static void Forge(Button button)
        {
            bool hot = false, down = false;
            typeof(Control).GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(button, true, null);
            button.MouseEnter += delegate { hot = true; button.Invalidate(); };
            button.MouseLeave += delegate { hot = false; down = false; button.Invalidate(); };
            button.MouseDown += delegate (object sender, MouseEventArgs e)
            {
                if (e.Button == MouseButtons.Left) { down = true; button.Invalidate(); }
            };
            button.MouseUp += delegate { down = false; button.Invalidate(); };
            button.Paint += delegate (object sender, PaintEventArgs e)
            {
                bool live = Live(button);
                PaintForged(e.Graphics, button, hot && live, down && live);
            };
        }

        static void PaintForged(Graphics g, Button button, bool hot, bool down)
        {
            Rectangle r = button.ClientRectangle;
            if (r.Width < 6 || r.Height < 6) return;
            string kind;
            if (!buttonArt.TryGetValue(button, out kind)) kind = "red";
            bool live = Live(button);
            string name = kind == "stone" ? "button-stone" : r.Width > r.Height * 6 ? "button-red-wide" : "button-red";
            Bitmap art = ArtAs(name, !live ? "grey" : down ? "down" : hot ? "hot" : null);
            ButtonRenderer.DrawParentBackground(g, r, button);
            if (art == null)
            {
                using (Brush plain = new SolidBrush(button.BackColor)) g.FillRectangle(plain, r);
            }
            else if (kind == "stone") Slice3(g, art, r, 22, 20);
            else Slice3(g, art, r, 31, 31);
            // A state of the button's own, in green or blue: washed over.
            Color own = button.BackColor;
            if (live && kind == "stone" && Math.Max(own.R, Math.Max(own.G, own.B)) - Math.Min(own.R, Math.Min(own.G, own.B)) > 30)
            {
                Rectangle inner = Rectangle.Inflate(r, -Math.Max(3, r.Height / 6), -Math.Max(3, r.Height / 6));
                using (Brush wash = new SolidBrush(Color.FromArgb(hot ? 110 : 85, Shade(own, 0.25f)))) g.FillRectangle(wash, inner);
            }
            Rectangle words = new Rectangle(r.X + r.Height / 5, r.Y, r.Width - 2 * (r.Height / 5), r.Height);
            if (down) words.Offset(1, 1);
            TextFormatFlags flags = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix |
                TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis;
            Func<string> under;
            string second = subLines.TryGetValue(button, out under) ? under() : "";
            Font small = null;
            Rectangle line = Rectangle.Empty;
            if (!string.IsNullOrEmpty(second))
            {
                // On the same line, after the words, smaller: the two centred
                // together, the small one's foot on the big one's.
                small = new Font(button.Font.FontFamily, button.Font.Size * 0.62f);
                Size big = TextRenderer.MeasureText(g, button.Text, button.Font, Size.Empty, TextFormatFlags.NoPadding);
                Size little = TextRenderer.MeasureText(g, second, small, Size.Empty, TextFormatFlags.NoPadding);
                int space = big.Height / 3;
                int left = r.X + (r.Width - big.Width - space - little.Width) / 2;
                int top = r.Y + (r.Height - big.Height) / 2;
                words = new Rectangle(left, top, big.Width + 2, big.Height);
                line = new Rectangle(left + big.Width + space, top + (big.Height - little.Height) * 3 / 4, little.Width + 2, little.Height);
                if (down)
                {
                    words.Offset(1, 1);
                    line.Offset(1, 1);
                }
                flags = TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine | TextFormatFlags.NoPadding;
            }
            Rectangle shadow = words;
            shadow.Offset(1, 1);
            Color text = !live ? Color.FromArgb(128, 122, 108) : button.ForeColor;
            TextRenderer.DrawText(g, button.Text, button.Font, shadow, Color.FromArgb(8, 6, 4), flags);
            TextRenderer.DrawText(g, button.Text, button.Font, words, text, flags);
            if (small != null)
            {
                Rectangle lineShadow = line;
                lineShadow.Offset(1, 1);
                TextRenderer.DrawText(g, second, small, lineShadow, Color.FromArgb(8, 6, 4), flags);
                TextRenderer.DrawText(g, second, small, line, button.Enabled ? StoneText : Color.FromArgb(128, 122, 108), flags);
                small.Dispose();
            }
        }

        // --- Sections, cards and frames --------------------------------------------------

        // A section's title in gold over a thin rule to its right.
        static Label Section(Control parent, string text, int x, int y, int width)
        {
            Label title = new Label();
            title.Text = text;
            title.UseMnemonic = false;
            title.AutoSize = true;
            title.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            title.ForeColor = Gold;
            title.BackColor = Color.Transparent;
            title.Location = new Point(x - 1, y);
            parent.Controls.Add(title);
            int start = x + TextRenderer.MeasureText(text, title.Font).Width + 4;
            Panel rule = new Panel();
            rule.Location = new Point(start, y + 10);
            rule.Size = new Size(Math.Max(0, x + width - start), 1);
            rule.BackColor = RuleColor;
            parent.Controls.Add(rule);
            return title;
        }

        // A number's card (Play's strip, Statistics): the pack's dark card,
        // its words over it.
        void Card(Panel card)
        {
            typeof(Control).GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(card, true, null);
            card.BackColor = Color.FromArgb(12, 12, 12);
            card.Paint += delegate (object sender, PaintEventArgs e)
            {
                Slice9(e.Graphics, Art("card"), card.ClientRectangle, 8, 8, 8, 8, ui, true);
            };
            foreach (Control child in card.Controls) child.BackColor = Color.Transparent;
        }

        // The controls a page frames: a list, a box of text, a chart, each in
        // the pack's inner frame drawn round it by its page; a drop-down or a
        // field in the small card's rim.
        readonly List<KeyValuePair<Control, string>> framed = new List<KeyValuePair<Control, string>>();

        void Frame(Control control, string kind)
        {
            framed.Add(new KeyValuePair<Control, string>(control, kind));
            control.BackColor = kind == "inset" ? InsetBody : Color.FromArgb(12, 12, 12);
            TextBox box = control as TextBox;
            if (box != null) box.BorderStyle = BorderStyle.None;
            ListView list = control as ListView;
            if (list != null) list.BorderStyle = BorderStyle.None;
        }

        static readonly Color InsetBody = Color.FromArgb(19, 19, 18);

        void PaintFrames(Control page, Graphics g)
        {
            foreach (KeyValuePair<Control, string> pair in framed)
            {
                Control control = pair.Key;
                if (control.Parent != page || !control.Visible) continue;
                if (pair.Value == "inset")
                {
                    Rectangle around = Rectangle.Inflate(control.Bounds, S(7), S(7));
                    SliceFrame(g, Art("inset"), around, 12, 12, 12, 14, 86, ui * 0.6f, false);
                }
                else
                {
                    Rectangle around = Rectangle.Inflate(control.Bounds, S(4), S(4));
                    Slice9(g, Art("card"), around, 8, 8, 8, 8, ui, true);
                }
            }
        }

        // --- The window ------------------------------------------------------------------

        // A stone face: a dark warm grey, blotches of three sizes laid soft over
        // it, a few hairline cracks, a shade toward its foot. The same stone
        // every time (one seed).
        static Bitmap Stone(int width, int height)
        {
            width = Math.Max(1, width);
            height = Math.Max(1, height);
            Bitmap stone = new Bitmap(width, height);
            Random random = new Random(1137);
            using (Graphics g = Graphics.FromImage(stone))
            {
                g.Clear(Color.FromArgb(34, 33, 30));
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                int[] cells = { 44, 15, 5 };
                int[] alphas = { 40, 28, 18 };
                for (int layer = 0; layer < cells.Length; layer++)
                {
                    int cell = cells[layer];
                    int w = width / cell + 3, h = height / cell + 3;
                    using (Bitmap noise = new Bitmap(w, h))
                    {
                        for (int x = 0; x < w; x++)
                            for (int y = 0; y < h; y++)
                            {
                                int v = random.Next(256);
                                noise.SetPixel(x, y, Color.FromArgb(alphas[layer], v, v * 95 / 100, v * 84 / 100));
                            }
                        g.DrawImage(noise, new Rectangle(-cell, -cell, w * cell, h * cell));
                    }
                }
                g.SmoothingMode = SmoothingMode.AntiAlias;
                using (Pen crack = new Pen(Color.FromArgb(56, 0, 0, 0), 1f))
                    for (int i = 0; i < width / 160; i++)
                    {
                        float x = random.Next(width), y = random.Next(height);
                        PointF[] line = new PointF[5];
                        for (int k = 0; k < line.Length; k++)
                        {
                            line[k] = new PointF(x, y);
                            x += random.Next(8, 24);
                            y += random.Next(-6, 7);
                        }
                        g.DrawLines(crack, line);
                    }
                using (LinearGradientBrush shade = new LinearGradientBrush(new Rectangle(0, -1, width, height + 2),
                    Color.FromArgb(20, 255, 236, 210), Color.FromArgb(150, 0, 0, 0), LinearGradientMode.Vertical))
                    g.FillRectangle(shade, 0, 0, width, height);
            }
            return stone;
        }

        // A thin rule across, the pack's bronze; light over dark.
        void PaintRule(Graphics g, int y, int left, int right)
        {
            int unit = Math.Max(1, S(1));
            using (Brush light = new SolidBrush(Color.FromArgb(120, 104, 70))) g.FillRectangle(light, left, y, right - left, unit);
            using (Brush dark = new SolidBrush(Color.FromArgb(6, 6, 6))) g.FillRectangle(dark, left, y + unit, right - left, unit);
        }

        // The window's frame, the pack's panel rim with its corner pieces, in
        // window pixels: drawn by the window, and by each page for its sides.
        void PaintFrame(Graphics g, Rectangle window)
        {
            SliceFrame(g, Art("frame"), window, 12, 12, 12, 14, 90, ui, false);
        }

        // The window's own face: the stone header, the title on its plaque,
        // the rule under the header and over the status line, the frame.
        void PaintWindow(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            int width = ClientSize.Width, head = S(84);
            if (headerStone == null || headerStone.Width != width || headerStone.Height != head)
            {
                if (headerStone != null) headerStone.Dispose();
                headerStone = Stone(width, head);
            }
            g.DrawImageUnscaled(headerStone, 0, 0);
            Bitmap plaque = Art("plaque");
            if (plaque != null) Slice3(g, plaque, new Rectangle(S(60), S(2), S(336), S(60)), 44, 44);
            PaintTitle(g);
            PaintRule(g, head, S(8), width - S(8));
            PaintRule(g, S(PageTop + PageHeight + 1), S(14), width - S(14));
            PaintFrame(g, ClientRectangle);
        }

        // The title in Cinzel Decorative on the plaque: gold, lighter at the
        // top, a dark edge and a shadow under it.
        void PaintTitle(Graphics g)
        {
            FontFamily family = TitleFamily();
            using (GraphicsPath path = new GraphicsPath())
            {
                path.AddString("Azeroth SurvivorUI Launcher", family, (int)TitleStyle(family), SF(19f), PointF.Empty,
                    StringFormat.GenericTypographic);
                // Fitted inside the plaque's dark middle (its spiked ends left
                // clear), centred in it.
                RectangleF size = path.GetBounds();
                RectangleF room = new RectangleF(SF(60 + 50), SF(2 + 16), SF(336 - 104), SF(60 - 32));
                float fit = Math.Min(1f, Math.Min(room.Width / size.Width, room.Height / size.Height));
                using (Matrix place = new Matrix())
                {
                    place.Translate(room.X + (room.Width - size.Width * fit) / 2, room.Y + (room.Height - size.Height * fit) / 2);
                    place.Scale(fit, fit);
                    place.Translate(-size.X, -size.Y);
                    path.Transform(place);
                }
                g.SmoothingMode = SmoothingMode.AntiAlias;
                using (GraphicsPath shadow = (GraphicsPath)path.Clone())
                using (Matrix drop = new Matrix())
                {
                    drop.Translate(SF(1.2f), SF(1.6f));
                    shadow.Transform(drop);
                    using (Brush dark = new SolidBrush(Color.FromArgb(220, 0, 0, 0))) g.FillPath(dark, shadow);
                }
                RectangleF bounds = path.GetBounds();
                using (LinearGradientBrush gold = new LinearGradientBrush(new RectangleF(bounds.X, bounds.Y - 1, bounds.Width, bounds.Height + 2),
                    Color.FromArgb(255, 242, 170), Color.FromArgb(206, 136, 14), LinearGradientMode.Vertical))
                    g.FillPath(gold, path);
                using (Pen edge = new Pen(Color.FromArgb(64, 36, 4), SF(0.6f))) g.DrawPath(edge, path);
                g.SmoothingMode = SmoothingMode.None;
            }
        }

        // No Windows border: the window is the pack's panel. Its header moves
        // it; minimize and close are the pack's own, at the top right; it
        // keeps a shadow, its taskbar button and its menu there.
        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams parameters = base.CreateParams;
                parameters.ClassStyle |= 0x20000;                       // CS_DROPSHADOW
                parameters.Style |= 0x00020000 | 0x00080000;            // WS_MINIMIZEBOX, WS_SYSMENU
                return parameters;
            }
        }

        bool HeaderHit(Point screen)
        {
            Point inside = PointToClient(screen);
            return inside.Y >= 0 && inside.Y < S(84);
        }

        void BuildWindowButtons()
        {
            Button close = new Button();
            Button minimize = new Button();
            foreach (Button button in new Button[] { minimize, close })
            {
                button.FlatStyle = FlatStyle.Flat;
                button.FlatAppearance.BorderSize = 0;
                button.FlatAppearance.MouseOverBackColor = Color.Transparent;
                button.FlatAppearance.MouseDownBackColor = Color.Transparent;
                button.BackColor = Color.Transparent;
                button.Cursor = Cursors.Hand;
                button.TabStop = false;
                button.Size = new Size(20, 20);
                bool hot = false;
                Button self = button;
                string piece = button == close ? "close" : "minimize";
                button.MouseEnter += delegate { hot = true; self.Invalidate(); };
                button.MouseLeave += delegate { hot = false; self.Invalidate(); };
                button.Paint += delegate (object sender, PaintEventArgs e)
                {
                    ButtonRenderer.DrawParentBackground(e.Graphics, self.ClientRectangle, self);
                    DrawArt(e.Graphics, ArtAs(piece, hot ? "hot" : null), self.ClientRectangle);
                };
                Controls.Add(button);
                button.BringToFront();
            }
            close.Location = new Point(733, 7);
            minimize.Location = new Point(710, 7);
            tips.SetToolTip(close, "Close: the launcher waits in the tray (right click its icon, Exit, to quit it).");
            tips.SetToolTip(minimize, "Minimize");
            close.Click += delegate { Close(); };
            minimize.Click += delegate { WindowState = FormWindowState.Minimized; };
        }

        // --- A coffee ---------------------------------------------------------------

        // In the header, a cup always gently steaming (faster under the mouse)
        // on the pack's stone plate: the Ko-fi, for whoever likes what
        // Survivor UI does. Its tooltip says what the launcher has seen them
        // play with it so far.
        const string KoFi = "https://ko-fi.com/morderous";
        static readonly Font CoffeeBig = new Font("Segoe UI", 9.5f, FontStyle.Bold);
        static readonly Font CoffeeSmall = new Font("Segoe UI", 7.5f);
        readonly Canvas coffee = new Canvas();
        readonly System.Windows.Forms.Timer steam = new System.Windows.Forms.Timer();
        float steamPhase;
        bool coffeeHot;

        void BuildCoffee()
        {
            coffee.Location = new Point(398, 14);
            coffee.Size = new Size(180, 50);
            coffee.BackColor = Color.Transparent;
            coffee.Cursor = Cursors.Hand;
            coffee.Paint += PaintCoffee;
            coffee.MouseEnter += delegate
            {
                coffeeHot = true;
                tips.SetToolTip(coffee, CoffeeWords());
                coffee.Invalidate();
            };
            coffee.MouseLeave += delegate { coffeeHot = false; coffee.Invalidate(); };
            coffee.Click += delegate
            {
                Open(KoFi);
                Status("Thank you! Ko-fi is open in your browser.");
            };
            Controls.Add(coffee);
            steam.Interval = 70;
            steam.Tick += delegate
            {
                if (!Visible || WindowState == FormWindowState.Minimized) return;
                steamPhase += coffeeHot ? 0.22f : 0.07f;
                coffee.Invalidate();
            };
            steam.Start();
        }

        string CoffeeWords()
        {
            int seconds = 0;
            foreach (KeyValuePair<DateTime, int> session in Sessions()) seconds += session.Value;
            if (sessionStart != DateTime.MinValue) seconds += (int)(DateTime.Now - sessionStart).TotalSeconds;
            SaveStats stats = shownStats ?? ReadSaveStats();
            long played = stats != null ? stats.Total("runs") : 0;
            string so = seconds >= 60 && played > 0 ? Hours(seconds) + " of play and " + Count(played) + " runs so far.\n"
                : played > 0 ? Count(played) + " runs so far.\n" : "";
            return so + "Survivor UI, Survivor Plates and this launcher are free, made in my spare time.\n" +
                "If they made your runs better, a coffee on Ko-fi says thanks and keeps them coming.\n" +
                "Thank you!  morderous";
        }

        void PaintCoffee(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            int w = W(coffee), h = H(coffee);
            // The plate: the pack's stone, lit under the mouse.
            Bitmap plate = ArtAs("button-stone", coffeeHot ? "hot" : null);
            if (plate != null) Slice3(g, plate, coffee.ClientRectangle, 22, 20);
            g.ScaleTransform(ui, ui);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            // The cup, a little smaller, clear of the plate's ends.
            System.Drawing.Drawing2D.GraphicsState plain = g.Save();
            g.TranslateTransform(17f, 7f);
            g.ScaleTransform(0.74f, 0.74f);
            // The saucer, the handle, the cup, the coffee in it.
            using (Brush saucer = new SolidBrush(Color.FromArgb(206, 196, 178))) g.FillEllipse(saucer, 10, 37, 34, 7);
            using (Pen handle = new Pen(Color.FromArgb(232, 224, 208), 3f)) g.DrawArc(handle, 33, 22, 11, 11, -80, 200);
            using (GraphicsPath cup = new GraphicsPath())
            {
                cup.AddLine(14, 19, 38, 19);
                cup.AddBezier(38, 19, 38, 31, 35, 39, 26, 39);
                cup.AddBezier(26, 39, 17, 39, 14, 31, 14, 19);
                using (LinearGradientBrush china = new LinearGradientBrush(new Rectangle(13, 19, 27, 21),
                    Color.FromArgb(252, 246, 234), Color.FromArgb(190, 178, 158), LinearGradientMode.Horizontal))
                    g.FillPath(china, cup);
            }
            using (Brush brew = new SolidBrush(Color.FromArgb(96, 54, 24))) g.FillEllipse(brew, 15, 17, 22, 5);
            // Three wisps of steam rising and swaying.
            for (int i = 0; i < 3; i++)
            {
                PointF[] wisp = new PointF[6];
                for (int k = 0; k < wisp.Length; k++)
                    wisp[k] = new PointF(20 + i * 6 + (float)Math.Sin(k * 0.9f - steamPhase - i * 2.1f) * 2.2f, 15 - k * 2.4f);
                using (Pen air = new Pen(Color.FromArgb(coffeeHot ? 170 : 115, 255, 255, 255), 1.4f)) g.DrawCurve(air, wisp);
            }
            g.Restore(plain);
            g.SmoothingMode = SmoothingMode.None;
            Txt(g, "Buy me a coffee", CoffeeBig, new Rectangle(53, 9, w - 74, 20), coffeeHot ? Color.FromArgb(255, 232, 140) : Gold, TextOnly);
            Txt(g, "if you like my work", CoffeeSmall, new Rectangle(54, 28, w - 74, 14), StoneText, TextOnly);
        }

        // The pages dressed: the secondary buttons in stone (the actions stay
        // red), the lists, boxes and charts in the pack's inner frame, the
        // drop-downs and the folder's field in its card rim.
        void SkinPages()
        {
            foreach (Button button in new Button[] { gameCheckButton, browseButton, foldersButton, betaButton, restoreButton })
                Wear(button, "stone");
            foreach (Control control in new Control[] { gameNews, notesBox, backupList, runList, runDetail, playChart, achList, classGrid })
                Frame(control, "inset");
            Frame(folderBox, "card");
            foreach (ComboBox box in new ComboBox[] { destBox, keepBox, runClass, runResult })
                Picker(box);
        }

        // A drop-down as the pack would draw it: its stone field, the line
        // picked, its arrow, lit under the mouse. A click opens the drop-down's
        // own list; the drop-down itself stays under the picker, out of sight.
        void Picker(ComboBox box)
        {
            Canvas picker = new Canvas();
            picker.Location = new Point(box.Left, box.Top - 1);
            picker.Size = new Size(box.Width, 26);
            picker.BackColor = Color.Transparent;
            picker.Cursor = Cursors.Hand;
            bool hot = false;
            picker.MouseEnter += delegate { hot = true; picker.Invalidate(); };
            picker.MouseLeave += delegate { hot = false; picker.Invalidate(); };
            picker.Click += delegate
            {
                box.Focus();
                box.DroppedDown = true;
            };
            box.SelectedIndexChanged += delegate { picker.Invalidate(); };
            box.DropDownClosed += delegate { picker.Invalidate(); };
            picker.Paint += delegate (object sender, PaintEventArgs e)
            {
                Graphics g = e.Graphics;
                Rectangle r = picker.ClientRectangle;
                Slice3(g, ArtAs("field", hot ? "hot" : null), r, 20, 20);
                int arrow = r.Height - S(8);
                DrawArt(g, ArtAs("arrow-down", hot ? "hot" : null), new Rectangle(r.Right - arrow - S(7), (r.Height - arrow) / 2, arrow, arrow));
                string text = box.SelectedItem != null ? box.SelectedItem.ToString() : "";
                Rectangle words = new Rectangle(r.X + S(11), r.Y, Math.Max(0, r.Width - arrow - S(24)), r.Height);
                Rectangle shadow = words;
                shadow.Offset(1, 1);
                TextFormatFlags flags = TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix;
                TextRenderer.DrawText(g, text, box.Font, shadow, Color.FromArgb(8, 6, 4), flags);
                TextRenderer.DrawText(g, text, box.Font, words, hot ? Color.FromArgb(255, 244, 210) : StoneText, flags);
            };
            box.Parent.Controls.Add(picker);
            picker.BringToFront();
        }

        // --- Boxes, tips and scroll bars in the pack's art ----------------------------

        // A message in the pack's frame, in place of Windows' own box: its
        // title in gold on stone, a gem for its kind (red a warning or an
        // error, green a question, blue a note), the words, and its buttons
        // (the first red, the rest stone). Enter takes the first, Escape the
        // last; the stone at its top moves it.
        DialogResult Ask(IWin32Window owner, string text, string caption, MessageBoxButtons buttons, MessageBoxIcon icon)
        {
            if (InvokeRequired)
                return (DialogResult)Invoke(new Func<DialogResult>(delegate { return Ask(owner, text, caption, buttons, icon); }));
            using (ArtBox box = new ArtBox(this, text, caption, buttons, icon))
            {
                if (!Visible)
                {
                    box.ShowInTaskbar = true;
                    box.StartPosition = FormStartPosition.CenterScreen;
                    return box.ShowDialog();
                }
                return box.ShowDialog(this);
            }
        }

        class ArtBox : Form
        {
            readonly float k;
            readonly string words, title, gem;
            readonly Rectangle wordsAt, gemAt;
            readonly int band;
            Bitmap stone;

            public ArtBox(MainForm owner, string text, string caption, MessageBoxButtons buttons, MessageBoxIcon icon)
            {
                k = owner.ui;
                words = text ?? "";
                title = caption ?? "";
                gem = icon == MessageBoxIcon.Error || icon == MessageBoxIcon.Warning ? "gem-red"
                    : icon == MessageBoxIcon.Question ? "gem-green" : "gem-blue";
                FormBorderStyle = FormBorderStyle.None;
                StartPosition = FormStartPosition.CenterParent;
                ShowInTaskbar = false;
                BackColor = Back;
                ForeColor = TextColor;
                Font = new Font("Segoe UI", 9.5f * k);
                DoubleBuffered = true;
                Text = title;
                if (owner.Icon != null) Icon = owner.Icon;
                int width = (int)(480 * k), pad = (int)(24 * k), gemSize = (int)(30 * k), gap = (int)(14 * k);
                band = (int)(44 * k);
                int textWidth = width - 2 * pad - gemSize - gap;
                Size measured = TextRenderer.MeasureText(words, Font, new Size(textWidth, int.MaxValue),
                    TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
                int top = band + (int)(20 * k);
                gemAt = new Rectangle(pad, top, gemSize, (int)(gemSize * 52f / 47f));
                wordsAt = new Rectangle(pad + gemSize + gap, top, textWidth, measured.Height + 4);
                int buttonsTop = top + Math.Max(measured.Height, gemAt.Height) + (int)(22 * k);
                int buttonHeight = (int)(32 * k);
                ClientSize = new Size(width, buttonsTop + buttonHeight + (int)(22 * k));

                List<KeyValuePair<string, DialogResult>> choices = new List<KeyValuePair<string, DialogResult>>();
                if (buttons == MessageBoxButtons.YesNo || buttons == MessageBoxButtons.YesNoCancel)
                {
                    choices.Add(new KeyValuePair<string, DialogResult>("Yes", DialogResult.Yes));
                    choices.Add(new KeyValuePair<string, DialogResult>("No", DialogResult.No));
                }
                else choices.Add(new KeyValuePair<string, DialogResult>("OK", DialogResult.OK));
                if (buttons == MessageBoxButtons.YesNoCancel || buttons == MessageBoxButtons.OKCancel)
                    choices.Add(new KeyValuePair<string, DialogResult>("Cancel", DialogResult.Cancel));
                int buttonWidth = (int)(112 * k), between = (int)(10 * k);
                int x = width - pad - choices.Count * buttonWidth - (choices.Count - 1) * between;
                Button first = null, last = null;
                for (int i = 0; i < choices.Count; i++)
                {
                    Button button = new Button();
                    Style(button, choices[i].Key);
                    button.Font = new Font("Segoe UI", 9.5f * k, FontStyle.Bold);
                    button.Bounds = new Rectangle(x, buttonsTop, buttonWidth, buttonHeight);
                    button.DialogResult = choices[i].Value;
                    if (i > 0) Wear(button, "stone");
                    Controls.Add(button);
                    if (first == null) first = button;
                    last = button;
                    x += buttonWidth + between;
                }
                AcceptButton = first;
                CancelButton = last;
                Paint += delegate (object sender, PaintEventArgs e) { PaintBox(e.Graphics, owner); };
            }

            protected override CreateParams CreateParams
            {
                get
                {
                    CreateParams parameters = base.CreateParams;
                    parameters.ClassStyle |= 0x20000;       // CS_DROPSHADOW
                    return parameters;
                }
            }

            protected override void WndProc(ref Message m)
            {
                base.WndProc(ref m);
                if (m.Msg == 0x84 && m.Result == (IntPtr)1)
                {
                    long at = m.LParam.ToInt64();
                    Point inside = PointToClient(new Point((short)(at & 0xFFFF), (short)((at >> 16) & 0xFFFF)));
                    if (inside.Y < band) m.Result = (IntPtr)2;
                }
            }

            void PaintBox(Graphics g, MainForm owner)
            {
                g.Clear(Back);
                if (stone == null) stone = Stone(ClientSize.Width, band);
                g.DrawImageUnscaled(stone, 0, 0);
                using (Font head = new Font("Segoe UI", 10.5f * k, FontStyle.Bold))
                {
                    Rectangle titleAt = new Rectangle((int)(22 * k), 0, ClientSize.Width - (int)(44 * k), band);
                    TextFormatFlags flags = TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis;
                    Rectangle shadow = titleAt;
                    shadow.Offset(1, 1);
                    TextRenderer.DrawText(g, title, head, shadow, Color.FromArgb(4, 4, 4), flags);
                    TextRenderer.DrawText(g, title, head, titleAt, Gold, flags);
                }
                int unit = Math.Max(1, (int)Math.Round(k));
                using (Brush light = new SolidBrush(Color.FromArgb(120, 104, 70))) g.FillRectangle(light, 0, band, ClientSize.Width, unit);
                using (Brush dark = new SolidBrush(Color.FromArgb(6, 6, 6))) g.FillRectangle(dark, 0, band + unit, ClientSize.Width, unit);
                DrawArt(g, Art(gem), gemAt);
                TextRenderer.DrawText(g, words, Font, wordsAt, Color.FromArgb(226, 220, 204),
                    TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.Left | TextFormatFlags.Top);
                SliceFrame(g, Art("frame"), ClientRectangle, 12, 12, 12, 14, 90, k * 0.9f, false);
            }

            protected override void Dispose(bool disposing)
            {
                if (disposing && stone != null) stone.Dispose();
                base.Dispose(disposing);
            }
        }

        // The tooltips on the pack's dark card, in its parchment words.
        Font tipFont;

        void SkinTips(ToolTip tip)
        {
            tip.OwnerDraw = true;
            tip.Popup += delegate (object sender, PopupEventArgs e)
            {
                if (tipFont == null) tipFont = new Font("Segoe UI", 9f * ui);
                string text = tip.GetToolTip(e.AssociatedControl);
                Size size = TextRenderer.MeasureText(text, tipFont, new Size(S(440), int.MaxValue), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
                e.ToolTipSize = new Size(size.Width + S(24), size.Height + S(18));
            };
            tip.Draw += delegate (object sender, DrawToolTipEventArgs e)
            {
                Graphics g = e.Graphics;
                using (Brush back = new SolidBrush(Color.FromArgb(12, 12, 12))) g.FillRectangle(back, e.Bounds);
                Slice9(g, Art("card"), e.Bounds, 8, 8, 8, 8, ui, true);
                if (tipFont == null) tipFont = new Font("Segoe UI", 9f * ui);
                TextRenderer.DrawText(g, e.ToolTipText, tipFont, Rectangle.Inflate(e.Bounds, -S(12), -S(9)), Color.FromArgb(230, 220, 196),
                    TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.Left | TextFormatFlags.Top);
            };
        }

        // A scroll bar in the pack's art laid over a list's or a box's own:
        // it follows it (a look every tenth of a second) and drives it, the
        // thumb dragged, the track clicked a page at a time, the wheel passed
        // on. Out of sight while there is nothing to scroll.
        internal class ArtScroll : Control
        {
            readonly MainForm owner;
            readonly Control target;
            readonly System.Windows.Forms.Timer look = new System.Windows.Forms.Timer();
            Native.ScrollInfo info;
            bool hot, dragging;
            int dragFrom, posFrom;

            public ArtScroll(MainForm owner, Control target)
            {
                this.owner = owner;
                this.target = target;
                SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
                SetStyle(ControlStyles.Selectable, false);
                BackColor = Color.FromArgb(14, 14, 13);
                Cursor = Cursors.Hand;
                Place();
                target.Parent.Controls.Add(this);
                BringToFront();
                target.LocationChanged += delegate { Place(); };
                target.SizeChanged += delegate { Place(); };
                target.VisibleChanged += delegate { Look(); };
                look.Interval = 100;
                look.Tick += delegate { Look(); };
                look.Start();
                Look();
            }

            void Place()
            {
                int width = SystemInformation.VerticalScrollBarWidth;
                Bounds = new Rectangle(target.Right - width, target.Top, width, target.Height);
            }

            bool Read(out Native.ScrollInfo read)
            {
                read = new Native.ScrollInfo();
                read.cbSize = Marshal.SizeOf(typeof(Native.ScrollInfo));
                read.fMask = 0x17;      // SIF_ALL
                return target.IsHandleCreated && Native.GetScrollInfo(target.Handle, 1, ref read);
            }

            void Look()
            {
                Native.ScrollInfo now;
                bool scrolls = Read(out now) && now.nPage > 0 && now.nMax - now.nMin + 1 > now.nPage;
                bool show = target.Visible && scrolls;
                if (show != Visible) Visible = show;
                if (now.nPos != info.nPos || now.nMax != info.nMax || now.nPage != info.nPage)
                {
                    info = now;
                    Invalidate();
                }
            }

            int Cap
            {
                get { return (int)Math.Round(Width * 30f / 50f); }
            }

            Rectangle Thumb()
            {
                int range = info.nMax - info.nMin + 1;
                int trackTop = Cap, track = Math.Max(1, Height - 2 * Cap);
                if (range <= 0 || info.nPage <= 0) return new Rectangle(0, trackTop, Width, track);
                int length = Math.Max((int)(Width * 1.4f), (int)((long)track * info.nPage / range));
                length = Math.Min(length, track);
                int span = Math.Max(1, range - info.nPage);
                int top = trackTop + (int)((long)(track - length) * (info.nPos - info.nMin) / span);
                return new Rectangle(0, top, Width, length);
            }

            protected override void OnPaint(PaintEventArgs e)
            {
                Graphics g = e.Graphics;
                g.Clear(BackColor);
                Bitmap track = Art("scroll-track-v");
                if (track != null) Slice9(g, track, ClientRectangle, 0, 30, 0, 30, (float)Width / track.Width, true);
                Bitmap thumb = ArtAs("scroll-thumb", hot || dragging ? "hot" : null);
                Rectangle at = Thumb();
                at.Inflate(-Math.Max(1, Width / 8), 0);
                if (thumb != null) Slice9(g, thumb, at, 0, 12, 0, 12, (float)at.Width / thumb.Width, true);
            }

            void ScrollTo(int position)
            {
                position = Math.Max(info.nMin, Math.Min(info.nMax - info.nPage + 1, position));
                ListView list = target as ListView;
                if (list != null)
                {
                    int row = list.Items.Count > 0 ? list.GetItemRect(0).Height : 1;
                    Native.Send(target.Handle, 0x1000 + 20, IntPtr.Zero, (IntPtr)((position - info.nPos) * row));     // LVM_SCROLL
                }
                else
                {
                    Native.Send(target.Handle, 0x115, (IntPtr)(4 | (position << 16)), IntPtr.Zero);                  // WM_VSCROLL, SB_THUMBPOSITION
                    Native.Send(target.Handle, 0x115, (IntPtr)8, IntPtr.Zero);                                       // SB_ENDSCROLL
                }
                Look();
            }

            void Step(int code)
            {
                Native.Send(target.Handle, 0x115, (IntPtr)code, IntPtr.Zero);
                Native.Send(target.Handle, 0x115, (IntPtr)8, IntPtr.Zero);
                Look();
            }

            protected override void OnMouseDown(MouseEventArgs e)
            {
                if (e.Button != MouseButtons.Left) return;
                Rectangle thumb = Thumb();
                if (thumb.Contains(e.Location))
                {
                    dragging = true;
                    dragFrom = e.Y;
                    posFrom = info.nPos;
                    Capture = true;
                }
                else if (e.Y < Cap) Step(0);                // SB_LINEUP
                else if (e.Y > Height - Cap) Step(1);       // SB_LINEDOWN
                else Step(e.Y < thumb.Top ? 2 : 3);         // SB_PAGEUP, SB_PAGEDOWN
                Invalidate();
            }

            protected override void OnMouseMove(MouseEventArgs e)
            {
                if (!dragging) return;
                Rectangle thumb = Thumb();
                int track = Math.Max(1, Height - 2 * Cap - thumb.Height);
                int span = Math.Max(1, info.nMax - info.nMin + 1 - info.nPage);
                ScrollTo(posFrom + (int)Math.Round((double)(e.Y - dragFrom) * span / track));
            }

            protected override void OnMouseUp(MouseEventArgs e)
            {
                dragging = false;
                Capture = false;
                Invalidate();
            }

            protected override void OnMouseEnter(EventArgs e)
            {
                hot = true;
                Invalidate();
            }

            protected override void OnMouseLeave(EventArgs e)
            {
                hot = false;
                Invalidate();
            }

            protected override void OnMouseWheel(MouseEventArgs e)
            {
                int lines = Math.Max(1, Math.Abs(e.Delta) / 120 * SystemInformation.MouseWheelScrollLines);
                for (int i = 0; i < lines; i++) Native.Send(target.Handle, 0x115, (IntPtr)(e.Delta > 0 ? 0 : 1), IntPtr.Zero);
                Native.Send(target.Handle, 0x115, (IntPtr)8, IntPtr.Zero);
                Look();
            }

            protected override void Dispose(bool disposing)
            {
                if (disposing) look.Dispose();
                base.Dispose(disposing);
            }
        }

        // --- Updates waiting -------------------------------------------------------

        // What waits, each with where a click takes you: the launcher's own
        // update (it updates itself), Survivor UI's (its tab, Install), the
        // game's (Play, Update game). Looked at every second; the checks
        // themselves run as the launcher opens, every half hour and at Check
        // for updates.
        readonly Canvas alertPill = new Canvas();
        readonly System.Windows.Forms.Timer alertWatch = new System.Windows.Forms.Timer();
        List<KeyValuePair<string, Action>> alerts = new List<KeyValuePair<string, Action>>();
        string alertsSeen = "";
        float alertBreath;
        bool alertHot;

        List<KeyValuePair<string, Action>> Alerts()
        {
            List<KeyValuePair<string, Action>> waiting = new List<KeyValuePair<string, Action>>();
            if (selfRelease != null && !selfUpdating)
                waiting.Add(new KeyValuePair<string, Action>("Launcher " + Short(selfRelease.InstallerVersion), delegate { UpdateSelf(); }));
            if (updateWaiting && latest != null)
                waiting.Add(new KeyValuePair<string, Action>("Survivor UI " + latest.Tag, delegate { ShowTab(1); }));
            if (!GameMissing() && GameBehind() && game != null)
                waiting.Add(new KeyValuePair<string, Action>("Game " + game.Latest, delegate { ShowTab(0); }));
            return waiting;
        }

        void BuildAlert()
        {
            // Made once the window is scaled: its place and size scaled here.
            alertPill.Location = new Point(S(538), S(89));
            alertPill.Size = new Size(S(206), S(28));
            alertPill.BackColor = Color.Transparent;
            alertPill.Cursor = Cursors.Hand;
            alertPill.Visible = false;
            alertPill.Paint += PaintAlert;
            alertPill.MouseEnter += delegate { alertHot = true; alertPill.Invalidate(); };
            alertPill.MouseLeave += delegate { alertHot = false; alertPill.Invalidate(); };
            alertPill.Click += delegate
            {
                if (alerts.Count > 0) alerts[0].Value();
            };
            Controls.Add(alertPill);
            alertPill.BringToFront();
            alertWatch.Interval = 80;
            int tick = 0;
            alertWatch.Tick += delegate
            {
                if (++tick >= 12)
                {
                    tick = 0;
                    alerts = Alerts();
                    string now = "";
                    foreach (KeyValuePair<string, Action> alert in alerts) now += alert.Key + "\n";
                    if (now != alertsSeen)
                    {
                        alertsSeen = now;
                        alertPill.Visible = alerts.Count > 0;
                        tips.SetToolTip(alertPill, alerts.Count == 0 ? "" : "Waiting:\n" + now.TrimEnd('\n') +
                            "\n\nA click takes you to the first. The launcher looks as it opens, every half hour and at Check for updates.");
                        foreach (Button tab in tabButtons) tab.Invalidate();
                    }
                }
                if (alertPill.Visible && Visible && WindowState != FormWindowState.Minimized)
                {
                    alertBreath += 0.1f;
                    alertPill.Invalidate();
                }
            };
            alertWatch.Start();
        }

        // The pill: the pack's stone, washed green and breathing, an arrow
        // and what waits ("2 updates waiting" for more than one).
        void PaintAlert(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Rectangle r = alertPill.ClientRectangle;
            Slice3(g, ArtAs("button-stone", alertHot ? "hot" : null), r, 22, 20);
            float glow = (float)(Math.Sin(alertBreath) + 1) / 2;
            Rectangle inner = Rectangle.Inflate(r, -S(4), -S(4));
            using (Brush wash = new SolidBrush(Color.FromArgb(70 + (int)(90 * glow), 46, 190, 80))) g.FillRectangle(wash, inner);
            using (Pen edge = new Pen(Color.FromArgb(120 + (int)(120 * glow), 150, 255, 160))) g.DrawRectangle(edge, inner.X, inner.Y, inner.Width - 1, inner.Height - 1);
            string words = alerts.Count == 0 ? "" : alerts.Count == 1 ? "\u2191  " + alerts[0].Key + " is out" : "\u2191  " + alerts.Count + " updates waiting";
            TextFormatFlags flags = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis;
            using (Font font = new Font("Segoe UI", SF(8.5f), FontStyle.Bold))
            {
                Rectangle shadow = inner;
                shadow.Offset(1, 1);
                TextRenderer.DrawText(g, words, font, shadow, Color.FromArgb(4, 20, 6), flags);
                TextRenderer.DrawText(g, words, font, inner, Color.White, flags);
            }
        }

        // --- The tabs -----------------------------------------------------------

        // The tabs as the pack's plates: stone, lit under the mouse; the open
        // one red with gold words.
        void SkinTabs()
        {
            foreach (Button tab in tabButtons)
            {
                Button self = tab;
                bool hot = false;
                typeof(Control).GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(tab, true, null);
                tab.MouseEnter += delegate { hot = true; self.Invalidate(); };
                tab.MouseLeave += delegate { hot = false; self.Invalidate(); };
                tab.Paint += delegate (object sender, PaintEventArgs e)
                {
                    Graphics g = e.Graphics;
                    Rectangle r = self.ClientRectangle;
                    bool open = tabButtons.IndexOf(self) == currentTab;
                    ButtonRenderer.DrawParentBackground(g, r, self);
                    if (open) Slice3(g, ArtAs("button-red", hot ? "hot" : null), r, 31, 31);
                    else Slice3(g, ArtAs("button-stone", hot ? "hot" : null), r, 22, 20);
                    TextFormatFlags flags = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine;
                    Rectangle shadow = r;
                    shadow.Offset(1, 1);
                    TextRenderer.DrawText(g, self.Text, self.Font, shadow, Color.FromArgb(8, 6, 4), flags);
                    TextRenderer.DrawText(g, self.Text, self.Font, r, open ? Gold : hot ? Color.FromArgb(252, 240, 200) : StoneText, flags);
                    int index = tabButtons.IndexOf(self);
                    bool waits = false;
                    foreach (KeyValuePair<string, Action> alert in alerts)
                        waits = waits || (index == 1 && alert.Key.StartsWith("Survivor UI")) || (index == 0 && alert.Key.StartsWith("Game"));
                    if (waits)
                    {
                        int dot = S(8);
                        Rectangle at = new Rectangle(r.Right - dot - S(5), r.Top + S(4), dot, dot);
                        g.SmoothingMode = SmoothingMode.AntiAlias;
                        using (Brush green = new SolidBrush(Color.FromArgb(80, 230, 110))) g.FillEllipse(green, at);
                        using (Pen rim = new Pen(Color.FromArgb(10, 40, 14))) g.DrawEllipse(rim, at);
                        g.SmoothingMode = SmoothingMode.None;
                    }
                };
            }
        }

        Panel NewPage()
        {
            Panel page = new Panel();
            page.Location = new Point(0, PageTop);
            page.Size = new Size(ClientSize.Width, PageHeight);
            page.BackColor = Back;
            page.Visible = false;
            page.Paint += delegate (object sender, PaintEventArgs e)
            {
                PaintFrames(page, e.Graphics);
                e.Graphics.TranslateTransform(-page.Left, -page.Top);
                PaintFrame(e.Graphics, ClientRectangle);
            };
            Controls.Add(page);
            pages.Add(page);
            return page;
        }

        // A tab opened: its page shown, its name gold over the gold line; the
        // one open kept for the next start.
        internal void ShowTab(int index)
        {
            ShowTab(index, false);
        }

        void ShowTab(int index, bool again)
        {
            if (index == currentTab && !again) return;
            currentTab = index;
            for (int i = 0; i < pages.Count; i++)
            {
                pages[i].Visible = i == index;
                tabButtons[i].ForeColor = i == index ? Gold : Muted;
                tabButtons[i].Invalidate();
            }
            Button tab = tabButtons[index];
            tabMark.Location = new Point(tab.Left + S(10), tab.Bottom - S(2));
            tabMark.Size = new Size(tab.Width - S(20), S(3));
            SetSetting("tab", index.ToString());
            if (index == 2) ShowSaveTab();
            if (index == 3) ShowStats();
            if (index == 4) ShowRuns();
        }

        static Label Caption(Control parent, string text, int x, int y)
        {
            Label label = new Label();
            label.Text = text;
            label.UseMnemonic = false;
            label.ForeColor = Muted;
            label.AutoSize = true;
            label.Location = new Point(x, y);
            parent.Controls.Add(label);
            return label;
        }

        static LinkLabel Link(Control parent, string text, int x, int y, Action click)
        {
            LinkLabel link = new LinkLabel();
            link.Text = text;
            link.AutoSize = true;
            link.Location = new Point(x, y);
            link.LinkColor = Gold;
            link.ActiveLinkColor = Color.White;
            link.VisitedLinkColor = Gold;
            link.LinkBehavior = LinkBehavior.HoverUnderline;
            link.LinkClicked += delegate { click(); };
            parent.Controls.Add(link);
            return link;
        }

        static void Open(string target)
        {
            try { Process.Start(target); } catch { }
        }

        // The launcher's own settings beyond its first few files: launcher.ini,
        // a key=value line each, beside addons-folder.txt.
        static Dictionary<string, string> launcherSettings;

        static string SettingsFile
        {
            get { return Path.Combine(Path.GetDirectoryName(ConfigPath), "launcher.ini"); }
        }

        static string Setting(string key, string fallback)
        {
            if (launcherSettings == null)
            {
                launcherSettings = new Dictionary<string, string>();
                try
                {
                    if (File.Exists(SettingsFile))
                        foreach (string line in File.ReadAllLines(SettingsFile))
                        {
                            int equal = line.IndexOf('=');
                            if (equal > 0) launcherSettings[line.Substring(0, equal)] = line.Substring(equal + 1);
                        }
                }
                catch { }
            }
            string value;
            return launcherSettings.TryGetValue(key, out value) ? value : fallback;
        }

        static void SetSetting(string key, string value)
        {
            Setting(key, null);
            launcherSettings[key] = value;
            try
            {
                List<string> lines = new List<string>();
                foreach (KeyValuePair<string, string> pair in launcherSettings) lines.Add(pair.Key + "=" + pair.Value);
                File.WriteAllLines(SettingsFile, lines.ToArray());
            }
            catch { }
        }

        // --- Play ---------------------------------------------------------------

        static readonly string[] StripNames = { "Today", "Last played", "Runs", "Wins" };
        readonly Label[] stripValues = new Label[4];
        readonly TextBox gameNews = new TextBox();

        void BuildPlayPage(Panel page)
        {
            // The game found, its version against the newest, Check version by
            // it (ShowGameLine); Find game... at the right.
            Style(gameCheckButton, "Check version");
            gameCheckButton.Font = new Font("Segoe UI", 7.5f, FontStyle.Bold);
            gameCheckButton.Location = new Point(20, 14);
            gameCheckButton.Size = new Size(92, 20);
            gameCheckButton.Visible = false;
            gameCheckButton.Click += delegate
            {
                if (checkingGame) return;
                gameByHand = true;
                CheckGame();
            };
            tips.SetToolTip(gameCheckButton, "Asks wow.aethus.pl now whether a newer Azeroth Survivors is out.");
            page.Controls.Add(gameCheckButton);

            gameLabel.Font = new Font("Segoe UI", 8.5f);
            gameLabel.ForeColor = Muted;
            gameLabel.AutoSize = true;
            gameLabel.Location = new Point(20, 14);
            page.Controls.Add(gameLabel);

            Style(browseButton, "Find game...");
            browseButton.Location = new Point(648, 10);
            browseButton.Size = new Size(92, 26);
            browseButton.Click += delegate { BrowseForGame(); };
            page.Controls.Add(browseButton);

            // Play: the game by the AddOns folder, started; the installer steps
            // into the tray. Get the game while there is none, Update game while
            // a newer one is out.
            playButton.Text = "▶  Play";
            playButton.FlatStyle = FlatStyle.Flat;
            playButton.FlatAppearance.BorderColor = RedEdge;
            playButton.BackColor = RedFill;
            playButton.ForeColor = Gold;
            playButton.Cursor = Cursors.Hand;
            playButton.Location = new Point(20, 46);
            playButton.Size = new Size(300, 62);
            playButton.Font = new Font("Segoe UI", 13f, FontStyle.Bold);
            playButton.Click += delegate { if (GameMissing() || GameBehind()) GetGame(); else Play(); };
            // The game's version, small, under its words, the two centred
            // together (playNote).
            Forge(playButton);
            subLines[playButton] = delegate { return playNote; };
            page.Controls.Add(playButton);

            // Beside Play, the player's numbers: today's and the last session
            // the launcher saw, and the save's runs and wins (Statistics).
            for (int i = 0; i < StripNames.Length; i++)
            {
                Panel card = new Panel();
                card.BackColor = Panel;
                card.Location = new Point(340 + i * 101, 46);
                card.Size = new Size(95, 62);
                Label name = new Label();
                name.Text = StripNames[i];
                name.Font = new Font("Segoe UI", 8f);
                name.ForeColor = Muted;
                name.AutoSize = true;
                name.Location = new Point(8, 8);
                card.Controls.Add(name);
                Label value = new Label();
                value.Text = "—";
                value.Font = new Font("Segoe UI", 11.5f, FontStyle.Bold);
                value.ForeColor = TextColor;
                value.AutoSize = true;
                value.Location = new Point(7, 29);
                card.Controls.Add(value);
                stripValues[i] = value;
                Card(card);
                page.Controls.Add(card);
            }

            // The game's own news: Aethus' notes for its newest version.
            Section(page, "Game news", 20, 124, 720);
            gameNews.Location = new Point(20, 144);
            gameNews.Size = new Size(720, 226);
            gameNews.Multiline = true;
            gameNews.ReadOnly = true;
            gameNews.ScrollBars = ScrollBars.Vertical;
            gameNews.BackColor = Panel;
            gameNews.ForeColor = TextColor;
            gameNews.BorderStyle = BorderStyle.FixedSingle;
            gameNews.Text = "Asking wow.aethus.pl for the game's news...";
            page.Controls.Add(gameNews);

            // The launcher's own ticks: with Windows, in the tray; its updates.
            startBox.Text = "Start with Windows, in the tray";
            startBox.AutoSize = true;
            startBox.Location = new Point(20, 388);
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
            page.Controls.Add(startBox);
            // Moved since it was set: the line follows the exe.
            if (startBox.Checked) SetStartWithWindows(true);

            selfBox.Text = "Update the launcher by itself";
            selfBox.AutoSize = true;
            selfBox.Location = new Point(300, 388);
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
            page.Controls.Add(selfBox);
            TickLook(startBox);
            TickLook(selfBox);

            // The game's Discord: news, help and the other players.
            Button discord = new Button();
            Style(discord, "Azeroth Survivors' Discord");
            discord.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            discord.Location = new Point(540, 383);
            discord.Size = new Size(200, 28);
            discord.ForeColor = Color.FromArgb(214, 220, 255);
            Wear(discord, "stone");
            discord.BackColor = Color.FromArgb(88, 101, 242);
            discord.Click += delegate { Open(GameDiscord); };
            tips.SetToolTip(discord, "The game's own Discord server: news, help and the other players.\n" +
                "Survivor UI's thread is there too (Survivor UI tab).");
            page.Controls.Add(discord);
        }

        // The game's news: Aethus' notes for the newest Azeroth Survivors, and
        // whether the one here is it.
        void ShowGameNews()
        {
            string text;
            if (GameExePath() == null) text = "No game found yet: click \"Get the game\", or \"Find game...\" if yours is somewhere else.";
            else if (game == null || game.Latest == null) return;
            else
            {
                string notes = string.IsNullOrEmpty(game.Notes) ? "" : game.Notes.Trim().Replace("\r\n", "\n").Replace("\n", "\r\n");
                text = "Azeroth Survivors " + game.Latest + (GameBehind() ? ", out now: click Update game to get it." : ", the one you have.") +
                    (notes != "" ? "\r\n\r\n" + notes : "");
            }
            if (text != gameNews.Text) gameNews.Text = text;
        }

        // --- Survivor UI ----------------------------------------------------------

        readonly CheckBox uiUse = new CheckBox();
        readonly CheckBox platesUse = new CheckBox();
        bool showingSwitches;
        const string GameDiscord = "https://discord.gg/azerothsurvivors";
        const string AddonThread = "https://discord.com/channels/1557821819032051852/1558188535058796664/threads/1559383648036327444";

        void BuildAddonPage(Panel page)
        {
            // Each addon on or off for the game, in its own list of addons
            // (AddOns\account.txt): nothing deleted, back on with a tick.
            uiUse.Text = "Survivor UI on";
            platesUse.Text = "Survivor Plates on";
            int x = 20;
            foreach (CheckBox box in new CheckBox[] { uiUse, platesUse })
            {
                box.AutoSize = true;
                box.Location = new Point(x, 12);
                box.FlatStyle = FlatStyle.Flat;
                box.FlatAppearance.BorderColor = TickEdge;
                box.Cursor = Cursors.Hand;
                page.Controls.Add(box);
                TickLook(box);
                x += 180;
            }
            uiUse.CheckedChanged += delegate { SwitchAddon("SurvivorUI", uiUse); };
            platesUse.CheckedChanged += delegate { SwitchAddon("SurvivorPlates", platesUse); };
            Label switchNote = Caption(page, "Off, the game skips it from its next start; nothing is deleted.", 380, 15);
            switchNote.Font = new Font("Segoe UI", 8f);

            Section(page, "Game's AddOns folder", 20, 46, 720);
            folderBox.Location = new Point(20, 66);
            folderBox.Size = new Size(620, 24);
            folderBox.BackColor = Panel;
            folderBox.ForeColor = TextColor;
            folderBox.BorderStyle = BorderStyle.FixedSingle;
            folderBox.TextChanged += delegate { ShowInstalled(); ShowSwitches(); };
            page.Controls.Add(folderBox);

            openLink.Text = "Open folder";
            openLink.AutoSize = false;
            openLink.Location = new Point(648, 69);
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
            page.Controls.Add(openLink);

            // Which folder the game keeps its things in, and the player's moved
            // there when they are in another (NoteFolders paints it).
            foldersButton.Text = "⇄  Check folder and move if necessary";
            foldersButton.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            foldersButton.FlatStyle = FlatStyle.Flat;
            foldersButton.Cursor = Cursors.Hand;
            foldersButton.Location = new Point(20, 98);
            foldersButton.Size = new Size(720, 26);
            foldersButton.Click += delegate { CheckFolders(); };
            folderTip.AutoPopDelay = 30000;
            folderTip.InitialDelay = 300;
            page.Controls.Add(foldersButton);
            Forge(foldersButton);

            // The release: large and gold, its version on it; the badge in its
            // place while it is the one installed.
            installButton.Text = "Install";
            installButton.FlatStyle = FlatStyle.Flat;
            installButton.FlatAppearance.BorderColor = Color.FromArgb(255, 226, 120);
            installButton.BackColor = StableFill;
            installButton.ForeColor = StableText;
            installButton.Cursor = Cursors.Hand;
            installButton.Location = new Point(20, 136);
            installButton.Size = new Size(350, 40);
            installButton.Font = new Font("Segoe UI", 11f, FontStyle.Bold);
            Active(installButton, false, StableText);
            installButton.Click += delegate { if (IsActive(installButton) && stable != null) Install(stable); };
            page.Controls.Add(installButton);
            Forge(installButton);

            upToDate.Location = installButton.Location;
            upToDate.Size = installButton.Size;
            upToDate.TextAlign = ContentAlignment.MiddleCenter;
            upToDate.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
            upToDate.ForeColor = Color.FromArgb(110, 225, 125);
            upToDate.BackColor = Color.FromArgb(22, 44, 28);
            upToDate.BorderStyle = BorderStyle.FixedSingle;
            upToDate.Visible = false;
            upToDate.BorderStyle = BorderStyle.None;
            upToDate.BackColor = Back;
            upToDate.Paint += delegate (object sender, PaintEventArgs e)
            {
                Graphics g = e.Graphics;
                Rectangle r = upToDate.ClientRectangle;
                g.Clear(Back);
                Rectangle bar = new Rectangle(r.X, r.Y + (r.Height - S(32)) / 2, r.Width, S(32));
                Slice3(g, Art("bar-back"), Rectangle.Inflate(bar, -S(3), -S(3)), 8, 8);
                Slice3(g, Art("bar-green"), Rectangle.Inflate(bar, -S(4), -S(4)), 6, 6);
                Slice3(g, Art("bar-border"), bar, 14, 14);
                TextFormatFlags flags = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine;
                Rectangle shadow = bar;
                shadow.Offset(1, 1);
                TextRenderer.DrawText(g, upToDate.Text, upToDate.Font, shadow, Color.FromArgb(8, 20, 4), flags);
                TextRenderer.DrawText(g, upToDate.Text, upToDate.Font, bar, Color.FromArgb(244, 255, 232), flags);
            };
            page.Controls.Add(upToDate);

            // The beta: lavender, its version on it; a warning first.
            betaButton.Text = "No beta right now";
            betaButton.FlatStyle = FlatStyle.Flat;
            betaButton.FlatAppearance.BorderColor = Color.FromArgb(112, 86, 176);
            betaButton.BackColor = Color.FromArgb(34, 26, 58);
            betaButton.ForeColor = BetaColor;
            betaButton.Cursor = Cursors.Hand;
            betaButton.Location = new Point(390, 140);
            betaButton.Size = new Size(350, 32);
            betaButton.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            Active(betaButton, false, BetaColor);
            betaButton.Click += delegate { if (IsActive(betaButton)) InstallBeta(); };
            page.Controls.Add(betaButton);
            Forge(betaButton);
            Label betaNote = Caption(page, "Betas come before a release: more bugs, more updates.", 390, 177);
            betaNote.Font = new Font("Segoe UI", 8f);

            Section(page, "What's new", 20, 196, 590);
            LinkLabel readLink = Link(page, "Read larger", 620, 196, ShowNotesWindow);
            readLink.AutoSize = false;
            readLink.Size = new Size(120, 18);
            readLink.TextAlign = ContentAlignment.MiddleRight;

            notesBox.Location = new Point(20, 216);
            notesBox.Size = new Size(720, 168);
            notesBox.Multiline = true;
            notesBox.ReadOnly = true;
            notesBox.ScrollBars = ScrollBars.Vertical;
            notesBox.BackColor = Panel;
            notesBox.ForeColor = TextColor;
            notesBox.BorderStyle = BorderStyle.FixedSingle;
            notesBox.Text = "Asking GitHub for the latest release...";
            page.Controls.Add(notesBox);

            Link(page, "Survivor UI on GitHub", 20, 396, delegate { Open("https://github.com/" + Repo); });
            Link(page, "Its thread on the game's Discord", 200, 396, delegate { Open(AddonThread); });
        }

        // The game's list of addons on or off: AddOns\account.txt, a line
        // "<AddOn>: enabled" or "<AddOn>: disabled" each; an addon not in it is on.
        static bool AddonOn(string addons, string name)
        {
            try
            {
                string path = Path.Combine(addons, "account.txt");
                if (!File.Exists(path)) return true;
                foreach (string line in File.ReadAllLines(path))
                {
                    int colon = line.IndexOf(':');
                    if (colon > 0 && string.Equals(line.Substring(0, colon).Trim(), name, StringComparison.OrdinalIgnoreCase))
                        return !string.Equals(line.Substring(colon + 1).Trim(), "disabled", StringComparison.OrdinalIgnoreCase);
                }
            }
            catch { }
            return true;
        }

        static void SetAddonOn(string addons, string name, bool on)
        {
            string path = Path.Combine(addons, "account.txt");
            List<string> lines = File.Exists(path) ? new List<string>(File.ReadAllLines(path)) : new List<string>();
            string row = name + ": " + (on ? "enabled" : "disabled");
            bool found = false;
            for (int i = 0; i < lines.Count; i++)
            {
                int colon = lines[i].IndexOf(':');
                if (colon > 0 && string.Equals(lines[i].Substring(0, colon).Trim(), name, StringComparison.OrdinalIgnoreCase))
                {
                    lines[i] = row;
                    found = true;
                }
            }
            if (!found) lines.Add(row);
            File.WriteAllText(path, string.Join("\n", lines.ToArray()) + "\n");
        }

        // The ticks as the game's list has them; greyed for an addon not there.
        void ShowSwitches()
        {
            showingSwitches = true;
            string addons = folderBox.Text;
            bool ui = Directory.Exists(Path.Combine(addons, "SurvivorUI"));
            bool plates = Directory.Exists(Path.Combine(addons, "SurvivorPlates"));
            uiUse.Enabled = ui;
            platesUse.Enabled = plates;
            uiUse.Checked = ui && AddonOn(addons, "SurvivorUI");
            platesUse.Checked = plates && AddonOn(addons, "SurvivorPlates");
            showingSwitches = false;
        }

        void SwitchAddon(string name, CheckBox box)
        {
            if (showingSwitches) return;
            if (GameRunning())
            {
                Ask(this, "Close the game first: it reads its list of addons as it starts.",
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                ShowSwitches();
                return;
            }
            try
            {
                SetAddonOn(folderBox.Text, name, box.Checked);
                string shown = name == "SurvivorUI" ? "Survivor UI" : "Survivor Plates";
                Status(box.Checked ? shown + " on: the game loads it from its next start."
                    : shown + " off: the game skips it from its next start; nothing is deleted.");
                ShowUpdateState();
            }
            catch (Exception error)
            {
                Status("Could not change the game's list of addons: " + error.Message);
                ShowSwitches();
            }
        }

        // --- Savegame -------------------------------------------------------------

        const string SavesFolderName = "Azeroth Survivors saves";
        readonly Label saveInfo = new Label();
        readonly ComboBox destBox = new ComboBox();
        readonly CheckBox autoBox = new CheckBox();
        readonly CheckBox usbBox = new CheckBox();
        readonly ComboBox keepBox = new ComboBox();
        readonly ListView backupList = new ListView();
        readonly Button restoreOne = new Button();
        bool fillingDestinations;

        // Where a backup goes: a name to show, and its folder (null: pick one).
        class Destination
        {
            public string Name, Folder;
            public override string ToString() { return Name; }
        }

        void BuildSavePage(Panel page)
        {
            Caption(page, "Your save", 20, 12);
            saveInfo.AutoSize = true;
            saveInfo.UseMnemonic = false;
            saveInfo.Location = new Point(100, 12);
            page.Controls.Add(saveInfo);
            Link(page, "Open folder", 664, 12, delegate
            {
                if (Directory.Exists(GameSave.SaveFolder())) Process.Start("explorer.exe", "\"" + GameSave.SaveFolder() + "\"");
            });

            // A backup now: where to (the Desktop, each USB drive plugged in, a
            // folder of one's own), the last one kept; and putting one back.
            Caption(page, "Back up to", 20, 50);
            DarkCombo(destBox);
            destBox.Location = new Point(100, 46);
            destBox.Size = new Size(350, 24);
            destBox.DropDown += delegate { FillDestinations(); };
            destBox.SelectedIndexChanged += delegate { DestinationPicked(); };
            page.Controls.Add(destBox);

            Style(saveButton, "Back up now");
            saveButton.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            saveButton.Location = new Point(460, 45);
            saveButton.Size = new Size(130, 26);
            saveButton.Click += delegate { BackUpSave(); };
            tips.SetToolTip(saveButton, "Zips your heroes, gear, talents and unlocks, with the game's and the addons'\n" +
                "settings (key bindings, chat, layout, Run History), into the place picked:\n" +
                "to keep, or to take to another PC. The game must be closed.");
            page.Controls.Add(saveButton);

            Style(restoreButton, "Restore save...");
            restoreButton.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            restoreButton.Location = new Point(600, 45);
            restoreButton.Size = new Size(140, 26);
            restoreButton.Click += delegate { RestoreSave(null); };
            tips.SetToolTip(restoreButton, "Puts a save zipped by the launcher into the game, on this PC or another.\n" +
                "Your save as it is now is kept on the Desktop first. The game must be closed.");
            page.Controls.Add(restoreButton);

            // By itself, after each game session the launcher sees end.
            Section(page, "Automatic", 20, 92, 720);
            autoBox.Text = "Back up after each game session";
            usbBox.Text = "Also copy it to a USB drive when one is plugged in";
            autoBox.Location = new Point(20, 114);
            usbBox.Location = new Point(20, 140);
            foreach (CheckBox box in new CheckBox[] { autoBox, usbBox })
            {
                box.AutoSize = true;
                box.FlatStyle = FlatStyle.Flat;
                box.FlatAppearance.BorderColor = TickEdge;
                box.Cursor = Cursors.Hand;
                page.Controls.Add(box);
            }
            autoBox.Checked = Setting("autoBackup", "0") == "1";
            usbBox.Checked = Setting("autoUsb", "0") == "1";
            TickLook(autoBox);
            TickLook(usbBox);
            autoBox.CheckedChanged += delegate
            {
                SetSetting("autoBackup", autoBox.Checked ? "1" : "0");
                Status(autoBox.Checked ? "Your save will be backed up each time the game closes." : "No more backups by themselves.");
            };
            usbBox.CheckedChanged += delegate { SetSetting("autoUsb", usbBox.Checked ? "1" : "0"); };

            Caption(page, "Keep the last", 470, 116);
            DarkCombo(keepBox);
            keepBox.Items.AddRange(new object[] { "5", "10", "20", "50" });
            keepBox.Location = new Point(560, 112);
            keepBox.Size = new Size(76, 24);
            keepBox.SelectedItem = Setting("autoKeep", "10");
            if (keepBox.SelectedIndex < 0) keepBox.SelectedIndex = 1;
            keepBox.SelectedIndexChanged += delegate { SetSetting("autoKeep", (string)keepBox.SelectedItem); };
            page.Controls.Add(keepBox);
            Caption(page, "automatic ones", 644, 116);
            Label autoNote = Caption(page, "Into Documents\\" + SavesFolderName + ". The launcher must be running (in the tray) as the game closes; " +
                "only the oldest automatic ones are removed, never the ones you make yourself.", 20, 166);
            autoNote.Font = new Font("Segoe UI", 8f);
            autoNote.AutoSize = false;
            autoNote.Size = new Size(720, 30);

            // The backups made: the ones the launcher remembers making, and the
            // ones in its folders, newest first.
            Section(page, "Your backups", 20, 202, 720);
            backupList.View = View.Details;
            backupList.HeaderStyle = ColumnHeaderStyle.None;
            backupList.FullRowSelect = true;
            backupList.MultiSelect = false;
            backupList.BackColor = Panel;
            backupList.ForeColor = TextColor;
            backupList.BorderStyle = BorderStyle.FixedSingle;
            backupList.Location = new Point(20, 222);
            backupList.Size = new Size(720, 162);
            backupList.Columns.Add("Taken", 130);
            backupList.Columns.Add("Where", 500);
            backupList.Columns.Add("Size", 70, HorizontalAlignment.Right);
            backupList.SelectedIndexChanged += delegate { restoreOne.Enabled = backupList.SelectedItems.Count > 0; };
            backupList.DoubleClick += delegate { RestoreSelected(); };
            page.Controls.Add(backupList);

            Style(restoreOne, "Restore this one");
            restoreOne.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
            restoreOne.Location = new Point(20, 394);
            restoreOne.Size = new Size(150, 26);
            restoreOne.Enabled = false;
            restoreOne.Click += delegate { RestoreSelected(); };
            page.Controls.Add(restoreOne);
            Link(page, "Show in folder", 184, 399, delegate
            {
                if (backupList.SelectedItems.Count == 0) return;
                string zip = (string)backupList.SelectedItems[0].Tag;
                if (File.Exists(zip)) Process.Start("explorer.exe", "/select,\"" + zip + "\"");
            });
            FillDestinations();
        }

        static List<DriveInfo> RemovableDrives()
        {
            List<DriveInfo> drives = new List<DriveInfo>();
            try
            {
                foreach (DriveInfo drive in DriveInfo.GetDrives())
                    if (drive.DriveType == DriveType.Removable && drive.IsReady) drives.Add(drive);
            }
            catch { }
            return drives;
        }

        // The places a backup can go, the one picked last selected.
        void FillDestinations()
        {
            fillingDestinations = true;
            string chosen = Setting("backupTo", "");
            destBox.Items.Clear();
            Destination desktop = new Destination();
            desktop.Name = "Desktop";
            desktop.Folder = GameSave.Desktop();
            destBox.Items.Add(desktop);
            foreach (DriveInfo drive in RemovableDrives())
            {
                Destination usb = new Destination();
                string label = "";
                try { label = drive.VolumeLabel; } catch { }
                usb.Name = "USB  " + drive.Name.TrimEnd('\\') + (label != "" ? "  " + label : "") +
                    "  (" + (drive.AvailableFreeSpace / 1073741824.0).ToString("0.0") + " GB free)";
                usb.Folder = Path.Combine(drive.RootDirectory.FullName, SavesFolderName);
                destBox.Items.Add(usb);
            }
            string custom = Setting("backupFolder", "");
            if (custom != "")
            {
                Destination folder = new Destination();
                folder.Name = "Folder  " + custom;
                folder.Folder = custom;
                destBox.Items.Add(folder);
            }
            Destination pick = new Destination();
            pick.Name = "Choose a folder...";
            destBox.Items.Add(pick);
            int index = 0;
            for (int i = 0; i < destBox.Items.Count; i++)
            {
                string folder = ((Destination)destBox.Items[i]).Folder;
                if (folder != null && string.Equals(folder.TrimEnd('\\'), chosen.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) index = i;
            }
            destBox.SelectedIndex = index;
            fillingDestinations = false;
        }

        void DestinationPicked()
        {
            if (fillingDestinations) return;
            Destination picked = (Destination)destBox.SelectedItem;
            if (picked == null) return;
            if (picked.Folder != null)
            {
                SetSetting("backupTo", picked.Folder);
                return;
            }
            using (FolderBrowserDialog dialog = new FolderBrowserDialog())
            {
                dialog.Description = "Where your save backups go";
                if (dialog.ShowDialog(this) == DialogResult.OK)
                {
                    SetSetting("backupFolder", dialog.SelectedPath);
                    SetSetting("backupTo", dialog.SelectedPath);
                }
            }
            BeginInvoke(new Action(FillDestinations));
        }

        string ChosenFolder()
        {
            Destination picked = destBox.SelectedItem as Destination;
            return picked != null && picked.Folder != null ? picked.Folder : GameSave.Desktop();
        }

        // The tab opened: the save's line and the backups, as they are now.
        void ShowSaveTab()
        {
            string save = GameSave.SaveFolder();
            string characters = Path.Combine(save, "characters.txt");
            if (File.Exists(characters))
            {
                FileInfo info = new FileInfo(characters);
                saveInfo.Text = "changed " + info.LastWriteTime.ToString("yyyy-MM-dd HH:mm") + "  ·  " + save;
                saveInfo.ForeColor = TextColor;
            }
            else
            {
                saveInfo.Text = "none yet in " + save + ": play the game once first.";
                saveInfo.ForeColor = Muted;
            }
            FillDestinations();
            ShowBackups();
        }

        // The backups the launcher made, kept by their paths (backups.txt).
        static string BackupsLog
        {
            get { return Path.Combine(Path.GetDirectoryName(ConfigPath), "backups.txt"); }
        }

        static void RememberBackup(string zip)
        {
            try { File.AppendAllText(BackupsLog, zip + "\r\n"); } catch { }
        }

        static List<FileInfo> KnownBackups()
        {
            Dictionary<string, FileInfo> found = new Dictionary<string, FileInfo>(StringComparer.OrdinalIgnoreCase);
            List<string> places = new List<string>();
            places.Add(GameSave.AutoFolder());
            places.Add(GameSave.Desktop());
            foreach (DriveInfo drive in RemovableDrives()) places.Add(Path.Combine(drive.RootDirectory.FullName, SavesFolderName));
            string custom = Setting("backupFolder", "");
            if (custom != "") places.Add(custom);
            foreach (string place in places)
            {
                try
                {
                    if (Directory.Exists(place))
                        foreach (FileInfo file in new DirectoryInfo(place).GetFiles("AzerothSurvivors-save-*.zip"))
                            found[file.FullName] = file;
                }
                catch { }
            }
            try
            {
                if (File.Exists(BackupsLog))
                    foreach (string line in File.ReadAllLines(BackupsLog))
                        if (line.Trim() != "" && File.Exists(line.Trim())) found[line.Trim()] = new FileInfo(line.Trim());
            }
            catch { }
            List<FileInfo> list = new List<FileInfo>(found.Values);
            list.Sort(delegate (FileInfo a, FileInfo b) { return b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc); });
            if (list.Count > 40) list.RemoveRange(40, list.Count - 40);
            return list;
        }

        void ShowBackups()
        {
            backupList.BeginUpdate();
            backupList.Items.Clear();
            foreach (FileInfo file in KnownBackups())
            {
                ListViewItem row = new ListViewItem(file.LastWriteTime.ToString("yyyy-MM-dd HH:mm"));
                bool auto = file.Name.StartsWith("AzerothSurvivors-save-auto-", StringComparison.OrdinalIgnoreCase);
                bool before = file.Name.StartsWith("AzerothSurvivors-save-before-restore-", StringComparison.OrdinalIgnoreCase);
                row.SubItems.Add((auto ? "Automatic  ·  " : before ? "Before a restore  ·  " : "") + file.FullName);
                row.SubItems.Add(Math.Max(1, file.Length / 1024) + " KB");
                row.Tag = file.FullName;
                backupList.Items.Add(row);
            }
            backupList.EndUpdate();
            restoreOne.Enabled = false;
        }

        void RestoreSelected()
        {
            if (backupList.SelectedItems.Count == 0) return;
            RestoreSave((string)backupList.SelectedItems[0].Tag);
        }

        // --- The game, watched -------------------------------------------------------

        // Every few seconds: whether the game runs. A session's end is kept for
        // the playtime (playtime.txt: its start and its seconds, a line each)
        // and, when asked, the save backed up by itself.
        readonly System.Windows.Forms.Timer gameWatch = new System.Windows.Forms.Timer();
        DateTime sessionStart = DateTime.MinValue;

        void WatchGame()
        {
            if (GameRunning()) sessionStart = DateTime.Now;
            gameWatch.Interval = 5000;
            gameWatch.Tick += delegate
            {
                bool running = GameRunning();
                if (running && sessionStart == DateTime.MinValue) sessionStart = DateTime.Now;
                else if (!running && sessionStart != DateTime.MinValue)
                {
                    DateTime start = sessionStart;
                    sessionStart = DateTime.MinValue;
                    GameClosed(start, DateTime.Now);
                }
            };
            gameWatch.Start();
        }

        static string PlaytimeLog
        {
            get { return Path.Combine(Path.GetDirectoryName(ConfigPath), "playtime.txt"); }
        }

        void GameClosed(DateTime start, DateTime end)
        {
            int seconds = (int)(end - start).TotalSeconds;
            if (seconds >= 10)
            {
                try
                {
                    File.AppendAllText(PlaytimeLog, start.ToString("yyyy-MM-dd HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture) +
                        ";" + seconds + "\r\n");
                }
                catch { }
            }
            if (Setting("autoBackup", "0") == "1")
            {
                // A moment for the game to finish writing the save as it closes.
                System.Windows.Forms.Timer wait = new System.Windows.Forms.Timer();
                wait.Interval = 4000;
                wait.Tick += delegate
                {
                    wait.Stop();
                    wait.Dispose();
                    AutoBackup();
                };
                wait.Start();
            }
            ShowStrip();
            if (currentTab == 3) ShowStats();
        }

        void AutoBackup()
        {
            string save = GameSave.SaveFolder();
            if (!GameSave.HasSave(save) || GameRunning()) return;
            int keep;
            if (!int.TryParse(Setting("autoKeep", "10"), out keep) || keep < 1) keep = 10;
            try
            {
                string folder = GameSave.AutoFolder();
                Directory.CreateDirectory(folder);
                string zip = FreeName(folder, "AzerothSurvivors-save-auto-" + DateTime.Now.ToString("yyyy-MM-dd_HHmm"));
                GameSave.Backup(save, GameSettingsFolder(), zip, SaveNote());
                GameSave.Prune(folder, keep);
                string where = "Documents";
                if (Setting("autoUsb", "0") == "1")
                    foreach (DriveInfo drive in RemovableDrives())
                    {
                        try
                        {
                            string usb = Path.Combine(drive.RootDirectory.FullName, SavesFolderName);
                            Directory.CreateDirectory(usb);
                            File.Copy(zip, Path.Combine(usb, Path.GetFileName(zip)), true);
                            GameSave.Prune(usb, keep);
                            where += " and " + drive.Name.TrimEnd('\\');
                        }
                        catch { }
                    }
                Status("Save backed up as the game closed (" + where + ").");
                if (currentTab == 2) ShowBackups();
            }
            catch (Exception error)
            {
                Status("Could not back up the save as the game closed: " + error.Message);
            }
        }

        // The game's sessions the launcher saw: start and seconds, oldest first.
        static List<KeyValuePair<DateTime, int>> Sessions()
        {
            List<KeyValuePair<DateTime, int>> list = new List<KeyValuePair<DateTime, int>>();
            try
            {
                if (File.Exists(PlaytimeLog))
                    foreach (string line in File.ReadAllLines(PlaytimeLog))
                    {
                        string[] parts = line.Split(';');
                        DateTime start;
                        int seconds;
                        if (parts.Length >= 2 && DateTime.TryParseExact(parts[0], "yyyy-MM-dd HH:mm:ss",
                                System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out start)
                            && int.TryParse(parts[1], out seconds))
                            list.Add(new KeyValuePair<DateTime, int>(start, seconds));
                    }
            }
            catch { }
            return list;
        }

        // The first start of 1.5: the runs in Survivor UI's Run History, from
        // before the launcher counted, as the playtime so far: each run's game
        // time (its endless end's, when it went on), ending at its "at". Once;
        // lines marked "runs" in playtime.txt.
        void SeedPlaytime()
        {
            if (Setting("playSeeded", "") != "") return;
            SetSetting("playSeeded", "1");
            try
            {
                string game = GameSettingsFolder();
                string path = game != null ? Path.Combine(Path.Combine(game, "saved"), "SurvivorUI.lua") : null;
                if (path == null || !File.Exists(path)) return;
                string keep;
                List<RunRecord> history = RunRecord.ReadAll(path, out keep);
                List<string> lines = new List<string>();
                DateTime now = DateTime.Now;
                foreach (RunRecord run in history)
                {
                    Dictionary<object, object> endless = run.Table("endless");
                    double seconds = endless != null ? RunRecord.NumOf(endless, "time") : run.Num("time");
                    double at = endless != null && RunRecord.NumOf(endless, "at") > 0 ? RunRecord.NumOf(endless, "at") : run.Num("at");
                    if (seconds < 10 || at <= 0) continue;
                    DateTime start = Local(at).AddSeconds(-seconds);
                    if (start >= now) continue;
                    lines.Add(start.ToString("yyyy-MM-dd HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture) + ";" + (int)seconds + ";runs");
                }
                lines.Sort(StringComparer.Ordinal);
                if (lines.Count > 0) File.AppendAllText(PlaytimeLog, string.Join("\r\n", lines.ToArray()) + "\r\n");
                // Read already: Run History's tab takes it as it is.
                runs = history;
                runsKeep = keep;
                runsFile = path;
                runsStamp = File.GetLastWriteTimeUtc(path);
            }
            catch { }
        }

        // A Unix time (the game's time()) in the computer's own time.
        static DateTime Local(double unix)
        {
            return new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).AddSeconds(unix).ToLocalTime();
        }

        static string Hours(int seconds)
        {
            if (seconds < 60) return seconds > 0 ? "<1m" : "0m";
            int minutes = seconds / 60;
            return minutes < 60 ? minutes + "m" : (minutes / 60) + "h " + (minutes % 60).ToString("00") + "m";
        }

        // --- Statistics --------------------------------------------------------------

        // The classes as the save numbers them, in the game's order, with
        // their colours; the zones in the order they open.
        static readonly int[] ClassIds = { 1, 2, 3, 4, 5, 7, 8, 9, 11 };
        static readonly string[] ClassNames = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid" };
        static readonly Color[] ClassColors = {
            Color.FromArgb(199, 156, 110), Color.FromArgb(245, 140, 186), Color.FromArgb(171, 212, 115),
            Color.FromArgb(255, 245, 105), Color.FromArgb(240, 240, 240), Color.FromArgb(40, 140, 236),
            Color.FromArgb(105, 204, 240), Color.FromArgb(160, 142, 214), Color.FromArgb(255, 125, 10) };
        static readonly string[] ZoneIds = { "elwynn", "duskwood", "wsg", "ungoro", "ab", "feralas", "arena", "sm", "av", "brm", "aq", "naxx" };
        static readonly string[] ZoneNames = { "Elwynn Forest", "Duskwood", "Warsong Gulch", "Un'Goro Crater", "Arathi Basin", "Feralas",
            "Gurubashi Arena", "Scarlet Monastery", "Alterac Valley", "Blackrock Mountain", "Gates of Ahn'Qiraj", "Naxxramas" };
        static readonly string[] ZoneShort = { "Elwynn", "Duskwood", "WSG", "Un'Goro", "AB", "Feralas", "Arena", "SM", "AV", "BRM", "AQ", "Naxx" };

        // The achievements' names, as the game shows them in English; the ones
        // made from a class or a zone are put together in AchievementName.
        static readonly Dictionary<string, string> AchievementNames = new Dictionary<string, string> {
            { "count:kills10k", "Exterminator" }, { "count:kills100k", "Scourge of Azeroth" }, { "count:kills1m", "A Million Dead" },
            { "count:gold5k", "Pocket Change" }, { "count:gold50k", "Treasure Hunter" },
            { "count:guardians100", "Lair Raider" }, { "count:guardians500", "Warden's Bane" },
            { "count:bosses100", "Boss Hunter" }, { "count:caches100", "Cache Cracker" },
            { "count:runs10", "Regular" }, { "count:runs100", "Veteran" }, { "count:wins50", "Conqueror" },
            { "feat:kills2500", "Slaughterhouse" }, { "feat:kills6000", "Carnage" }, { "feat:lairs", "Lair Breaker" },
            { "feat:endless25", "Overtime" }, { "feat:endless30", "Unending" }, { "feat:endless40", "Deathless Hour" },
            { "feat:bare", "Bare Knuckles" }, { "feat:thrifty", "Thrifty" }, { "feat:odds", "Against the Odds" },
            { "feat:nou", "no u" }, { "feat:herod", "Spin to Win" }, { "feat:hakkar", "Suck It, Hakkar!" },
            { "feat:nefarian", "Bad Dragon!" }, { "feat:cthun", "Eye Caramba!" }, { "feat:vancleef", "You're Fired" },
            { "feat:stitches", "Stitches Get Stitches" }, { "feat:kazzak", "Not Today, Satan" }, { "feat:mosh", "Clever Girl" },
            { "feat:kovork", "Bonk the Bonker" }, { "feat:gordok", "Stop Hitting Yourself" }, { "feat:azuregos", "Blue Screen of Death" },
            { "legendaryset", "Legendary" }, { "pieces:all", "The Whole Armory" },
            { "talents:1", "Fully Talented" }, { "talents:9", "Master of All" }, { "talents:all", "Master of All" },
            { "codex:50", "Jeweler's Eye" }, { "codex:all", "Every Bauble" }, { "codex:100", "Every Bauble" },
            { "coop:together", "Better Together" }, { "coop:fiveofakind", "Five of a Kind" },
            { "coop:photosynthesis", "Rest in Photosynthesis" }, { "coop:odds", "Against All Odds" },
            { "coop:brotherhood", "The Brotherhood Falls" }, { "coop:bump", "Things That Go Bump in the Night" },
            { "coop:team", "For the Team" }, { "coop:jurassic", "Jurassic Pack" }, { "coop:smoothie", "Hakkar Smoothie" },
            { "coop:holyframe", "Holy Frame Drops" }, { "coop:dragonslayers", "Dragonslayers" } };

        static string AchievementName(string id)
        {
            string name;
            if (AchievementNames.TryGetValue(id, out name)) return name;
            int colon = id.IndexOf(':');
            string kind = colon > 0 ? id.Substring(0, colon) : id;
            string what = colon > 0 ? id.Substring(colon + 1) : "";
            int zone = Array.IndexOf(ZoneIds, what);
            int cls = -1;
            for (int i = 0; i < ClassNames.Length; i++)
                if (string.Equals(ClassNames[i], what, StringComparison.OrdinalIgnoreCase)) cls = i;
            if (kind == "class" && cls >= 0) return ClassNames[cls] + " Victorious";
            if (kind == "classlast" && cls >= 0) return ClassNames[cls] + " of the Scarab Wall";
            if (kind == "zone9" && zone >= 0) return "Champion of " + ZoneNames[zone];
            if (kind == "zone" && zone >= 0) return ZoneNames[zone] + " cleared";
            if (kind == "pieces") return "Collect " + what + " pieces of gear";
            // One the launcher does not know yet: its id, readable.
            string words = (what != "" ? what : kind).Replace('_', ' ');
            return words.Length > 0 ? char.ToUpper(words[0]) + words.Substring(1) : id;
        }

        static readonly string[] StatNames = { "Playtime", "Runs", "Wins", "Kills", "Gold", "Bosses", "Guardians", "Caches" };
        static readonly string[] StatKeys = { null, "runs", "wins", "kills", "gold", "bosses", "guardians", "caches" };
        readonly Label[] statValues = new Label[8];
        readonly Label[] statSubs = new Label[8];
        readonly Label achCount = new Label();
        readonly Label collectionLine = new Label();
        readonly Canvas playChart = new Canvas();
        readonly Canvas achList = new Canvas();
        readonly Canvas classGrid = new Canvas();
        SaveStats shownStats;       // the save as last read whole (a read caught mid-write keeps the one before)
        int[] dayPlay = new int[14];

        void BuildStatsPage(Panel page)
        {
            // The account's numbers along the top: the playtime the launcher
            // saw, then the save's own totals.
            for (int i = 0; i < StatNames.Length; i++)
            {
                Panel card = new Panel();
                card.BackColor = Panel;
                card.Location = new Point(20 + i * 90, 8);
                card.Size = new Size(84, 62);
                Label name = new Label();
                name.Text = StatNames[i];
                name.Font = new Font("Segoe UI", 8f);
                name.ForeColor = Muted;
                name.AutoSize = true;
                name.Location = new Point(7, 5);
                card.Controls.Add(name);
                Label value = new Label();
                value.Text = "—";
                value.Font = new Font("Segoe UI", 11.5f, FontStyle.Bold);
                value.ForeColor = TextColor;
                value.AutoSize = true;
                value.Location = new Point(6, 21);
                card.Controls.Add(value);
                Label sub = new Label();
                sub.Font = new Font("Segoe UI", 7.5f);
                sub.ForeColor = Muted;
                sub.AutoSize = false;
                sub.Location = new Point(7, 44);
                sub.Size = new Size(76, 14);
                card.Controls.Add(sub);
                statValues[i] = value;
                statSubs[i] = sub;
                Card(card);
                page.Controls.Add(card);
            }
            tips.SetToolTip(statValues[0], "The time the game ran while the launcher was open or in the tray,\n" +
                "and from before launcher 1.5, the game time of the runs in Survivor UI's Run History.");

            Section(page, "Playtime, last 14 days", 20, 82, 350);
            playChart.Location = new Point(20, 102);
            playChart.Size = new Size(350, 112);
            playChart.BackColor = Panel;
            playChart.Paint += DrawPlayChart;
            page.Controls.Add(playChart);

            Section(page, "Achievements, newest first", 390, 82, 260);
            achCount.AutoSize = false;
            achCount.Location = new Point(560, 82);
            achCount.Size = new Size(180, 18);
            achCount.TextAlign = ContentAlignment.TopRight;
            achCount.ForeColor = TextColor;
            page.Controls.Add(achCount);
            achList.Location = new Point(390, 102);
            achList.Size = new Size(350, 112);
            achList.BackColor = Panel;
            achList.Paint += DrawAchievements;
            Scrollable(achList, achScrolls);
            page.Controls.Add(achList);

            Section(page, "Classes and zones: gold where the zone's final boss fell to that class", 20, 226, 720);
            classGrid.Location = new Point(20, 246);
            classGrid.Size = new Size(720, 158);
            classGrid.BackColor = Panel;
            classGrid.Paint += DrawClassGrid;
            page.Controls.Add(classGrid);

            collectionLine.AutoSize = true;
            collectionLine.UseMnemonic = false;
            collectionLine.ForeColor = Muted;
            collectionLine.Location = new Point(20, 410);
            page.Controls.Add(collectionLine);
        }

        // The save read (never written): its text out of the seal, then its
        // lines. Read beside the game, which writes it all the time.
        static SaveStats ReadSaveStats()
        {
            try
            {
                string path = Path.Combine(GameSave.SaveFolder(), "characters.txt");
                if (!File.Exists(path)) return null;
                string text;
                using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                using (StreamReader reader = new StreamReader(stream)) text = reader.ReadToEnd();
                string plain = GameSave.Unseal(text);
                return plain != null ? SaveStats.Parse(plain) : null;
            }
            catch { return null; }
        }

        // A count told short: 721,076 as it is, a million and up as 1.23M.
        static string Count(long n)
        {
            if (n >= 1000000) return (n / 1000000.0).ToString("0.##", System.Globalization.CultureInfo.InvariantCulture) + "M";
            return n.ToString("N0", System.Globalization.CultureInfo.InvariantCulture);
        }

        void ShowStats()
        {
            bool saveThere = File.Exists(Path.Combine(GameSave.SaveFolder(), "characters.txt"));
            SaveStats read = ReadSaveStats();
            if (read != null || !saveThere) shownStats = read;
            SaveStats stats = shownStats;

            // The playtime: every session the launcher saw, the one going on too.
            dayPlay = new int[14];
            int total = 0;
            DateTime first = DateTime.MaxValue;
            List<KeyValuePair<DateTime, int>> sessions = Sessions();
            if (sessionStart != DateTime.MinValue)
                sessions.Add(new KeyValuePair<DateTime, int>(sessionStart, (int)(DateTime.Now - sessionStart).TotalSeconds));
            foreach (KeyValuePair<DateTime, int> session in sessions)
            {
                total += session.Value;
                if (session.Key < first) first = session.Key;
                int day = (session.Key.Date - DateTime.Today.AddDays(-13)).Days;
                if (day >= 0 && day < 14) dayPlay[day] += session.Value;
            }
            statValues[0].Text = total > 0 ? Hours(total) : "—";
            statSubs[0].Text = first != DateTime.MaxValue
                ? "since " + first.ToString("MMM d", System.Globalization.CultureInfo.InvariantCulture) : "not seen yet";

            for (int i = 1; i < StatKeys.Length; i++)
            {
                statValues[i].Text = stats != null ? Count(stats.Total(StatKeys[i])) : "—";
                statSubs[i].Text = "";
            }
            if (stats != null && stats.Total("runs") > 0)
                statSubs[2].Text = (100.0 * stats.Total("wins") / stats.Total("runs")).ToString("0.#", System.Globalization.CultureInfo.InvariantCulture) + "% of runs";
            if (stats != null && stats.Total("runs") > 0)
                statSubs[3].Text = Count(stats.Total("kills") / stats.Total("runs")) + " a run";

            achCount.Text = stats != null ? stats.Achievements.Count + " earned" : "";
            collectionLine.Text = stats == null
                ? (saveThere ? "The save could not be read just now; it is read again each time this tab opens."
                    : "No save yet in " + GameSave.SaveFolder() + ": play the game once first.")
                : "Collection:  " + stats.Items + " pieces of gear  ·  " + stats.Seen + " jewels seen in the codex  ·  " +
                  stats.Pets + (stats.Pets == 1 ? " pet" : " pets") + "  ·  " + stats.Tabards + (stats.Tabards == 1 ? " tabard" : " tabards") +
                  "  ·  " + stats.Heroes.Count + (stats.Heroes.Count == 1 ? " hero" : " heroes");
            playChart.Invalidate();
            achList.Invalidate();
            classGrid.Invalidate();
        }

        static string DayHours(int seconds)
        {
            if (seconds < 3600) return Math.Max(1, seconds / 60) + "m";
            return (seconds / 3600.0).ToString("0.#", System.Globalization.CultureInfo.InvariantCulture) + "h";
        }

        const TextFormatFlags TextOnly = TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;

        // A bar a day, today's in bright gold, its time over it.
        void DrawPlayChart(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.ScaleTransform(ui, ui);
            int max = 3600, sum = 0;
            foreach (int seconds in dayPlay) { if (seconds > max) max = seconds; sum += seconds; }
            int slot = (W(playChart) - 14) / 14;
            int floor = H(playChart) - 22, top = 20;
            using (Font small = new Font("Segoe UI", 7f))
            using (Brush bar = new SolidBrush(Color.FromArgb(178, 140, 30)))
            using (Brush today = new SolidBrush(Gold))
            using (Brush empty = new SolidBrush(Color.FromArgb(70, 64, 50)))
            {
                for (int i = 0; i < 14; i++)
                {
                    DateTime day = DateTime.Today.AddDays(i - 13);
                    int x = 7 + i * slot;
                    int height = dayPlay[i] <= 0 ? 0 : Math.Max(2, (int)((floor - top) * (double)dayPlay[i] / max));
                    if (height > 0)
                    {
                        g.FillRectangle(i == 13 ? today : bar, x + 4, floor - height, slot - 8, height);
                        Txt(g, DayHours(dayPlay[i]), small, new Rectangle(x - 6, floor - height - 14, slot + 12, 12),
                            TextColor, TextOnly | TextFormatFlags.HorizontalCenter);
                    }
                    else g.FillRectangle(empty, x + 4, floor - 1, slot - 8, 1);
                    Txt(g, day.Day.ToString(), small, new Rectangle(x, floor + 5, slot, 12),
                        i == 13 ? Gold : Muted, TextOnly | TextFormatFlags.HorizontalCenter);
                }
            }
            if (sum == 0)
                Txt(g, "No game sessions seen yet. The launcher counts the time the game runs while it is open or in the tray.",
                    BaseFont, new Rectangle(16, 8, W(playChart) - 32, floor - 12), Muted,
                    TextOnly | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.WordBreak);
        }

        // The newest achievements, their dates beside them.
        void DrawAchievements(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.ScaleTransform(ui, ui);
            SaveStats stats = shownStats;
            if (stats == null || stats.Achievements.Count == 0)
            {
                Txt(g, stats == null ? "No save read yet." : "None yet: they come with your runs.", BaseFont,
                    new Rectangle(0, 0, W(achList), H(achList)), Muted, TextOnly | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
                return;
            }
            List<string> ids = new List<string>(stats.Achievements);
            ids.Sort(delegate (string a, string b) { return stats.When(b).CompareTo(stats.When(a)); });
            using (Font small = new Font("Segoe UI", 8f))
            {
                Rectangle area = new Rectangle(0, 4, W(achList) - 4, H(achList) - 8);
                Scrolled(g, achScrolls, "achievements", area, delegate (Graphics inner)
                {
                    int y = area.Y + 2;
                    foreach (string id in ids)
                    {
                        long when = stats.When(id);
                        string date = when > 0
                            ? new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).AddSeconds(when).ToLocalTime().ToString("MMM d", System.Globalization.CultureInfo.InvariantCulture)
                            : "";
                        Txt(inner, date, small, new Rectangle(10, y + 2, 52, 16), Muted, TextOnly);
                        Txt(inner, AchievementName(id), BaseFont, new Rectangle(62, y, W(achList) - 76, 18), TextColor,
                            TextOnly | TextFormatFlags.EndEllipsis);
                        y += 21;
                    }
                    return y;
                });
            }
        }

        // A row a class, a column a zone: gold where the zone's final boss fell
        // to that class; the talent points it has spent at the right.
        void DrawClassGrid(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.ScaleTransform(ui, ui);
            SaveStats stats = shownStats;
            const int nameWidth = 84, talentWidth = 72, headHeight = 20, rowHeight = 15;
            int column = (W(classGrid) - nameWidth - talentWidth) / ZoneIds.Length;
            using (Font small = new Font("Segoe UI", 7.5f))
            using (Brush stripe = new SolidBrush(Color.FromArgb(29, 27, 23)))
            using (Brush beat = new SolidBrush(Color.FromArgb(214, 170, 40)))
            using (Pen open = new Pen(Color.FromArgb(84, 76, 60)))
            {
                for (int z = 0; z < ZoneIds.Length; z++)
                    Txt(g, ZoneShort[z], small, new Rectangle(nameWidth + z * column - 6, 4, column + 12, 14), Muted,
                        TextOnly | TextFormatFlags.HorizontalCenter);
                Txt(g, "Talents", small, new Rectangle(W(classGrid) - talentWidth, 4, talentWidth - 10, 14), Muted,
                    TextOnly | TextFormatFlags.Right);
                for (int c = 0; c < ClassIds.Length; c++)
                {
                    int y = headHeight + c * rowHeight;
                    if (c % 2 == 0) g.FillRectangle(stripe, 0, y, W(classGrid), rowHeight);
                    int id = ClassIds[c];
                    bool hero = stats != null && stats.Heroes.Contains(id);
                    Txt(g, ClassNames[c], small, new Rectangle(10, y + 1, nameWidth - 12, rowHeight - 2),
                        hero ? ClassColors[c] : Color.FromArgb(104, 98, 86), TextOnly);
                    HashSet<string> zones = null;
                    if (stats != null) stats.Beat.TryGetValue(id, out zones);
                    for (int z = 0; z < ZoneIds.Length; z++)
                    {
                        Rectangle cell = new Rectangle(nameWidth + z * column + 6, y + 3, column - 12, rowHeight - 6);
                        if (zones != null && zones.Contains(ZoneIds[z])) g.FillRectangle(beat, cell);
                        else g.DrawRectangle(open, cell.X, cell.Y, cell.Width - 1, cell.Height - 1);
                    }
                    int points = 0;
                    if (stats != null) stats.TalentPoints.TryGetValue(id, out points);
                    Txt(g, points > 0 ? points + " / 51" : "—", small,
                        new Rectangle(W(classGrid) - talentWidth, y + 1, talentWidth - 10, rowHeight - 2),
                        points >= 51 ? Gold : points > 0 ? TextColor : Muted, TextOnly | TextFormatFlags.Right);
                }
            }
        }

        // The numbers beside Play: today's playtime and the last session the
        // launcher saw (the one going on counted too), the save's runs and wins.
        void ShowStrip()
        {
            List<KeyValuePair<DateTime, int>> sessions = Sessions();
            int today = 0;
            DateTime last = DateTime.MinValue;
            foreach (KeyValuePair<DateTime, int> session in sessions)
            {
                if (session.Key.Date == DateTime.Today) today += session.Value;
                DateTime end = session.Key.AddSeconds(session.Value);
                if (end > last) last = end;
            }
            if (sessionStart != DateTime.MinValue)
            {
                today += (int)(DateTime.Now - (sessionStart.Date == DateTime.Today ? sessionStart : DateTime.Today)).TotalSeconds;
                last = DateTime.Now;
            }
            stripValues[0].Text = Hours(today);
            stripValues[1].Text = sessionStart != DateTime.MinValue ? "now" : last == DateTime.MinValue ? "—"
                : last.Date == DateTime.Today ? "today" : last.Date == DateTime.Today.AddDays(-1) ? "yesterday"
                : last.ToString("MMM d", System.Globalization.CultureInfo.InvariantCulture);
            SaveStats stats = ReadSaveStats();
            if (stats != null)
            {
                stripValues[2].Text = Count(stats.Total("runs"));
                stripValues[3].Text = Count(stats.Total("wins"));
            }
        }

        // --- Run History ------------------------------------------------------------

        readonly ComboBox runClass = new ComboBox();
        readonly ComboBox runResult = new ComboBox();
        readonly Label runCount = new Label();
        readonly ListView runList = new ListView();
        readonly Canvas runDetail = new Canvas();
        List<RunRecord> runs = new List<RunRecord>();
        string runsNote = "";       // why there are none, when there are none
        string runsFile;            // the file read, and its time then: read again only once it changes
        DateTime runsStamp;
        RunRecord shownRun;
        bool fillingRuns;
        string detailTab = "overview";      // the run's detail: "overview" or "build"
        static readonly Rectangle overviewTabAt = new Rectangle(10, 6, 100, 24), buildTabAt = new Rectangle(114, 6, 100, 24),
            statsTabAt = new Rectangle(218, 6, 100, 24);
        string runsKeep = "all";    // Survivor UI's Keep setting, as read
        readonly CheckBox keepWins = new CheckBox();
        bool showingKeep;

        void BuildRunsPage(Panel page)
        {
            Caption(page, "Show", 20, 12);
            DarkCombo(runClass);
            runClass.Location = new Point(62, 8);
            runClass.Size = new Size(140, 24);
            runClass.Items.Add("All classes");
            foreach (string name in ClassNames) runClass.Items.Add(name);
            runClass.SelectedIndex = 0;
            runClass.SelectedIndexChanged += delegate { FillRuns(); };
            page.Controls.Add(runClass);

            DarkCombo(runResult);
            runResult.Location = new Point(210, 8);
            runResult.Size = new Size(130, 24);
            runResult.Items.AddRange(new object[] { "All results", "Victories", "Deaths", "Left early" });
            runResult.SelectedIndex = 0;
            runResult.SelectedIndexChanged += delegate { FillRuns(); };
            page.Controls.Add(runResult);

            runCount.AutoSize = true;
            runCount.ForeColor = Muted;
            runCount.Location = new Point(352, 12);
            page.Controls.Add(runCount);
            // Survivor UI's own Keep setting (Options, Run History), from here.
            keepWins.Text = "Keep only victories and endless";
            keepWins.AutoSize = true;
            keepWins.FlatStyle = FlatStyle.Flat;
            keepWins.FlatAppearance.BorderColor = TickEdge;
            keepWins.Cursor = Cursors.Hand;
            keepWins.Location = new Point(510, 10);
            page.Controls.Add(keepWins);
            TickLook(keepWins);
            keepWins.CheckedChanged += delegate { KeepWinsChanged(); };
            tips.SetToolTip(keepWins, "Only here, in the launcher: the list keeps your victories and the runs gone on in endless mode.\n" +
                "The game's own Run History keeps what its options say (Survivor UI's Options, Run History).");

            // The runs, newest first; one picked is shown under them.
            runList.View = View.Details;
            runList.FullRowSelect = true;
            runList.MultiSelect = false;
            runList.HideSelection = false;
            runList.HeaderStyle = ColumnHeaderStyle.Nonclickable;
            runList.BackColor = Panel;
            runList.ForeColor = TextColor;
            runList.BorderStyle = BorderStyle.FixedSingle;
            runList.Location = new Point(20, 38);
            runList.Size = new Size(720, 124);
            runList.Columns.Add("When", 96);
            runList.Columns.Add("Hero", 92);
            runList.Columns.Add("Class", 70);
            runList.Columns.Add("Zone", 132);
            runList.Columns.Add("Result", 64);
            runList.Columns.Add("Time", 56, HorizontalAlignment.Right);
            runList.Columns.Add("Kills", 62, HorizontalAlignment.Right);
            runList.Columns.Add("DPS", 62, HorizontalAlignment.Right);
            runList.Columns.Add("Level", 46, HorizontalAlignment.Right);
            runList.OwnerDraw = true;
            typeof(Control).GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(runList, true, null);
            runList.DrawColumnHeader += delegate (object sender, DrawListViewColumnHeaderEventArgs e)
            {
                using (Brush back = new SolidBrush(Color.FromArgb(30, 29, 26))) e.Graphics.FillRectangle(back, e.Bounds);
                using (Pen line = new Pen(RuleColor))
                    e.Graphics.DrawLine(line, e.Bounds.Left, e.Bounds.Bottom - 1, e.Bounds.Right, e.Bounds.Bottom - 1);
                Rectangle words = new Rectangle(e.Bounds.X + S(4), e.Bounds.Y, e.Bounds.Width - S(8), e.Bounds.Height);
                TextRenderer.DrawText(e.Graphics, e.Header.Text, runList.Font, words, Muted, TextOnly | TextFormatFlags.VerticalCenter |
                    (e.Header.TextAlign == HorizontalAlignment.Right ? TextFormatFlags.Right : TextFormatFlags.Left));
            };
            runList.DrawItem += delegate (object sender, DrawListViewItemEventArgs e) { };
            runList.DrawSubItem += delegate (object sender, DrawListViewSubItemEventArgs e)
            {
                Rectangle bounds = e.Bounds;
                if (e.ColumnIndex == 0) bounds.Width = runList.Columns[0].Width;
                // The class's bar sits on the dark even on the run picked, so its
                // white words keep reading; the rest of the row goes gold.
                bool classBar = (e.ColumnIndex <= 2 || e.ColumnIndex == 4) && e.Item.Tag is RunRecord;
                using (Brush back = new SolidBrush(e.Item.Selected && !classBar ? Color.FromArgb(62, 54, 22) : Panel)) e.Graphics.FillRectangle(back, bounds);
                Rectangle words = new Rectangle(bounds.X + S(4), bounds.Y, bounds.Width - S(8), bounds.Height);
                TextFormatFlags flags = TextOnly | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis |
                    (runList.Columns[e.ColumnIndex].TextAlign == HorizontalAlignment.Right ? TextFormatFlags.Right : TextFormatFlags.Left);
                RunRecord run = e.Item.Tag as RunRecord;
                if (e.ColumnIndex == 4 && run != null)
                {
                    Rectangle bar = new Rectangle(bounds.X + S(1), bounds.Y + S(2), bounds.Width - S(4), bounds.Height - S(4));
                    Color color = e.SubItem.ForeColor;
                    using (Brush wash = new SolidBrush(Color.FromArgb(115, color))) e.Graphics.FillRectangle(wash, bar);
                    using (Pen edge = new Pen(Color.FromArgb(e.Item.Selected ? 230 : 153, color)))
                        e.Graphics.DrawRectangle(edge, bar.X, bar.Y, bar.Width - 1, bar.Height - 1);
                    Rectangle shadowed = words;
                    shadowed.Offset(1, 1);
                    TextRenderer.DrawText(e.Graphics, e.SubItem.Text, runList.Font, shadowed, Color.FromArgb(10, 6, 4), flags);
                    TextRenderer.DrawText(e.Graphics, e.SubItem.Text, runList.Font, words, Color.White, flags);
                    return;
                }
                if (e.ColumnIndex <= 2 && run != null)
                {
                    // When, hero and class: one bar in the class's colour, as the
                    // build's rows (a wash of it, its border, the words white);
                    // stronger on the run picked.
                    Color color = ClassColor(run.Str("classKey"));
                    Rectangle bar = new Rectangle(bounds.X, bounds.Y + S(2), bounds.Width, bounds.Height - S(4));
                    if (e.ColumnIndex == 0)
                    {
                        bar.X += S(2);
                        bar.Width -= S(2);
                    }
                    if (e.ColumnIndex == 2) bar.Width -= S(3);
                    using (Brush wash = new SolidBrush(Color.FromArgb(e.Item.Selected ? 138 : 115, color))) e.Graphics.FillRectangle(wash, bar);
                    using (Pen edge = new Pen(Color.FromArgb(e.Item.Selected ? 230 : 153, color)))
                    {
                        e.Graphics.DrawLine(edge, bar.Left, bar.Top, bar.Right - 1, bar.Top);
                        e.Graphics.DrawLine(edge, bar.Left, bar.Bottom - 1, bar.Right - 1, bar.Bottom - 1);
                        if (e.ColumnIndex == 0) e.Graphics.DrawLine(edge, bar.Left, bar.Top, bar.Left, bar.Bottom - 1);
                        if (e.ColumnIndex == 2) e.Graphics.DrawLine(edge, bar.Right - 1, bar.Top, bar.Right - 1, bar.Bottom - 1);
                    }
                    Rectangle shadow = words;
                    shadow.Offset(1, 1);
                    TextRenderer.DrawText(e.Graphics, e.SubItem.Text, runList.Font, shadow, Color.FromArgb(10, 6, 4), flags);
                    TextRenderer.DrawText(e.Graphics, e.SubItem.Text, runList.Font, words, Color.White, flags);
                    return;
                }
                TextRenderer.DrawText(e.Graphics, e.SubItem.Text, runList.Font, words, e.SubItem.ForeColor, flags);
            };
            runList.SelectedIndexChanged += delegate
            {
                if (fillingRuns) return;
                shownRun = runList.SelectedItems.Count > 0 ? (RunRecord)runList.SelectedItems[0].Tag : null;
                moment = "endless";
                detailScrolls.Reset();
                runDetail.Invalidate();
            };
            page.Controls.Add(runList);

            runDetail.Location = new Point(20, 176);
            runDetail.Size = new Size(720, 252);
            runDetail.MouseClick += delegate (object sender, MouseEventArgs e)
            {
                Point at = new Point((int)(e.X / ui), (int)(e.Y / ui));
                string picked = overviewTabAt.Contains(at) ? "overview" : buildTabAt.Contains(at) ? "build" : statsTabAt.Contains(at) ? "stats" : null;
                if (picked != null && picked != detailTab)
                {
                    detailTab = picked;
                    detailScrolls.Reset();
                    runDetail.Invalidate();
                }
                bool twoMoments = shownRun != null && shownRun.Table("endless") != null;
                string when = !twoMoments ? null : victoryAt.Contains(at) ? "victory" : endlessAt.Contains(at) ? "endless" : null;
                if (when != null && when != moment)
                {
                    moment = when;
                    detailScrolls.Reset();
                    runDetail.Invalidate();
                }
            };
            runDetail.MouseMove += delegate (object sender, MouseEventArgs e)
            {
                Point at = new Point((int)(e.X / ui), (int)(e.Y / ui));
                bool onTab = shownRun != null && (overviewTabAt.Contains(at) || buildTabAt.Contains(at) || statsTabAt.Contains(at) ||
                    (shownRun.Table("endless") != null && (victoryAt.Contains(at) || endlessAt.Contains(at))));
                runDetail.Cursor = onTab ? Cursors.Hand : Cursors.Default;
            };
            runDetail.BackColor = Panel;
            runDetail.Paint += DrawRunDetail;
            Scrollable(runDetail, detailScrolls);
            page.Controls.Add(runDetail);
        }

        // Survivor UI's saved settings, read again when they changed: the game
        // writes them as it goes back to the character screen or closes.
        void ShowRuns()
        {
            string game = GameSettingsFolder();
            string path = game != null ? Path.Combine(Path.Combine(game, "saved"), "SurvivorUI.lua") : null;
            if (path == null || !File.Exists(path))
            {
                runs = new List<RunRecord>();
                runsFile = null;
                runsNote = game == null ? "No game found yet: pick it in the Play tab."
                    : "No runs kept yet. Run History is Survivor UI's: play a run with it on, and once the game goes back to the character screen its runs show here.";
                FillRuns();
                return;
            }
            DateTime stamp = File.GetLastWriteTimeUtc(path);
            if (path == runsFile && stamp == runsStamp)
            {
                if (!runsFilled) FillRuns();
                FitRunColumns();
                return;
            }
            Cursor = Cursors.WaitCursor;
            try
            {
                runs = RunRecord.ReadAll(path, out runsKeep);
                runsNote = runs.Count == 0
                    ? "No runs kept yet. Run History is Survivor UI's: play a run with it on, and once the game goes back to the character screen its runs show here."
                    : "";
                runsFile = path;
                runsStamp = stamp;
            }
            catch (Exception error)
            {
                runs = new List<RunRecord>();
                runsFile = null;
                runsNote = "Could not read Survivor UI's saved settings: " + error.Message;
            }
            finally
            {
                Cursor = Cursors.Default;
            }
            shownRun = null;
            FillRuns();
        }

        static Color ClassColor(string classKey)
        {
            for (int i = 0; i < ClassNames.Length; i++)
                if (string.Equals(ClassNames[i], classKey, StringComparison.OrdinalIgnoreCase)) return ClassColors[i];
            return TextColor;
        }

        static string ResultWord(string result)
        {
            return result == "victory" ? "Victory" : result == "dead" ? "Died" : result == "left" ? "Left" : result;
        }

        static Color ResultColor(string result)
        {
            return result == "victory" ? Color.FromArgb(110, 225, 125) : result == "dead" ? Color.FromArgb(236, 104, 96) : Muted;
        }

        static string Clock(double seconds)
        {
            int total = (int)seconds;
            return total / 60 + ":" + (total % 60).ToString("00");
        }

        // A big number short: 5.23M, 4.68k, 929.
        static string Big(double n)
        {
            System.Globalization.CultureInfo invariant = System.Globalization.CultureInfo.InvariantCulture;
            if (n >= 1000000) return (n / 1000000).ToString("0.##", invariant) + "M";
            if (n >= 1000) return (n / 1000).ToString("0.##", invariant) + "k";
            return Math.Round(n).ToString(invariant);
        }

        static string When(DateTime date)
        {
            return date.ToString(date.Year == DateTime.Now.Year ? "MMM d  HH:mm" : "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
        }

        void ShowKeep()
        {
            showingKeep = true;
            keepWins.Checked = Setting("runsWinsOnly", "0") == "1";
            showingKeep = false;
        }

        // Only in the launcher: its list keeps the victories and the runs gone
        // on in endless mode; the game's Run History keeps by its own options.
        void KeepWinsChanged()
        {
            if (showingKeep) return;
            SetSetting("runsWinsOnly", keepWins.Checked ? "1" : "0");
            shownRun = null;
            FillRuns();
            Status(keepWins.Checked ? "Run History here shows only your victories and endless runs; the game's own keeps by its options."
                : "Run History here shows every run again.");
        }

        // The zone's column takes the width left, so the header has no light
        // end past the last column, with or without a scroll bar.
        void FitRunColumns()
        {
            int others = 0;
            for (int i = 0; i < runList.Columns.Count; i++) if (i != 3) others += runList.Columns[i].Width;
            int row = runList.Items.Count > 0 && runList.IsHandleCreated ? runList.GetItemRect(0).Height : runList.Font.Height + S(6);
            bool scroll = (runList.Items.Count + 1) * row > runList.Height - S(4);
            int inside = runList.Width - 2 * SystemInformation.BorderSize.Width - (scroll ? SystemInformation.VerticalScrollBarWidth : 0);
            runList.Columns[3].Width = Math.Max(S(100), inside - others);
        }

        bool runsFilled;

        void FillRuns()
        {
            runsFilled = true;
            ShowKeep();
            fillingRuns = true;
            runList.BeginUpdate();
            runList.Items.Clear();
            string cls = runClass.SelectedIndex > 0 ? ClassNames[runClass.SelectedIndex - 1] : null;
            string result = new string[] { null, "victory", "dead", "left" }[Math.Max(0, runResult.SelectedIndex)];
            int shown = 0, wins = 0;
            ListViewItem keep = null;
            foreach (RunRecord run in runs)
            {
                if (cls != null && !string.Equals(run.Str("classKey"), cls, StringComparison.OrdinalIgnoreCase)) continue;
                if (result != null && run.Str("result") != result) continue;
                if (keepWins.Checked && run.Str("result") != "victory" && run.Table("endless") == null) continue;
                ListViewItem row = new ListViewItem(run.Num("at") > 0 ? When(Local(run.Num("at"))) : run.Str("when"));
                row.UseItemStyleForSubItems = false;
                row.ForeColor = Muted;
                row.SubItems.Add(run.Str("hero"), TextColor, Panel, runList.Font);
                row.SubItems.Add(run.Str("class"), ClassColor(run.Str("classKey")), Panel, runList.Font);
                row.SubItems.Add(run.Str("zone"), TextColor, Panel, runList.Font);
                Dictionary<object, object> endless = run.Table("endless");
                if (endless != null)
                {
                    row.SubItems.Add("Endless", EndlessColor, Panel, runList.Font);
                    row.SubItems.Add(Clock(RunRecord.NumOf(endless, "time")), TextColor, Panel, runList.Font);
                }
                else
                {
                    row.SubItems.Add(ResultWord(run.Str("result")), ResultColor(run.Str("result")), Panel, runList.Font);
                    row.SubItems.Add(Clock(run.Num("time")), TextColor, Panel, runList.Font);
                }
                row.SubItems.Add(((long)run.Num("kills")).ToString("N0", System.Globalization.CultureInfo.InvariantCulture), TextColor, Panel, runList.Font);
                row.SubItems.Add(Big(run.Num("meterDps")), TextColor, Panel, runList.Font);
                row.SubItems.Add(((int)run.Num("level")).ToString(), Muted, Panel, runList.Font);
                row.Tag = run;
                runList.Items.Add(row);
                if (run == shownRun) keep = row;
                shown++;
                if (run.Str("result") == "victory") wins++;
            }
            if (keep == null && runList.Items.Count > 0) keep = runList.Items[0];
            if (keep != null) keep.Selected = true;
            shownRun = keep != null ? (RunRecord)keep.Tag : null;
            runList.EndUpdate();
            fillingRuns = false;
            runCount.Text = runs.Count == 0 ? "" : shown + (shown == 1 ? " run" : " runs") + "  ·  " + wins + (wins == 1 ? " victory" : " victories");
            FitRunColumns();
            if (keep != null) keep.EnsureVisible();
            runDetail.Invalidate();
        }

        // The run picked: who and where, its numbers, then its damage by spell,
        // its gear, its bosses and how it ended.
        // --- Parts that scroll ------------------------------------------------------

        // Parts of a canvas that scroll on their own (a run's columns, the
        // achievements): each its area as last drawn, in the canvas's old
        // units, its content's height, how far it is scrolled. The wheel over
        // one moves it; a thin bar at its right shows where it is, its thumb
        // dragged.
        class ScrollPart
        {
            public Rectangle Area;
            public int Content, Offset;

            // How far it can scroll (a few units over are let be).
            public int Most
            {
                get { return Content - Area.Height > 6 ? Content - Area.Height : 0; }
            }

            public int Thumb
            {
                get { return Content <= 0 ? Area.Height : Math.Max(16, Area.Height * Area.Height / Math.Max(1, Content)); }
            }
        }

        class ScrollParts
        {
            readonly Dictionary<string, ScrollPart> parts = new Dictionary<string, ScrollPart>();

            public ScrollPart Get(string key)
            {
                ScrollPart part;
                if (!parts.TryGetValue(key, out part)) parts[key] = part = new ScrollPart();
                return part;
            }

            public void Reset()
            {
                foreach (ScrollPart part in parts.Values) part.Offset = 0;
            }

            public ScrollPart At(Point at)
            {
                foreach (ScrollPart part in parts.Values)
                    if (part.Most > 0 && part.Area.Contains(at)) return part;
                return null;
            }
        }

        readonly ScrollParts detailScrolls = new ScrollParts();
        readonly ScrollParts achScrolls = new ScrollParts();

        // A part drawn scrolled within its area: drawn on a picture of the
        // area's own size (the panel's colour under it), moved up by how far
        // it is scrolled, then laid in place, so nothing of it strays out.
        // draw returns where its content ends. While it has more than fits,
        // its bar at its right.
        void Scrolled(Graphics g, ScrollParts parts, string key, Rectangle area, Func<Graphics, int> draw)
        {
            ScrollPart part = parts.Get(key);
            PointF[] corners = { new PointF(area.X, area.Y), new PointF(area.Right, area.Bottom) };
            using (Matrix placed = g.Transform) placed.TransformPoints(corners);
            part.Area = Rectangle.FromLTRB((int)(corners[0].X / ui), (int)(corners[0].Y / ui), (int)(corners[1].X / ui), (int)(corners[1].Y / ui));
            part.Offset = Math.Min(part.Offset, part.Most);
            Rectangle device = Rectangle.FromLTRB((int)Math.Round(corners[0].X), (int)Math.Round(corners[0].Y),
                (int)Math.Round(corners[1].X), (int)Math.Round(corners[1].Y));
            int bottom = area.Bottom;
            if (device.Width > 0 && device.Height > 0)
                using (Bitmap picture = new Bitmap(device.Width, device.Height))
                {
                    using (Graphics inner = Graphics.FromImage(picture))
                    {
                        inner.Clear(InsetBody);
                        inner.ScaleTransform(ui, ui);
                        inner.TranslateTransform(-area.X, -area.Y - part.Offset);
                        bottom = draw(inner);
                    }
                    GraphicsState state = g.Save();
                    g.ResetTransform();
                    g.DrawImageUnscaled(picture, device.X, device.Y);
                    g.Restore(state);
                }
            part.Content = bottom - area.Y + 4;
            if (part.Offset > part.Most) part.Offset = part.Most;
            if (part.Most <= 0) return;
            using (Brush track = new SolidBrush(Color.FromArgb(44, 40, 30)))
                g.FillRectangle(track, area.Right - 3, area.Y, 3, area.Height);
            int thumb = part.Thumb, top = area.Y + (area.Height - thumb) * part.Offset / Math.Max(1, part.Most);
            using (Brush grip = new SolidBrush(Color.FromArgb(196, 182, 96)))
                g.FillRectangle(grip, area.Right - 3, top, 3, thumb);
        }

        // The wheel and the thumb for a canvas's parts.
        void Scrollable(Canvas canvas, ScrollParts parts)
        {
            ScrollPart dragged = null;
            int dragFrom = 0, offsetFrom = 0;
            canvas.MouseEnter += delegate
            {
                if (!canvas.Focused && (Form.ActiveForm == this)) canvas.Focus();
            };
            canvas.MouseWheel += delegate (object sender, MouseEventArgs e)
            {
                ScrollPart part = parts.At(new Point((int)(e.X / ui), (int)(e.Y / ui)));
                if (part == null) return;
                int steps = Math.Max(1, Math.Abs(e.Delta) / 120);
                part.Offset = Math.Max(0, Math.Min(part.Most, part.Offset - Math.Sign(e.Delta) * 48 * steps));
                canvas.Invalidate();
            };
            canvas.MouseDown += delegate (object sender, MouseEventArgs e)
            {
                if (e.Button != MouseButtons.Left) return;
                Point at = new Point((int)(e.X / ui), (int)(e.Y / ui));
                ScrollPart part = parts.At(at);
                if (part == null || at.X < part.Area.Right - 12) return;
                dragged = part;
                dragFrom = at.Y;
                offsetFrom = part.Offset;
            };
            canvas.MouseMove += delegate (object sender, MouseEventArgs e)
            {
                if (dragged == null) return;
                int travel = Math.Max(1, dragged.Area.Height - dragged.Thumb);
                int y = (int)(e.Y / ui);
                dragged.Offset = Math.Max(0, Math.Min(dragged.Most, offsetFrom + (y - dragFrom) * dragged.Most / travel));
                canvas.Invalidate();
            };
            canvas.MouseUp += delegate { dragged = null; };
        }

        // --- A run's detail -----------------------------------------------------------

        // The moment shown of a run won and gone on in endless mode: "endless"
        // (the whole run as it ended) or "victory" (as it stood at the
        // victory); a run without endless has only its own.
        string moment = "endless";
        static readonly Rectangle victoryAt = new Rectangle(466, 6, 120, 24), endlessAt = new Rectangle(590, 6, 120, 24);
        static readonly Color EndlessColor = Color.FromArgb(204, 143, 255);

        // The run's record for the moment shown.
        RunRecord Moment(RunRecord run)
        {
            Dictionary<object, object> endless = run.Table("endless");
            if (endless == null || moment != "endless") return run;
            RunRecord end = new RunRecord();
            end.Data = endless;
            return end;
        }

        void DrawRunDetail(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.ScaleTransform(ui, ui);
            int width = W(runDetail);
            RunRecord run = shownRun;
            if (run == null)
            {
                Txt(g, runs.Count == 0 ? runsNote : "Pick a run above to see it here.", BaseFont,
                    new Rectangle(24, 0, width - 48, H(runDetail)), Muted,
                    TextOnly | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.WordBreak);
                return;
            }
            System.Globalization.CultureInfo invariant = System.Globalization.CultureInfo.InvariantCulture;
            Dictionary<object, object> endless = run.Table("endless");
            RunRecord view = Moment(run);
            using (Font title = new Font("Segoe UI", 11f, FontStyle.Bold))
            using (Font head = new Font("Segoe UI", 8.5f, FontStyle.Bold))
            using (Font small = new Font("Segoe UI", 8f))
            using (Pen line = new Pen(Color.FromArgb(70, 62, 46)))
            {
                // The detail's tabs, as the window's: stone, the open one red;
                // at the right, the run's two moments when it went on in
                // endless mode.
                foreach (string tab in new string[] { "overview", "build", "stats" })
                {
                    Rectangle at = tab == "overview" ? overviewTabAt : tab == "build" ? buildTabAt : statsTabAt;
                    Plate(g, at, tab == "overview" ? "Overview" : tab == "build" ? "Build" : "Stats", tab == detailTab, head);
                }
                if (endless != null)
                {
                    Plate(g, victoryAt, "Victory  " + Clock(run.Num("time")), moment == "victory", head, FellColor);
                    Plate(g, endlessAt, "Endless  " + Clock(RunRecord.NumOf(endless, "time")), moment == "endless", head, EndlessColor);
                }
                g.TranslateTransform(0, 32);
                string hero = run.Str("hero");
                int x = 10;
                Txt(g, hero, title, new Point(x, 6), ClassColor(run.Str("classKey")), TextOnly);
                x += MeasureW(g, hero, title, TextOnly) + 10;
                string mods = run.Str("mods");
                string who = "Level " + (int)view.Num("level") + " " + run.Str("race") + " " + run.Str("class") + "  ·  " + run.Str("zone") +
                    (mods != "" && mods != "normal" ? "  ·  " + mods : "");
                Txt(g, who, BaseFont, new Rectangle(x, 9, width - x - 190, 18), Muted, TextOnly | TextFormatFlags.EndEllipsis);
                bool showingEnd = view != run;
                string end = showingEnd ? "Endless  " + Clock(view.Num("time")) : ResultWord(run.Str("result")) + "  " + Clock(run.Num("time"));
                Txt(g, end, title, new Rectangle(width - 190, 6, 180, 22), showingEnd ? EndlessColor : ResultColor(run.Str("result")),
                    TextOnly | TextFormatFlags.Right);

                // The moment's numbers; at the endless end, what the endless
                // part added to the victory's beside them.
                int looted = RunRecord.List(view.Table("loot")).Count, fresh = 0;
                foreach (Dictionary<object, object> item in RunRecord.List(view.Table("loot")))
                    if (RunRecord.Field(item, "new") is bool && (bool)RunRecord.Field(item, "new")) fresh++;
                Func<string, string> more = delegate (string key)
                {
                    if (!showingEnd) return "";
                    double added = view.Num(key) - run.Num(key);
                    return added > 0 ? " (+" + (key == "dealt" || key == "taken" ? Big(added) : ((long)added).ToString("N0", invariant)) + ")" : "";
                };
                string numbers = ((long)view.Num("kills")).ToString("N0", invariant) + more("kills") + " kills  ·  " + Big(view.Num("meterDps")) + " DPS  ·  " +
                    Big(view.Num("dealt")) + more("dealt") + " damage  ·  " + Big(view.Num("taken")) + " taken  ·  " +
                    ((long)view.Num("gold")).ToString("N0", invariant) + more("gold") + " gold  ·  " + (int)view.Num("bosses") + " bosses  ·  " +
                    (int)view.Num("guardians") + " guardians  ·  " + (int)view.Num("elites") + " elites  ·  " +
                    looted + " looted" + (fresh > 0 ? ", " + fresh + " new" : "");
                Txt(g, numbers, small, new Rectangle(10, 32, width - 20, 16), TextColor, TextOnly | TextFormatFlags.EndEllipsis);

                g.DrawLine(line, 10, 52, width - 10, 52);
                int bottom = H(runDetail) - 32 - 8;
                if (detailTab == "stats")
                {
                    Rectangle whole = new Rectangle(10, 58, width - 20, bottom - 58);
                    Scrolled(g, detailScrolls, "stats", whole, delegate (Graphics inner) { return DrawStats(inner, view, whole, head, small); });
                }
                else if (detailTab == "build")
                {
                    g.DrawLine(line, 470, 60, 470, bottom);
                    Rectangle left = new Rectangle(10, 58, 450, bottom - 58), right = new Rectangle(482, 58, 228, bottom - 58);
                    Scrolled(g, detailScrolls, "build", left, delegate (Graphics inner) { return DrawBuild(inner, view, left, head, small); });
                    Scrolled(g, detailScrolls, "build-gear", right, delegate (Graphics inner) { return DrawGear(inner, view, right, head, small); });
                }
                else
                {
                    g.DrawLine(line, 254, 60, 254, bottom);
                    g.DrawLine(line, 500, 60, 500, bottom);
                    Rectangle one = new Rectangle(10, 58, 234, bottom - 58), two = new Rectangle(264, 58, 228, bottom - 58),
                        three = new Rectangle(510, 58, 200, bottom - 58);
                    Scrolled(g, detailScrolls, "sources", one, delegate (Graphics inner) { return DrawSources(inner, view, one, head, small); });
                    Scrolled(g, detailScrolls, "gear", two, delegate (Graphics inner) { return DrawGear(inner, view, two, head, small); });
                    Scrolled(g, detailScrolls, "end", three, delegate (Graphics inner) { return DrawEnd(inner, view, three, head, small); });
                }
            }
        }

        // A plate of the detail: stone, red with gold words when chosen.
        void Plate(Graphics g, Rectangle at, string words, bool chosen, Font font)
        {
            if (chosen) Slice3(g, Art("button-red"), at, 31, 31);
            else Slice3(g, Art("button-stone"), at, 22, 20);
            Rectangle shadow = at;
            shadow.Offset(1, 1);
            TextFormatFlags flags = TextOnly | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter;
            Txt(g, words, font, shadow, Color.FromArgb(6, 4, 2), flags);
            Txt(g, words, font, at, chosen ? Gold : StoneText, flags);
        }

        // A moment's plate in its own colour (Victory green, Endless purple):
        // the stone washed with it, strong when chosen, its words white then,
        // in the colour when not.
        void Plate(Graphics g, Rectangle at, string words, bool chosen, Font font, Color color)
        {
            string tint = color == FellColor ? "green" : "purple";
            Slice3(g, ArtAs("button-red", chosen ? tint : tint + "-dim"), at, 31, 31);
            Rectangle shadow = at;
            shadow.Offset(1, 1);
            TextFormatFlags flags = TextOnly | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter;
            Txt(g, words, font, shadow, Color.FromArgb(6, 4, 2), flags);
            Txt(g, words, font, at, chosen ? Color.White : Shade(color, 0.35f), flags);
        }

        // A row as the game's Run History paints it: a wash of the colour over
        // the dark, a border of it.
        static void RowBar(Graphics g, Rectangle at, Color color, int wash, int edge)
        {
            using (Brush fill = new SolidBrush(Color.FromArgb(wash, color))) g.FillRectangle(fill, at);
            if (edge > 0)
                using (Pen line = new Pen(Color.FromArgb(edge, color))) g.DrawRectangle(line, at.X, at.Y, at.Width - 1, at.Height - 1);
        }

        static readonly Color FellColor = Color.FromArgb(110, 225, 125);

        // The run's stats as the game's Stats panel groups them (CharacterPane.lua's
        // SECTIONS): each group in its colour, each number as the panel writes
        // it, and what the gear gave of it beside it; only the numbers above 0.
        class StatRow
        {
            public string Label, Gear, GearFormat;
            public Func<Dictionary<object, object>, double> Value;     // the number as shown, to be above 0
            public Func<Dictionary<object, object>, string> Text;
            public string GearTotal, GearHow;
        }

        class StatGroup
        {
            public string Title;
            public Color Color;
            public List<StatRow> Rows = new List<StatRow>();
        }

        static double Stat(Dictionary<object, object> stats, string key)
        {
            return RunRecord.NumOf(stats, key);
        }

        static string Pct(double value)
        {
            return Math.Round(value * 100).ToString("+0;-0;0", System.Globalization.CultureInfo.InvariantCulture) + "%";
        }

        static string Fixed(double value, string format)
        {
            return value.ToString(format, System.Globalization.CultureInfo.InvariantCulture);
        }

        static StatRow Row(string label, Func<Dictionary<object, object>, double> value, Func<Dictionary<object, object>, string> text)
        {
            StatRow row = new StatRow();
            row.Label = label;
            row.Value = value;
            row.Text = text;
            return row;
        }

        static StatRow Geared(StatRow row, string gear, string total, string how, string format)
        {
            row.Gear = gear;
            row.GearTotal = total;
            row.GearHow = how;
            row.GearFormat = format;
            return row;
        }

        static StatGroup StatSet(string title, Color color, params StatRow[] rows)
        {
            StatGroup group = new StatGroup();
            group.Title = title;
            group.Color = color;
            group.Rows.AddRange(rows);
            return group;
        }

        static readonly StatGroup[] StatGroups = {
            StatSet("Offense", Color.FromArgb(255, 115, 64),
                Geared(Row("Crit", s => Stat(s, "crit"), s => Fixed(Stat(s, "crit") * 100, "0.0") + "%"), "gcrit", "crit", null, null),
                Geared(Row("Crit Dmg", s => Stat(s, "cm"), s => Fixed(Stat(s, "cm") * 100, "0") + "%"), "gcm", null, null, null),
                Geared(Row("Damage", s => Stat(s, "dmg") - 1, s => Pct(Stat(s, "dmg") - 1)), "gdmg", "dmg", "less1", null),
                Geared(Row("Haste", s => 1 - Stat(s, "cd"), s => Pct(1 - Stat(s, "cd"))), "gcd", "cd", "from1", null),
                Geared(Row("Echo", s => Stat(s, "echo"), s => Fixed(Stat(s, "echo") * 100, "0") + "%"), "gecho", "echo", null, null)),
            StatSet("Defense", Color.FromArgb(77, 166, 255),
                Geared(Row("Health", s => Stat(s, "hp"), s => Fixed(Stat(s, "hp"), "0")), "ghp", "hp", null, "+0"),
                Geared(Row("Regen", s => Stat(s, "reg"), s => Fixed(Stat(s, "reg"), "0.0")), "greg", "reg", null, "+0.0"),
                Row("Lifesteal", s => Stat(s, "lch"), s => Fixed(Stat(s, "lch") * 100, "0.0") + "%"),
                Geared(Row("Armor", s => Stat(s, "arm"), s => Fixed(Stat(s, "arm") * 100, "0") + "%"), "garm", "arm", null, null),
                Row("Kill Heal", s => Stat(s, "heal"), s => Fixed(Stat(s, "heal"), "0")),
                Row("Thorns", s => Stat(s, "thn"), s => Fixed(Stat(s, "thn") * 100, "0") + "%"),
                Row("Lives", s => Stat(s, "liv"), s => Fixed(Stat(s, "liv"), "0"))),
            StatSet("Reach", Color.FromArgb(184, 115, 255),
                Geared(Row("Area", s => Stat(s, "area") - 1, s => Pct(Stat(s, "area") - 1)), "garea", "area", "less1", null),
                Geared(Row("Targets", s => Stat(s, "cnt"), s => "+" + Fixed(Stat(s, "cnt"), "0")), "gcnt", "cnt", null, "+0"),
                Geared(Row("Pickup", s => Stat(s, "pick"), s => Fixed(Stat(s, "pick"), "0") + " yd"), "gpick", null, null, null)),
            StatSet("Utility", Color.FromArgb(89, 230, 140),
                Geared(Row("Speed", s => Stat(s, "spd") - 1, s => Pct(Stat(s, "spd") - 1)), "gspd", "spd", "less1", null),
                Row("Experience", s => Stat(s, "xp") - 1, s => Pct(Stat(s, "xp") - 1)),
                Geared(Row("Gold", s => Stat(s, "gold") - 1, s => Pct(Stat(s, "gold") - 1)), "ggold", "gold", "less1", null),
                Row("Luck", s => Stat(s, "luck"), s => Pct(Stat(s, "luck"))),
                Row("Buff Power", s => Stat(s, "bp"), s => Pct(Stat(s, "bp")))),
            StatSet("Damage over time", Color.FromArgb(64, 217, 217),
                Row("DoT Stacks", s => Stat(s, "dots"), s => Fixed(Stat(s, "dots"), "0")),
                Row("DoT Haste", s => Stat(s, "doth"), s => Pct(Stat(s, "doth")))),
            StatSet("Bonus damage", Color.FromArgb(255, 209, 0),
                Row("Vs Elites", s => Stat(s, "big"), s => Pct(Stat(s, "big"))),
                Row("Execute", s => Stat(s, "exe"), s => Pct(Stat(s, "exe"))),
                Row("Vs Controlled", s => Stat(s, "cc"), s => Pct(Stat(s, "cc"))),
                Row("Vs Afflicted", s => Stat(s, "dotd"), s => Pct(Stat(s, "dotd"))),
                Row("Shielded", s => Stat(s, "shd"), s => Pct(Stat(s, "shd"))),
                Row("Melee", s => Stat(s, "auto"), s => Pct(Stat(s, "auto"))),
                Row("Pet Damage", s => Stat(s, "pet"), s => Pct(Stat(s, "pet")))),
        };

        // What the gear gave of a number, as the game's pane tells it
        // (CharacterPane.lua, SurvivorUI_StatGear); null when nothing.
        static string GearPart(StatRow row, Dictionary<object, object> stats)
        {
            if (row.Gear == null) return null;
            double value = Stat(stats, row.Gear);
            if (Math.Abs(value) < 0.0001) return null;
            if (row.GearFormat != null) return Fixed(value, row.GearFormat);
            double share = value * 100;
            return share.ToString(Math.Abs(share - Math.Round(share)) > 0.05 ? "+0.0;-0.0" : "+0;-0", System.Globalization.CultureInfo.InvariantCulture) + "%";
        }

        // Three columns of groups; a group shows only with a number above 0.
        int DrawStats(Graphics g, RunRecord run, Rectangle area, Font head, Font small)
        {
            Dictionary<object, object> stats = run.Table("stats");
            if (stats == null)
            {
                Txt(g, "No stats kept with this run.", small, new Point(area.X, area.Y + 2), Muted, TextOnly);
                return area.Y + 20;
            }
            int columns = 3, gap = 14;
            int width = (area.Width - (columns - 1) * gap - 8) / columns;
            int[] heights = new int[columns];
            int bottom = area.Y;
            foreach (StatGroup group in StatGroups)
            {
                List<StatRow> shown = new List<StatRow>();
                foreach (StatRow row in group.Rows)
                    if (row.Value(stats) > 0.0001) shown.Add(row);
                if (shown.Count == 0) continue;
                int column = 0;
                for (int c = 1; c < columns; c++) if (heights[c] < heights[column]) column = c;
                int x = area.X + column * (width + gap), y = area.Y + heights[column];
                RowBar(g, new Rectangle(x, y, width, 18), group.Color, 115, 178);
                Shadowed(g, group.Title, head, new Rectangle(x + 5, y + 1, width - 10, 16), Color.White, TextOnly | TextFormatFlags.VerticalCenter);
                y += 22;
                foreach (StatRow row in shown)
                {
                    Txt(g, row.Label, small, new Rectangle(x + 5, y, width - 10, 15), TextColor, TextOnly);
                    string gear = GearPart(row, stats);
                    int gearWidth = gear != null ? 64 : 0;
                    Txt(g, row.Text(stats), small, new Rectangle(x, y, width - 6 - gearWidth, 15), Color.White, TextOnly | TextFormatFlags.Right);
                    if (gear != null)
                        Txt(g, "gear " + gear, small, new Rectangle(x + width - 6 - gearWidth, y, gearWidth, 15), Muted, TextOnly | TextFormatFlags.Right);
                    y += 16;
                }
                y += 8;
                heights[column] = y - area.Y;
                bottom = Math.Max(bottom, y);
            }
            return bottom;
        }

        // The run's build: each spell in its slot with its rank, its cooldown
        // and its range as they were, the racial marked. Returns where it ends.
        int DrawBuild(Graphics g, RunRecord run, Rectangle area, Font head, Font small)
        {
            Txt(g, "Build", head, new Point(area.X, area.Y), Gold, TextOnly);
            double xp = run.Num("talentXp");
            if (xp > 0)
                Txt(g, ((long)xp).ToString("N0", System.Globalization.CultureInfo.InvariantCulture) + " talent experience from this run",
                    small, new Rectangle(area.X + 120, area.Y + 1, area.Width - 128, 15), Muted, TextOnly | TextFormatFlags.Right);
            int[] columns = { 0, 250, 310, 384 };
            string[] names = { "Spell", "Rank", "Cooldown", "Range" };
            for (int c = 0; c < names.Length; c++)
                Txt(g, names[c], small, new Rectangle(area.X + columns[c], area.Y + 18, 80, 14), Muted, TextOnly);
            List<Dictionary<object, object>> spells = RunRecord.List(run.Table("build"));
            int y = area.Y + 35;
            if (spells.Count == 0)
            {
                Txt(g, "None kept.", small, new Point(area.X, y), Muted, TextOnly);
                y += 16;
            }
            foreach (Dictionary<object, object> spell in spells)
            {
                bool racial = RunRecord.Field(spell, "racial") is bool && (bool)RunRecord.Field(spell, "racial");
                string name = RunRecord.Field(spell, "name") as string ?? "";
                Color color = ColorOf(RunRecord.Field(spell, "color"), TextColor);
                RowBar(g, new Rectangle(area.X, y, area.Width - 8, 17), color, racial ? 18 : 115, racial ? 0 : 153);
                Color words = racial ? Readable(color) : Color.White, more = racial ? Muted : Color.FromArgb(232, 232, 232);
                Shadowed(g, name, small, new Rectangle(area.X + 4, y + 1, 200, 15), words, TextOnly | TextFormatFlags.EndEllipsis);
                if (racial)
                {
                    int after = area.X + 4 + Math.Min(200, MeasureW(g, name, small, TextOnly)) + 6;
                    Txt(g, "racial", small, new Rectangle(after, y + 1, 60, 15), Muted, TextOnly);
                }
                double rank = RunRecord.NumOf(spell, "rank");
                Shadowed(g, rank > 0 ? ((int)rank).ToString() : "", small, new Rectangle(area.X + columns[1], y + 1, 50, 15), words, TextOnly);
                Shadowed(g, RunRecord.Field(spell, "cd") as string ?? "", small, new Rectangle(area.X + columns[2], y + 1, 70, 15), more, TextOnly);
                Shadowed(g, RunRecord.Field(spell, "range") as string ?? "", small, new Rectangle(area.X + columns[3], y + 1, 60, 15), more, TextOnly);
                y += 20;
            }
            return y;
        }

        static Color ColorOf(object value, Color fallback)
        {
            Dictionary<object, object> rgb = value as Dictionary<object, object>;
            if (rgb != null)
                return Color.FromArgb(Channel(RunRecord.NumOf(rgb, 1.0)), Channel(RunRecord.NumOf(rgb, 2.0)), Channel(RunRecord.NumOf(rgb, 3.0)));
            string hex = value as string;
            int argb;
            if (hex != null && hex.Length == 8 && int.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out argb))
                return Color.FromArgb(255, Color.FromArgb(argb));
            return fallback;
        }

        static int Channel(double value)
        {
            return Math.Max(0, Math.Min(255, (int)Math.Round(value * 255)));
        }

        // A colour lifted a little toward white, to read on the dark panel.
        static Color Readable(Color color)
        {
            if (color.R + color.G + color.B >= 300) return color;
            return Color.FromArgb((color.R + 255) / 2, (color.G + 255) / 2, (color.B + 255) / 2);
        }

        // The damage by spell as the game's meter draws it: each bar in the
        // spell's own colour, full and bright, lighter at its top; the words
        // white over it with a shadow.
        int DrawSources(Graphics g, RunRecord run, Rectangle area, Font head, Font small)
        {
            Txt(g, "Damage by spell", head, new Point(area.X, area.Y), Gold, TextOnly);
            List<Dictionary<object, object>> sources = RunRecord.List(run.Table("sources"));
            int y = area.Y + 20;
            if (sources.Count == 0)
            {
                Txt(g, "None kept.", small, new Point(area.X, y + 2), Muted, TextOnly);
                return y + 18;
            }
            foreach (Dictionary<object, object> source in sources)
            {
                double share = RunRecord.NumOf(source, "share");
                Color color = ColorOf(RunRecord.Field(source, "color"), Muted);
                Rectangle bar = new Rectangle(area.X, y + 1, Math.Max(4, (int)((area.Width - 6) * Math.Min(1, share))), 17);
                using (Brush back = new SolidBrush(Color.FromArgb(30, 28, 25))) g.FillRectangle(back, area.X, y + 1, area.Width - 6, 17);
                RowBar(g, bar, color, 115, 153);
                string name = RunRecord.Field(source, "name") as string ?? "";
                double rank = RunRecord.NumOf(source, "rank");
                string words = name + (rank > 0 ? "  R" + (int)rank : "");
                string right = Big(RunRecord.NumOf(source, "dmg")) + "   " + Math.Round(share * 100) + "%";
                Rectangle left = new Rectangle(area.X + 4, y + 2, area.Width - 92, 15), number = new Rectangle(area.Right - 92, y + 2, 82, 15);
                Shadowed(g, words, small, left, Color.White, TextOnly | TextFormatFlags.EndEllipsis);
                Shadowed(g, right, small, number, Color.White, TextOnly | TextFormatFlags.Right);
                y += 19;
            }
            return y;
        }

        void Shadowed(Graphics g, string text, Font font, Rectangle at, Color color, TextFormatFlags flags)
        {
            Rectangle shadow = at;
            shadow.Offset(1, 1);
            Txt(g, text, font, shadow, Color.FromArgb(10, 6, 4), flags);
            Txt(g, text, font, at, color, flags);
        }

        int DrawGear(Graphics g, RunRecord run, Rectangle area, Font head, Font small)
        {
            Txt(g, "Jewelry", head, new Point(area.X, area.Y), Gold, TextOnly);
            List<Dictionary<object, object>> gear = RunRecord.List(run.Table("gear"));
            int y = area.Y + 20;
            if (gear.Count == 0)
            {
                Txt(g, "None worn.", small, new Point(area.X, y + 2), Muted, TextOnly);
                return y + 18;
            }
            foreach (Dictionary<object, object> piece in gear)
            {
                string label = (RunRecord.Field(piece, "label") as string ?? "").Trim();
                int space = label.IndexOf(' ');
                if (space > 0) label = label.Substring(0, space);
                string name = RunRecord.Field(piece, "name") as string ?? "";
                Rectangle row = new Rectangle(area.X, y, area.Width - 8, 29);
                if (name == "")
                {
                    RowBar(g, row, Color.FromArgb(128, 128, 140), 15, 38);
                    Txt(g, label, small, new Rectangle(area.X + 4, y + 2, 50, 14), Color.FromArgb(115, 115, 128), TextOnly);
                    Txt(g, "empty", small, new Rectangle(area.X + 54, y + 2, area.Width - 62, 14), Color.FromArgb(102, 102, 115), TextOnly);
                    y += 33;
                    continue;
                }
                RowBar(g, row, ColorOf(RunRecord.Field(piece, "color"), TextColor), 115, 178);
                Shadowed(g, label, small, new Rectangle(area.X + 4, y + 2, 50, 14), Color.White, TextOnly);
                Shadowed(g, name, small, new Rectangle(area.X + 54, y + 1, area.Width - 62, 15), Color.White, TextOnly | TextFormatFlags.EndEllipsis);
                Shadowed(g, RunRecord.Field(piece, "tags") as string ?? "", small, new Rectangle(area.X + 54, y + 14, area.Width - 62, 14),
                    Color.FromArgb(236, 236, 236), TextOnly | TextFormatFlags.EndEllipsis);
                y += 33;
            }
            return y;
        }

        int DrawEnd(Graphics g, RunRecord run, Rectangle area, Font head, Font small)
        {
            int y = area.Y;
            Txt(g, "Bosses", head, new Point(area.X, y), Gold, TextOnly);
            y += 20;
            Dictionary<object, object> tracker = run.Table("tracker");
            List<Dictionary<object, object>> bosses = RunRecord.List(RunRecord.Field(tracker, "bosses"));
            if (bosses.Count == 0)
            {
                Txt(g, "None kept.", small, new Point(area.X, y), Muted, TextOnly);
                y += 16;
            }
            foreach (Dictionary<object, object> boss in bosses)
            {
                // Its state: dead (when it fell), up (alive as the run ended),
                // due (not come yet: when it would have).
                string state = RunRecord.Field(boss, "state") as string;
                bool dead = state == "dead", due = state == "due";
                bool final = RunRecord.Field(boss, "final") is bool && (bool)RunRecord.Field(boss, "final");
                Txt(g, RunRecord.Field(boss, "name") as string ?? "", small, new Rectangle(area.X, y, area.Width - 70, 14),
                    dead ? FellColor : due ? Muted : final ? Gold : TextColor, TextOnly | TextFormatFlags.EndEllipsis);
                Txt(g, dead ? Clock(RunRecord.NumOf(boss, "fell")) : due ? "due " + Clock(RunRecord.NumOf(boss, "at")) : "alive", small,
                    new Rectangle(area.Right - 70, y, 64, 14), dead ? FellColor : due ? Muted : Color.FromArgb(236, 104, 96), TextOnly | TextFormatFlags.Right);
                y += 16;
            }
            y += 6;

            // How it ended: the blows before a death, the party's damage, and
            // the run's biggest hits.
            Dictionary<object, object> death = run.Table("death");
            List<Dictionary<object, object>> party = RunRecord.List(run.Table("party"));
            if (death != null)
            {
                Txt(g, "Death", head, new Point(area.X, y), Gold, TextOnly);
                y += 20;
                Dictionary<string, double> byWho = new Dictionary<string, double>();
                Dictionary<string, int> hits = new Dictionary<string, int>();
                string killer = null;
                double soonest = double.MaxValue;
                foreach (Dictionary<object, object> hit in RunRecord.List(RunRecord.Field(death, "hits")))
                {
                    string who = RunRecord.Field(hit, "who") as string ?? "?";
                    double amount = RunRecord.NumOf(hit, "amount"), ago = RunRecord.NumOf(hit, "ago");
                    double sum;
                    byWho.TryGetValue(who, out sum);
                    byWho[who] = sum + amount;
                    int count;
                    hits.TryGetValue(who, out count);
                    hits[who] = count + 1;
                    if (ago < soonest) { soonest = ago; killer = who; }
                }
                if (killer != null)
                {
                    Txt(g, "Killed by " + killer, small, new Rectangle(area.X, y, area.Width - 6, 14),
                        Color.FromArgb(236, 104, 96), TextOnly | TextFormatFlags.EndEllipsis);
                    y += 16;
                }
                List<string> attackers = new List<string>(byWho.Keys);
                attackers.Sort(delegate (string a, string b) { return byWho[b].CompareTo(byWho[a]); });
                foreach (string attacker in attackers)
                {
                    Txt(g, attacker + "  ×" + hits[attacker], small, new Rectangle(area.X, y, area.Width - 50, 14),
                        TextColor, TextOnly | TextFormatFlags.EndEllipsis);
                    Txt(g, Big(byWho[attacker]), small, new Rectangle(area.Right - 50, y, 44, 14), Muted, TextOnly | TextFormatFlags.Right);
                    y += 16;
                }
                y += 6;
            }
            if (party.Count > 0)
            {
                Txt(g, "Party", head, new Point(area.X, y), Gold, TextOnly);
                y += 20;
                foreach (Dictionary<object, object> member in party)
                {
                    Txt(g, RunRecord.Field(member, "name") as string ?? "", small, new Rectangle(area.X, y, area.Width - 66, 14),
                        ClassColor(RunRecord.Field(member, "class") as string), TextOnly | TextFormatFlags.EndEllipsis);
                    Txt(g, Big(RunRecord.NumOf(member, "dps")) + " DPS", small, new Rectangle(area.Right - 66, y, 60, 14),
                        Muted, TextOnly | TextFormatFlags.Right);
                    y += 16;
                }
                y += 6;
            }
            List<Dictionary<object, object>> crits = RunRecord.List(run.Table("crits"));
            if (crits.Count > 0)
            {
                Txt(g, "Biggest hits", head, new Point(area.X, y), Gold, TextOnly);
                y += 20;
                foreach (Dictionary<object, object> crit in crits)
                {
                    RowBar(g, new Rectangle(area.X, y, area.Width - 8, 17), ColorOf(RunRecord.Field(crit, "color"), Muted), 115, 153);
                    Shadowed(g, RunRecord.Field(crit, "ability") as string ?? "", small, new Rectangle(area.X + 4, y + 1, area.Width - 62, 15),
                        Color.White, TextOnly | TextFormatFlags.EndEllipsis);
                    Shadowed(g, Big(RunRecord.NumOf(crit, "amount")), small, new Rectangle(area.Right - 60, y + 1, 48, 15),
                        Color.White, TextOnly | TextFormatFlags.Right);
                    y += 20;
                }
            }
            return y;
        }

        // A drop-down drawn dark like the rest, its picked line in gold.
        static void DarkCombo(ComboBox box)
        {
            box.DropDownStyle = ComboBoxStyle.DropDownList;
            box.FlatStyle = FlatStyle.Flat;
            box.BackColor = Panel;
            box.ForeColor = TextColor;
            box.DrawMode = DrawMode.OwnerDrawFixed;
            box.ItemHeight = (int)Math.Round(18 * planned);
            box.DrawItem += delegate (object sender, DrawItemEventArgs e)
            {
                bool edit = (e.State & DrawItemState.ComboBoxEdit) != 0;
                bool hot = !edit && (e.State & DrawItemState.Selected) != 0;
                using (Brush back = new SolidBrush(hot ? Color.FromArgb(62, 54, 22) : Panel)) e.Graphics.FillRectangle(back, e.Bounds);
                if (e.Index < 0) return;
                TextRenderer.DrawText(e.Graphics, box.Items[e.Index].ToString(), box.Font,
                    new Rectangle(e.Bounds.X + 3, e.Bounds.Y, e.Bounds.Width - 3, e.Bounds.Height),
                    hot ? Gold : TextColor, TextOnly | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
            };
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
            tray.Text = "Azeroth SurvivorUI Launcher";
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
                tray.ShowBalloonTip(5000, "Azeroth SurvivorUI Launcher",
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

        // --- The game's save ---------------------------------------------------

        // What the zip's note says of the launcher and the game.
        string SaveNote()
        {
            string exe = GameExePath();
            Version game = exe != null ? GameVersionOf(exe) : null;
            return "Azeroth SurvivorUI Launcher " + Short(OwnVersion) + ", game " + (game != null ? game.ToString() : "unknown");
        }

        // The game's own folder (its settings), or null with no game.
        string GameSettingsFolder()
        {
            string exe = GameExePath();
            if (exe == null) return null;
            string folder = GameDataFolder(exe);
            return Directory.Exists(folder) ? folder : null;
        }

        // A name on the Desktop not taken yet.
        static string FreeName(string folder, string stem)
        {
            string path = Path.Combine(folder, stem + ".zip");
            for (int n = 2; File.Exists(path); n++) path = Path.Combine(folder, stem + "-" + n + ".zip");
            return path;
        }

        void BackUpSave()
        {
            string save = GameSave.SaveFolder();
            if (!GameSave.HasSave(save))
            {
                Ask(this, "No save found in:\n\n" + save + "\n\nPlay the game once first.",
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (GameRunning())
            {
                Ask(this, "Close the game first: it writes your save as you play and as it closes.",
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            string folder = ChosenFolder();
            Cursor = Cursors.WaitCursor;
            try
            {
                Directory.CreateDirectory(folder);
                string zip = FreeName(folder, "AzerothSurvivors-save-" + DateTime.Now.ToString("yyyy-MM-dd_HHmm"));
                GameSave.Backup(save, GameSettingsFolder(), zip, SaveNote());
                RememberBackup(zip);
                Status("Save backed up: " + zip);
                ShowBackups();
            }
            catch (Exception error)
            {
                Status("Could not back up the save: " + error.Message);
                Ask(this, "Could not back up the save into:\n" + folder + "\n\n" + error.Message, "Survivor UI",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                Cursor = Cursors.Default;
            }
        }

        // A save put in the game: the zip given, or one picked (from the place
        // backups go).
        void RestoreSave(string zip)
        {
            if (zip == null)
            {
                using (OpenFileDialog dialog = new OpenFileDialog())
                {
                    dialog.Title = "Pick a save to put in the game";
                    dialog.Filter = "Azeroth Survivors save (*.zip)|*.zip";
                    string folder = ChosenFolder();
                    dialog.InitialDirectory = Directory.Exists(folder) ? folder : GameSave.Desktop();
                    if (dialog.ShowDialog(this) != DialogResult.OK) return;
                    zip = dialog.FileName;
                }
            }
            bool hasSettings;
            string problem = GameSave.Check(zip, out hasSettings);
            if (problem != null)
            {
                Ask(this, "That zip is not a save made by the launcher:\n\n" + problem,
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (GameRunning())
            {
                Ask(this, "Close the game first: it writes your save as you play and as it closes, " +
                    "and would write over the one put in.", "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            string save = GameSave.SaveFolder();
            string game = GameSettingsFolder();
            string ask = "Put this save in the game?\n\n" + zip +
                "\n\nYour heroes, their gear, talents and unlocks become the ones in it. " +
                "Your save as it is now is kept on the Desktop first.";
            bool withSettings = false;
            if (hasSettings && game != null)
            {
                DialogResult choice = Ask(this, ask +
                    "\n\nIt also carries the game's settings and the addons' (key bindings, chat windows, " +
                    "layout, Run History). Take those too?\n\nYes: the save and the settings.\nNo: the save only.",
                    "Survivor UI", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
                if (choice == DialogResult.Cancel) return;
                withSettings = choice == DialogResult.Yes;
            }
            else if (Ask(this, ask, "Survivor UI", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            {
                return;
            }
            Cursor = Cursors.WaitCursor;
            string kept = null;
            try
            {
                // What is there now, kept first: nothing is put in if this fails.
                if (GameSave.HasSave(save) || (withSettings && game != null))
                {
                    kept = FreeName(GameSave.Desktop(), "AzerothSurvivors-save-before-restore-" + DateTime.Now.ToString("yyyy-MM-dd_HHmm"));
                    GameSave.Backup(save, game, kept, SaveNote());
                    RememberBackup(kept);
                }
                GameSave.Restore(zip, save, game, withSettings);
                Status("Save put in" + (withSettings ? ", with its settings" : "") + ". Start the game to play it.");
                Ask(this, "The save is in the game" + (withSettings ? ", with its settings" : "") + "." +
                    (kept != null ? "\n\nYour save from before is kept on the Desktop:\n" + kept : ""),
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception error)
            {
                Status("Could not put the save in: " + error.Message);
                Ask(this, "Could not put the save in:\n\n" + error.Message +
                    (kept != null && File.Exists(kept) ? "\n\nYour save from before is on the Desktop:\n" + kept : ""),
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                Cursor = Cursors.Default;
                if (currentTab == 2) ShowSaveTab();
            }
        }

        void Play()
        {
            string exe = GameExePath();
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
            DialogResult go = Ask(this,
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
            if (IsHandleCreated) NoteFolders(false);
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
            // No border: the header moves the window, as a title bar would.
            if (m.Msg == 0x84 && m.Result == (IntPtr)1)
            {
                long at = m.LParam.ToInt64();
                if (HeaderHit(new Point((short)(at & 0xFFFF), (short)((at >> 16) & 0xFFFF)))) m.Result = (IntPtr)2;
            }
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
            updateWaiting = known && installed != null && Newer(latest.Tag, installed) && AddonOn(folderBox.Text, "SurvivorUI");
            bool current = known && installed != null && !updateWaiting;
            tray.Icon = updateWaiting ? (trayUpdateIcon ?? tray.Icon) : (trayIcon ?? tray.Icon);
            tray.Text = updateWaiting ? Trim("Survivor UI " + latest.Tag + " is out: click to update", 63)
                : current ? "Azeroth SurvivorUI Launcher: up to date" : "Azeroth SurvivorUI Launcher";
            installItem.Enabled = updateWaiting && !installing;
            // Play, or Get the game while there is none: by the AddOns folder,
            // nor in its usual place.
            bool missing = GameMissing();
            bool behind = !missing && GameBehind();
            bool playable = !installing && !gettingGame && GameExePath() != null;
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
                if (!behind) note = "(ver. " + game.Version + ")";
                else if (game.Latest != game.Version) note = "(ver. " + game.Version + " → " + game.Latest + ")";
                else note = "(ver. " + game.Version + ", new data)";
            }
            if (note != playNote)
            {
                playNote = note;
                playButton.Padding = Padding.Empty;
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
            addonLabel.ForeColor = updateWaiting ? Color.FromArgb(110, 225, 125) : installed == null ? Muted : VersionYellow;
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

        // A tick as the pack's switch: green on the left when on, red on the
        // right when off; its words gold when on, grey when off. The whole tick
        // is drawn here (the switch at any scale, the words beside it); the
        // mouse on it lights the switch.
        void TickLook(CheckBox box)
        {
            bool hot = false;
            Action words = delegate { box.ForeColor = box.Checked ? TickText : Muted; };
            words();
            box.Padding = new Padding(0, 0, 24, 0);
            typeof(Control).GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(box, true, null);
            box.CheckedChanged += delegate { words(); box.Invalidate(); };
            box.MouseEnter += delegate { hot = true; box.Invalidate(); };
            box.MouseLeave += delegate { hot = false; box.Invalidate(); };
            box.Paint += delegate (object sender, PaintEventArgs e)
            {
                Graphics g = e.Graphics;
                ButtonRenderer.DrawParentBackground(g, box.ClientRectangle, box);
                int h = Math.Min(box.Height - 2, S(20));
                int w = (int)Math.Round(h * 83f / 52f);
                Rectangle at = new Rectangle(0, (box.Height - h) / 2, w, h);
                Bitmap art = ArtAs(box.Checked ? "switch-on" : "switch-off", !box.Enabled ? "grey" : hot ? "hot" : null);
                if (art != null) DrawArt(g, art, at);
                else using (Brush plain = new SolidBrush(box.Checked ? Color.FromArgb(90, 140, 50) : Color.FromArgb(120, 30, 30))) g.FillRectangle(plain, at);
                Rectangle text = new Rectangle(at.Right + S(6), 0, Math.Max(0, box.Width - at.Right - S(6)), box.Height);
                TextRenderer.DrawText(g, box.Text, box.Font, text, box.Enabled ? box.ForeColor : Color.FromArgb(90, 90, 86),
                    TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);
            };
        }

        static void Style(Button button, string text)
        {
            button.Text = text;
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderColor = RedEdge;
            button.BackColor = RedFill;
            button.ForeColor = Gold;
            button.Cursor = Cursors.Hand;
            Forge(button);
        }

        void Status(string text)
        {
            if (InvokeRequired) { BeginInvoke(new Action<string>(Status), text); return; }
            statusLabel.Text = text;
        }

        // --- The game's AddOns folder -----------------------------------------

        // The AddOns folder for a game executable: in the game's own folder.
        static string AddonsFor(string exePath)
        {
            return Path.Combine(GameDataFolder(exePath), "AddOns");
        }

        // The folder the game keeps its things in, by its version (read in the
        // game's code, 2026-10-23):
        //   0.112.5 and newer: a benilla-config folder beside the exe, always
        //     (C:\Git\wenilla\benilla-config\benilla-config for the usual
        //     install); an exe whose version is not read and carries no build
        //     path counts as these;
        //   0.112.0 to 0.112.4: the folder they were built from, a worktree on
        //     Aethus' PC, which the exe carries (BuiltDataFolder);
        //   older: C:\Git\wenilla\benilla-config, the folder they were built
        //     from too, which is the exe's own for the usual install.
        static readonly Version BesideFrom = new Version(0, 112, 5);

        static string GameDataFolder(string exePath)
        {
            string dir = Path.GetDirectoryName(exePath);
            Version version = GameVersionOf(exePath);
            string built = BuiltDataFolder(exePath);
            if ((version != null && version >= BesideFrom) || (version == null && built == null))
                return Path.Combine(dir, "benilla-config");
            if (built != null) return built;
            if (string.Equals(Path.GetFileName(dir), "benilla-config", StringComparison.OrdinalIgnoreCase))
                return dir;
            return Path.Combine(dir, "benilla-config");
        }

        // The older folders the game (0.112.5 and newer) copies into its new
        // one the first time it starts: C:\Git\wenilla\benilla-config and each
        // worktree's under C:\Git\wenilla\.claude\worktrees.
        static List<string> LegacyFolders()
        {
            List<string> list = new List<string>();
            list.Add(@"C:\Git\wenilla\benilla-config");
            try
            {
                string worktrees = @"C:\Git\wenilla\.claude\worktrees";
                if (Directory.Exists(worktrees))
                    foreach (string tree in Directory.GetDirectories(worktrees))
                        list.Add(Path.Combine(tree, "benilla-config"));
            }
            catch { }
            return list;
        }

        // The game (0.112.5 and newer) has not started once since: its new
        // folder is not there yet, and an older one holds the player's things.
        // It brings them along itself as it starts, but only while its folder
        // is missing: the launcher makes nothing there until then.
        static bool GameWillBringAlong(string exePath)
        {
            return GameWillBringAlong(exePath, LegacyFolders());
        }

        static bool GameWillBringAlong(string exePath, IEnumerable<string> legacy)
        {
            try
            {
                Version version = GameVersionOf(exePath);
                if (version == null || version < BesideFrom) return false;
                string data = GameDataFolder(exePath);
                if (Directory.Exists(data)) return false;
                foreach (string folder in legacy)
                    if (!SameFolder(folder, data) && (Directory.Exists(Path.Combine(folder, "AddOns")) || Directory.Exists(Path.Combine(folder, "saved"))))
                        return true;
            }
            catch { }
            return false;
        }

        const string FirstStartNote =
            "Azeroth Survivors 0.112.5 and newer keep your addons and settings in a new folder,\n" +
            "and the game moves them there by itself the first time it starts.\n\n" +
            "Click Play once (you can close the game at the menu), then come back:\n" +
            "the launcher will use the new folder from then on.";

        // The game wherever it was found before (by its exe, or by the AddOns
        // folder saved), next to the installer, or in its usual place; its
        // AddOns folder as the game itself has it. No game: the folder saved.
        static string FindAddonsFolder()
        {
            string saved = null;
            try { if (File.Exists(ConfigPath)) saved = File.ReadAllText(ConfigPath).Trim(); }
            catch { }
            string exe = RememberedExe();
            if (exe == null && !string.IsNullOrEmpty(saved)) exe = GameFor(saved);
            if (exe == null)
            {
                string here = AppDomain.CurrentDomain.BaseDirectory;
                foreach (string dir in new[] { here, Path.Combine(here, "benilla-config"), Path.GetDirectoryName(here.TrimEnd('\\')) ?? here, CommonGameFolder })
                {
                    string candidate = Path.Combine(dir, GameExe);
                    if (File.Exists(candidate)) { exe = candidate; break; }
                }
            }
            if (exe != null)
            {
                RememberExe(exe);
                return AddonsFor(exe);
            }
            return !string.IsNullOrEmpty(saved) && Directory.Exists(saved) ? saved : null;
        }

        // The game's exe, kept beside the AddOns folder's note: the AddOns
        // folder no longer says where the game is.
        static string ExeNotePath
        {
            get { return Path.Combine(Path.GetDirectoryName(ConfigPath), "game-exe.txt"); }
        }

        static string RememberedExe()
        {
            try
            {
                if (!File.Exists(ExeNotePath)) return null;
                string exe = File.ReadAllText(ExeNotePath).Trim();
                return File.Exists(exe) ? exe : null;
            }
            catch { return null; }
        }

        static void RememberExe(string exe)
        {
            try { File.WriteAllText(ExeNotePath, exe); } catch { }
        }

        static bool SameFolder(string a, string b)
        {
            try
            {
                return string.Equals(Path.GetFullPath(a).TrimEnd('\\'), Path.GetFullPath(b).TrimEnd('\\'),
                    StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        // --- Where the game keeps its things ----------------------------------

        // The game keeps its AddOns, saved settings and options in a folder
        // named benilla-config. Built as Aethus builds it (the benilla engine's
        // "dev" build), that folder is in the one the exe was built from, a
        // path the exe carries ("<folder>\crates\benilla-formats"), wherever
        // the exe itself sits; a worktree of a checkout found on this PC goes
        // to the checkout's, as the engine does (local_state.rs, shared_root).
        // Up to 0.111 that was C:\Git\wenilla\benilla-config, the exe's own
        // folder; the 0.112 build, made from another folder on his PC, moved it
        // for every player (2026-10-23). Null when the exe carries no such
        // path. Read once per exe (its size and time).
        static readonly Dictionary<string, string> builtFolders = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        static readonly Dictionary<string, Version> gameVersions = new Dictionary<string, Version>(StringComparer.OrdinalIgnoreCase);

        static string BuiltDataFolder(string exePath)
        {
            string key = ReadFacts(exePath);
            if (key == null) return null;
            lock (builtFolders) { string known; return builtFolders.TryGetValue(key, out known) ? known : null; }
        }

        // The game's version as its exe writes it, null when not found.
        static Version GameVersionOf(string exePath)
        {
            string key = ReadFacts(exePath);
            if (key == null) return null;
            lock (builtFolders) { Version known; return gameVersions.TryGetValue(key, out known) ? known : null; }
        }

        // An exe's build path and version read once (by its size and time);
        // the key they are kept by, null when the exe cannot be read.
        static string ReadFacts(string exePath)
        {
            try
            {
                FileInfo info = new FileInfo(exePath);
                if (!info.Exists) return null;
                string key = info.FullName + "|" + info.Length + "|" + info.LastWriteTimeUtc.Ticks;
                lock (builtFolders)
                    if (builtFolders.ContainsKey(key)) return key;
                byte[] data = File.ReadAllBytes(info.FullName);
                string built = ReadBuiltFolder(data);
                Version version = null;
                try
                {
                    string text = VersionIn(data);
                    if (text != null) version = new Version(text);
                }
                catch { }
                lock (builtFolders)
                {
                    builtFolders[key] = built;
                    gameVersions[key] = version;
                }
                return key;
            }
            catch { return null; }
        }

        static string ReadBuiltFolder(byte[] data)
        {
            byte[] mark = System.Text.Encoding.ASCII.GetBytes(@"\crates\benilla-formats");
            for (int at = Find(data, mark, 0); at >= 0; at = Find(data, mark, at + mark.Length))
            {
                // Back from the mark over the path's characters, to its drive.
                int start = at;
                while (start > 0 && at - start < 400 && data[start - 1] >= 0x20 && data[start - 1] < 0x7F) start--;
                string text = System.Text.Encoding.ASCII.GetString(data, start, at - start);
                int drive = text.LastIndexOf(@":\", StringComparison.Ordinal);
                if (drive < 1 || !char.IsLetter(text[drive - 1])) continue;
                string root = text.Substring(drive - 1);
                if (root.IndexOfAny(Path.GetInvalidPathChars()) >= 0) continue;
                return Path.Combine(SharedRoot(root), "benilla-config");
            }
            return null;
        }

        static int Find(byte[] data, byte[] mark, int from)
        {
            if (from >= data.Length) return -1;
            for (int at = Array.IndexOf(data, mark[0], from); at >= 0 && at <= data.Length - mark.Length;
                at = at + 1 < data.Length ? Array.IndexOf(data, mark[0], at + 1) : -1)
            {
                int k = 1;
                while (k < mark.Length && data[at + k] == mark[k]) k++;
                if (k == mark.Length) return at;
            }
            return -1;
        }

        // A linked worktree (its .git a file naming <checkout>\.git\worktrees\
        // <name>) to its checkout, when that is on this PC; else as it is.
        static string SharedRoot(string here)
        {
            try
            {
                string dotGit = Path.Combine(here, ".git");
                string probe = Path.Combine(here, ".probe-identity");
                if (File.Exists(dotGit) && !File.Exists(probe) && !Directory.Exists(probe))
                {
                    string line = File.ReadAllText(dotGit).Trim();
                    if (line.StartsWith("gitdir:", StringComparison.Ordinal))
                    {
                        string gitdir = line.Substring(7).Trim();
                        string dotGitDir = Path.GetDirectoryName(Path.GetDirectoryName(gitdir));
                        string primary = dotGitDir == null ? null : Path.GetDirectoryName(dotGitDir);
                        if (!string.IsNullOrEmpty(primary) && Directory.Exists(primary)) return primary;
                    }
                }
            }
            catch { }
            return here;
        }

        // What a move leaves where it is: the game itself and its data, its
        // logs and pictures, and the folders a move sets aside.
        static readonly string[] StayFolders = { "Data", "WoW", "Logs", "Diagnostics", "Screenshots", "cache" };
        static readonly string[] StayExtensions = { ".exe", ".bak", ".dll", ".pdb", ".dmp", ".mpq", ".zip", ".rar" };

        // The player's things in a folder of the game: its entries but those.
        static List<string> Movable(string from, string game)
        {
            List<string> items = new List<string>();
            if (!Directory.Exists(from)) return items;
            string gameFull = Path.GetFullPath(game).TrimEnd('\\') + "\\";
            foreach (string entry in Directory.GetFileSystemEntries(from))
            {
                string name = Path.GetFileName(entry);
                if (name.StartsWith("moved-", StringComparison.OrdinalIgnoreCase)
                    || name.StartsWith("before-move-", StringComparison.OrdinalIgnoreCase)) continue;
                if (Directory.Exists(entry))
                {
                    if (Array.Exists(StayFolders, delegate (string stay) { return string.Equals(stay, name, StringComparison.OrdinalIgnoreCase); })) continue;
                    // The game's own folder inside this one stays where it is.
                    if (gameFull.StartsWith(Path.GetFullPath(entry).TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase)) continue;
                }
                else if (Array.IndexOf(StayExtensions, Path.GetExtension(name).ToLowerInvariant()) >= 0) continue;
                items.Add(name);
            }
            items.Sort(StringComparer.OrdinalIgnoreCase);
            return items;
        }

        // When a folder of the game last saved the player's settings.
        static DateTime LastSaved(string folder)
        {
            DateTime newest = DateTime.MinValue;
            try
            {
                foreach (string file in new[] { Path.Combine(folder, "saved-variables.lua"), Path.Combine(folder, "config.toml") })
                    if (File.Exists(file) && File.GetLastWriteTime(file) > newest) newest = File.GetLastWriteTime(file);
                string saved = Path.Combine(folder, "saved");
                if (Directory.Exists(saved))
                    foreach (string file in Directory.GetFiles(saved, "*.lua", SearchOption.AllDirectories))
                        if (File.GetLastWriteTime(file) > newest) newest = File.GetLastWriteTime(file);
            }
            catch { }
            return newest;
        }

        static string SavedLine(string folder)
        {
            DateTime last = LastSaved(folder);
            return last == DateTime.MinValue ? "(no settings saved there yet)" : "(settings last saved " + last.ToString("yyyy-MM-dd HH:mm") + ")";
        }

        class FolderPlan
        {
            public string Game;                     // the folder the game keeps its things in
            public string From;                     // another folder of the game still holding the player's, or null
            public List<string> Items = new List<string>();
        }

        // Of the candidates, the one holding the player's AddOns or saved
        // settings that is not the game's folder (the one saved last, of two).
        static FolderPlan PlanFolders(string game, IEnumerable<string> candidates)
        {
            FolderPlan plan = new FolderPlan();
            plan.Game = game;
            DateTime best = DateTime.MinValue;
            foreach (string candidate in candidates)
            {
                if (string.IsNullOrEmpty(candidate) || SameFolder(candidate, game) || !Directory.Exists(candidate)) continue;
                if (!Directory.Exists(Path.Combine(candidate, "AddOns")) && !Directory.Exists(Path.Combine(candidate, "saved"))) continue;
                List<string> items = Movable(candidate, game);
                if (items.Count == 0) continue;
                DateTime stamp = LastSaved(candidate);
                if (plan.From == null || stamp > best)
                {
                    plan.From = candidate;
                    plan.Items = items;
                    best = stamp;
                }
            }
            return plan;
        }

        // The game's folder for the game found, against the folders it used
        // before: the one beside its exe, the usual one, the AddOns folder
        // saved and the one in the box.
        FolderPlan PlanFolders()
        {
            string exe = GameExePath();
            if (exe == null) return null;
            string game = Path.GetDirectoryName(AddonsFor(exe));
            string dir = Path.GetDirectoryName(exe);
            List<string> candidates = new List<string>();
            candidates.Add(string.Equals(Path.GetFileName(dir), "benilla-config", StringComparison.OrdinalIgnoreCase)
                ? dir : Path.Combine(dir, "benilla-config"));
            candidates.Add(CommonGameFolder);
            candidates.AddRange(LegacyFolders());
            try
            {
                if (File.Exists(ConfigPath)) candidates.Add(Path.GetDirectoryName(File.ReadAllText(ConfigPath).Trim().TrimEnd('\\')));
            }
            catch { }
            string box = folderBox.Text.Trim().TrimEnd('\\');
            if (box != "") candidates.Add(Path.GetDirectoryName(box));
            return PlanFolders(game, candidates);
        }

        // The player's things from a folder of the game to the one it uses:
        // each copied over (what the game had made there under the same name
        // set aside first in before-move-<time> there), then the originals
        // set aside in moved-<time> where they were. Nothing is deleted. An
        // addon the game's AddOns folder has already stays as it is: Install
        // may have put a newer one there before the move.
        static void MoveState(string from, string game, List<string> items, string stamp)
        {
            Directory.CreateDirectory(game);
            string keep = Path.Combine(game, "before-move-" + stamp);
            string left = Path.Combine(from, "moved-" + stamp);
            foreach (string name in items)
            {
                string source = Path.Combine(from, name), target = Path.Combine(game, name);
                if (string.Equals(name, "AddOns", StringComparison.OrdinalIgnoreCase) && Directory.Exists(source) && Directory.Exists(target))
                {
                    foreach (string entry in Directory.GetFileSystemEntries(source))
                    {
                        string there = Path.Combine(target, Path.GetFileName(entry));
                        if (Directory.Exists(entry) && Directory.Exists(there)) continue;   // the game's folder has this addon
                        MergeInto(entry, there, Path.Combine(Path.Combine(keep, name), Path.GetFileName(entry)));
                    }
                    continue;
                }
                MergeInto(source, target, Path.Combine(keep, name));
            }
            Directory.CreateDirectory(left);
            foreach (string name in items)
            {
                string source = Path.Combine(from, name), aside = Path.Combine(left, name);
                if (Directory.Exists(source)) Directory.Move(source, aside);
                else if (File.Exists(source)) File.Move(source, aside);
            }
        }

        // A file or folder copied onto another: a file already there copied to
        // keep first; what only the target has stays.
        static void MergeInto(string source, string target, string keep)
        {
            if (File.Exists(source))
            {
                if (Directory.Exists(target))
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(keep));
                    Directory.Move(target, keep);
                }
                else if (File.Exists(target))
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(keep));
                    File.Copy(target, keep, true);
                }
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                File.Copy(source, target, true);
                return;
            }
            if (File.Exists(target))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(keep));
                File.Move(target, keep);
            }
            Directory.CreateDirectory(target);
            foreach (string entry in Directory.GetFileSystemEntries(source))
            {
                string name = Path.GetFileName(entry);
                MergeInto(entry, Path.Combine(target, name), Path.Combine(keep, name));
            }
        }

        // Why the button is there, in its tooltip.
        const string FolderWhy =
            "The game keeps your AddOns, addon settings, key bindings and options in a folder\n" +
            "its exe names. If Aethus' build changes that folder (as the game's 0.112 did),\n" +
            "the game starts from an empty one and your things look gone.\n\n" +
            "This checks which folder the game uses now. If your data is somewhere else,\n" +
            "the launcher makes a backup and moves it to the new place. Nothing is deleted.\n" +
            "Close the game first.";

        // A move worth telling of: the other folder holds an addon, or an
        // addon's saved settings, that the game's folder lacks. (The game
        // writes fresh settings in its new folder as it closes, so dates do
        // not tell: what is missing does.) One copied by hand is not told of
        // again; a click still checks and offers.
        static bool MoveNeeded(FolderPlan plan)
        {
            if (plan == null || plan.From == null) return false;
            try
            {
                string addons = Path.Combine(plan.From, "AddOns");
                if (Directory.Exists(addons))
                    foreach (string addon in Directory.GetDirectories(addons))
                        if (!Directory.Exists(Path.Combine(Path.Combine(plan.Game, "AddOns"), Path.GetFileName(addon)))) return true;
                string saved = Path.Combine(plan.From, "saved");
                if (Directory.Exists(saved))
                    foreach (string file in Directory.GetFiles(saved, "*.lua"))
                        if (!File.Exists(Path.Combine(Path.Combine(plan.Game, "saved"), Path.GetFileName(file)))) return true;
            }
            catch { }
            return false;
        }

        // The folders' button: steel blue, or green while the player's things
        // wait in another folder of the game; the tooltip says where.
        void NoteFolders(bool tell)
        {
            // The AddOns folder as the game has it now (the game may have
            // updated itself since the launcher opened).
            string exe = GameExePath();
            if (exe != null && !installing)
            {
                string addons = AddonsFor(exe);
                if (!SameFolder(folderBox.Text, addons))
                {
                    folderBox.Text = addons;
                    try { File.WriteAllText(ConfigPath, addons); } catch { }
                }
            }
            // The game will bring the player's things along as it first starts:
            // nothing to move by hand, Play first.
            if (exe != null && GameWillBringAlong(exe))
            {
                foldersButton.BackColor = FolderFill;
                foldersButton.ForeColor = FolderText;
                foldersButton.FlatAppearance.BorderColor = FolderEdge;
                folderTip.SetToolTip(foldersButton, FirstStartNote);
                if (tell) Status("Click Play once: the game moves your addons and settings to its new folder by itself.");
                return;
            }
            FolderPlan plan = null;
            try { plan = PlanFolders(); }
            catch { }
            bool waiting = MoveNeeded(plan);
            foldersButton.BackColor = waiting ? MoveFill : FolderFill;
            foldersButton.ForeColor = waiting ? Color.White : FolderText;
            foldersButton.FlatAppearance.BorderColor = waiting ? MoveEdge : FolderEdge;
            foldersButton.FlatAppearance.MouseOverBackColor = waiting ? Color.FromArgb(40, 140, 66) : Color.FromArgb(32, 66, 90);
            foldersButton.FlatAppearance.MouseDownBackColor = foldersButton.FlatAppearance.MouseOverBackColor;
            folderTip.SetToolTip(foldersButton, waiting
                ? "Your data is in:\n" + plan.From + "\n\nThe game now uses:\n" + plan.Game + "\n\nClick to move it there.\n\n" + FolderWhy
                : (plan != null ? "The game uses:\n" + plan.Game + "\n\n" : "") + FolderWhy);
            if (waiting && tell)
                Status("Your addons and settings are in an older folder of the game: click the green button.");
        }

        // The link: the game's folder said, the AddOns folder set to it, and
        // the player's things moved into it from an older one, when asked.
        void CheckFolders()
        {
            if (GameExePath() == null)
            {
                Status("Find the game first: \"Find game...\".");
                return;
            }
            if (GameWillBringAlong(GameExePath()))
            {
                NoteFolders(false);
                Ask(this, FirstStartNote, "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            FolderPlan plan = PlanFolders();
            string addons = Path.Combine(plan.Game, "AddOns");
            if (plan.From == null)
            {
                if (!SameFolder(folderBox.Text, addons))
                {
                    folderBox.Text = addons;
                    try { File.WriteAllText(ConfigPath, addons); } catch { }
                }
                NoteFolders(false);
                Ask(this, "The game keeps its AddOns, saved settings and options in:\n\n" + plan.Game +
                    "\n" + SavedLine(plan.Game) + "\n\nNothing of yours is in another folder of the game: nothing to move.",
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
            DialogResult go = Ask(this,
                "The game keeps its AddOns, saved settings and options in:\n\n" + plan.Game + "\n" + SavedLine(plan.Game) +
                "\n\nYours are in another folder of the game:\n\n" + plan.From + "\n" + SavedLine(plan.From) +
                "\n\nMove them to the game's folder?\n" + string.Join(", ", plan.Items.ToArray()) +
                "\n\nNothing is deleted: what the game has in its folder under those names is kept there in before-move-" + stamp +
                ", and the originals in moved-" + stamp + ", where they are now.",
                "Survivor UI", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            if (go != DialogResult.Yes) return;
            if (GameRunning())
            {
                Ask(this, "Close the game first: it writes its settings as it closes.",
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            Cursor = Cursors.WaitCursor;
            try
            {
                MoveState(plan.From, plan.Game, plan.Items, stamp);
                folderBox.Text = addons;
                try { File.WriteAllText(ConfigPath, addons); } catch { }
                Status("Moved to the game's folder: " + string.Join(", ", plan.Items.ToArray()) + ".");
            }
            catch (Exception error)
            {
                Status("Could not move everything: " + error.Message);
                Ask(this, "Could not move everything: " + error.Message + "\n\nThe originals are still in:\n" + plan.From,
                    "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            finally
            {
                Cursor = Cursors.Default;
            }
            NoteFolders(false);
            ShowInstalled();
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
                    DialogResult go = Ask(this,
                        "It is recommended that " + GameExe + " be inside the game's benilla-config folder, usually:\n\n" +
                        CommonGameFolder + "\n\nThe addons would go to:\n" + AddonsFor(dialog.FileName) +
                        "\n\nUse this place anyway?",
                        "Survivor UI", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
                    if (go != DialogResult.Yes) return;
                }
                RememberExe(dialog.FileName);
                folderBox.Text = AddonsFor(dialog.FileName);
                try { File.WriteAllText(ConfigPath, folderBox.Text); } catch { }
                Status("AddOns folder set.");
                NoteFolders(true);
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
                    (InstalledVersion(folderBox.Text) == null ? "Survivor UI is not in the game's AddOns folder yet."
                    : updateWaiting ? "Survivor UI " + latest.Tag + " is out." : "so is Survivor UI."));
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
            versionLabel.Text = pending != null ? "Launcher ver. " + Short(OwnVersion) + " \u2192 " + Short(pending.InstallerVersion)
                : "Launcher " + Short(OwnVersion) + Stage;
            versionLabel.ForeColor = pending != null ? Color.FromArgb(110, 225, 125) : VersionYellow;
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
                selfButton.BackColor = StoneFill;
                selfButton.FlatAppearance.BorderColor = RedEdge;
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
                tray.ShowBalloonTip(6000, "Azeroth SurvivorUI Launcher " + Short(selfRelease.InstallerVersion) + " is out",
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
                    tray.ShowBalloonTip(5000, "Azeroth SurvivorUI Launcher", "Updated to " + Short(OwnVersion) + ".", ToolTipIcon.Info);
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
        // The game: the one found or picked before, else by the AddOns folder,
        // else in its usual place. Its AddOns folder may be far from it (the
        // game's own folder: BuiltDataFolder).
        string GameExePath()
        {
            string exe = RememberedExe() ?? GameFor(folderBox.Text);
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
            if (text != "" && text != notesBox.Text) notesBox.Text = text;
            ShowGameNews();
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
            gameLabel.Location = found ? new Point(gameCheckButton.Right + S(6), gameCheckButton.Top + S(3)) : new Point(gameCheckButton.Left, gameCheckButton.Top);
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
                    DialogResult go = Ask(this,
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
                RememberExe(Path.Combine(folder, GameExe));
                string addons = AddonsFor(Path.Combine(folder, GameExe));
                // An update to 0.112.5 or newer over a player's older folders:
                // the game brings them along as it first starts, only while its
                // new folder is missing, so nothing is made there now.
                bool bringing = GameWillBringAlong(Path.Combine(folder, GameExe));
                if (!bringing) Directory.CreateDirectory(addons);
                BeginInvoke(new Action(delegate
                {
                    GameProgress(-1, 0, null);
                    folderBox.Text = addons;
                    try { File.WriteAllText(ConfigPath, addons); } catch { }
                    Status("Azeroth Survivors " + plan.Version + " is ready." + (bringing ? " Click Play once." : ""));
                    // Survivor UI next, unless it is there already.
                    if (!bringing && stable != null && stable.ZipUrl != null && InstalledVersion(addons) == null) Install(stable);
                    else Ask(this,
                        "Azeroth Survivors " + plan.Version + " is ready.\n\n" + (bringing ? FirstStartNote : "Click Play."),
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
                    Ask(this, "Could not get the game:\n\n" + error.Message + ".", "Azeroth Survivors", MessageBoxButtons.OK, MessageBoxIcon.Error);
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
            string gameExe = GameExePath();
            if (gameExe != null && GameWillBringAlong(gameExe))
            {
                // A folder made now would stop the game's own copy of the old ones.
                Status("Click Play once first: the game moves your addons and settings to its new folder.");
                Ask(this, FirstStartNote, "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            if (gameExe != null && !SameFolder(folderBox.Text, AddonsFor(gameExe)))
            {
                folderBox.Text = AddonsFor(gameExe);
                try { File.WriteAllText(ConfigPath, folderBox.Text); } catch { }
            }
            string addons = folderBox.Text.Trim();
            if (addons == "" || release == null) { Status("Pick the game first."); return; }
            if (!Directory.Exists(Path.GetDirectoryName(addons.TrimEnd('\\'))))
            {
                // The game's own folder, not made yet (the game makes it as it
                // first starts): made now. Any other, refused.
                string exe = GameExePath();
                if (exe != null && SameFolder(AddonsFor(exe), addons))
                    Directory.CreateDirectory(Path.GetDirectoryName(addons.TrimEnd('\\')));
                else
                {
                    Ask(this, "That folder does not look like the game's: " + addons, "Survivor UI", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
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
                    Ask(this,
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
                    Ask(this, "The install failed:\n\n" + error.Message +
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
    // The game's save, taken whole into a zip and put back from one: the
    // heroes, their gear, talents and unlocks (%APPDATA%\wenilla-rogue: the
    // characters.txt the game keeps sealed, its own backups in Saves beside
    // it, a few of its own settings), and the game's settings and the addons'
    // with them, from the game's own folder (key bindings, chat windows,
    // camera, layout, options, the addons' saved settings and Run History).
    // The seal is the same on every PC, so a save taken here plays on another.
    // The AddOns, the game's data, logs and caches stay out.
    static class GameSave
    {
        // In the zip: the save under one folder, the settings under the other,
        // and a note at the top for whoever opens it.
        const string SaveRoot = "wenilla-rogue/";
        const string SettingsRoot = "benilla-config/";
        const string NoteName = "Azeroth Survivors save.txt";
        // The sealed save's first characters.
        const string Seal = "RSE1:";
        static readonly string[] SettingsFiles = { "config.toml", "saved-variables.lua", "once-buff-durations-on" };
        static readonly string[] SettingsFolders = { "saved", "bindings", "layout", "chat", "camera" };

        // %APPDATA%\wenilla-rogue (SURVIVORUI_SAVE_DIR in its place, for a test).
        public static string SaveFolder()
        {
            string test = Environment.GetEnvironmentVariable("SURVIVORUI_SAVE_DIR");
            if (!string.IsNullOrEmpty(test)) return test;
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "wenilla-rogue");
        }

        // The Desktop (SURVIVORUI_DESKTOP_DIR in its place, for a test).
        public static string Desktop()
        {
            string test = Environment.GetEnvironmentVariable("SURVIVORUI_DESKTOP_DIR");
            if (!string.IsNullOrEmpty(test)) return test;
            return Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        }

        // Documents\Azeroth Survivors saves, the automatic backups' (SURVIVORUI_AUTO_DIR in its place, for a test).
        public static string AutoFolder()
        {
            string test = Environment.GetEnvironmentVariable("SURVIVORUI_AUTO_DIR");
            if (!string.IsNullOrEmpty(test)) return test;
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Azeroth Survivors saves");
        }

        // The oldest automatic backups in a folder go, the newest kept; the
        // ones made by hand are never touched.
        public static void Prune(string folder, int keep)
        {
            List<FileInfo> autos = new List<FileInfo>(new DirectoryInfo(folder).GetFiles("AzerothSurvivors-save-auto-*.zip"));
            autos.Sort(delegate (FileInfo a, FileInfo b) { return b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc); });
            for (int i = keep; i < autos.Count; i++)
            {
                try { autos[i].Delete(); } catch { }
            }
        }

        // The seal's key: public in the community's description of the format.
        static readonly byte[] SealKey = SealKeyBytes();

        static byte[] SealKeyBytes()
        {
            byte[] head = System.Text.Encoding.ASCII.GetBytes("azeroth-survivors/save/v1/");
            byte[] tail = { 0x9c, 0x4e, 0x27, 0xd1, 0x6a, 0xf0, 0x13, 0xb8, 0x5d, 0xe2, 0x71, 0x0c, 0xa9, 0x36, 0xc4, 0x8f };
            byte[] key = new byte[head.Length + tail.Length];
            Buffer.BlockCopy(head, 0, key, 0, head.Length);
            Buffer.BlockCopy(tail, 0, key, head.Length, tail.Length);
            return key;
        }

        static byte[] Join(params byte[][] parts)
        {
            int size = 0;
            foreach (byte[] part in parts) size += part.Length;
            byte[] all = new byte[size];
            int at = 0;
            foreach (byte[] part in parts)
            {
                Buffer.BlockCopy(part, 0, all, at, part.Length);
                at += part.Length;
            }
            return all;
        }

        // The save's text out of its seal ("RSE1:" + base64 of a nonce, the
        // text XORed with HMAC-SHA1 blocks, and an HMAC-SHA1 tag), or null
        // when it is not one or its tag does not match (caught mid-write).
        // Read only: the launcher never seals a save.
        public static string Unseal(string sealedText)
        {
            string text = sealedText.Trim();
            if (!text.StartsWith(Seal, StringComparison.Ordinal)) return null;
            byte[] blob;
            try { blob = Convert.FromBase64String(text.Substring(Seal.Length)); }
            catch (FormatException) { return null; }
            if (blob.Length < 36) return null;
            int size = blob.Length - 36;
            byte[] nonce = new byte[16], body = new byte[size];
            Buffer.BlockCopy(blob, 0, nonce, 0, 16);
            Buffer.BlockCopy(blob, 16, body, 0, size);
            using (System.Security.Cryptography.HMACSHA1 mac = new System.Security.Cryptography.HMACSHA1(SealKey))
            {
                byte[] tag = mac.ComputeHash(Join(System.Text.Encoding.ASCII.GetBytes("tag"), nonce, body));
                for (int i = 0; i < 20; i++)
                    if (tag[i] != blob[16 + size + i]) return null;
                byte[] plain = new byte[size];
                byte[] ks = System.Text.Encoding.ASCII.GetBytes("ks");
                for (int block = 0; block * 20 < size; block++)
                {
                    byte[] stream = mac.ComputeHash(Join(ks, nonce, BitConverter.GetBytes((ulong)block)));
                    for (int i = 0; i < 20 && block * 20 + i < size; i++) plain[block * 20 + i] = (byte)(body[block * 20 + i] ^ stream[i]);
                }
                return System.Text.Encoding.UTF8.GetString(plain);
            }
        }

        public static bool HasSave(string saveFolder)
        {
            return File.Exists(Path.Combine(saveFolder, "characters.txt"));
        }

        // A folder's files into the zip under a root, at their paths below it.
        static int AddFolder(ZipArchive archive, string folder, string root)
        {
            int count = 0;
            if (!Directory.Exists(folder)) return 0;
            foreach (string file in Directory.GetFiles(folder, "*", SearchOption.AllDirectories))
            {
                string inside = file.Substring(folder.Length).TrimStart('\\', '/').Replace('\\', '/');
                archive.CreateEntryFromFile(file, root + inside, CompressionLevel.Optimal);
                count++;
            }
            return count;
        }

        // The save, and the settings when gameFolder is given, into zipPath
        // (written aside first, so a failure leaves no half zip). Says what
        // went in.
        public static string Backup(string saveFolder, string gameFolder, string zipPath, string note)
        {
            if (!HasSave(saveFolder)) throw new IOException("no save in " + saveFolder);
            string part = zipPath + ".part";
            if (File.Exists(part)) File.Delete(part);
            int settings = 0;
            using (ZipArchive archive = ZipFile.Open(part, ZipArchiveMode.Create))
            {
                AddFolder(archive, saveFolder, SaveRoot);
                if (gameFolder != null && Directory.Exists(gameFolder))
                {
                    foreach (string name in SettingsFiles)
                    {
                        string file = Path.Combine(gameFolder, name);
                        if (File.Exists(file))
                        {
                            archive.CreateEntryFromFile(file, SettingsRoot + name, CompressionLevel.Optimal);
                            settings++;
                        }
                    }
                    foreach (string name in SettingsFolders)
                        settings += AddFolder(archive, Path.Combine(gameFolder, name), SettingsRoot + name + "/");
                }
                ZipArchiveEntry entry = archive.CreateEntry(NoteName);
                using (StreamWriter writer = new StreamWriter(entry.Open()))
                {
                    writer.Write("Azeroth Survivors save, taken " + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + " by " + note + ".\r\n\r\n" +
                        "wenilla-rogue: the heroes, their gear, talents and unlocks, with the game's own backups (Saves).\r\n" +
                        (settings > 0 ? "benilla-config: the game's settings and the addons' (key bindings, chat windows, camera, layout, Run History).\r\n" : "") +
                        "\r\nTo put it in the game, on this PC or another: Azeroth SurvivorUI Launcher, \"Restore save...\", with the game closed.\r\n");
                }
            }
            if (File.Exists(zipPath)) File.Delete(zipPath);
            File.Move(part, zipPath);
            return settings > 0
                ? "Your heroes, gear, talents and unlocks, with the game's and the addons' settings."
                : "Your heroes, gear, talents and unlocks (no game folder found for the settings).";
        }

        // Each entry's place under its root; null for one outside the two, or
        // one that would climb out (a "..").
        static string Inside(ZipArchiveEntry entry, string root)
        {
            string name = entry.FullName.Replace('\\', '/');
            if (!name.StartsWith(root, StringComparison.OrdinalIgnoreCase)) return null;
            string rest = name.Substring(root.Length);
            if (rest == "" || rest.EndsWith("/")) return null;
            foreach (string part in rest.Split('/'))
                if (part == ".." || part == "." || part.Contains(":")) return null;
            return rest;
        }

        // Null when the zip is a save (hasSettings: whether it carries the
        // settings too), else why not.
        public static string Check(string zipPath, out bool hasSettings)
        {
            hasSettings = false;
            try
            {
                using (ZipArchive archive = ZipFile.OpenRead(zipPath))
                {
                    ZipArchiveEntry characters = archive.GetEntry(SaveRoot + "characters.txt");
                    if (characters == null) return "it has no " + SaveRoot + "characters.txt.";
                    byte[] head = new byte[Seal.Length];
                    using (Stream stream = characters.Open())
                    {
                        int got = 0;
                        while (got < head.Length)
                        {
                            int n = stream.Read(head, got, head.Length - got);
                            if (n <= 0) break;
                            got += n;
                        }
                    }
                    if (System.Text.Encoding.ASCII.GetString(head) != Seal) return "its characters.txt is not the game's save.";
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        string name = entry.FullName.Replace('\\', '/');
                        if (name.Contains("..")) return "it has a file that climbs out of its folder: " + entry.FullName;
                        if (Inside(entry, SettingsRoot) != null) hasSettings = true;
                    }
                }
                return null;
            }
            catch (Exception error)
            {
                return "it could not be read: " + error.Message;
            }
        }

        // A zip's entries under a root, put in a folder, over what is there.
        static void PutIn(ZipArchive archive, string root, string folder)
        {
            string full = Path.GetFullPath(folder).TrimEnd('\\') + "\\";
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                string rest = Inside(entry, root);
                if (rest == null) continue;
                string target = Path.GetFullPath(Path.Combine(folder, rest.Replace('/', '\\')));
                if (!target.StartsWith(full, StringComparison.OrdinalIgnoreCase)) continue;
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                entry.ExtractToFile(target, true);
            }
        }

        // The zip's save put in saveFolder; its settings in gameFolder too
        // when withSettings. Files the zip does not carry stay as they are.
        // All of it unpacked aside first, so a broken zip touches nothing.
        public static void Restore(string zipPath, string saveFolder, string gameFolder, bool withSettings)
        {
            bool hasSettings;
            string problem = Check(zipPath, out hasSettings);
            if (problem != null) throw new InvalidDataException(problem);
            string staging = Path.Combine(Path.GetTempPath(), "SurvivorSave-" + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff"));
            try
            {
                using (ZipArchive archive = ZipFile.OpenRead(zipPath))
                {
                    PutIn(archive, SaveRoot, Path.Combine(staging, "save"));
                    if (withSettings && hasSettings && gameFolder != null)
                        PutIn(archive, SettingsRoot, Path.Combine(staging, "settings"));
                }
                CopyOver(Path.Combine(staging, "save"), saveFolder);
                if (withSettings && hasSettings && gameFolder != null)
                    CopyOver(Path.Combine(staging, "settings"), gameFolder);
            }
            finally
            {
                try { if (Directory.Exists(staging)) Directory.Delete(staging, true); } catch { }
            }
        }

        static void CopyOver(string from, string to)
        {
            if (!Directory.Exists(from)) return;
            foreach (string file in Directory.GetFiles(from, "*", SearchOption.AllDirectories))
            {
                string target = Path.Combine(to, file.Substring(from.Length).TrimStart('\\'));
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                File.Copy(file, target, true);
            }
        }
    }

    // A panel its owner draws, without flicker.
    class Canvas : Panel
    {
        public Canvas()
        {
            DoubleBuffered = true;
            ResizeRedraw = true;
            SetStyle(ControlStyles.Selectable, true);
            TabStop = false;
        }
    }

    // The save's lines as numbers (Statistics): the account's totals, each
    // class's zones beaten and talent points spent, the achievements and when
    // each came, the collection. Read only.
    class SaveStats
    {
        public readonly Dictionary<string, long> Totals = new Dictionary<string, long>();
        public readonly Dictionary<int, HashSet<string>> Beat = new Dictionary<int, HashSet<string>>();
        public readonly Dictionary<int, int> TalentPoints = new Dictionary<int, int>();
        public readonly HashSet<int> Heroes = new HashSet<int>();
        public readonly List<string> Achievements = new List<string>();
        public readonly Dictionary<string, long> AchievedAt = new Dictionary<string, long>();
        public int Items, Seen, Pets, Tabards;

        public long Total(string key)
        {
            long value;
            return Totals.TryGetValue(key, out value) ? value : 0;
        }

        public long When(string achievement)
        {
            long at;
            return AchievedAt.TryGetValue(achievement, out at) ? at : 0;
        }

        static string[] Entries(string list)
        {
            return list.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
        }

        // "key=number,key=number": each into the table given.
        static void Pairs(string list, Dictionary<string, long> into)
        {
            foreach (string pair in Entries(list))
            {
                int equal = pair.LastIndexOf('=');
                long value;
                if (equal > 0 && long.TryParse(pair.Substring(equal + 1), out value)) into[pair.Substring(0, equal)] = value;
            }
        }

        // The lines: stat|kills=..,gold=..; beat|<class>|zone,zone; talent|<class>|<xp>|key:rank,..;
        // hero|<class>|..; ach|id,id; achat|id=unix time,..; items|; seen|name=n,..; pets|; tabard|.
        public static SaveStats Parse(string text)
        {
            SaveStats stats = new SaveStats();
            foreach (string raw in text.Split('\n'))
            {
                string[] parts = raw.TrimEnd('\r').Split('|');
                if (parts.Length < 2) continue;
                int cls;
                switch (parts[0])
                {
                    case "stat":
                        Pairs(parts[1], stats.Totals);
                        break;
                    case "beat":
                        if (parts.Length >= 3 && int.TryParse(parts[1], out cls)) stats.Beat[cls] = new HashSet<string>(Entries(parts[2]));
                        break;
                    case "talent":
                        if (parts.Length >= 4 && int.TryParse(parts[1], out cls))
                        {
                            int points = 0;
                            foreach (string pair in Entries(parts[3]))
                            {
                                int colon = pair.LastIndexOf(':');
                                int rank;
                                if (colon > 0 && int.TryParse(pair.Substring(colon + 1), out rank)) points += rank;
                            }
                            stats.TalentPoints[cls] = points;
                        }
                        break;
                    case "hero":
                        if (int.TryParse(parts[1], out cls)) stats.Heroes.Add(cls);
                        break;
                    case "ach":
                        stats.Achievements.AddRange(Entries(parts[1]));
                        break;
                    case "achat":
                        Pairs(parts[1], stats.AchievedAt);
                        break;
                    case "items":
                        stats.Items = Entries(parts[1]).Length;
                        break;
                    case "pets":
                        stats.Pets = Entries(parts[1]).Length;
                        break;
                    case "tabard":
                        stats.Tabards = Entries(parts[1]).Length;
                        break;
                    case "seen":
                        Dictionary<string, long> seen = new Dictionary<string, long>();
                        Pairs(parts[1], seen);
                        foreach (long times in seen.Values) if (times > 0) stats.Seen++;
                        break;
                }
            }
            return stats;
        }
    }

    // Survivor UI's saved settings (saved\SurvivorUI.lua) read as data. The
    // game writes them as Lua, names given table constructors of strings,
    // numbers, true, false and nil; only that is read here, and nothing is
    // run. A table comes back as a Dictionary<object, object>, its number
    // keys as doubles.
    class LuaData
    {
        readonly string s;
        int pos;

        LuaData(string text)
        {
            s = text;
        }

        public static Dictionary<string, object> Globals(string text)
        {
            LuaData reader = new LuaData(text);
            Dictionary<string, object> globals = new Dictionary<string, object>();
            while (true)
            {
                reader.Skip();
                if (reader.pos >= reader.s.Length) return globals;
                string name = reader.Name();
                if (name == null) throw reader.Wrong("a name");
                reader.Skip();
                reader.Expect('=');
                globals[name] = reader.Value();
            }
        }

        FormatException Wrong(string wanted)
        {
            return new FormatException(wanted + " expected at character " + pos);
        }

        void Expect(char c)
        {
            if (pos >= s.Length || s[pos] != c) throw Wrong("'" + c + "'");
            pos++;
        }

        // Spaces, the separators between a table's fields, and comments.
        void Skip()
        {
            while (pos < s.Length)
            {
                char c = s[pos];
                if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == ',' || c == ';') pos++;
                else if (c == '-' && pos + 1 < s.Length && s[pos + 1] == '-')
                {
                    int end;
                    if (pos + 3 < s.Length && s[pos + 2] == '[' && s[pos + 3] == '[')
                    {
                        end = s.IndexOf("]]", pos + 4, StringComparison.Ordinal);
                        pos = end < 0 ? s.Length : end + 2;
                    }
                    else
                    {
                        end = s.IndexOf('\n', pos);
                        pos = end < 0 ? s.Length : end + 1;
                    }
                }
                else break;
            }
        }

        static bool Letter(char c)
        {
            return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
        }

        static bool Digit(char c)
        {
            return c >= '0' && c <= '9';
        }

        string Name()
        {
            if (pos >= s.Length || !Letter(s[pos])) return null;
            int start = pos;
            while (pos < s.Length && (Letter(s[pos]) || Digit(s[pos]))) pos++;
            return s.Substring(start, pos - start);
        }

        object Value()
        {
            Skip();
            if (pos >= s.Length) throw Wrong("a value");
            char c = s[pos];
            if (c == '{') return Table();
            if (c == '"' || c == '\'') return Text();
            if (Digit(c) || c == '-' || c == '.') return Number();
            string word = Name();
            if (word == "true") return true;
            if (word == "false") return false;
            if (word == "nil") return null;
            throw Wrong("a value");
        }

        Dictionary<object, object> Table()
        {
            pos++;
            Dictionary<object, object> table = new Dictionary<object, object>();
            double next = 1;
            while (true)
            {
                Skip();
                if (pos >= s.Length) throw Wrong("'}'");
                if (s[pos] == '}')
                {
                    pos++;
                    return table;
                }
                if (s[pos] == '[')
                {
                    pos++;
                    object key = Value();
                    Skip();
                    Expect(']');
                    Skip();
                    Expect('=');
                    object value = Value();
                    if (key != null && value != null) table[key] = value;
                    continue;
                }
                int start = pos;
                string name = Name();
                if (name != null && name != "true" && name != "false" && name != "nil")
                {
                    Skip();
                    if (pos < s.Length && s[pos] == '=')
                    {
                        pos++;
                        object value = Value();
                        if (value != null) table[name] = value;
                        continue;
                    }
                }
                pos = start;
                object item = Value();
                if (item != null) table[next] = item;
                next++;
            }
        }

        object Number()
        {
            int start = pos;
            if (s[pos] == '-') pos++;
            if (pos + 1 < s.Length && s[pos] == '0' && (s[pos + 1] == 'x' || s[pos + 1] == 'X'))
            {
                pos += 2;
                int digits = pos;
                while (pos < s.Length && Uri.IsHexDigit(s[pos])) pos++;
                double hex = Convert.ToInt64(s.Substring(digits, pos - digits), 16);
                return s[start] == '-' ? -hex : hex;
            }
            while (pos < s.Length)
            {
                char c = s[pos];
                if (Digit(c) || c == '.') pos++;
                else if (c == 'e' || c == 'E')
                {
                    pos++;
                    if (pos < s.Length && (s[pos] == '+' || s[pos] == '-')) pos++;
                }
                else break;
            }
            double value;
            if (!double.TryParse(s.Substring(start, pos - start), System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture, out value))
            {
                // inf and nan, as some writers put them: kept as numbers.
                string word = Name();
                if (word == "inf") return s[start] == '-' ? double.NegativeInfinity : double.PositiveInfinity;
                if (word == "nan") return double.NaN;
                throw Wrong("a number");
            }
            return value;
        }

        string Text()
        {
            char quote = s[pos++];
            System.Text.StringBuilder text = new System.Text.StringBuilder();
            while (true)
            {
                if (pos >= s.Length) throw Wrong("the string's end");
                char c = s[pos++];
                if (c == quote) return text.ToString();
                if (c != '\\')
                {
                    text.Append(c);
                    continue;
                }
                if (pos >= s.Length) throw Wrong("an escape");
                char e = s[pos++];
                if (Digit(e))
                {
                    int code = e - '0';
                    for (int i = 0; i < 2 && pos < s.Length && Digit(s[pos]); i++) code = code * 10 + (s[pos++] - '0');
                    text.Append((char)code);
                    continue;
                }
                switch (e)
                {
                    case 'n': text.Append('\n'); break;
                    case 'r': text.Append('\r'); break;
                    case 't': text.Append('\t'); break;
                    case 'a': text.Append('\a'); break;
                    case 'b': text.Append('\b'); break;
                    case 'f': text.Append('\f'); break;
                    case 'v': text.Append('\v'); break;
                    case '\r':
                        if (pos < s.Length && s[pos] == '\n') pos++;
                        text.Append('\n');
                        break;
                    default: text.Append(e); break;
                }
            }
        }
    }

    // One run of Survivor UI's Run History (SurvivorUIDB.runHistory, newest
    // first), as its saved table; the page reads the fields it shows.
    class RunRecord
    {
        public Dictionary<object, object> Data;

        public static List<RunRecord> ReadAll(string path)
        {
            string keep;
            return ReadAll(path, out keep);
        }

        // keep: Survivor UI's Keep setting (historyWhich: all, victories, none).
        public static List<RunRecord> ReadAll(string path, out string keep)
        {
            keep = "all";
            string text;
            using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (StreamReader reader = new StreamReader(stream, System.Text.Encoding.UTF8)) text = reader.ReadToEnd();
            List<RunRecord> runs = new List<RunRecord>();
            object db;
            if (!LuaData.Globals(text).TryGetValue("SurvivorUIDB", out db)) return runs;
            keep = Field(db, "historyWhich") as string ?? "all";
            foreach (Dictionary<object, object> entry in List(Field(db, "runHistory")))
            {
                RunRecord run = new RunRecord();
                run.Data = entry;
                runs.Add(run);
            }
            return runs;
        }

        public static object Field(object table, object key)
        {
            Dictionary<object, object> fields = table as Dictionary<object, object>;
            object value;
            return fields != null && key != null && fields.TryGetValue(key, out value) ? value : null;
        }

        public static double NumOf(object table, object key)
        {
            object value = Field(table, key);
            return value is double ? (double)value : 0;
        }

        // A list's entries that are tables, from [1] on until one is missing.
        public static List<Dictionary<object, object>> List(object table)
        {
            List<Dictionary<object, object>> list = new List<Dictionary<object, object>>();
            Dictionary<object, object> fields = table as Dictionary<object, object>;
            if (fields == null) return list;
            for (double i = 1; ; i++)
            {
                object value;
                if (!fields.TryGetValue(i, out value)) return list;
                Dictionary<object, object> entry = value as Dictionary<object, object>;
                if (entry != null) list.Add(entry);
            }
        }

        public string Str(string key)
        {
            return Field(Data, key) as string ?? "";
        }

        public double Num(string key)
        {
            return NumOf(Data, key);
        }

        public Dictionary<object, object> Table(string key)
        {
            return Field(Data, key) as Dictionary<object, object>;
        }
    }

    class NotesForm : Form
    {
        // The launcher's pack's colours (its panel, its parchment words).
        static readonly Color Back = Color.FromArgb(19, 19, 18);
        static readonly Color Panel = Color.FromArgb(24, 23, 21);
        static readonly Color Gold = Color.FromArgb(255, 209, 0);
        static readonly Color TextColor = Color.FromArgb(228, 222, 206);
        static readonly Color Muted = Color.FromArgb(168, 160, 142);
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
            // The pack's scroll bar over the box's own.
            new MainForm.ArtScroll(null, box);
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
