#!/bin/bash

EXTENSIONS=()
DIRECTORY=""
REPORT_FILE="file_analysis.txt"
SIZE_FILTER=""
PERMISSIONS_FILTER=""
LAST_MODIFIED_FILTER=""

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
  echo "  -s, --size         Filter files by size (e.g., +1M for files larger than 1 megabyte)"
  echo "  -p, --permissions  Filter files by permissions (e.g., 644 for files with permissions 644)"
  echo "  -m, --modified     Filter files by last modified timestamp (e.g., '2023-01-01 00:00:00' for files modified after January 1, 2023)"
  echo "  -h, --help         Display help information"
  echo ""
}

function validate_directory() {
  while true; do
    if [ -z "$DIRECTORY" ]; then
      echo ""
      echo "Missing directory argument. Please enter a directory!"
    elif ! [ -d "$DIRECTORY" ]; then
      echo "$DIRECTORY is not a valid directory. Please enter a valid directory!"
    else
      break
    fi
    read -p "Enter a directory: " DIRECTORY
  done
}

function validate_extension() {
  while [ ${#EXTENSIONS[@]} -eq 0 ]; do
    if [ -z "${EXTENSIONS[0]}" ]; then
      echo ""
      echo "Missing file extension argument. Please enter a file extension!"
    elif ! [[ "${EXTENSIONS[0]}" =~ ^\.[a-zA-Z0-9]+$ ]]; then
      echo "Invalid file extension format. Please enter a valid file extension starting with a dot (e.g., .txt, .jpeg, .sh)."
    else
      break
    fi
    read -p "Enter a file extension: " -a EXTENSIONS
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

  while read FILE; do
    FILENAME=$(basename "$FILE")
    FILE_INFO=($(stat -c "%s %A %U %y" "$FILE"))

    files_by_owner["${FILE_INFO[2]}"]+="${FILE_INFO[0]} $FILENAME ${FILE_INFO[1]} ${FILE_INFO[2]} ${FILE_INFO[3]}"$'\n'
    owner_sizes["${FILE_INFO[2]}"]=$((owner_sizes["${FILE_INFO[2]}"] + ${FILE_INFO[0]}))
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
}

while [ $# -gt 0 ]; do
  case $1 in
    -d|--directory)
      DIRECTORY="$2"
      shift 2
      ;;
    -e|--extensions)
       shift
      EXTENSIONS=("$@")
      break
      ;;
      -s|--size)
      SIZE_FILTER="$2"
      shift 2
      ;;
    -p|--permissions)
      PERMISSIONS_FILTER="$2"
      shift 2
      ;;
    -m|--modified)
      LAST_MODIFIED_FILTER="$2"
      shift 2
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

# Build the find command with filters
find_command="find \"$DIRECTORY\" -type f -regex \".*\\($regex_pattern\\)$\""

if [ -n "$SIZE_FILTER" ]; then
  find_command+=" -size $SIZE_FILTER"
fi

if [ -n "$PERMISSIONS_FILTER" ]; then
  find_command+=" -perm $PERMISSIONS_FILTER"
fi

if [ -n "$LAST_MODIFIED_FILTER" ]; then
  find_command+=" -newermt \"$LAST_MODIFIED_FILTER\""	
fi

# Search for files and store the result
FILES=$(eval "$find_command")

if [ -z "$FILES" ]; then
  echo "No files found with the specified extensions and filters in the directory '$DIRECTORY'."
  exit 4
fi

generate_report
