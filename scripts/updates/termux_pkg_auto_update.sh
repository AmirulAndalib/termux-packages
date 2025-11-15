# shellcheck shell=bash
termux_pkg_auto_update() {
	if [[ -n "${__CACHED_TAG:-}" ]]; then
		termux_pkg_upgrade_version "${__CACHED_TAG}"
		return $?
	fi

	local project_host
	project_host="$(echo "${TERMUX_PKG_SRCURL}" | cut -d"/" -f3)"

	if [[ -z "${TERMUX_PKG_UPDATE_METHOD}" ]]; then
		if [[ "${project_host}" == "github.com" ]]; then
			TERMUX_PKG_UPDATE_METHOD="github"
		elif [[ "${project_host}" == "gitlab.com" ]]; then
			TERMUX_PKG_UPDATE_METHOD="gitlab"
		else
			TERMUX_PKG_UPDATE_METHOD="repology"
		fi
	fi

	case "${TERMUX_PKG_UPDATE_METHOD}" in
	github)
		if [[ "${project_host}" != "github.com" ]]; then
			termux_error_exit "package does not seems to be hosted on github.com, but has been configured to use it's method."
		else
			termux_github_auto_update
		fi
		;;
	gitlab)
		if [[ "${project_host}" != "${TERMUX_GITLAB_API_HOST}" ]]; then
			termux_error_exit "package does not seems to be hosted on ${TERMUX_GITLAB_API_HOST}, but has been configured to use it's method."
		else
			termux_gitlab_auto_update
		fi
		;;
	repology)
		termux_repology_auto_update
		;;
	*)
		termux_error_exit <<-EndOfError
			ERROR: wrong value '${TERMUX_PKG_UPDATE_METHOD}' for TERMUX_PKG_UPDATE_METHOD.
			Can be 'github', 'gitlab' or 'repology'
		EndOfError
		;;
	esac
}
