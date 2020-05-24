# Docker Tags

This "script" implements a single function to list the existing tags at the
Docker [hub] for a given public image.

  [hub]: https://hub.docker.com/

When called as a script, all arguments will be forwarded to the function so that
you will be able to try it.

## Synopsis

The function takes short options led by a single-dash, or long options led by a
double dash. Long options can be separated from their value by an equal sign or
a space separator. Recognised options are:

+ `-f` or `--filter`, a regular expression to restrict tags to versions matching
  the expression.

## Example

The following will return all tags for the official [alpine] image:

```shell
./docker_tags.sh alpine
```

The following would only return "real" releases for [alpine]:

```shell
./docker_tags.sh --filter '[0-9]+(\.[0-9]+)+' alpine
```

  [alpine]: https://hub.docker.com/_/alpine