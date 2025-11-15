# shellcheck shell=bash
# Default algorithm to use for packages hosted on github.com
termux_github_auto_update() {
	local latest_tag tag_type project filter_regex=""

	if [[ -z "${TERMUX_PKG_UPDATE_TAG_TYPE}" ]]; then # If not set, then decide on the basis of url.
		if [[ "${TERMUX_PKG_SRCURL:0:4}" == "git+" ]]; then
			# Get newest tag.
			tag_type="newest-tag"
		else
			# Get the latest release tag.
			tag_type="latest-release-tag"
		fi
	else
		[[ "$TERMUX_PKG_UPDATE_TAG_TYPE" == "latest-regex" ]] && filter_regex="$TERMUX_PKG_UPDATE_VERSION_REGEXP"
	fi

	project="$(echo "${TERMUX_PKG_SRCURL}" | cut -d'/' -f4-5)"
	project="${project#git+}"
	# shellcheck disable=SC2086
	latest_tag="$(termux_github_api_get_tag "${project}" "${TERMUX_PKG_UPDATE_TAG_TYPE}" $filter_regex)"

	if [[ -z "${latest_tag}" ]]; then
		termux_error_exit "Unable to get tag from ${TERMUX_PKG_SRCURL}"
	fi

	termux_pkg_upgrade_version "${latest_tag}"
}
