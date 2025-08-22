# Bismarck Android APK Toolkit

Bismarck collects a master inventory of installed applications from an
Android device. It highlights social apps and other metadata to help you
triage a device quickly.

## Overview

- Enumerates packages via `adb shell pm list packages -f` across all
  partitions.
- Builds a single `apps_master.csv` with paths, versions, permissions,
  hashes, and running state. The column schema is documented in
  [`docs/apps_master_schema.md`](docs/apps_master_schema.md).
- Records version, SDK levels, size, and permissions for each package in
  `apk_metadata.csv` to seed static analysis and ML workflows.
- Places all artifacts under `output/<serial>/<run_id>/` with `latest` pointing to the most recent run.

## How it works

1. The script binds to the chosen device and performs health checks.
2. Package discovery populates the master inventory.
3. Social triage marks packages using exact matches and keyword heuristics.
4. SHA-256 hashes are attempted on-device or on the host and recorded with
   their source.
5. A summary report captures counts and social hits for the run.

## How to run

### Full device scan

```bash
./run.sh -d <serial>
```

Runs every collection step for the specified device. To discover attached
devices, run `./list_devices.sh`. Each invocation creates a timestamped
directory at `output/<serial>/<run_id>/` and updates the
`output/<serial>/latest` symlink.

Per-run artifacts are written under this directory:

- `reports/` – CSV reports (`apk_list.csv`, `apk_metadata.csv`,
  `apk_hashes.csv`, `running_apps.csv`, optional `social_apps_found.csv`,
  `motorola_apps.csv`) along with `run.log` and `run_summary.txt`.
- `apks/` – reserved for pulled APKs (feature pending).
- `raw/` – raw command outputs.
- `manifest.json` – run summary referencing the above files.

### Legacy interactive menu (deprecated)

```bash
./run.sh --menu
```

Launches the historical text menu for running individual steps. It is retained
only for backwards compatibility and may be removed in the future.

### Running step scripts directly

Each step can be invoked on its own for scripting or debugging. Provide the
device serial with `-d <serial>`:

- `steps/generate_apk_list.sh` – write `apk_list.csv` with package paths.
- `steps/generate_apk_metadata.sh` – capture version, SDK levels, size, and
  permissions in `apk_metadata.csv`.
- `steps/generate_apk_hashes.sh` – compute SHA-256 hashes into
  `apk_hashes.csv`.
- `steps/generate_running_apps.sh` – log running processes to
  `running_apps.csv`.
- `steps/generate_manifest.sh -l <log_file>` – produce `manifest.json` summary.
- `find_social_apps.sh` – flag social apps into `social_apps_found.csv`.
- `find_motorola_apps.sh` – list Motorola apps in `motorola_apps.csv`.

### Pulling and profiling a single APK

Use `./pull_tiktok_apk.sh -p <package>` to grab an APK from the device. When
`aapt` is available, static features such as SDK levels, size, and declared
permissions are written to `<package>_features.csv` alongside the pulled files.

## Supporting and contributing

- File issues or feature requests on the repository to report bugs or ask
  questions.
- Before submitting a pull request, run `bash -n` and `shellcheck` on
  modified scripts to ensure they pass basic validation.
- Contributions that expand device coverage or improve data quality are
  welcome.

## What to look for

Inspect `output/<serial>/<run_id>/manifest.json` (or the
`output/<serial>/latest` symlink) for counts and a list of detected social apps.
The run directory also contains:

- `reports/` with CSVs and logs
- `apks/` (placeholder for pulled APK files)
- `raw/` with low-level command output

Derived CSV views are planned but not yet available. The `GENERATE_DERIVED`
flag in `config.sh` is currently unused.

## Troubleshooting

- "No device selected": ensure exactly one device is connected or use
  `--device <serial>`.
- "Device unhealthy": the script could not communicate with the selected
  device after restarting the ADB server.
- "hash failed (no access)": the APK could not be read; device or filesystem
  permissions may block access.
