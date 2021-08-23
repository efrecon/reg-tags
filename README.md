# Image Tags

This library implements a few functions to operate on the existing tags at the
Docker [hub] for public images.

+ `img_tags` will print out the tags for the image which name is passed as an
  argument.
+ `img_newtags` will make the difference between tags: it will show the list of
  tags in the first image that are not present in the second image which names
  are passed as arguments.
+ `img_unqualify` will remove the registry URL from the beginning of an image
  name. It is handy when cleaning names from the `DOCKER_REPO` environment
  variable passed to [hooks].
+ `img_version` converts a pure semantic version to a number that can be
  compared with `-gt`, `-lt`, etc.
+ `img_labels` will print out all the labels for a given image at a given tag
  (default: latest).
+ `img_auth` will authorise at a registry, this can be handy when calling
  `img_labels` several times on the same image (but different tags).

  [hub]: https://hub.docker.com/
  [hooks]: https://docs.docker.com/docker-hub/builds/advanced/

## Synopsis for `img_tags` and `img_newtags`

The functions takes short options led by a single-dash, or long options led by a
double dash. Long options can be separated from their value by an equal sign or
a space separator. The end of options can be marked by a single (and optional)
`--`. Recognised options are:

+ `-f` or `--filter`, a regular expression to restrict tags to versions matching
  the expression.
+ `-r` or `--registry` the root of the Docker registry, defaults to
  `https://registry.hub.docker.com/`
+ `-v` or `--verbose` is a tag that turns on verbosity on stderr.

## Tests

There are no tests! But there are a number of "binaries", named after the name
of the functions to exercise their behaviour in the [bin] directory.

  [bin]: ./bin/

## Examples

### Tags

The following will return all tags for the official [alpine] image:

```shell
./bin/img_tags.sh alpine
```

The following would only return "real" releases for [alpine]:

```shell
./bin/img_tags.sh --filter '[0-9]+(\.[0-9]+)+' alpine
```

  [alpine]: https://hub.docker.com/_/alpine

### Labels

The following command would print out all the labels for the
`yanzinetworks/alpine` image:

```shell
./bin/img_labels.sh yanzinetworks/alpine
```

All labels are output in the `env` format, e.g.:

```shell
org.opencontainers.image.authors=Emmanuel Frecon <efrecon+github@gmail.com>
org.opencontainers.image.created=
org.opencontainers.image.description=glibc-capable Alpine
org.opencontainers.image.documentation=https://github.com/YanziNetworks/alpine/README.md
org.opencontainers.image.licenses=MIT
org.opencontainers.image.source=https://github.com/YanziNetworks/alpine
org.opencontainers.image.title=alpine
org.opencontainers.image.url=https://github.com/YanziNetworks/alpine
org.opencontainers.image.vendor=Yanzi Networks AB
org.opencontainers.image.version=
```

## Docker Hub

### Detecting New Tags

The main use of these functions is when implementing Docker Hub [hooks] when you
have an image that derives from an official library image and should be rebuilt
every time the official image has a new version. The hub itself has a similar
feature, but it is disabled for library images. Using this library and some CI
logic, you should be able to write code similar to the following in your hooks
(this takes alpine as an example, passing the version as the build argument
`version`).

```shell
#!/usr/bin/env sh

im="alpine"

# shellcheck disable=SC1090
. "$(dirname "$0")/reg-tags/image_tags.sh"


for tag in $(img_newtags --filter '[0-9]+(\.[0-9]+)+$' --verbose -- "$im" "$(img_unqualify "$DOCKER_REPO")"); do
      echo "============== Building ${DOCKER_REPO}:$tag"
      docker build --build-arg version="$tag" -t "${DOCKER_REPO}:$tag" .
done
```

To implement CI logic to detect changes, [talonneur] can be used.

  [hooks]: https://docs.docker.com/docker-hub/builds/advanced/
  [talonneur]: https://github.com/YanziNetworks/talonneur

### Rebuild on Local Changes

The example above will rebuild when a new tag for an image appears. If you
wanted to re-generate all your derived images whenever your own modifications
change, you could make use of the `org.opencontainers.image.revision` OCI
annotation and set it to the git checksum that is passed to the Docker Hub hook
as the variable `SOURCE_COMMIT`. The following code builds upon the previous
snippet as an example of this technique:

```shell
#!/usr/bin/env sh

im="alpine"

# shellcheck disable=SC1090
. "$(dirname "$0")/reg-tags/image_tags.sh"

# Login at the Docker hub to be able to access info about the image.
token=$(img_auth "$DOCKER_REPO")

for tag in $(img_tags --filter '[0-9]+(\.[0-9]+)+$' --verbose -- "$im"); do
    # Get the revision out of the org.opencontainers.image.revision label, this
    # will be the label where we store information about this repo (it cannot be
    # the tag, since we tag as the base image).
    revision=$(img_labels --verbose --token "$token" -- "$DOCKER_REPO" "$tag" |
                grep "^org.opencontainers.image.revision" |
                sed -E 's/^org.opencontainers.image.revision=(.+)/\1/')
    # If the revision is different from the source commit (including empty,
    # which will happen when our version of the image does not already exist),
    # build the image, making sure we label with the git commit sha at the
    # org.opencontainers.image.revision OCI label, but using the same tag as the
    # library image.
    if [ "$revision" != "$SOURCE_COMMIT" ]; then
        echo "============== No ${DOCKER_REPO}:$tag at $SOURCE_COMMIT"
        docker build \
            --build-arg version="$tag" \
            --tag "${DOCKER_REPO}:$tag" \
            --label "org.opencontainers.image.revision=$SOURCE_COMMIT" \
            .
    fi
done
```
