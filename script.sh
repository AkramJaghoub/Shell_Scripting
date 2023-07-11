#!/bin/bash

EXTENSIONS=()
DIRECTORY=""
REPORT_FILE="file_analysis.txt"
SIZE_FILTER="-10000G"
PERMISSIONS_FILTER="000"
LAST_MODIFIED_FILTER="+0"


function display_help() {
  echo ""
  echo "Description:"
  echo "This shell script performs a comprehensive analysis of files within the specified directory and its subdirectories."
  echo "It generates a report containing file details such as size, owner, permissions, and last modified timestamp."
  echo "The files are grouped by owner, and the groups are sorted by the total size occupied by each owner."
  echo ""
  echo "Usage: ./script.sh [OPTIONS]"
  echo "Options:"
  echo "  -d, --directory    Specify the directory path for analysis"
  echo "  -e, --extensions   List files with specified extensions (space-separated)"
  echo "  -s, --size         Filter files by size (in bytes)"
  echo "  -p, --permissions  Filter files by permissions"
  echo "  -m, --modified     Filter files by last modified timestamp"
  echo "  -h, --help         Display help information"
  echo ""
  echo "Additional Details:"
  echo "  -s, --size         Filter files by size (in bytes)"
  echo "    Usage:"
  echo "      '+num[options]'"
  echo "          OR"
  echo "      '-num[options]'"
  echo "       options: "
  echo "      'b'    for 512-byte blocks (default value if no suffix is used)"
  echo "      'c'    for bytes"
  echo "      'w'    for two-byte words"
  echo "      'k'    for kilobytes (units of 1024 bytes)"
  echo "      'M'    for megabytes (units of 1048576 bytes)"
  echo "      'G'    for gigabytes (units of 1073741824 bytes)"
  echo ""
  echo "  -p, --permissions  Filter files by permissions"
  echo "    Usage:"
  echo "      'u=x'  for files that have executable permission for the user"
  echo "      'g=r'  for files that have read permission for the group"
  echo "      'o=w'  for files that have write permission for others"
  echo "      'a=rwx' for files that have read, write, and execute permission for all"
  echo ""
  echo "  -m, --modified     Filter files by last modified timestamp"
  echo "    Usage:" 
  echo "       '-n'  for files modified less than n minutes"
  echo "       '+n'  for files modified more than n minutes"
  echo ""
}

function validate_directory() {
  while true; do
    if [ -z "$DIRECTORY" ]; then
      echo ""
      echo "Missing directory argument. Please enter a directory!"
    elif ! [ -d "$DIRECTORY" ]; then
      echo "$DIRECTORY is not a valid directory path. Please enter a valid directory path!"
    else
      break
    fi
    read -p "Enter a directory: " DIRECTORY
  done
}

