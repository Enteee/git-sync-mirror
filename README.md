# git-sync-mirror
_A simple synchronization container image for git repositories over HTTPS_

*Features*:
* Authentication with https tokens
* If needed, use a different HTTPS Proxy for source and destination
* TLS-Trust On First Use: Seamlessly run this container behind a https scanning proxy
* Skip certificate checks (don't do that)
* Configure time to sleep between synchronization attempts

## Usage

```
$ docker run \
  --rm \
  --env SRC_REPO=source \
  --env DST_REPO=destination \
  --env SLEEP_TIME=30s \
  enteee/git-sync-mirror
```

*Note*: The container is designed for synchronization over `https` with supported authentication using access tokens.
For example replace `source` with `https://github-user:github-access-token@github.com/Enteee/git-sync-mirror.git`

## Environment Variables

| Variable | Description | Mandatory | Example |
| -------- | ----------- | :-------: | ------- |
| `SRC_REPO` | Source repository | Yes | `https://github.com/Enteee/git-sync-mirror.git` |
| `DST_REPO` | Destination repository | Yes | `https://github.com/Enteee/git-sync-mirror.git` |
| `HTTP_TLS_VERIFY` | Enable/Disable certificate cheks | No, default: `true` | `true` or `false` |
| `HTTP_SRC_PROXY` | HTTP Proxy to use when connecting to `SRC_REPO` | No, default: `` | `http://localhost:8080` |
| `HTTP_DST_PROXY` | HTTP Proxy to use when connecting to `DST_REPO` | No, default: `` | `http://localhost:8080` |
| `SLEEP_TIME` | Time to sleep between synchronizations | No, default: `60s` | `30m` |

For TLS-Trust On First Use configuration see: [Enteee/tls-tofu](https://github.com/Enteee/tls-tofu).
