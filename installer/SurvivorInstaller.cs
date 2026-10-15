// Survivor UI Installer: installs and updates Survivor UI and Survivor Plates
// from the latest GitHub release, into Azeroth Survivors' AddOns folder.
//
// What it does, and nothing else:
//   - asks GitHub which release is the latest, and shows its notes;
//   - finds the game's AddOns folder (or lets the player pick the game);
//   - on Install, downloads the release's zip, removes the old SurvivorUI and
//     SurvivorPlates folders and unzips the new ones in their place.
//
// Built with the C# compiler that comes with Windows (.NET Framework 4.8):
// see build.bat. C# 5, no external packages.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("Survivor UI Installer")]
[assembly: System.Reflection.AssemblyProduct("Survivor UI")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

namespace SurvivorInstaller
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }

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
        readonly Button openButton = new Button();
        readonly Label statusLabel = new Label();

        Release latest;

        static string ConfigPath
        {
            get
            {
                string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "SurvivorUIInstaller");
                Directory.CreateDirectory(dir);
                return Path.Combine(dir, "addons-folder.txt");
            }
        }

        public MainForm()
        {
            this.Text = "Survivor UI Installer";
            ClientSize = new Size(560, 460);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Back;
            ForeColor = TextColor;
            Font = new Font("Segoe UI", 9.5f);
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            Label title = new Label();
            title.Text = "Survivor UI  &&  Survivor Plates";
            title.Font = new Font("Segoe UI", 15f, FontStyle.Bold);
            title.ForeColor = Gold;
            title.AutoSize = true;
            title.Location = new Point(18, 14);
            Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "Interface addons for Azeroth Survivors";
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

            Label notesLabel = new Label();
            notesLabel.Text = "What's new";
            notesLabel.ForeColor = Muted;
            notesLabel.AutoSize = true;
            notesLabel.Location = new Point(20, 166);
            Controls.Add(notesLabel);

            notesBox.Location = new Point(20, 186);
            notesBox.Size = new Size(520, 196);
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

            Style(openButton, "Open AddOns folder");
            openButton.Location = new Point(190, 396);
            openButton.Size = new Size(150, 36);
            openButton.Click += delegate
            {
                if (Directory.Exists(folderBox.Text)) Process.Start("explorer.exe", "\"" + folderBox.Text + "\"");
            };
            Controls.Add(openButton);

            statusLabel.Location = new Point(20, 438);
            statusLabel.Size = new Size(520, 20);
            statusLabel.ForeColor = Muted;
            Controls.Add(statusLabel);

            folderBox.Text = FindAddonsFolder() ?? "";
            if (folderBox.Text == "") Status("Click \"Find game...\" and pick " + GameExe + ".");
            ShowInstalled();

            Shown += delegate { new Thread(FetchLatest) { IsBackground = true }.Start(); };
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
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
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
                    notesBox.Text = "Could not reach GitHub: " + error.Message + "\r\n\r\nCheck your internet connection and open the installer again.";
                    latestLabel.Text = "Latest:  unknown";
                }));
            }
        }

        void ShowLatest(Release release)
        {
            latest = release;
            latestLabel.Text = "Latest:  " + release.Tag;
            latestLabel.ForeColor = Gold;
            notesBox.Text = Plain(release.Notes);
            installButton.Enabled = release.ZipUrl != null;
            if (release.ZipUrl == null) Status("The latest release has no zip to install.");
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
            installButton.Enabled = false;
            browseButton.Enabled = false;
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
                BeginInvoke(new Action(delegate { installButton.Enabled = true; browseButton.Enabled = true; }));
            }
        }
    }
}
