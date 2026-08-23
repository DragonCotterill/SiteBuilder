#!/bin/bash
#set -o errexit
set -o nounset
set -o pipefail # Always Set this. It means that if any command fails in a pipeline, then the exit code is retained, rather than just the last entry

# Global Flags
CONTENTDIR="Content"
ROOTDIR=$(pwd)
PUBLICDIR="Public"
TEMPLATEDIR="Templates"
WEBDIR="www"
VERBOSE=false
FORCE=false
DEFAULTTEMPLATE="base.html"
OFFSETDIR="/"
# The config file resides in the Templates directory. It is used as default setup for a variety of static variables. If it cannot be found, the value is blanked out.
CONFIGFILE="config"
# External applications and utilities
DEPENDENCIES="pandoc"

setup_colors() {
#  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
	if [ -t 1 ]; then
		NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
	else
		NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
	fi
}

err() {
  echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: ${ORANGE}$*${NOFORMAT}" >&2
}

die() {
	echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: ${RED}Fatal: ${NOFORMAT}${1}" >&2
	exit 1
}

verb_log() {
	[[ ${VERBOSE} = true ]] && echo -e "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: ${GREEN}[+]${NOFORMAT} ${1}"
	return 0
}

installed_and_executable() {
	cmd=$(command -v "${1}")
	[[ -n "${cmd}" ]] && [[ -f "${cmd}" ]] && [[ -x "${cmd}" ]]
	return ${?}
}

html_escape() {
	local s="$1"
	s="${s//&/&amp;}"
	s="${s//</&lt;}"
	s="${s//>/&gt;}"
	s="${s//\"/&quot;}"
	s="${s//\'/&#39;}"
	printf '%s' "${s}"
}

print_help() {
  echo -e "${CYAN}Sitebuilder${NOFORMAT}"
  echo -e "A simple static page generator. Give it a template and a series of Markdown text files and it'll produce a full website."
  echo -e ""
  echo -e "${CYAN}Usage:${NOFORMAT}"
	echo -e "  sitebuilder.sh [-b <templatename>] [-c <dir>] [-p <dir>] [-r <path>] [-t <dir>] [-w <dir>]"
	echo -e "  sitebuilder.sh -h"
  echo -e ""
  echo -e "${CYAN}Options:${NOFORMAT}"
  echo -e "  -b <templatename> The base template name to use (default \"template.html\")"
  echo -e "  -c <dir>	Content Directory (Default \"Content\")"
  echo -e "  -d		Print the full documentation"
  echo -e "  -f   FORCE update of all documents (Deletes all previous documents)"
  echo -e "  -g   Load a config file. (Default none)"
  echo -e "  -o   Offset directory - used to put everything into a sub-directory (Default \"/\")"
  echo -e "  -p <dir>	Public Directory (Default \"Public\")"
  echo -e "  -r <path>	Path to root of site. Default is to use the current directory."
  echo -e "  -t <dir>	Templates directory (Default \"Templates\")"
  echo -e "  -w <dir>	Web directory (Default \"www\")"
  echo -e "  -v		VERBOSE. List all processing and messages"
  echo -e "  -h		Show help"
}

