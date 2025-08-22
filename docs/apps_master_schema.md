# apps_master.csv Schema

Column | Description
------ | -----------
1. `device_serial` | Device serial number used for adb operations
2. `run_id` | Timestamp identifier for this run (YYYYMMDD_HHMMSS)
3. `package` | Android application package name
4. `apk_path` | Absolute path to the APK on device
5. `partition` | Top-level partition of the APK path (data/system/product/vendor/unknown)
6. `is_user` | `true` if the app resides under `data/`
7. `is_social` | Social app flag based on exact or heuristic match
8. `social_method` | `exact`, `heuristic`, or `none`
9. `version_name` | Reported version name
10. `version_code` | Reported version code
11. `permissions` | Semicolon-delimited requested permissions
12. `sha256` | SHA-256 of the APK when available
13. `hash_source` | `device`, `host`, or `none`
14. `is_running` | `true` if a process for the package is running
15. `detection_notes` | Notes on detections or anomalies
16. `source_cmd` | Command used to collect the package list
17. `parser_version` | Version of the parsing logic
18. `tool_commit` | Git commit hash of the tool used
19. `adb_version` | Version of adb used during collection
20. `captured_at` | UTC timestamp when data was captured