function validate_extension() {
  while true; do
    if [ ${#EXTENSIONS[@]} -eq 0 ] || [ -z "${EXTENSIONS[0]}" ]; then
      echo ""
      echo "Missing or empty file extension argument. Please enter a file extension!"
    elif ! [[ "${EXTENSIONS[0]}" =~ ^\.[a-zA-Z0-9]+$ ]]; then
      echo "Invalid file extension format. Please enter a valid file extension starting with a dot (e.g., .txt, .jpeg, .sh)."
    else
      break
    fi
    read -p "Enter a file extension: " -a EXTENSIONS
  done
}  

function validate_size_filter() {
  if [[ -n "$1" ]]; then
    SIZE_FILTER="$1"
    return
  fi

  while true; do
    read -p "Missing argument for size. Please enter the argument: " SIZE_FILTER

    if [[ "$SIZE_FILTER" =~ ^[-+]?[0-9]+[bcwkMG]?$ ]]; then
      break
    fi

    echo "Invalid argument for size. Please enter a valid argument"
  done
}

function validate_last_modified_filter() {
  if [[ -n "$1" ]]; then
    LAST_MODIFIED_FILTER="$1"
    return
  fi

  while true; do
    read -p "Missing argument for last modified. Please enter the argument: " LAST_MODIFIED_FILTER

    if [[ "$LAST_MODIFIED_FILTER" =~ ^[+-]?[0-9]+$ ]]; then
      break
    fi

    echo "Invalid argument for last modified. Please enter a valid argument"
  done
}

function validate_permissions_filter() {
  if [[ -n "$1" ]]; then
    PERMISSIONS_FILTER="$1"
    return
  fi

  while true; do
    read -p "Missing argument for permissions. Please enter the argument: " PERMISSIONS_FILTER

    if [[ "$PERMISSIONS_FILTER" =~ ^([0-7]{3}|[ugoa]=[rwx])$ ]]; then
      break
    fi

    echo "Invalid argument for permissions. Please enter a valid argument"
  done
}

function generate_report() {
  echo ""
  echo "Generating report................."

  echo "" > "$REPORT_FILE"
  echo "----------- $(echo "$FILES" | wc -l) Files found -----------" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  declare -A files_by_owner
  declare -A owner_sizes
  
  TOTAL_SIZE="0"
 
  while read FILE; do
    FILENAME=$(basename "$FILE")
    FILE_INFO=($(stat -c "%s %A %U %y" "$FILE"))

    files_by_owner["${FILE_INFO[2]}"]+="${FILE_INFO[0]} $FILENAME ${FILE_INFO[1]} ${FILE_INFO[2]} ${FILE_INFO[3]}"$'\n'
    owner_sizes["${FILE_INFO[2]}"]=$((owner_sizes["${FILE_INFO[2]}"] + ${FILE_INFO[0]}))
    
    ((TOTAL_FILES++))
    ((TOTAL_SIZE += ${FILE_INFO[0]}))
    
  done <<< "$FILES"


  sorted_owners=$(for OWNER in "${!owner_sizes[@]}"; do echo "${owner_sizes[$OWNER]} $OWNER"; done | sort -rn | cut -d ' ' -f 2)

  for OWNER in $sorted_owners; do
    OWNER_SIZE=${owner_sizes["$OWNER"]}

    echo "Owner: $OWNER" >> "$REPORT_FILE"
    echo "Total Size: $OWNER_SIZE bytes" >> "$REPORT_FILE"
    echo "----------------------------" >> "$REPORT_FILE"

    sorted_files=$(echo "${files_by_owner["$OWNER"]}" | sort -k1,1rn)

    while read line; do
      read SIZE FILENAME PERMISSIONS OWNER LAST_MODIFIED <<< "$line"

      echo "File Name: $FILENAME" >> "$REPORT_FILE"
      echo "File permissions: $PERMISSIONS" >> "$REPORT_FILE"
      echo "File owner: $OWNER" >> "$REPORT_FILE"
      echo "File size(bytes): $SIZE" >> "$REPORT_FILE"
      echo "Last modification done on the file: $LAST_MODIFIED" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    done <<< "$sorted_files"

    echo "" >> "$REPORT_FILE"
  done

  echo "Report generated successfully. Please check $REPORT_FILE for the file analysis."

  echo "Summary Information"
  echo "Total Files: $TOTAL_FILES"
  echo "Total Size: $TOTAL_SIZE bytes"
}

while [ $# -gt 0 ]; do
  case $1 in
    -d|--directory)
      DIRECTORY="$2"
      shift 2
      ;;
    -e|--extensions)
      shift
      while [[ "$1" != -* ]] && [ $# -gt 0 ]; do
        EXTENSIONS+=("$1")
        shift
      done
      ;;
    -p|--permissions)
      if [ $# -ge 2 ] && [[ ! "$2" =~ ^- ]]; then
        validate_permissions_filter "$2"
        shift 2
      else
        validate_permissions_filter
        shift
      fi
      ;;
    -m|--modified)
      if [ $# -ge 2 ] && [[ ! "$2" =~ ^- ]]; then
        validate_last_modified_filter "$2"
        shift 2
      else
        validate_last_modified_filter
        shift
      fi
      ;;
    -s|--size)
      if [ $# -ge 2 ] && [[ ! "$2" =~ ^- ]]; then
        validate_size_filter "$2"
        shift 2
      else
        validate_size_filter
        shift
      fi
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    *)
      echo "Invalid option"
      display_help
      break
      ;;
  esac
done

validate_directory
validate_extension

regex_pattern=""
for extension in "${EXTENSIONS[@]}"; do
  if ! [ -z "$regex_pattern" ]; then
    regex_pattern+="\|"
  fi
  regex_pattern+="$extension"
done

FILES=$(find "$DIRECTORY" -type f -size "$SIZE_FILTER" -perm "-$PERMISSIONS_FILTER" -mmin "$LAST_MODIFIED_FILTER" -regex ".*\($regex_pattern\)$")

if [ -z "$FILES" ]; then
  echo "No files found with the specified extensions ($EXTENSIONS) in the directory '$DIRECTORY'."
  exit 4
fi

generate_report
