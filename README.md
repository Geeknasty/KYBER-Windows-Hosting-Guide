# Windows Docker Guide for KYBER Dedicated Servers (SWBF2)

Host community servers for **STAR WARS Battlefront II (2017)** using KYBER with Docker on Windows — bypassing common NTFS permission issues (like Activation64.dll errors) by using native Linux volumes.

[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![KYBER](https://img.shields.io/badge/KYBER-Community%20Discord%20Server-%23f2ae09?logo=star-wars&logoColor=black)](https://kyber.gg/)

**Quick Links:**
- [Full Guide](#guide-hosting-kyber-dedicated-servers-on-windows-docker--kyber) (below)
- [Official KYBER Docs](https://docs.kyber.gg/g/hosting/dedicated-servers)
- [KYBER Discord](https://discord.gg/kyber) (for support/questions)

## Features / Why This Guide?
- Step-by-step Windows-specific setup using Docker Desktop + WSL2
- Avoids common pitfalls (NTFS mounts, permission errors)
- Supports mods, plugins, Kyber Module, and multiple gamemodes/servers
- Example configs included (`docker-compose.yml`, `.env` templates)

## Prerequisites (Quick Check)
- Windows 10/11 with Virtualization enabled in BIOS
- Docker Desktop (WSL 2 backend)
- ~180 GB free space temporarily
- KYBER CLI + valid EA/Kyber credentials
---
<br><br>

# Guide: Hosting KYBER Dedicated Servers on Windows (Docker + KYBER)

This guide allows you to host a Kyber V2 dedicated server on Windows using Docker Desktop bypassing NTFS permission issues by utilizing native Linux volumes without manually setting up a full Linux distribution.
<br><br>
## Prerequisites

### 1. Enable System Virtualization
* Ensure **Virtualization** is enabled in your BIOS/UEFI.
  * Restart your PC and repeatedly tap the key to enter BIOS setup (usually Delete, F2, or F10 — watch the boot screen for the hint).
  * Find and turn on the virtualization option (look in Advanced, CPU, or Security menu; it’s called Intel VT-x, AMD-V, SVM Mode, or similar — change from Disabled to Enabled).
  * Save & exit (usually F10 → Yes), let it reboot — virtualization is now active (check in Task Manager → Performance tab if you want to confirm).
  * Can't find it? Google "[your motherboard model] enable virtualization"

* Enable **WSL** and **Virtual Machine Platform** via PowerShell (Admin):
    ```powershell
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    ```
* Install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/#install-docker-desktop-on-windows) and ensure it is set to use the **WSL 2 engine**.

<br>

### 2: Storage Preparation (CRITICAL)
Battlefront II requires ~90GB of space. Because this guide uses Docker Volumes to bypass NTFS errors, you may temporarily need ~180GB (90GB for the download + 90GB for the Volume).

### Relocating the Docker Disk Image (Highly Recommended)
By default, Docker Desktop stores its virtual disk (where volumes live) on your C: drive. If your C: drive is small, move the disk image to a larger drive:

1. Open Docker Desktop Settings.
2. Navigate to `Resources` > `Advanced`.
3. Under Disk image location, click `Browse` and select a folder on a secondary drive.
4. Click `Apply`. Docker will move your existing data and volumes to the new location.

<img src="assets/docker-settings.png" width="720" alt="Docker Settings Screen">


<br>

### 3. Obtain Kyber Credentials
* Download the **Kyber CLI** from the [Kyber Prerequisites Docs](https://docs.kyber.gg/g/hosting/dedicated-servers/prereq).
* Run the following to link your accounts and generate tokens:
    * `kyber_cli get_token` (For your Kyber Identity)
    * `kyber_cli get_ea_token` (To verify game ownership)

>__IMPORTANT:__ : If your EA password contains special characters it may not work. It may be a good idea to change your password to UPPERCASE, lowercase, and numbers.

<img src="assets/kyber_cli_commands.png" width="720" alt="kyber_cli commands">

---

<br><br>


## Step 1: Download Game or Reuse your existing Battlefront II installation
Download the game files using the Kyber_CLI.
1.  Run the download:

```bash
kyber_cli download_game -p C:\Path\To\Your\GameFolder -t <your_ea_token>
```
2.  Once the progress reaches 100%, you can cancel the process.

> __Note:__ You may want to change the download path if your `C:\` drive has limited space.

**Alternative: Reuse your existing Battlefront II installation** (Recommended if already downloaded the game and it's unmodified)

If you have Star Wars Battlefront II installed locally (Steam, EA App/Origin, etc.), you can copy directly from there instead of downloading ~90 GB again. However, any modifications to the game files may negativly effect server hosting. If you're unsure it may be better to download a fresh copy.

1. Locate your game install folder:
   - Steam: Right-click game in library → Manage → Browse local files
   - EA App/Origin: Right-click game → Locate installed files
   Typical paths:
   - `C:\Program Files (x86)\Steam\steamapps\common\STAR WARS Battlefront II`
   - `C:\Program Files\EA Games\STAR WARS Battlefront II`

2. When using ingest command from Step 2, but point `/source` to your game folder:

   (e.g., `-v "C:\Program Files (x86)\Steam\steamapps\common\STAR WARS Battlefront II:/source" -v swbf2_data:/dest`).
---
<br><br>
## Step 2: Create Linux-Native Docker Volumes
**Important Warning:**  
Directly mounting a Windows folder (e.g. via `-v "C:\GameFolder:/mnt/battlefront"`) into the Docker container will almost always cause **Activation64.dll** errors.  

This happens because NTFS (Windows' filesystem) doesn't fully support the Linux-style file execution permissions that the server needs for certain game DLLs.

**Required fix:** Copy (or extract) all files into a Docker volume created inside the Linux filesystem.

1.  **Create the volumes:**
    ```bash
    docker volume create swbf2_data
    docker volume create empty_data
    # Create mod/plugin volumes as needed
    docker volume create kyber_module_ver10 #example volume for beta ver/10 kyber-module
    docker volume create swbf2_mods_hvv_chaos #example volume for hvv chaos mods
    ```
2.  **Ingest the Game files, Plugins, and Kyber Module:**
    ```bash
    docker run --rm -v "C:\Path\To\Your\GameFolder:/source" -v swbf2_data:/dest alpine sh -c "apk add --no-cache rsync && rsync -ah --info=progress2 --no-inc-recursive /source/ /dest/"
    ```

    >__Note:__ This may take some time to finish. Depending on the size of data.
      #### This works identically for:
    * Game files 
    * Plugin .kbplugin files (place them in a folder, ingest the folder)
    * Kyber Module folder (e.g, `"-v C:\ProgramData\Kyber\Module:/source"`) -> (e.g, `-v kyber_module_ver10:/dest`)

3.  **Ingest the Mod files:** (See Step 3a Preparing Mods)
    ```bash
    docker run --rm -v "C:\Path\To\Your\ExportedMods\HVV_CHAOS_MODS.tar:/archive.tar" -v swbf2_mods_hvv_chaos:/dest alpine sh -c "tar -xf /archive.tar -C /dest"
    ```
    >__Note:__ This command is different because we need to extract the modcollection.tar into our docker volume.
  #### We reuse this section several times. Creating Docker Volumes and ingesting files.

---
<br><br>
## Step 3: Preparing Mods, Plugins, and Modules
Follow this pattern for all external assets to ensure maximum performance and zero permission errors.

<img src="assets/kyber_export_mods.png" align="right" width="250" alt="Settings">

### a. Mods
* In the Kyber Launcher: **Options -> Export Collection TAR**.
* Create a volume (e.g., `swbf2_mods_hvv_chaos`) and ingest the `.tar` contents into it using the "Ingest the Mod files:" `docker run tar` method found in Step 2.



### b. Plugins
* Clone [Plugin Examples](https://github.com/ArmchairDevelopers/PluginExamples.git).
* Zip your chosen plugin (ensure `.json` is at the root).
* Rename the file extension from `.zip` to `.kbplugin`.
* Ensure the filename matches the plugin name (e.g., `HVVPlayground.kbplugin`) for consistent loading.
* Move this into a volume (e.g., `swbf2_plugins_hvvplayground`) using the same `docker run` method used in Step 2.

<img src="assets/kyber-module_setting.png" align="right" width="300" alt="Settings">

### c. Kyber Module (`Kyber.dll`)
* In Kyber Launcher: **Settings -> Accounts & Updates**.
* Set **Target Service** to `kyber-module` and **Release Channel** to `ver/beta10`.
* Join any server to trigger the update.
* Locate the files at `C:\ProgramData\Kyber\Module\`.
* Move this into a volume (e.g., `kyber_module_ver10`) using the same `docker run` method used in Step 2.


---
<br><br>
## Step 4: Deployment

### If you do not want to use `docker-compose` you can use `docker run` to set env variables and mount volumes to container paths as shown in  [Dedicated-Server Config Docs](https://docs.kyber.gg/g/hosting/dedicated-servers/config) in which case you're done. 

<br>

### If you would like to control your KYBER servers with YAML configuration files, continue with `docker-compose` below.

<br>

To deploy the server we will use docker-compose. This will require a `docker-compose.yml` and a few `.env` files. We will use the `docker-compose.yml` as a reusable template, `secrets.env` to store tokens, and `<ServerName>.env` to store individual server settings and environment variables. See the [Dedicated-Server Config Docs](https://docs.kyber.gg/g/hosting/dedicated-servers/config) for a list of environment variables.

### A. docker-compose.yml file
 * Create a file named `docker-compose.yml` in your project directory. It acts as a universal template. This file will be what we use to start the server. Server logs will be output in the same directory as this file.
```yaml
services:
  kyber-server:
    image: ghcr.io/armchairdevelopers/kyber-server:latest
    container_name: kyber-test-server
    env_file:
      - secrets.env
    network_mode: "host"
    privileged: true
    command: ["--module-branch=ver/beta10", "--module-path=/root/.local/share/kyber/module"]
    environment:
      - KYBER_SERVER_NAME=${SERVER_NAME:-}
      - KYBER_SERVER_PASSWORD=${SERVER_PASSWORD:-}
      - KYBER_SERVER_MAX_PLAYERS=${SERVER_MAX_PLAYERS:-}
      - KYBER_MAP_ROTATION=${SERVER_MAP_ROTATION:-}
      - KYBER_SERVER_DESCRIPTION=${SERVER_DESCRIPTION:-}
      - KYBER_MODULE_CHANNEL=ver/beta10
      - KYBER_LOG_LEVEL=info
      # Short-form variables: Only passed to container if defined in .env
      - KYBER_MOD_FOLDER
      - KYBER_SERVER_PLUGINS_PATH
    volumes:
      - swbf2_data:/mnt/battlefront
      - kyber_mods:/mnt/battlefront/mods
      - kyber_plugins:/mnt/plugins
      # Mounting ver/10 Kyber.dll
      - kyber_module_ver10:/root/.local/share/kyber/module/
      # Mount the server logs (will output in same directory as docker-compose.yml /Logs/)
      - ./logs:/root/.local/share/maxima/wine/prefix/drive_c/users/root/AppData/Roaming/ArmchairDevelopers/Kyber/Logs/
    restart: unless-stopped

volumes:
  swbf2_data:
    external: true
  kyber_module_ver10:
    external: true
  kyber_mods:
    external: true
    name: ${MOD_VOLUME:-empty_data}
  kyber_plugins:
    external: true
    name: ${PLUGIN_VOLUME:-empty_data}

```
###  B Environment Files (.env)

* Create `secrets.env` in the same directory as your `docker-compose.yml`. This keeps your token and `EAusername:password` seperate and organized. We will load `secrets.env` automatically by listing it in our `docker-compose.yml`.  If your EA password contains special characters, you may need to change your password. Use `kyber_cli get_token` → KYBER_TOKEN

```yml
# secrets.env
# Secret Stuff
KYBER_TOKEN=your_kyber_token_here
MAXIMA_CREDENTIALS='EAusername:password'
```

* Now in the same directory as your `docker-compose.yml` we can create files for individual servers or gamemodes named `<ServerName>.env` (e.g., `hvvchaos.env`, `hvv6v6.env`, `coopBFPlusXL.env`. etc) This keeps your different game mode settings organized. 
<details>
<summary>🚨 <strong>CLICK HERE: How to get your base64 map rotation string</strong> (includes screenshot) 🚨</summary>

<img src="assets/Kyber_export_map_rotation.png" width="720" alt="Kyber Launcher map rotation base64 tool">

> **Explanation:** In the Kyber Launcher → **Host Tab** → **Export** → **Copy To Clipboard** the base64 string.  
> Paste it into your `.env` file like this:  
> `SERVER_MAP_ROTATION='WyJzdXBfZ2Vvbm9zaXMiLCJzdXBfY2FzY2FkZSJd'`
</details>

<br>

```yml
# hvvchaos.env
# Server Settings
SERVER_NAME='HVV Chaos Playground'
SERVER_MAX_PLAYERS=40
SERVER_DESCRIPTION='(Optional) A longer UTF-8 description (≤256 characters) for server rules or links.'
SERVER_MAP_ROTATION='<base64_encoded_JSON_array_of_maps>'
#Pick which Mods and Plugins you want 
MOD_VOLUME=swbf2_mods_hvv_chaos
PLUGIN_VOLUME=swbf2_plugins_hvvplayground
# You can copy the 2 ENV Variables below into all <gamemode>.env that use mods and plugins
KYBER_MOD_FOLDER=/mnt/battlefront/mods
KYBER_SERVER_PLUGINS_PATH=/mnt/plugins
```
* We can use the `empty_data` volume for servers without mods or plugins
```yml
# vanillahvv.env
# Server Settings
SERVER_NAME='No Mods Server'
SERVER_MAX_PLAYERS=12
SERVER_DESCRIPTION='Vanilla HvV Map Rotation Test Server'
SERVER_MAP_ROTATION='<base64_encoded_JSON_array_of_maps>'
SERVER_PASSWORD=1234
#We use empty mod and plugin volumes
MOD_VOLUME=empty_data
PLUGIN_VOLUME=empty_data
```
---
<br><br>
## Step 4: Launching

### Run the server by specifying only the per-server/gamemode `.env` file (`secrets.env` loads automatically via `docker-compose.yml`):
```powershell
docker-compose --env-file hvvchaos.env up -d
```
>__Note:__ Use `-d` for detached (background) mode. Watch logs with `docker compose logs -f` or check on the running containers in docker-desktop.

<br><br><br>
- Use the `.example` files as templates only.
- Copy them to remove the `.example` suffix (e.g., `cp secrets.env.example secrets.env`).
- The `.gitignore` file automatically prevents committing real `.env` files.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
