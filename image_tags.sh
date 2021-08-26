#!/usr/bin/env sh

# NOTE: This implementation makes use of the local keyword. While this is not a
# pure POSIX shell construction, it is available in almost all implementations.

_img_downloader() {
    if command -v curl >/dev/null; then
        [ "$_verbose" = "1" ] && echo "Using curl for downloads" >&2
        # shellcheck disable=SC2037
        printf %s\\n "curl -sSL"
    elif command -v wget >/dev/null; then
        [ "$_verbose" = "1" ] && echo "Using wget for downloads" >&2
        # shellcheck disable=SC2037
        printf %s\\n "wget -q -O -"
    else
        printf %s\\n ""
    fi
}

_img_authorizer() {
    # shellcheck disable=SC3043
    local _qualifier
    _qualifier="$(printf %s\\n "$1" | cut -d / -f 1)"
    if printf %s\\n "$_qualifier" | grep -qE '^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[A-Za-z]{2,6}$'; then
        case "$_qualifier" in
            docker.*)
                printf %s\\n "auth.docker.io";;
            *)
                printf %s\\n "${_qualifier}";;
        esac
    else
        printf %s\\n "auth.docker.io"
    fi
}

_img_registry() {
    # shellcheck disable=SC3043
    local _qualifier
    _qualifier="$(printf %s\\n "$1" | cut -d / -f 1)"
    if printf %s\\n "$_qualifier" | grep -qE '^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[A-Za-z]{2,6}$'; then
        case "$_qualifier" in
            docker.*)
                printf %s\\n "registry.docker.io";;
            *)
                printf %s\\n "${_qualifier}";;
        esac
    else
        printf %s\\n "registry.docker.io"
    fi
}

_img_image() {
    # shellcheck disable=SC3043
    local _qualifier
    _qualifier="$(printf %s\\n "$1" | cut -d / -f 1)"
    if printf %s\\n "$_qualifier" | grep -qE '^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[A-Za-z]{2,6}$'; then
        printf %s\\n "$1" | cut -d / -f 2-
    elif printf %s\\n "$1" | grep -q '/'; then
        printf %s\\n "$1"
    else
        printf %s\\n "library/$1"
    fi
}

github_releases() {
    # shellcheck disable=SC3043
    local _verbose=0 ; # Be silent by default
    # shellcheck disable=SC3043
    local _api=https://api.github.com/; # GitHub API root
    # shellcheck disable=SC3043
    local _jq=jq     ; # Default is to look for jq under the PATH
    # shellcheck disable=SC3043
    local _ver='v[0-9]+\.[0-9]+\.[0-9]+'; # How to extract the release number
    # shellcheck disable=SC3043
    local _field='tag_name'; # Which JSON field to extract the release # from
    while [ $# -gt 0 ]; do
        case "$1" in
            -g | --github)
                _api=$2; shift 2;;
            --github=*)
                _api="${1#*=}"; shift 1;;

            --jq)
                _jq=$2; shift 2;;
            --jq=*)
                _jq="${1#*=}"; shift 1;;

            -f | --field)
                _field=$2; shift;;
            --field=*)
                _field="${1#*=}"; shift 1;;

            -r | --release)
                _ver=$2; shift;;
            --release=*)
                _ver="${1#*=}"; shift 1;;

            -v | --verbose)
                _verbose=1; shift;;
            --verbose=*)
                _verbose="${1#*=}"; shift 1;;

            --trace)
                _verbose=2; shift;;

            --)
                shift; break;;
            -*)
                echo "$1 unknown option!" >&2; return 1;;
            *)
                break;
        esac
    done

    # Decide how to download silently
    # shellcheck disable=SC3043
    local download
    download="$(_img_downloader)"
    if [ -z "$download" ]; then return 1; fi

    if [ "$#" = "0" ]; then
        return 1
    fi

    # Decide if we can use jq or not
    if ! command -v "$_jq" >/dev/null; then
        [ "$_verbose" -ge "1" ] && echo "jq not found as $_jq, will approximate" >&2
        _jq=
    fi

    [ "$_verbose" -ge "1" ] && echo "Getting releases for $1" >&2
    if [ -z "$_jq" ]; then
        $download "${_api%/}/repos/$1/releases" |
            grep -oE "[[:space:]]*\"${_field}\"[[:space:]]*:[[:space:]]*\"(${_ver})\"" |
            sed -E "s/[[:space:]]*\"${_field}\"[[:space:]]*:[[:space:]]*\"(${_ver})\"/\\1/"
    else
        $download "${_api%/}/repos/$1/releases" |
            jq -r ".[].${_field}"
    fi
}


