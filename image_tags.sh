#!/usr/bin/env sh

img_tags() {
    _filter=".*"
    _verbose=0
    _reg=https://registry.hub.docker.com/
    _pages=
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

            -p | --pages)
                _pages=$2; shift 2;;
            --pages=*)
                _pages="${1#*=}"; shift 1;;

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

    # Decide how to download silently
    download=
    if command -v curl >/dev/null; then
        [ "$_verbose" = "1" ] && echo "Using curl for downloads" >&2
        # shellcheck disable=SC2037
        download="curl -sSL"
    elif command -v wget >/dev/null; then
        [ "$_verbose" = "1" ] && echo "Using wget for downloads" >&2
        # shellcheck disable=SC2037
        download="wget -q -O -"
    else
        return 1
    fi

    # Library images or user/org images?
    if printf %s\\n "$1" | grep -oq '/'; then
        hub="${_reg%/}/v2/repositories/$1/tags/"
    else
        hub="${_reg%/}/v2/repositories/library/$1/tags/"
    fi

    # Get number of pages
    if [ -z "$_pages" ]; then
        [ "$_verbose" = "1" ] && echo "Discovering pagination from $hub" >&2
        first=$($download "$hub")
        count=$(printf %s\\n "$first" | sed -E 's/\{\s*"count":\s*([0-9]+).*/\1/')
        if [ "$count" = "0" ]; then
            [ "$_verbose" = "1" ] && echo "No tags, probably non-existing repo" >&2
            return 0
        else
            [ "$_verbose" = "1" ] && echo "$count existing tag(s) for $1" >&2
        fi
        pagination=$(   printf %s\\n "$first" |
                        grep -Eo '"name":\s*"[a-zA-Z0-9_.-]+"' |
                        wc -l)
        _pages=$(( count / pagination + 1))
        [ "$_verbose" = "1" ] && echo "$_pages pages to download for $1" >&2
    fi

    # Get all tags one page after the other
    i=0
    while [ "$i" -lt "$_pages" ]; do
        i=$(( i + 1 ))
        [ "$_verbose" = "1" ] && echo "Downloading page $i / $_pages" >&2
        page=$($download "$hub?page=$i")
        printf %s\\n "$page" |
            grep -Eo '"name":\s*"[a-zA-Z0-9_.-]+"' |
            sed -E 's/"name":\s*"([a-zA-Z0-9_.-]+)"/\1/' |
            grep -E "$_filter" || true
    done
}

img_newtags() {
    _flt=".*"
    _verbose=0
    _reg=https://registry.hub.docker.com/
    _pages=
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

            -p | --pages)
                _pages=$2; shift 2;;
            --pages=*)
                _pages="${1#*=}"; shift 1;;

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

    # Disable globbing to make the options reconstruction below safe.
    _oldstate=$(set +o); set -f
    _opts="--filter $_flt --registry $_reg --pages=$_pages"
    [ "$_verbose" = "1" ] && _opts="$_opts --verbose"
    _existing=$(mktemp)

    [ "$_verbose" = "1" ] && echo "Collecting relevant tags for $2" >&2
    # shellcheck disable=SC2086
    img_tags $_opts -- "$2" > "$_existing"
    [ "$_verbose" = "1" ] && echo "Diffing aginst relevant tags for $1" >&2
    # shellcheck disable=SC2086
    img_tags $_opts -- "$1" | grep -F -x -v -f "$_existing"

    rm -f "$_existing"
    # Restore globbing state
    set +vx; eval "$_oldstate"
}

img_unqualify() {
    printf %s\\n "$1" | sed -E 's/^([[:alnum:]]+\.)?docker\.(com|io)\///'
}


# From: https://stackoverflow.com/a/37939589
img_version() {
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}
