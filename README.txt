File Auditor & Backup Tool
==========================

Files
-----
- auditor.sh: main program, menu, and command-line interface.
- lib.sh: helper and feature functions.

Requirements
------------
- Linux or another Unix-like system
- Bash 4 or newer (associative arrays are used)

Run
---
From this folder:

    chmod +x auditor.sh lib.sh
    ./auditor.sh ../sample_data

Run one supported command-line action:

    ./auditor.sh ../sample_data scan
    ./auditor.sh ../sample_data perms
    ./auditor.sh ../sample_data ext
    ./auditor.sh ../sample_data backup

The first argument is the directory to audit. If omitted, the current
directory is used. If the second argument is omitted, the interactive menu
opens. The menu also provides search, list backups, and restore.

Backups and log
---------------
Backups are stored in a `backups/` directory inside the audited directory.
The audit log is `auditor.log` in the audited directory. These generated
items are excluded from scans, reports, and subsequent backup runs.

Restore creates a new file named `restored_<backup filename>` in the
audited directory. It refuses to overwrite an existing destination.

Testing
-------
Check syntax with:

    bash -n auditor.sh
    bash -n lib.sh

Use only a practice directory such as the supplied sample_data. The script
does not delete original files and checks that restore destinations do not
already exist.

Team contribution
-----------------
Student 1: Patrick Ihab Youssef
Student ID: 2406232