# Try using the API as in img_labels and as in the ruby implementation
# https://github.com/Jack12816/plankton/blob/58bd9deee339c645d36454a3819d95fcfe34e55d/lib/plankton/monkey_patches.rb#L119
# instead.
img_tags() {
    # shellcheck disable=SC3043
    local _filter=".*"
    # shellcheck disable=SC3043
    local _verbose=0 ; # Be silent by default
    # shellcheck disable=SC3043
    local _reg=      ; # Guess the registry by default
    # shellcheck disable=SC3043
    local _auth=     ; # Guess where to authorise by default
    # shellcheck disable=SC3043
    local _token=    ; # Authorisation token, when empty (default) go get it first
    # shellcheck disable=SC3043
    local _jq=jq     ; # Default is to look for jq under the PATH
    while [ $# -gt 0 ]; do
        case "$1" in
            -f | --filter)
                _filter=$2; shift 2;;
            --filter=*)
                _filter="${1#*=}"; shift 1;;

            -r | --registry)
                _reg=$2; shift 2;;
            --registry=*)
                _reg="${1#*=}"; shift 1;;

            -a | --auth)
                _auth=$2; shift 2;;
            --auth=*)
                _auth="${1#*=}"; shift 1;;

            -t | --token)
                _token=$2; shift 2;;
            --token=*)
                _token="${1#*=}"; shift 1;;

            --jq)
                _jq=$2; shift 2;;
            --jq=*)
                _jq="${1#*=}"; shift 1;;

            -v | --verbose)
                _verbose=1; shift;;
            --verbose=*)
                _verbose="${1#*=}"; shift 1;;

            --trace)
                _verbose=2; shift;;

            --)
                shift; break;;
            -*)
                echo "$1 unknown option!" >&2; return 1;;
            *)
                break;
        esac
    done

    # Decide how to download silently
    # shellcheck disable=SC3043
    local download
    download="$(_img_downloader)"
    if [ -z "$download" ]; then return 1; fi

    if [ "$#" = "0" ]; then
        return 1
    fi

    # Decide if we can use jq or not
    if ! command -v "$_jq" >/dev/null; then
        [ "$_verbose" -ge "1" ] && echo "jq not found as $_jq, will approximate" >&2
        _jq=
    fi

    # Library images or user/org images?
    # shellcheck disable=SC3043
    local _img
    _img="$(_img_image "$1")"
    [ -z "$_reg" ] && _reg=https://$(_img_registry "$1")
    if [ "${_reg%%/}" = "https://registry.docker.io" ]; then
        _reg=https://registry-1.docker.io
    fi

    # Authorizing at Docker for that image. We need to do this, even for public
    # images.
    if [ -z "$_token" ]; then
        if [ "$_verbose" -ge "1" ]; then
            _token=$(img_auth --jq="$_jq" --auth="$_auth" --verbose -- "$1")
        else
            _token=$(img_auth --jq="$_jq" --auth="$_auth" -- "$1")
        fi
        [ "$_verbose" -ge "2" ] && echo ">> Auth token: $_token" >&2
    fi

    if [ -n "$_token" ] && [ "$_token" != "null" ]; then
        # Get the digest of the image configuration
        [ "$_verbose" -ge "1" ] && echo "Getting tags for ${_img}" >&2
        if [ -z "$_jq" ]; then
            $download \
                    --header "Authorization: Bearer $_token" \
                    "${_reg%%/}/v2/${_img}/tags/list?n=40" |
                grep -E '.*"tags"[[:space:]]*:[[:space:]]*\[([^]]+)\]' |
                sed -E 's/.*"tags"[[:space:]]*:[[:space:]]*\[([^]]+)\].*/\1/' |
                sed -E 's/"[[:space:]]*,[[:space:]]*/\n/g' |
                sed -E -e 's/^"//g' -e 's/"$//' |
                grep -E "$_filter"
        else
            $download \
                    --header "Authorization: Bearer $_token" \
                    "${_reg%%/}/v2/${_img}/tags/list" |
                jq -r .tags |
                head -n -1 | tail -n +2 |
                sed -E -e 's/^[[:space:]]*"//g' -e 's/",?$//' |
                grep -E "$_filter"
        fi
    fi
}