print_docs() {
  cat<<ENDHELP
Sitebuilder

Overview:
	A simple static page generator. Give it a template and a series of Markdown text files and it'll produce a full website.

Directory Structure:
	Content	- Contains directories and files which are the basic content of the site.
	Public	- All files which are to be made public and unchanged. Typically graphics/images, Stylesheets, .pdf files and other non-mutable content.
	Templates 	- HTML templates.
	www 		- Where all the resulting files end up.

	All of these locations can be specified as parameters when running SiteBuilder, the default is that these locations exist in the current working directory.
	SiteBuilder will look for an "index.txt" (or "index.md") file in all directories to be used as the content for that directory. Directories and files may be preceeded with a number followed by a dot (.) to order the contents appropriately. These values are removed from the resulting items.

Files:
	config - Resides in the Template directory. Can store a number of default global values.
	All files ending with .txt or .md in the Content directory will be converted to .html files in the www directory in the same directory structure.
	Files may be preceeded by a number followed by a dot eg. 1.First Page.txt, 2.Second Page.txt etc. to automatically sort the entries. The number and dot are removed during processing leaving only the the text after the dot, but the order will be retained. Useful for Next/Prev pointers.


Content Structure:
	An example file can be as simple as:
---
@Template OtherTemplate.html
@Title Example Title
@Tags This, That, The Other
@Body
Here is the main content of the page.

---

A variable is declared with an at "@" at the start of the line. Everything after the first space is considered as the various content upto another @ entry or the end of the file. Variables are usually case sensitive, so it's best to be consistent in how they are defined.
If the Template variable is modified then it overrides the default "Template:" value in the config.data file.

Variables:
	To use a variable within a template, simply enclose it within double curly braces. eg. {{Title}}
	There is also an optional way of using variables in case they have NOT been defined, or the value is nothing (""). Use {{Title|Some title}} to use "Some title" should one not be defined.
	There is also an inclusion value that if a variable HAS been defined, and is not empty ("") then replace it with something else. Use {{Tags>These tags have been defined {{Tags}}}} so that if the "Tags" variable has been defined replace it with some extra text.
	NB. Variable names are case-sensitive. Do not use { or } values as standalone values within the replacements. The results would be unpredictable.

	Only the variable "Body" will be parsed as Markdown. Everything else will be passed as-is.

Reserved List Variables:
	There are a number of variables which are computed automatically based on the directory structure of the Content directory. These are automatically created as un-ordered lists and may be stylised with CSS.
	{{PrimaryNavigation}} - Based on the root of the Content Directory. No link to the Home directory.
	{{SecondaryNavigation}} - Based on the directory structure for each underlying directory, used within pages in that specifc directory. Not used in the root directory.
	{{Navigation}} - A complete heirarchical directory and file structure.
	{{BreadCrumbs}} - A directory list to the current working file. TODO: Not implemented yet.
	{{Include|<filename>}} - which will include <filename> from the Templates directory. In this way you can also include additional shared elements based on defined variables.
	{{Digest}} or {{DigestReverse}} - This will go through all of the entries in the current directory and use the variable values of "@Digest" as entries. If this is added to the Index entry then all other files could have a single line which will be included in the output. {{Digest}} sorts alphabetically, {{DigestReverse}} sorts in reverse order. If a file does not have a @Digest value then it simply won't be included. This is only computed at run-time. If you add a new file, then you'll also need to update the file containing the {{Digest}} command for it to be included.

	In addition, each top level <ul> entry is given the ID PrimaryNavigation, SecondayNavigation and Navigation as appropriate.

Reserved Non-list variables:
	{{NavigateNext}}, {{NavigatePrevious}} - The filename of the next or previous document within the directory. Blank if no such document exists.
	{{NavigateNextName}}, {{NavigatePreviousName}} - The real document name to the next or previous document within the directory. Blank if no such document exists.
	{{TagList}} - List of Tags used throughout the site. NB. Adding a new page with an additional tag will NOT update other (older) documents. Use the -f flag to FORCE a site-wide update.

NB. Do NOT embed multiple variable replacements inside other variables.
	DO NOT do this:
	{{NavigateNext><a href="{{NavigateNext}}"><span class="next">{{NavigateNextName}}</span></a>}}
	Do this instead:
	@NavNext <a href="{{NavigateNext}}"><span class="next">{{NavigateNextName}}</span></a>
	{{NavigateNext>{{NavNext}}}}

	In this way, if a NavigateNext (or NavigatePrevious) value is detected then the relevant value would be included. If the NavigatePrevious value is blank, then the whole inclusion value would be skipped. If you need to include multiple replacement values, then create intermediate variables instead.

The regex is not forgiving! 

ENDHELP
}

check_deps() {
	local deps="${DEPENDENCIES}"

	for dep in "${deps[@]}"; do
		installed_and_executable "${dep}" || die "Missing '${dep}' dependency or not executable"
	done
}

