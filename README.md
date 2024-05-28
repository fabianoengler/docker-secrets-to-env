# docker-secrets-to-env
Set Environment Variables from docker secrets files (usually from /run/secrets/)


------------------------------


This script reads docker secrets files from `/run/secrets` and export
them as environment variables. The env variables names are based on the
filename of the secret but converted to uppercase and replacing
hypens (`-`) with underscores (`_`), e.g. a secret named `my-secret-key`
becomes env variable `MY_SECRET_KEY`.

For example, suppose you generate a new random password with openssl for your
database and store it as a docker secret with:
```
openssl rand -hex 16 | docker secret create my-db-password
```

Since you named the secret as `my-db-password`, it will be exposed by docker
to the running container as the file `/run/secrets/my-db-password`.
After running this script, you should have a new environment variable
named `MY_DB_PASSWORD` and the value for the variable will the content
of the file `/run/secrets/my-db-password`.


You can have multiple versions (also called revisions or rotations) of a
secret by appending the suffix `--v{n}` or `--r{n}` to the secret name,
where `{n}` can be any non-negative integer. In case there are multiple
versions/revisions of the same secret, the highest number is used.
The version/revision suffix is removed from the env variable name.

The double hyphen for versions is used to prevent conflict with already
exiting variables names ending in `-V{N}`. For example, suppose you have
a legacy API and you start calling your new API as v2 but you still
need to access the old API, you could have env variables names
like `API_V1` and `API_V2`.

For example, the following secret names would be mapped as the
following env variables names:

```
Secret filename              Env variable name
========================================================
/run/secret/db-password      DB_PASSWORD
/run/secret/api-url          API_URL
/run/secret/cache-key        (ignored in favor of cache-key--v3)
/run/secret/cache-key--v2    (ignored in favor of cache-key--v3)
/run/secret/cache-key--v3    CACHE_KEY
/run/secret/api-v1           API_V1
/run/secret/api-v2           (ignored in favor of api-v2--v2)
/run/secret/api-v2--v2       API_V2
```


## How to use this script

Download the main script file to your project:
```
curl -O https://raw.githubusercontent.com/fabianoengler/docker-secrets-to-env/master/docker-secrets-to-env.sh
```

Add a line to source the script from your entrypoint script:
```
source docker-secrets-to-env.sh
```

That's it, when you run your container, all secrets on from `/run/secrets`
will be exposed as environment variables automatically after the entrypoint
script sources the script `docker-secrets-to-env.sh`.

If you want to see what the script is doing, set the
variable `DEBUG_SECRETS` before the source line:
```
DEBUG_SECRETS=1
source docker-secrets-to-env.sh
```

If you want to change the directory where the script looks for the
secrets files, you can set the variable `SECRETS_DIR` before sourcing
the script.


## Limitations

This script is not POSIX and currently only works with bash.
This can be a problem for alpine based docker images, as alpine uses
busybox with ash by default instead of bash.

In that case, you can still add bash to your docker image
and set the entrypoint script to run with bash, something like:

```Dockerfile
FROM alpine:latest
RUN apk update && apk add bash
...
ENTRYPOINT /bin/bash entrypoint.sh
```