img_auth() {
    # shellcheck disable=SC3043
    local _verbose=0 ; # Be silent by default
    # shellcheck disable=SC3043
    local _auth=     ; # Default is to guess where to authorise
    # shellcheck disable=SC3043
    local _jq=jq     ; # Default is to look for jq under the PATH
    while [ $# -gt 0 ]; do
        case "$1" in
            -a | --auth)
                _auth=$2; shift 2;;
            --auth=*)
                _auth="${1#*=}"; shift 1;;

            --jq)
                _jq=$2; shift 2;;
            --jq=*)
                _jq="${1#*=}"; shift 1;;

            -v | --verbose)
                _verbose=1; shift;;
            --verbose=*)
                _verbose="${1#*=}"; shift 1;;

            --)
                shift; break;;
            -*)
                echo "$1 unknown option!" >&2; return 1;;
            *)
                break;
        esac
    done

    # Decide how to download silently
    # shellcheck disable=SC3043
    local download
    download="$(_img_downloader)"
    if [ -z "$download" ]; then return 1; fi

    if [ "$#" = "0" ]; then
        return 1
    fi

    # Decide if we can use jq or not
    if ! command -v "$_jq" >/dev/null; then
        [ "$_verbose" -ge "1" ] && echo "jq not found as $_jq, will approximate" >&2
        _jq=
    fi

    # Library images or user/org images?
    # shellcheck disable=SC3043
    local _img
    _img="$(_img_image "$1")"

    # Default authorizer
    [ -z "$_auth" ] && _auth=https://$(_img_authorizer "$1")/

    # Authorizing at Docker for that image
    [ "$_verbose" -ge "1" ] && echo "Authorizing for $_img at $_auth" >&2
    if [ -z "$_jq" ]; then
        $download "${_auth%%/}/token?scope=repository:$_img:pull&service=$(_img_registry "$1")" |
            grep -E '^\{?[[:space:]]*"token"' |
            sed -E 's/\{?[[:space:]]*"token"[[:space:]]*:[[:space:]]*"([a-zA-Z0-9_.-]+)".*/\1/'
    else
        $download "${_auth%%/}/token?scope=repository:$_img:pull&service=$(_img_registry "$1")" |
            $_jq -r '.token'
    fi
}

