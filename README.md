# Watcher's Eye

_One by one, they stood their ground against a creature they had no hope of understanding, let alone defeating, and one by one, they became a part of it._

Watcher's Eye is a social network post surveillance tool.

## How to use

Create `settings.yml` and write the following settings.

```yaml
targets:
- kind: mastodon
  label: gene_mastodon
  domain: ap.jadiunr.net
  acct: jadiunr@ap.jadiunr.net
  credentials:
    token: xxxxxxxxxxxxxxxxxxxxxxxx
- kind: twitter
  label: gene_twitter
  account_id: '909813619868680194'
  credentials:
    consumer_key: xxxx
    consumer_secret: xxxx
    access_token: xxxx
    access_token_secret: xxxx
- kind: misskey
  label: gene_misskey
  domain: misskey.io
  acct: jadiunr@misskey.io
  private_only: true
  credentials:
    token: xxxxxxxxxxxxxxx

publishers:
- kind: discord
  label: discord1
  targets:
  - gene_mastodon
  - gene_misskey
  webhook_url: https://discord.com/api/webhooks/xxxxxxxxxxx
- kind: discord
  label: discord2
  targets:
  - gene_twitter
  webhook_url: https://discord.com/api/webhooks/xxxxxxxxxxx
```

Then, run the Docker Container

```
docker-compose build
docker-compose run --rm app carton install --deployment
docker-compose up -d
```

## Configuration details

### targets

Define the target to be surveilled.

#### kind

Specifies the type of service to which the surveilling target belongs.
Currently, Watcher's Eye supports the following three services.

- mastodon
- misskey
- twitter

#### label

Assign a label to the surveilled object.
This label will be used by Publisher.

#### acct (Other than Twitter)

Specifies the acct to be surveilled.

#### account_id (Twitter only)

Specifies the account ID to be surveilled.
Note that it is not the Screen Name.

#### credentials

Describe the Credentials for accessing the API.
Use the correct key for each service.

- Mastodon, Misskey

```
  credentials:
    token: xxxxxxxxxxxxxxxxxxxxxxxx
```

- Twitter

```
  credentials:
    consumer_key: xxxx
    consumer_secret: xxxx
    access_token: xxxx
    access_token_secret: xxxx
```

#### private_only

When enabled, only posts with Visibility equivalent to Private will be retrieved.
This is not available for Twitter.

### publishers

Defines the forwarding destination for retrieved posts.

#### kind

Specify the type of service to be forwarded.
Currently, only Discord is supported, but soon Slack will be available as well.

#### label

Unlike the label of targets, there is no specific use for it.

#### targets

Specifies the surveilling targets defined in the targets section in list format.

#### webhook_url

Specify the URL of Incoming Webhook that matches the kind.
