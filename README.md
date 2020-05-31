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
  https://registry.hub.docker.com/
+ `-v` or `--verbose` is a tag that turns on verbosity on stderr.

## Tests

There are no tests! But there are a number of "binaries", named after the name
of the functions to exercise their behaviour in the [bin] directory.

  [bin]: ./bin/

## Example

The following will return all tags for the official [alpine] image:

```shell
./bin/img_tags.sh alpine
```

The following would only return "real" releases for [alpine]:

```shell
./bin/img_tags.sh --filter '[0-9]+(\.[0-9]+)+' alpine
```

  [alpine]: https://hub.docker.com/_/alpine

## Docker Hub

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