img_labels() {
    # shellcheck disable=SC3043
    local _verbose=0 ; # Be silent by default
    # shellcheck disable=SC3043
    local _reg=      ; # Guess the registry by default
    # shellcheck disable=SC3043
    local _auth=     ; # Guess where to authorise by default
    # shellcheck disable=SC3043
    local _jq=jq     ; # Default is to use jq from the PATH when it exists
    # shellcheck disable=SC3043
    local _pfx=      ; # Prefix to add in front of each label name
    # shellcheck disable=SC3043
    local _token=    ; # Authorisation token, when empty (default) go get it first
    while [ $# -gt 0 ]; do
        case "$1" in
            -r | --registry)
                _reg=$2; shift 2;;
            --registry=*)
                _reg="${1#*=}"; shift 1;;

            -a | --auth)
                _auth=$2; shift 2;;
            --auth=*)
                _auth="${1#*=}"; shift 1;;

            -p | --prefix)
                _pfx=$2; shift 2;;
            --prefix=*)
                _pfx="${1#*=}"; shift 1;;

            --jq)
                _jq=$2; shift 2;;
            --jq=*)
                _jq="${1#*=}"; shift 1;;

            -t | --token)
                _token=$2; shift 2;;
            --token=*)
                _token="${1#*=}"; shift 1;;

            -v | --verbose)
                _verbose=1; shift;;
            --verbose=*)
                _verbose="${1#*=}"; shift 1;;

            --trace)
                _verbose=2; shift;;

            --)
                shift; break;;
            -*)
                echo "$1 unknown option!" >&2; return 1;;
            *)
                break;
        esac
    done

    # Decide how to download silently
    # shellcheck disable=SC3043
    local download
    download="$(_img_downloader)"
    if [ -z "$download" ]; then return 1; fi

    if [ "$#" = "0" ]; then
        return 1
    fi

    # Decide if we can use jq or not
    if ! command -v "$_jq" >/dev/null; then
        [ "$_verbose" -ge "1" ] && echo "jq not found as $_jq, will approximate" >&2
        _jq=
    fi

    # Library images or user/org images?
    # shellcheck disable=SC3043
    local _img
    _img="$(_img_image "$1")"
    [ -z "$_reg" ] && _reg=https://$(_img_registry "$1")
    if [ "${_reg%%/}" = "https://registry.docker.io" ]; then
        _reg=https://registry-1.docker.io
    fi

    # Default to tag called latest when none specified
    # shellcheck disable=SC3043
    local _tag
    if [ "$#" -ge "2" ]; then
        _tag=$2
    else
        [ "$_verbose" -ge "1" ] && echo "No tag specified, defaulting to latest" >&2
        _tag=latest
    fi

    # Authorizing at Docker for that image. We need to do this, even for public
    # images.
    if [ -z "$_token" ]; then
        if [ "$_verbose" -ge "1" ]; then
            _token=$(img_auth --jq="$_jq" --auth="$_auth" --verbose -- "$1")
        else
            _token=$(img_auth --jq="$_jq" --auth="$_auth" -- "$1")
        fi
        [ "$_verbose" -ge "2" ] && echo ">> Auth token: $_token" >&2
    fi

    if [ -n "$_token" ] && [ "$_token" != "null" ]; then
        # Get the digest of the image configuration
        [ "$_verbose" -ge "1" ] && echo "Getting digest for ${_img}:${_tag}" >&2
        if [ -z "$_jq" ]; then
            _digest=$(  $download \
                            --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                            --header "Authorization: Bearer $_token" \
                            "${_reg%%/}/v2/${_img}/manifests/$_tag" |
                        grep -E '"digest"' |
                        head -n 1 |
                        sed -E 's/[[:space:]]*"digest"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' )
        else
            _digest=$(  $download \
                            --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                            --header "Authorization: Bearer $_token" \
                            "${_reg%%/}/v2/${_img}/manifests/$_tag" |
                        $_jq -r '.config.digest' )
        fi
        [ "$_verbose" -ge "2" ] && echo ">> Digest: $_digest" >&2

        if [ -n "$_digest" ] && [ "$_digest" != "null" ]; then
            # Download the content of the image configuration. This will be in JSON
            # format. Then isolate the labels present at .container_config.Labels (or is
            # it .config.Labels?) and reprint them in something that can be evaluated if
            # necessary, i.e. label=value
            [ "$_verbose" -ge "1" ] && echo "Getting configuration for ${_img}:${_tag}" >&2
            if [ -z "$_jq" ]; then
                _conf=$($download \
                            --header "Authorization: Bearer $_token" \
                            "${_reg%%/}/v2/${_img}/blobs/$_digest")
                # Check if "Labels" is null or empty, if not isolate everything between
                # the opening and end curly brace and look for labels there. This will
                # not work if the label name or content contains curly braces! In the
                # JSON block after "Labels", we remove the leading and ending curly
                # brace and replace "," with quotes with line breaks in between.
                if ! printf %s\\n "$_conf" | grep -qE '"Labels"[[:space:]]*:[[:space:]]*(null|\{\})'; then
                    printf %s\\n "$_conf" |
                    sed -E 's/.*"Labels"[[:space:]]*:[[:space:]]*(\{[^}]+\}).*/\1/' |
                    sed -e 's/^{//' -e 's/}$//' -e 's/","/"\n"/g' |
                    sed -E "s/[[:space:]]*\"([^\"]+)\"[[:space:]]*:[[:space:]]*\"(.*)\"\$/${_pfx}\1=\2/g"
                fi
            else
                $download \
                    --header "Authorization: Bearer $_token" \
                    "${_reg%%/}/v2/${_img}/blobs/$_digest" |
                $_jq -r '.container_config.Labels' |
                head -n -1 | tail -n +2 |
                sed -E 's/(.+),$/\1/g' |
                sed -E "s/[[:space:]]*\"([^\"]+)\"[[:space:]]*:[[:space:]]*\"(.*)\"\$/${_pfx}\1=\2/g"
            fi
        fi
    fi
}


