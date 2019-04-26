# git-sync-mirror
A simple synchronization container image for git repositories

## Usage

```
$ docker run \
  --rm \
  -env SRC_REPO=<source> \
  -env DST_REPO=<dst> \
  -env SLEEP_TIME__S=30 \
  enteee/git-sync-mirror
```

This currently only supports synchronization over `https` with authentication using access tokens.
For example replace `<src>` with `https://<github-user>:<github-access-token>@github.com/Enteee/git-sync-mirror.git`
