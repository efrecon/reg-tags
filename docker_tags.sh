#!/usr/bin/env sh

docker_tags() {
    filter=.*
    while [ $# -gt 0 ]; do
        case "$1" in
            -f | --filter)
                filter=$2; shift 2;;
            --filter=*)
                filter="${1#*=}"; shift 1;;

            --)
                shift; break;;
            -*)
                echo "$1 unknown option!" >&2; return 1;;
            *)
                break;
        esac
    done


    if printf %s\\n "$1" | grep -oq '/'; then
        hub="https://registry.hub.docker.com/v2/repositories/$1/tags/"
    else
        hub="https://registry.hub.docker.com/v2/repositories/library/$1/tags/"
    fi

    # Get number of pages
    download=
    if command -v curl >/dev/null; then
        # shellcheck disable=SC2037
        download="curl -sSL"
    elif command -v wget >/dev/null; then
        # shellcheck disable=SC2037
        download="wget -q -O -"
    else
        return 1
    fi

    first=$($download "$hub")
    count=$(printf %s\\n "$first" | sed -E 's/\{\s*"count":\s*([0-9]+).*/\1/')
    [ "$count" = "0" ] && return 0
    pagination=$(   printf %s\\n "$first" |
                    grep -Eo '"name":\s*"[a-zA-Z0-9_.-]+"' |
                    wc -l)
    pages=$(( count / pagination + 1))

    # Get all tags one page after the other
    i=0
    while [ "$i" -le "$pages" ]; do
        i=$(( i + 1 ))
        page=$($download "$hub?page=$i")
        printf %s\\n "$page" |
            grep -Eo '"name":\s*"[a-zA-Z0-9_.-]+"' |
            sed -E 's/"name":\s*"([a-zA-Z0-9_.-]+)"/\1/' |
            grep -E "$filter"
    done
}

# Run directly? call function!
if [ "$(basename "$0")" = "docker_tags.sh" ] && [ "$#" -gt "0" ]; then
    docker_tags "$@"
fi