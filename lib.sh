#!/usr/bin/bash

# Display information
log_info() {
    echo "[INFO] $*"
}

# Display errors
log_error() {
    echo "[ERROR] $*" >&2
}

# Save actions in the log file
log_action() {
    local directory="$1"
    local action="$2"

    echo "$(date '+%Y-%m-%d %H:%M:%S') $action" >> "$directory/auditor.log"
}

# Check directory
require_dir() {
    local directory="$1"

    if [ ! -d "$directory" ]; then
        log_error "Directory does not exist: $directory"
        return 1
    fi
}


# 1. SCAN DIRECTORY
scan_directory() {
    local directory="$1"
    local path
    local files=0
    local folders=0

    for path in "$directory"/*; do

        [[ -e "$path" ]] || continue

        if [[ -d "$path" ]]; then
            echo "[dir ] ${path##*/}"
            ((folders++))

        elif [[ -f "$path" ]]; then
            echo "[file] ${path##*/}"
            ((files++))
        fi

    done

    printf '\nFiles: %d  Folders: %d\n' "$files" "$folders"

    log_action "$directory" "Scanned directory"
}


# 2. PERMISSION AUDIT
permission_audit() {
    local directory="$1"
    local path
    local unreadable=0
    local executable=0
    local flags="---"

    for path in "$directory"/*; do

        [[ -e "$path" ]] || continue

        if [[ -f "$path" ]]; then

            flags="---"

            [[ -r "$path" ]] && flags="r--"
            [[ -w "$path" ]] && flags="${flags:0:1}w-"
            [[ -x "$path" ]] && flags="${flags:0:2}x"

            echo "$flags  ${path##*/}"

            [[ -r "$path" ]] || ((unreadable++))
            [[ -x "$path" ]] && ((executable++))

        fi

    done

    printf '\nUnreadable files: %d\n' "$unreadable"
    printf 'Executable files: %d\n' "$executable"

    log_action "$directory" "Completed permission audit"
}


# 3. EXTENSION REPORT
extension_report() {
    local directory="$1"
    local path
    local filename
    local extension

    local txt=0
    local log=0
    local sh=0
    local jpg=0
    local other=0

    for path in "$directory"/*; do

        [ -e "$path" ] || continue

        if [ -f "$path" ]; then

            filename="${path##*/}"

            if [[ "$filename" == *.* && "$filename" != .* ]]; then
                extension="${filename##*.}"
                extension="${extension,,}"
            else
                extension="other"
            fi

            case "$extension" in
                txt) ((txt++)) ;;
                log) ((log++)) ;;
                sh)  ((sh++)) ;;
                jpg) ((jpg++)) ;;
                *)   ((other++)) ;;
            esac

        fi

    done

    echo "txt : $txt"
    echo "log : $log"
    echo "sh  : $sh"
    echo "jpg : $jpg"
    echo "other : $other"

    log_action "$directory" "Generated extension report"
}


# 4. SEARCH FOR A FILE
search_file() {
    local directory="$1"
    local path
    local query
    local found=0

    read -r -p "Enter file name to search for: " query

    for path in "$directory"/*; do

        [[ -e "$path" ]] || continue

        [[ "$path" == "$directory/backups" ]] && continue
        [[ "$path" == "$directory/auditor.log" ]] && continue

        if [[ -f "$path" ]]; then

            if [[ "${path##*/}" == *"$query"* ]]; then
                echo "$path"
                found=1
            fi

        fi

    done

    if [[ "$found" -eq 0 ]]; then
        echo "No files matched: $query"
    fi

    log_action "$directory" "Searched for: $query"
}


# 5. BACKUP READABLE FILES
backup_all() {
    local directory="$1"
    local backup_dir="$directory/backups"
    local path
    local filename
    local destination
    local saved=0
    local skipped=0

    mkdir -p "$backup_dir" || return 1

    for path in "$directory"/*; do

        [[ -e "$path" ]] || continue

        [[ "$path" == "$backup_dir" ]] && continue
        [[ "$path" == "$directory/auditor.log" ]] && continue

        if [[ -f "$path" ]]; then

            if [[ -r "$path" ]]; then

                filename="${path##*/}"
                destination="$backup_dir/${filename}_$(date '+%Y%m%d_%H%M%S').bak"

                if cp -- "$path" "$destination"; then
                    ((saved++))
                else
                    ((skipped++))
                    log_error "Could not back up: $path"
                fi

            else
                ((skipped++))
                log_error "Unreadable file: $path"
            fi

        fi

    done

    printf '\nFiles saved: %d\n' "$saved"
    printf 'Files skipped: %d\n' "$skipped"

    log_action "$directory" "Backup completed"
}


# 6. LIST BACKUPS
list_backups() {
    local directory="$1"
    local backup_dir="$directory/backups"
    local path
    local found=0

    if [[ -d "$backup_dir" ]]; then

        for path in "$backup_dir"/*; do

            [[ -e "$path" ]] || continue

            if [[ -f "$path" && "$path" == *.bak ]]; then
                echo "${path##*/}"
                found=1
            fi

        done

    fi

    if [[ "$found" -eq 0 ]]; then
        echo "(no backups yet)"
    fi

    log_action "$directory" "Listed backups"
}


# 7. RESTORE BACKUP
restore_backup() {
    local directory="$1"
    local backup_dir="$directory/backups"
    local requested
    local source
    local destination

    if [[ ! -d "$backup_dir" ]]; then
        log_error "No backups directory exists"
        return 1
    fi

    read -r -p "Enter backup filename: " requested

    if [[ -z "$requested" || "$requested" == */* ]]; then
        log_error "Invalid backup filename"
        return 1
    fi

    source="$backup_dir/$requested"

    if [[ ! -f "$source" ]]; then
        log_error "Backup does not exist"
        return 1
    fi

    destination="$directory/restored_$requested"

    if [[ -e "$destination" ]]; then
        log_error "Destination already exists"
        return 1
    fi

    if cp -- "$source" "$destination"; then
        log_info "Restored to: $destination"
        log_action "$directory" "Restored backup: $requested"
    else
        log_error "Restore failed"
        return 1
    fi
}
