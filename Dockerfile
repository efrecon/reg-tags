FROM alpine:3

LABEL MAINTAINER=efrecon+github@gmail.com
LABEL org.opencontainers.image.title="efrecon/reg-tags"
LABEL org.opencontainers.image.description="Docker registry tags operations"
LABEL org.opencontainers.image.authors="Emmanuel Frécon <efrecon+github@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/efrecon/reg-tags"
LABEL org.opencontainers.image.documentation="https://github.com/efrecon/reg-tags/README.md"
LABEL org.opencontainers.image.source="https://github.com/efrecon/reg-tags/Dockerfile"

# hadolint disable=DL3018  # No version pinpointing, but ok for the purpose
RUN apk add --no-cache curl
COPY *.sh /usr/local/lib/
COPY bin/*.sh /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/image_tags.sh" ]