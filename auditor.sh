#!/usr/bin/env bash
# Main entry point for the File Auditor & Backup Tool.
# Loads helper functions, validates the target directory, and starts the menu or CLI action.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

TARGET_DIR="${1:-.}"
ACTION="${2:-}"

require_dir "$TARGET_DIR" || exit 1
TARGET_DIR="$(cd -- "$TARGET_DIR" && pwd)"

show_menu() {
    # Display the available operations and keep running until the user exits.
    while true; do
        printf '\n===== File Auditor & Backup Tool =====\n'
        printf '1. Scan directory\n'
        printf '2. Permission audit\n'
        printf '3. Extension report\n'
        printf '4. Search for a file\n'
        printf '5. Back up readable files\n'
        printf '6. List backups\n'
        printf '7. Restore a backup\n'
        printf '8. Exit\n'
        read -r -p 'Choose an option: ' choice

        case "$choice" in
            1) scan_directory "$TARGET_DIR" ;;
            2) permission_audit "$TARGET_DIR" ;;
            3) extension_report "$TARGET_DIR" ;;
            4) search_file "$TARGET_DIR" ;;
            5) backup_all "$TARGET_DIR" ;;
            6) list_backups "$TARGET_DIR" ;;
            7) restore_backup "$TARGET_DIR" ;;
            8) printf 'Goodbye.\n'; break ;;
            *) log_error "Invalid menu choice: $choice" ;;
        esac
    done
}

case "$ACTION" in
    "")
        show_menu
        ;;
    scan)
        scan_directory "$TARGET_DIR"
        ;;
    perms)
        permission_audit "$TARGET_DIR"
        ;;
    ext)
        extension_report "$TARGET_DIR"
        ;;
    backup)
        backup_all "$TARGET_DIR"
        ;;
    *)
        log_error "Unknown action: $ACTION (use scan, perms, ext, or backup)"
        exit 1
        ;;
esac