walk() {
	local indent="${2:-0}"
	basename "${1}"
	printf "%*s%s\n" "${indent}" '' "$1"
	for entry in "$1"/*; do
		[[ -d "${entry}" ]] && walk "${entry}" $((indent+4))
	done
}

add_entry() {
	if [[ ${tmpentry} == "" ]]; then
		tmpentry=${1}
	else
		tmpentry="${tmpentry}${1}"
	fi
}

rewrite_path() {
  echo "$1" | awk -F/ '{
   	for (i=1; i<=NF; i++) {
      gsub(/^[0-9]+\./, "", $i)  # remove leading number + dot
     	gsub(/_/, "", $i)          # remove underscores
   	}
   	print $0
 	}' OFS="/"
}

url_encode_path() {
	local s="$1"
	local out="" c i hex

# Encode bytes for safe href values, preserving "/" as a path separator.
	LC_ALL=C
	for (( i=0; i<${#s}; i++ )); do
		c="${s:i:1}"
		case "${c}" in
			[a-zA-Z0-9.~_/-])
				out+="${c}"
			;;
			*)
				printf -v hex '%%%02X' "'${c}"
				out+="${hex}"
			;;
		esac
	done

	printf '%s' "${out}"
}

display_name_for_entry() {
	local path="$1"
	local name="${path##*/}"
	local display="${name}"

# Remove leading number followed by a dot, e.g. "01.Intro" -> "Intro"
	display="${display#[0-9]*.}"

# Only remove file extensions from display text, not hrefs.
	if [[ -f "${path}" && "${display}" == *.* && "${display}" != .* ]]; then
		display="${display%.*}"
	fi

	printf '%s' "${display}"
}

nav_tree() {
	local dir="$1"
	local rel_base="$2"
	local entry name display href escaped_display escaped_href

	if [[ ${rel_base} == "" ]]; then
		printf "<ul id='Navigation'>"
	else
		printf "<ul>"
	fi

	shopt -s nullglob dotglob

	for entry in "$dir"/*; do
		name="${entry##*/}"

# Ignore entries starting with "_" or the main index.
		[[ "$name" == _* || "$name" == index.* ]] && continue

		if [[ -n "${rel_base}" ]]; then
			href="${rel_base}/$name"
		else
			href="${name}"
		fi

		display="$(display_name_for_entry "${entry}")"
		escaped_display="$(html_escape "${display}")"
		escaped_href="$(html_escape "$(url_encode_path "$(rewrite_path "$href")")")"
		escaped_href=$(echo "${escaped_href}" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt/\.html/; s/\.md/\.html/')

		if [[ -d "${entry}" ]]; then
	  	printf '  <li><a href="%s%s">%s</a>\n' "${OFFSETDIR}" "${escaped_href}" "${escaped_display}"
			nav_tree "${entry}" "${href}"
	  	printf '  </li>\n'
		elif [[ -f "${entry}" ]]; then
		  printf '  <li><a href="%s%s">%s</a></li>\n' "${OFFSETDIR}" "${escaped_href}" "${escaped_display}"
	  fi

	done
	printf '</ul>\n'
}

dump_digest() {
	local file="$1"
	local keyword="$2"
	grep "^${keyword}" "$file" 2>/dev/null | sed "s/^${keyword}[[:space:]]*//"
}

digest_sorted() {
	local dir="$1"
	local keyword="$2"
	find "${dir}" -type f | sort | while IFS= read -r file; do
		dump_digest "${file}" "${keyword}"
	done
}

digest_reverse() {
	local dir="$1"
	local keyword="$2"
	find "${dir}" -type f | sort -r | while IFS= read -r file; do
		dump_digest "${file}" "${keyword}"
	done
}

prev_file() {
	local target="$1"
	local dir
	dir=$(dirname -- "${target}")
	local base
	base=$(basename -- "${target}")

	local prev=""
	while IFS= read -r file; do
# If file name starts with an underscore, or is index.(txt/md) then completely ignore it.
		[[ "${file}" == _* || "${file}" == index.* ]] && continue
		if [[ "${file}" == "${base}" ]]; then
			[[ -n "${prev}" ]] && printf '%s\n' "${prev}"
			return
		fi
		prev="${file}"
	done < <(LC_ALL=C ls -1 -- "${dir}")
}

