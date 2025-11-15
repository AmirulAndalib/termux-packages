# shellcheck shell=bash
termux_github_api_get_tag() {
	if [[ -z "$1" ]]; then
		termux_error_exit <<-EndOfUsage
			Usage: ${FUNCNAME[0]} project [tag_type] [filter_regex]?
			Returns the latest tag of the given package.
		EndOfUsage
	fi

	if [[ -z "${GITHUB_TOKEN:-}" ]]; then
		# Needed to use graphql API.
		termux_error_exit "GITHUB_TOKEN environment variable not set."
	fi

	local project="$1" tag_type="$2" filter_regex="$3"

	if [[ -n "${filter_regex}" && "${tag_type}" != "latest-regex" ]]; then
		termux_error_exit "You can only specify a filter regex with tag_type=latest-regex"
	fi

	local jq_filter
	local api_url="https://api.github.com"
	local -a curl_opts=(
		--silent
		--location
		--retry 10
		--retry-delay 1
		-H "Authorization: token ${GITHUB_TOKEN}"
		-H "Accept: application/vnd.github.v3+json"
		--write-out '|%{http_code}'
	)

	if [[ "${tag_type}" == "newest-tag" ]]; then
		# We use graphql intensively so we should slowdown our requests to avoid hitting github ratelimits.
		sleep 1

		api_url="${api_url}/graphql"
		jq_filter='.data.repository.refs.edges[0].node.name'
		curl_opts+=(-X POST)
		curl_opts+=(
			-d "$(
				cat <<-EOF | tr '\n' ' '
					{
						"query": "query {
							repository(owner: \"${project%/*}\", name: \"${project##*/}\") {
								refs(refPrefix: \"refs/tags/\", first: 1, orderBy: {
									field: TAG_COMMIT_DATE, direction: DESC
								})
								{
									edges {
										node {
											name
										}
									}
								}
							}
						}"
					}
				EOF
			)"
		)

	elif [[ "${tag_type}" == "latest-release-tag" ]]; then
		api_url="${api_url}/repos/${project}/releases/latest"
		jq_filter=".tag_name"
	elif [[ "${tag_type}" == "latest-regex" ]]; then
		api_url="${api_url}/repos/${project}/releases"
		jq_filter=".[].tag_name"
	else
		termux_error_exit <<-EndOfError
			ERROR: Invalid tag_type: '${tag_type}'.
			Allowed values: 'newest-tag', 'latest-release-tag', 'latest-regex'.
		EndOfError
	fi

	local response
	response="$(curl "${curl_opts[@]}" "${api_url}")"

	local http_code
	http_code="${response##*|}"
	# Why printf "%s\n"? Because echo interpolates control characters, which jq does not like.
	response="$(printf "%s\n" "${response%|*}")"

	local tag_name
	if [[ "${http_code}" == "200" ]]; then
		if jq --exit-status --raw-output "${jq_filter}" <<<"${response}" >/dev/null; then
			tag_name="$(jq --exit-status --raw-output "${jq_filter}" <<<"${response}")"
			tag_name="${tag_name#v}" # Remove leading 'v' which is common in version tag.
			if [[ -n "${filter_regex}" ]]; then
				tag_name="$(grep -P "${filter_regex}" <<<"$tag_name" | head -n 1)"
				[[ -z "${tag_name}" ]] && termux_error_exit "No tags matched regex '${filter_regex}' in '${response}'"
			fi
		else
			termux_error_exit "Failed to parse tag name from: '${response}'"
		fi
	elif [[ "${http_code}" == "404" ]]; then
		if jq --exit-status "has(\"message\") and .message == \"Not Found\"" <<<"${response}"; then
			termux_error_exit <<-EndOfError
				ERROR: No '${tag_type}' found (${api_url}).
					Try using '$(
					if [ "${tag_type}" = "newest-tag" ]; then
						echo "latest-release-tag"
					else
						echo "newest-tag"
					fi
				)'.
			EndOfError
		else
			termux_error_exit <<-EndOfError
				ERROR: Failed to get '${tag_type}'(${api_url})'.
				Response:
				${response}
			EndOfError
		fi
	else
		termux_error_exit <<-EndOfError
			ERROR: Failed to get '${tag_type}'(${api_url})'.
			HTTP code: ${http_code}
			Response:
			${response}
		EndOfError
	fi

	# If program control reached here and still no tag_name, then something went wrong.
	if [[ -z "${tag_name:-}" ]] || [[ "${tag_name}" == "null" ]]; then
		termux_error_exit <<-EndOfError
			ERROR: JQ could not find '${tag_type}'(${api_url})'.
			Response:
			${response}
			Please report this as bug.
		EndOfError
	fi

	echo "${tag_name}"
}