img_newtags() {
    # shellcheck disable=SC3043
    local _flt=".*"
    # shellcheck disable=SC3043
    local _verbose=0 ; # Be silent by default
    # shellcheck disable=SC3043
    local _reg=      ; # Guess the registry by default
    # shellcheck disable=SC3043
    local _auth=     ; # Guess where to authorise by default
    # shellcheck disable=SC3043
    local _token=    ; # Authorisation token, when empty (default) go get it first
    # shellcheck disable=SC3043
    local _jq=jq     ; # Default is to look for jq under the PATH
    while [ $# -gt 0 ]; do
        case "$1" in
            -f | --filter)
                _flt=$2; shift 2;;
            --filter=*)
                _flt="${1#*=}"; shift 1;;

            -r | --registry)
                _reg=$2; shift 2;;
            --registry=*)
                _reg="${1#*=}"; shift 1;;

            -a | --auth)
                _auth=$2; shift 2;;
            --auth=*)
                _auth="${1#*=}"; shift 1;;

            -t | --token)
                _token=$2; shift 2;;
            --token=*)
                _token="${1#*=}"; shift 1;;

            --jq)
                _jq=$2; shift 2;;
            --jq=*)
                _jq="${1#*=}"; shift 1;;

            -v | --verbose)
                _verbose=1; shift;;

            --)
                shift; break;;
            -*)
                echo "$1 unknown option!" >&2; return 1;;
            *)
                break;
        esac
    done

    [ "$#" -lt "2" ] && return 1

    # shellcheck disable=SC3043
    local _existing
    _existing="$(mktemp)"

    [ "$_verbose" = "1" ] && echo "Collecting relevant tags for $2" >&2
    # shellcheck disable=SC2086
    img_tags \
        --verbose=$_verbose \
        --filter "$_flt" \
        --registry "$_reg" \
        --jq="$_jq" \
        --auth="$_auth" \
        --token="$_token" \
        -- \
            "$2" > "$_existing"
    [ "$_verbose" = "1" ] && echo "Diffing against relevant tags for $1" >&2
    # shellcheck disable=SC2086
    img_tags \
        --verbose=$_verbose \
        --filter "$_flt" \
        --registry "$_reg" \
        --jq="$_jq" \
        --auth="$_auth" \
        --token="$_token" \
        -- \
            "$1" |
        grep -F -x -v -f "$_existing"

    rm -f "$_existing"
}

img_unqualify() {
    printf %s\\n "$1" | sed -E 's/^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[A-Za-z]{2,6}\///'
}


# From: https://stackoverflow.com/a/37939589
img_version() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}