next_file() {
	local target="$1"
	local dir
	dir=$(dirname -- "${target}")
	local base
	base=$(basename -- "${target}")

	local found=0
	while IFS= read -r file; do
		[[ "${file}" == _* || "${file}" == index.* ]] && continue
		if (( found )); then
			printf '%s\n' "${file}"
			return
		fi
		[[ "${file}" == "${base}" ]] && found=1
	done < <(LC_ALL=C ls -1 -- "${dir}")
}

create_breadcrumbs() {
	local start_dir="$(realpath "$1")"
	local target_dir="$(realpath "$2")"
	local relative_path current dirs

# Verify target is beneath start
	case "${target_dir}" in
	"${start_dir}"/*) ;;
    *)
			echo "Error: '${target_dir}' is not a subdirectory of '${start_dir}'" >&2
			exit 1
		;;
	esac

# Extract path components between start and target
	relative_path="${target_dir#"$start_dir"/}"
	IFS='/' read -r -a dirs <<< "${relative_path}"

	echo "<ul id=\"BreadCrumbs\">"
	for ((i=0; i<${#dirs[@]}; i++)); do
		href=""
		for ((j=i+1; j<${#dirs[@]}; j++)); do
			href+="../"
		done
		if [[ -z "$href" ]]; then
			href="./"
		fi
		dirname=$(echo "${dirs[$i]}" | sed -E 's/^[0-9]+\.//; s/_//g')
		echo "<li><a href=\"${href}\">${dirname}</a></li>"
		if (( i < ${#dirs[@]} - 1 )); then
			echo "<ul>"
		fi
	done
	for ((i=${#dirs[@]}-2; i>=0; i--)); do
		echo "</ul>"
	done

	echo "</ul>"
}


create_secondary_nav() {
	verb_log "Creating Secondary Navigation for directory ${1}"

# Are we in the root directory?
	if [[ "${1}" = "${CONTENTDIR}" ]]; then
		sb_SecondaryNavigation=""
	else

		local tmpentry="<ul id='SecondaryNavigation'>"
		local entryval entryname
#		walk "${1}"

	  for entry in "$1"/*; do
	    [[ -d "$entry" ]] && basename "${entry}"
			entryval=$(basename "${entry}")
			entryname=$(basename "${entry}" | sed 's/^[0-9]\.//g')

			if [[ ${entryname:0:1} != "_" ]]; then
				if [[ -d "$entry" ]]; then
					verb_log "[SECDIR] ${entryname}"
					add_entry "<li><a href=\"${entryname}/\">${entryname}</a></li>"
				else
					entryname=$(echo "${entryname}" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt//; s/\.md//')
					if [[ ${entryname} != "index" ]]; then
						add_entry "<li><a href=\"${entryname}.html\">${entryname}</a></li>"
					fi
#					echo "File ${entryname}"
				fi
			fi

			verb_log "[SEC] ${entryval}"
 	 done
		sb_SecondaryNavigation="${tmpentry}</ul>"

	fi
}

create_primary_nav() {
	verb_log "Creating Primary Navigation ( ${CONTENTDIR} )"

	tmpentry="<ul id='PrimaryNavigation'>"
#	walk "${CONTENTDIR}"

  for entry in "$1"/*; do
#    [[ -d "$entry" ]] && basename "${entry}"
		entryval=$(basename "${entry}")
		entryname=$(basename "${entry}" | sed 's/^[0-9]\.//g')

		if [[ ${entryname:0:1} != "_" ]]; then
			if [[ -d "$entry" ]]; then
				verb_log "[DIR] ${entryname}"
				add_entry "<li><a href=\"${OFFSETDIR}${entryname}/\">${entryname}</a></li>"
			else
				entryname=$(echo "${entryname}" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt//; s/\.md//')
				if [[ ${entryname} != "index" ]]; then
					add_entry "<li><a href=\"${OFFSETDIR}${entryname}.html\">${entryname}</a></li>"
				fi
#				echo "File ${entryname}"
			fi
		fi

		verb_log "[PRI] ${entryval}"
  done
	sb_PrimaryNavigation="${tmpentry}</ul>"

# find Content -type d | awk -F'/' '{printf "%*s%s\n", 4*(NF-2), "", $0}'
# tree -L 1 --sort name | grep -v _ | grep -v index.txt | tail -n +2 | head -n -2

}

# Render the template using the pre-defined variables.
# Special inclusion of "include" as this will read is a default set of additional variables.
# $1 is the line from the Template file
# $2 is the Output file
# $3 is the original input file
render_template() {
	local text="$1"

  # {{var}} or {{var|alt}}
#  local re='\{\{([a-zA-Z_][a-zA-Z0-9_]*)([\|\>])?([^}]*)?\}\}'
  local re='\{\{([a-zA-Z_][a-zA-Z0-9_]*)([\|\>])?([^}]*[^{]*)?\}\}'

  while [[ $text =~ $re ]]; do
    local token="${BASH_REMATCH[0]}"
    local varname="${BASH_REMATCH[1]}"
    local incloption="${BASH_REMATCH[2]}"
    local alt="${BASH_REMATCH[3]}"
    local replacement tmpvarname

# WARNING! Variables are case sensitive.
#    if [[ ${!"sb_"+varname+x} && -n ${!"sb_"+varname} ]]; then


# Include is a special exemption. It will include a template component. This can be used for common elements.
    if [[ ( "${varname}" == "include" || "${varname}" == "Include" ) && -n ${alt} ]]; then
    	if [[ "${alt}" == *".."* ]]; then
    		die "Attempted out of bounds inclusion ${CYAN}'${alt}'"
    	fi
   		verb_log "INCLUDE ${alt}"
   		replacement=$(cat "${TEMPLATEDIR}/${alt}")

# Digest is a special exemption - It will include any @Digest entries from all files in the current directory.
# TODO: Consider piping the resulting output thrugh the markdown processor.
    elif [[ ( "${varname}" == "digest" || "${varname}" == "digestreverse" || "${varname}" == "Digest" || "${varname}" == "DigestReverse") ]]; then
    	dir=$(dirname "$3")
    	if [[ ( "${varname}" == "digest" || "${varname}" == "Digest" ) ]]; then
    		verb_log "Creating Digest for directory ${CYAN}${dir}${NOFORMAT}"
    		replacement=$(digest_sorted "${dir}" "@Digest")
    	else
    		replacement=$(digest_reverse "${dir}" "@Digest")
    	fi

    elif [[ ( "${varname}" == "breadcrumbs" || "${varname}" == "BreadCrumbs" ) ]]; then
    	dir=$(dirname "$3")
			verb_log "Creating BreadCrumbs between ${CYAN}${CONTENTDIR}}${NOFORMAT} and ${CYAN}${dir}${NOFORMAT}"
    	replacement=$(create_breadcrumbs "${CONTENTDIR}" "${dir}")

# Variable exists AND is non-empty
		elif [[ -v "sb_${varname}" ]]; then
			tmpvarname="sb_${varname}"
			replacement="${!tmpvarname}"
#			replacement=$(echo -e "${!tmpvarname}" | pandoc -f markdown -t html )

# The Body field is always processed through Markdown.
			if [[ "${varname}" == "Body" ]]; then
# Switched to pandoc because I want the ability to do tables.
				replacement=$(echo -e "${replacement}" | pandoc -f markdown -t html )
#				replacement=$(echo -e "$replacement" | markdown )
			fi

# The Option exists, and has additional content, so just throw the additional content straight in. If it has the original tag entry, then it would get re-parsed.
			if [[ "${incloption}" == ">" && "${replacement}" != "" ]]; then
				verb_log "${YELLOW}Found an include for ${GREEN}${varname}${YELLOW} replace with ${BLUE}${alt}${NOFORMAT}"
				replacement="${alt}"
      else
				verb_log "Got variable ${varname} -> ${tmpvarname} -- Replace with (${replacement})"
      fi

# Variable missing or empty, but alternative supplied, means we need to check what the option was.
# | indicates OR - Use the alt variable if the original was blank.
# > indicates AND - Use the alt variable if the original was NOT blank. (processed above)
# TODO: When processing lots of file, old variable names could be hanging around. This could cause unwanted issues. Maybe deleting (unset) old variables for each new file? But then you'd have to re-read the config etc. Not decided yet.
    elif [[ -n $alt ]]; then
			if [[ "${incloption}" == "|" ]]; then
				verb_log "${YELLOW}Found an empty value for ${GREEN}${varname}${YELLOW} replace with ${BLUE}${alt}${NOFORMAT}"
      	replacement="${alt}"
      fi
    else

# Variable missing and no alternative so replace with empty
      replacement=""
    fi

    text="${text/${token}/${replacement}}"
#		text=$(echo "$text" | sed 's/$token/$replacement/g')
  done

  echo -e "$text" >> "$2"
#  printf '%s' "$text" >> "$2"
}

flush_var() {
  if [[ -n "sb_$current_var" ]]; then
   	# Assign variable dynamically without trimming trailing newlines
   	printf -v "sb_$current_var" '%s' "$current_val"
		verb_log "Reading variable: sb_${current_var} = ${current_val}"
  fi
}

load_config() {
	local cfg_file="${1}"
	local current_var=""
	local current_val=""

	if [[ -z "$cfg_file" || ! -f "$cfg_file" ]]; then
 		die "File not found: $cfg_file"
 		exit 1
	fi

	verb_log "Reading Page: $cfg_file"

	while IFS= read -r line || [[ -n "$line" ]]; do
	  if [[ $line =~ ^@([A-Za-z_][A-Za-z0-9_]*) ]]; then
    	# New variable entry found, flush previous
    	flush_var
    	current_var="${BASH_REMATCH[1]}"
    	# Remove the @name part and leading spaces
    	current_val="${line#@${current_var}}"
    	current_val="${current_val# }"
  	else
	    # Append line to current_val with newline
    	current_val+=$'\n'"$line"
  	fi
	done < "$cfg_file"

	# Flush last variable
	flush_var
}

process_file() {
	local inputfile=${1}
	local outputfile=${2}
# Technically, the Input file is just a Config since it loads content into the variables. We actually process the Template to setup the final output.

# Check to skip a _digest file as it's not an active page.
	if [[ ! $(basename "${inputfile}") == "_digest" ]]; then

		verb_log "Processing file: ${inputfile} --> ${outputfile}"
		echo "" > "${outputfile}"

# Read through the input file first to set variables.
# If the CONFIGFILE is set, load it each time to reset any variables. Bit inefficient, but for the time being it works.
		if [[ -r "${CONFIGFILE}" ]]; then
			load_config "${CONFIGFILE}"
		fi

# It's not actually a config file, but the Content file is treated as such to set the necessary variables.
		load_config "${inputfile}"
# The local file may have changed which Template to use.
		verb_log "Use template: ${sb_Template}"

		create_secondary_nav "$(dirname "${inputfile}")"
		sb_NavigatePrevious=$(prev_file "${inputfile}" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt/.html/; s/\.md/.html/')
		sb_NavigateNext=$(next_file "${inputfile}" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt/.html/; s/\.md/.html/')
		sb_NavigatePreviousName=$(prev_file "${inputfile}" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt//; s/\.md//')
		sb_NavigateNextName=$(next_file "${inputfile}" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt//; s/\.md//')
		sb_Navigation=$(nav_tree "${CONTENTDIR}" "")

# Use the template (either original, or overwritten value) to process the file.
		while IFS= read -r line; do
#		echo $line
			render_template "$line" "${outputfile}" "${inputfile}"
		done < "${TEMPLATEDIR}/${sb_Template}"

	fi

}

copyfiles() {
	local SRC="$1"
	local DST="$2"
	local rel new_rel new_file new_dir dir rel base

	verb_log "Copying Content files."

	if [[ ! -d "${SRC}" ]]; then
	  die "Source directory does not exist: ${SRC}"
	  exit 1
	fi

	mkdir -p "${DST}"

# Create rewritten directory structure
	find "$SRC" -type d | while IFS= read -r dir; do
	  rel="${dir#$SRC/}"
	  [[ "$rel" == "$dir" ]] && continue

  	new_rel=$(rewrite_path "$rel")
  	mkdir -p "$DST/$new_rel"
	done

# Copy files with rewritten filenames
	find "$SRC" -type f | while IFS= read -r file; do
	  rel="${file#$SRC/}"
	  dir=$(dirname "$rel")
	  base=$(basename "$rel")

  	new_dir=$(rewrite_path "$dir")
  	new_file=$(echo "$base" | sed -E 's/^[0-9]+\.//; s/_//g; s/\.txt/.html/; s/\.md/.html/')

#mod_date=$(date -r "$file")
#verb_log "Checking $file $mod_date"
#verb_log "Against $DST/$new_dir/$new_file"
		if [ "$file" -nt "$DST/$new_dir/$new_file" ]; then # Check to see if current file is newer
			verb_log "Updating: $file"

			# Read and process the file, using whatever Template has been specified.
			process_file "$file" "${DST}/${new_dir}/${new_file}"

		fi
#  	cp -a "$file" "$DST/$new_dir/$new_file"

	done

	verb_log "Copy completed."
}

main() {
	setup_colors
	check_deps

	while getopts ":b:c:dfg:o:p:r:t:hv" opt; do
		case "${opt}" in
			b  ) DEFAULTTEMPLATE="${OPTARG}" ;;
			c  ) CONTENTDIR="${OPTARG}" ;;
			d  ) print_docs; exit 0 ;;
			f  ) FORCE=true ;;
			g  ) CONFIGFILE="${OPTARG}" ;;
			h  ) print_help; exit 0 ;;
			o  ) OFFSETDIR="${OPTARG}" ;;
			p  ) PUBLICDIR="${OPTARG}" ;;
			r  ) ROOTDIR="${OPTARG}" ;;
			t  ) TEMPLATEDIR="${OPTARG}" ;;
			v  ) VERBOSE=true ;;
			\? ) die "Unknown option: -${OPTARG}" ;;
			:  ) die "Missing option argument for -${OPTARG}" ;;
			*  ) die "Unimplemented option: -${opt}. See help (-h option)" ;;
		esac
	done

	verb_log "${CYAN}VERBOSE set to ${VERBOSE}${NOFORMAT}"
	verb_log "${CYAN}FORCE set to ${FORCE}${NOFORMAT}"

	CONTENTDIR="${ROOTDIR}/${CONTENTDIR}"
	PUBLICDIR="${ROOTDIR}/${PUBLICDIR}"
	TEMPLATEDIR="${ROOTDIR}/${TEMPLATEDIR}"
	WEBDIR="${ROOTDIR}/${WEBDIR}"
	DEFAULTTEMPLATE="${DEFAULTTEMPLATE}"
	sb_Template=${DEFAULTTEMPLATE}
	CONFIGFILE="${TEMPLATEDIR}/${CONFIGFILE}"

	verb_log "${CYAN}Root Directory set to${NOFORMAT}     : ${ROOTDIR}"
	verb_log "${CYAN}Content Directory set to${NOFORMAT}  : ${CONTENTDIR}"
	verb_log "${CYAN}Template Directory set to${NOFORMAT} : ${TEMPLATEDIR}"
	verb_log "${CYAN}Public Directory set to${NOFORMAT}   : ${PUBLICDIR}"
	verb_log "${CYAN}Web Directory set to${NOFORMAT}      : ${WEBDIR}"
	verb_log "${CYAN}Default template set to${NOFORMAT}   : ${DEFAULTTEMPLATE}"
	verb_log "${CYAN}Home Directory set to${NOFORMAT}     : ${OFFSETDIR}"

	if [[ -r $CONFIGFILE ]]; then
		verb_log "${CYAN}Config file set to${NOFORMAT}        : ${CONFIGFILE}"
	else
		CONFIGFILE=""
	fi

# Check for the FORCE option to clear the WEBDIR first.
	if [[ "${FORCE}" = "true" ]]; then
		verb_log "FORCE reset of Web directory"
		rm -rf ${WEBDIR}/*
	fi

# Deal with Public files
	verb_log "Copying Public Files"
	if [[ "${VERBOSE}" = "true" ]]; then
		cp -u -v -r ${PUBLICDIR}/* ${WEBDIR}
	else
		cp -u -r ${PUBLICDIR}/* ${WEBDIR}
	fi

	create_primary_nav "${CONTENTDIR}"

#	verb_log "Creating Secondary Navigations"
#	create_secondary_nav "${CONTENTDIR}"


# Copy Files
	copyfiles "${CONTENTDIR}" "${WEBDIR}${OFFSETDIR}"


}

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi
