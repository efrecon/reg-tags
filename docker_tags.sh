#!/usr/bin/env sh

docker_tags() {
    _filter=".*"
    _verbose=0
    while [ $# -gt 0 ]; do
        case "$1" in
            -f | --filter)
                _filter=$2; shift 2;;
            --filter=*)
                _filter="${1#*=}"; shift 1;;

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
        hub="https://registry.hub.docker.com/v2/repositories/$1/tags/"
    else
        hub="https://registry.hub.docker.com/v2/repositories/library/$1/tags/"
    fi
    [ "$_verbose" = "1" ] && echo "Discovering pagination from $hub" >&2

    # Get number of pages
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
    pages=$(( count / pagination + 1))
    [ "$_verbose" = "1" ] && echo "$pages pages to download for $1" >&2

    # Get all tags one page after the other
    i=0
    while [ "$i" -lt "$pages" ]; do
        i=$(( i + 1 ))
        [ "$_verbose" = "1" ] && echo "Downloading page $i / $pages" >&2
        page=$($download "$hub?page=$i")
        printf %s\\n "$page" |
            grep -Eo '"name":\s*"[a-zA-Z0-9_.-]+"' |
            sed -E 's/"name":\s*"([a-zA-Z0-9_.-]+)"/\1/' |
            grep -E "$_filter"
    done
}

# Run directly? call function!
if [ "$(basename "$0")" = "docker_tags.sh" ] && [ "$#" -gt "0" ]; then
    docker_tags "$@"
fi