#!/usr/bin/env bash
# Helper functions for the File Auditor & Backup Tool.
# Each public feature records exactly one audit-log entry.

log_info() {
    printf '[INFO] %s\n' "$*"
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

log_action() {
    # Append one timestamped record to the audit log in the audited directory.
    local directory="$1"
    local action="$2"
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$action" >> "$directory/auditor.log"
}

require_dir() {
    # Return success only when the supplied path is an existing directory.
    local directory="$1"
    if [[ ! -d "$directory" ]]; then
        log_error "Directory does not exist: $directory"
        return 1
    fi
    return 0
}

scan_directory() {
    # Recursively list files and directories, then print their totals.
    local directory="$1"
    local path files=0 folders=0
    while IFS= read -r -d '' path; do
        if [[ -d "$path" ]]; then
            printf '[dir ] %s\n' "${path#"$directory"/}"
            ((folders += 1))
        elif [[ -f "$path" ]]; then
            printf '[file] %s\n' "${path#"$directory"/}"
            ((files += 1))
        fi
    done < <(find "$directory" -mindepth 1 -not -path "$directory/backups" -not -path "$directory/backups/*" -not -name 'auditor.log' -print0 | sort -z)
    printf 'Files: %d     Folders: %d\n' "$files" "$folders"
    log_action "$directory" "Scanned directory"
}

permission_audit() {
    # Show the current user's read/write/execute access for each regular file.
    local directory="$1"
    local path flags unreadable=0 executable=0
    while IFS= read -r -d '' path; do
        flags='---'
        [[ -r "$path" ]] && flags="r${flags:1}"
        [[ -w "$path" ]] && flags="${flags:0:1}w${flags:2}"
        [[ -x "$path" ]] && flags="${flags:0:2}x"
        printf '%s   %s\n' "$flags" "${path#"$directory"/}"
        [[ -r "$path" ]] || ((unreadable += 1))
        [[ -x "$path" ]] && ((executable += 1))
    done < <(find "$directory" -type f ! -path "$directory/backups/*" ! -name 'auditor.log' -print0 | sort -z)
    printf 'Unreadable files: %d       Executable files: %d\n' "$unreadable" "$executable"
    log_action "$directory" "Completed permission audit"
}

extension_report() {
    # Count files by extension using an associative array.
    local directory="$1"
    local path filename extension
    declare -A counts=()
    while IFS= read -r -d '' path; do
        filename="${path##*/}"
        if [[ "$filename" == *.* && "$filename" != .* ]]; then
            extension="${filename##*.}"
            extension="${extension,,}"
            case "$extension" in
                txt|log|sh|jpg) ;;
                *) extension="other" ;;
            esac
        else
            extension="other"
        fi
        ((counts["$extension"] += 1))
    done < <(find "$directory" -type f ! -path "$directory/backups/*" ! -name 'auditor.log' -print0)
    for extension in txt log sh jpg other; do
        printf '%s : %d\n' "$extension" "${counts[$extension]:-0}"
    done
    log_action "$directory" "Generated extension report"
}

search_file() {
    # Prompt for a name fragment and print every matching file path.
    local directory="$1"
    local query path found=0
    read -r -p 'Enter text to search for in file names: ' query
    while IFS= read -r -d '' path; do
        if [[ "${path##*/}" == *"$query"* ]]; then
            printf '%s\n' "$path"
            found=1
        fi
    done < <(find "$directory" -type f ! -path "$directory/backups/*" ! -name 'auditor.log' -print0)
    if (( found == 0 )); then
        printf 'No files matched: %s\n' "$query"
    fi
    log_action "$directory" "Searched file names for: $query"
}

backup_all() {
    # Copy every readable regular file into backups with a timestamped .bak name.
    local directory="$1"
    local backup_dir="$directory/backups"
    local path filename stamp destination saved=0 skipped=0 suffix
    mkdir -p "$backup_dir" || { log_error "Cannot create backup directory"; log_action "$directory" "Backup failed"; return 1; }

    while IFS= read -r -d '' path; do
        if [[ -r "$path" ]]; then
            filename="${path##*/}"
            stamp="$(date '+%Y%m%d_%H%M%S')"
            destination="$backup_dir/${filename}_${stamp}.bak"
            suffix=1
            while [[ -e "$destination" ]]; do
                destination="$backup_dir/${filename}_${stamp}_${suffix}.bak"
                ((suffix += 1))
            done
            if cp -- "$path" "$destination"; then
                ((saved += 1))
            else
                log_error "Could not back up: $path"
                ((skipped += 1))
            fi
        else
            log_error "Skipping unreadable file: $path"
            ((skipped += 1))
        fi
    done < <(find "$directory" -type f ! -path "$backup_dir/*" ! -name 'auditor.log' -print0)
    printf 'Files saved: %d       Files skipped: %d\n' "$saved" "$skipped"
    log_action "$directory" "Backed up files (saved: $saved, skipped: $skipped)"
}

list_backups() {
    # Print saved backup filenames, or the required empty-state message.
    local directory="$1"
    local backup_dir="$directory/backups"
    local path found=0
    if [[ -d "$backup_dir" ]]; then
        while IFS= read -r -d '' path; do
            printf '%s\n' "${path##*/}"
            found=1
        done < <(find "$backup_dir" -maxdepth 1 -type f -name '*.bak' -print0 | sort -z)
    fi
    (( found == 1 )) || printf '(no backups yet)\n'
    log_action "$directory" "Listed backups"
}

restore_backup() {
    # Restore a selected backup as restored_NAME without overwriting any file.
    local directory="$1"
    local backup_dir="$directory/backups"
    local requested source destination
    if [[ ! -d "$backup_dir" ]]; then
        log_error "No backups directory exists"
        log_action "$directory" "Restore requested but no backups directory exists"
        return 1
    fi
    read -r -p 'Enter the exact backup filename to restore: ' requested
    if [[ "$requested" == */* || -z "$requested" ]]; then
        log_error "Enter a backup filename only"
        log_action "$directory" "Restore failed: invalid backup name"
        return 1
    fi
    source="$backup_dir/$requested"
    if [[ ! -f "$source" ]]; then
        log_error "Backup does not exist: $requested"
        log_action "$directory" "Restore failed: backup not found ($requested)"
        return 1
    fi
    destination="$directory/restored_$requested"
    if [[ -e "$destination" ]]; then
        log_error "Restore destination already exists; refusing to overwrite: $destination"
        log_action "$directory" "Restore refused: destination exists ($requested)"
        return 1
    fi
    if cp -- "$source" "$destination"; then
        log_info "Restored to: $destination"
        log_action "$directory" "Restored backup: $requested"
    else
        log_error "Restore failed: $requested"
        log_action "$directory" "Restore failed while copying: $requested"
        return 1
    fi
}
