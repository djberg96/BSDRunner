# Running AI Securely in a FreeBSD Jail

## A command-line guide using Blackship 0.5.0, Ollama, and Pi

Validated on FreeBSD 15.1-RELEASE/amd64 on November 16, 2026.

## Purpose

This guide distills a working experiment into a repeatable command-line
procedure for running a local AI coding agent inside a FreeBSD jail. It does
not depend on BSDRunner or any graphical interface.

The final system has these properties:

- Blackship owns the jail lifecycle, VNET network, ZFS storage, health check,
  resource limits, and read-only source mount.
- Ollama and the coding agent run in the same jail.
- Ollama listens only on `127.0.0.1` inside the jail. Nothing is published to
  the LAN or host wildcard addresses.
- The coding agent runs as an unprivileged `ai` user.
- A selected source repository is mounted read-only, `nosuid`, and `noexec`.
- The runtime jail receives temporary Internet access only while downloading a
  model. That access is removed and verified afterward.
- RCTL limits memory, CPU, and process consumption.
- GPU access is not delegated. This is a CPU-only profile.
- The jail does not start automatically at boot unless the operator later
  chooses to add Blackship's reserved `autostart` tag.

This is defense in depth, not a claim that a jail is a virtual machine. FreeBSD
jails share the host kernel. Do not run code you would not trust with the
specific kernel interfaces and files that you expose to it.

## What the experiment established

The successful path used Blackship 0.5.0, the FreeBSD Ollama package, Pi 1.5.2,
and `gemma4:latest`. A source repository was presented at `/workspace/project`
through a Blackship manifest volume. Pi could read and analyze the repository,
while the host copy remained read-only from the jail.

The important operational lesson was that the inference server and agent must
agree about context length. Ollama and Pi are both configured for 32,768 tokens
in this guide. A large context consumes more memory, so 32K is a deliberate
CPU-workstation compromise rather than a maximum.

Local model output is still untrusted. The isolation in this guide protects the
host and source tree; it does not make the model's technical conclusions
correct. Review every answer and proposed change.

## Architecture and trust boundaries

The host remains the security boundary and administrator:

```text
FreeBSD host
  |
  +-- Blackship project and ZFS datasets
  |
  +-- VNET: ai-private (10.77.42.0/24)
       |
       +-- ollama jail (10.77.42.10)
            |
            +-- Ollama API: 127.0.0.1:11434 only
            +-- Pi coding agent: unprivileged user "ai"
            +-- /workspace/project
                 read-only + nosuid + noexec nullfs mount
```

There is no Blackship port exposure. The host drives the jail through
`blackship console` and `blackship exec`. The agent talks to Ollama over jail
loopback. With the temporary PF egress anchor empty, the jail can reach its own
gateway but cannot reach the Internet.

## Prerequisites

This procedure assumes:

- FreeBSD 15.0 or newer on amd64.
- Root access for installation, ZFS, PF, and jail lifecycle operations.
- ZFS with a pool such as `zroot`.
- At least 8 GiB of host RAM and 20 GiB of free storage. A 32 GiB host is much
  more comfortable for a 32K context and the tested model.
- A source directory that the agent may read.
- An existing, understood PF policy or willingness to review a minimal one.

Commands prefixed with `#` run as root. Commands prefixed with `$` run as the
ordinary account that owns the source repository.

The examples use these values. Change them consistently for your host:

```text
ZFS pool:       zroot
Release:        15.1-RELEASE
Project:        blackship-ai
Manifest:       /usr/local/etc/blackship-ai/blackship.toml
Build context:  /usr/local/etc/blackship-ai/ollama
Private subnet: 10.77.42.0/24
Gateway:        10.77.42.1
Jail address:   10.77.42.10/24
Jail name:      ollama
Source:         /home/example/src/project
Jail mount:     /workspace/project
```

Before selecting the subnet, make sure it does not overlap an active route:

```sh
$ netstat -rn -f inet
$ ifconfig
```

Also record the source owner's numeric IDs. The jail account should use the
same values so ordinary file permissions remain meaningful through nullfs:

```sh
$ id -u
1001
$ id -g
1001
```

## 1. Enable RCTL accounting

Blackship fails closed when a manifest requests resource limits but the host
cannot enforce them. Resource accounting is a boot-time FreeBSD setting.

Check it first:

```sh
# sysctl -n kern.racct.enable
```

If the result is `0`, enable it in `/boot/loader.conf` and reboot:

```sh
# sysrc -f /boot/loader.conf kern.racct.enable=1
# shutdown -r now
```

After the reboot, require a result of `1` before continuing:

```sh
# sysctl -n kern.racct.enable
1
```

## 2. Install and verify Blackship 0.5.0

Skip this section when `blackship --version` already reports a compatible
version newer than or equal to 0.5.0. Do not downgrade a newer installation.

The following installs the official FreeBSD amd64 0.5.0 archive only after
checking its expected SHA-256 and archive layout:

```sh
# BLACKSHIP_URL="https://github.com/seuros/blackship/releases/download/blackship-v0.5.0/blackship-freebsd-amd64.tar.gz"
# BLACKSHIP_SHA256="02742fe641896fb1d6586eef352a6049bc8c56fee85fc5d190022e625d60ff0c"
# BLACKSHIP_TMP="$(mktemp -d /tmp/blackship-install.XXXXXX)"
# fetch -o "$BLACKSHIP_TMP/blackship.tar.gz" "$BLACKSHIP_URL"
# test "$(sha256 -q "$BLACKSHIP_TMP/blackship.tar.gz")" = "$BLACKSHIP_SHA256"
# test "$(tar -tzf "$BLACKSHIP_TMP/blackship.tar.gz")" = "blackship"
# tar -xzf "$BLACKSHIP_TMP/blackship.tar.gz" -C "$BLACKSHIP_TMP" blackship
# "$BLACKSHIP_TMP/blackship" --format json capabilities
# install -m 0755 "$BLACKSHIP_TMP/blackship" /usr/local/bin/blackship
# rm -rf "$BLACKSHIP_TMP"
```

Verify the installed binary and its machine-readable capability contract:

```sh
$ blackship --version
blackship 0.5.0
$ blackship capabilities --format json | jq '.data.output_schema_version'
1
```

The second command requires `jq`; the capability command itself does not.

## 3. Create the root-owned build context

Create system directories for the canonical manifest and build context:

```sh
# install -d -o root -g wheel -m 0755 /usr/local/etc/blackship-ai/ollama
# install -d -o root -g wheel -m 0755 /var/db/blackship-ai
```

Create `/usr/local/etc/blackship-ai/ollama/Jailfile` with the following
content. Replace the `AI_UID` and `AI_GID` defaults if the source owner does not
use 1001:1001.

```dockerfile
FROM 15.1-RELEASE
LABEL name=blackship-ai version=1 purpose=local-private-ai experimental=true

ARG AI_UID=1001
ARG AI_GID=1001

RUN pkg install -y ollama npm-node22
RUN npm install -g @earendil-works/pi-coding-agent@1.5.2
RUN pw groupadd ai -g ${AI_GID}
RUN pw useradd ai -u ${AI_UID} -g ai -m -s /bin/sh
RUN install -d -o nobody -g nobody /var/lib/ollama
RUN install -d -o ai -g ai /home/ai/.pi/agent

COPY pi-models.json /home/ai/.pi/agent/models.json
COPY pi-settings.json /home/ai/.pi/agent/settings.json
RUN chown -R ai:ai /home/ai/.pi
RUN chmod 0600 /home/ai/.pi/agent/models.json /home/ai/.pi/agent/settings.json

RUN sysrc ollama_enable=YES
RUN sysrc ollama_use_vulkan=0
RUN sysrc ollama_context_length=32768
RUN sysrc 'ollama_env=HOME=/var/lib/ollama OLLAMA_HOST=127.0.0.1:11434 OLLAMA_NO_CLOUD=1'
```

This intentionally omits `EXPOSE 11434/tcp`. Ollama is useful only to the
agent inside this jail, so it binds to jail loopback and is never published.
Cloud features and Vulkan are explicitly disabled.

Create `/usr/local/etc/blackship-ai/ollama/pi-models.json`:

```json
{
  "providers": {
    "ollama": {
      "api": "openai-completions",
      "apiKey": "ollama",
      "baseUrl": "http://127.0.0.1:11434/v1",
      "models": [
        {
          "_launch": true,
          "contextWindow": 32768,
          "id": "gemma4:latest",
          "input": ["text", "image"],
          "reasoning": true
        }
      ]
    }
  }
}
```

Create `/usr/local/etc/blackship-ai/ollama/pi-settings.json`:

```json
{
  "defaultModel": "gemma4:latest",
  "defaultProvider": "ollama"
}
```

Protect the complete build context:

```sh
# chown -R root:wheel /usr/local/etc/blackship-ai
# find /usr/local/etc/blackship-ai -type d -exec chmod 0755 {} +
# find /usr/local/etc/blackship-ai -type f -exec chmod 0644 {} +
```

Validate the Jailfile before it can affect a jail root:

```sh
$ blackship template validate /usr/local/etc/blackship-ai/ollama/Jailfile
[OK] Jailfile is valid
```

## 4. Write the Blackship manifest

Create `/usr/local/etc/blackship-ai/blackship.toml`:

```toml
[config]
project = "blackship-ai"
data_dir = "/var/db/blackship-ai"
releases_dir = "/var/db/blackship-ai/releases"
cache_dir = "/var/db/blackship-ai/cache"
zfs_enabled = true
zpool = "zroot"
dataset = "blackship-ai"

[[networks]]
name = "ai-private"
subnet = "10.77.42.0/24"
gateway = "10.77.42.1"

[[jails]]
name = "ollama"
release = "15.1-RELEASE"
build = "/usr/local/etc/blackship-ai/ollama"
hostname = "ollama.local"
tags = ["local-ai", "experimental"]

[jails.mount]
volumes = ["/home/example/src/project:/workspace/project:ro"]

[jails.resources]
memory = "24g"
cpu = "400"
maxproc = 512

[jails.network]
vnet = true
networks = ["ai-private"]
bridge = "blackship-ai0"
ip_cidr = "10.77.42.10/24"

[jails.network.dns]
nameservers = ["1.1.1.1"]
mode = "custom"

[jails.healthcheck]
enabled = true

[[jails.healthcheck.checks]]
name = "ollama-api"
command = "fetch -qo /dev/null http://127.0.0.1:11434/api/tags"
target = "jail"
start_period = 120
```

Change the source path to one specific repository. Never mount `/home`, `/`, or
another broad directory. The `ro` mode is mandatory for this profile.

The example's 24 GiB limit is intended for a 32 GiB host. Keep the ceiling at
or below roughly 75 percent of physical RAM so the host retains enough memory
for ZFS ARC and the desktop. For a 16 GiB host, start with `memory = "12g"` and
expect more constrained model choices. `cpu = "400"` caps the jail at the
equivalent of four fully occupied CPU cores; it is a ceiling, not a reservation.

Make the manifest root-owned and validate it:

```sh
# chown root:wheel /usr/local/etc/blackship-ai/blackship.toml
# chmod 0644 /usr/local/etc/blackship-ai/blackship.toml
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml check
```

## 5. Bootstrap the release and private network

Download and verify the FreeBSD base release through Blackship:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml bootstrap 15.1-RELEASE
# blackship -c /usr/local/etc/blackship-ai/blackship.toml releases verify 15.1-RELEASE
```

Create the named network. The address range must match the manifest:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml network create ai-private \
    --subnet 10.77.42.0/24 \
    --gateway 10.77.42.1 \
    --bridge blackship-ai0
```

Ask Blackship to establish its PF anchors. `--enable-pf` creates a minimal PF
configuration only when PF is not already configured; review an existing
ruleset rather than replacing it.

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml setup --enable-pf
# blackship -c /usr/local/etc/blackship-ai/blackship.toml network list
```

Blackship deliberately does not install outbound NAT. At this point the jail
network has a host gateway but no Internet path.

## 6. Preview, build, and start

Always inspect the dry-run before the mutating operation:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml \
    armada -f /usr/local/etc/blackship-ai/blackship.toml \
    up ollama --dry-run
```

Build and start the jail:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml \
    armada -f /usr/local/etc/blackship-ai/blackship.toml \
    up ollama --build
```

Jailfile `RUN` instructions execute in a chroot that uses the host's network,
which is how `pkg` and `npm` fetch the pinned tools during this build. The
source repository volume is not attached to that build root; it attaches only
when the completed runtime jail starts. Audit the Jailfile and its package
sources before building.

Inspect the normalized inventory, health, and resource use:

```sh
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml ps --host
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml health ollama
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml stats ollama
```

The runtime jail name shown by `jls` is `blackship-ai-ollama`. Blackship
commands accept the service name `ollama`.

## 7. Verify isolation before downloading a model

Confirm that Ollama listens only on jail loopback:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- \
    sockstat -4 -l
```

The Ollama listener must be `127.0.0.1:11434`, not `*:11434` or
`0.0.0.0:11434`.

Confirm that Blackship has no published port:

```sh
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml ports ollama
```

Confirm the source mount and its restrictions:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- mount
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec \
    -u ai -w /workspace/project ollama -- \
    sh -c 'test ! -w . && echo "source is not writable"'
```

Blackship manifest volumes are attached read-only, `nosuid`, and `noexec`.
They detach when the jail stops. This is suitable for review and explanation,
not for letting an agent edit or execute the host checkout.

Finally, confirm that outbound access currently fails:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- \
    fetch -T 5 -qo /dev/null https://registry.ollama.ai
```

Continue only when that command fails.

## 8. Open a temporary provisioning window

The model must be downloaded once. The safest practical command-line workflow
is a named PF anchor that is normally empty and is loaded only for provisioning.

Integrate these three lines into `/etc/pf.conf`. Do not overwrite an existing
ruleset, and place the filter anchor before a later `quick` rule that would
prevent it from being evaluated:

```pf
nat-anchor "blackship-ai-egress"
anchor "blackship-ai-egress"
load anchor "blackship-ai-egress" from "/etc/pf.anchors/blackship-ai-egress"
```

Back up and validate the complete host ruleset before loading it:

```sh
# cp -p /etc/pf.conf /etc/pf.conf.before-blackship-ai
# install -d -o root -g wheel -m 0755 /etc/pf.anchors
# install -o root -g wheel -m 0600 /dev/null /etc/pf.anchors/blackship-ai-egress
# pfctl -nf /etc/pf.conf
# pfctl -f /etc/pf.conf
```

Find the host's default external interface:

```sh
# route -n get default | awk '/interface:/{print $2}'
em0
```

Write `/etc/pf.anchors/blackship-ai-egress`, replacing `em0` as necessary:

```pf
ext_if = "em0"
ai_net = "10.77.42.0/24"

nat on $ext_if inet from $ai_net to any -> ($ext_if)
pass out on $ext_if inet from $ai_net to any keep state
```

Validate the anchor and load only that anchor:

```sh
# pfctl -n -a blackship-ai-egress -f /etc/pf.anchors/blackship-ai-egress
# pfctl -a blackship-ai-egress -f /etc/pf.anchors/blackship-ai-egress
```

If the host uses a stricter PF policy, integrate the equivalent DNS and HTTPS
rules into that policy rather than weakening it globally. The important
properties are that the rule applies only to `10.77.42.0/24` and that it can be
removed independently.

Verify that the jail can now resolve and reach the model registry:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- \
    fetch -T 10 -qo /dev/null https://registry.ollama.ai
```

## 9. Pull the model, then close egress

Download the tested model through the local Ollama service:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- \
    ollama pull gemma4:latest
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- \
    ollama list
```

Immediately clear the temporary anchor, remove its on-disk rules, and kill
states originating from the jail address:

```sh
# pfctl -a blackship-ai-egress -F all
# pfctl -k 10.77.42.10
# install -o root -g wheel -m 0600 /dev/null /etc/pf.anchors/blackship-ai-egress
```

Verify the closed state rather than assuming the PF change worked:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- \
    fetch -T 5 -qo /dev/null https://registry.ollama.ai
```

That command must fail. Also confirm that the downloaded model remains present:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml exec ollama -- \
    ollama list
```

The empty anchor file makes the offline state survive a PF reload or reboot.
Repeat the narrowly scoped provisioning window only when deliberately pulling
or updating a model.

## 10. Run the coding agent

Open a console as the unprivileged account:

```sh
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml \
    console -u ai ollama
```

Inside the jail:

```sh
$ cd /workspace/project
$ pi
```

Pi should report `gemma4:latest`, provider `ollama`, the project directory, and
a context window of approximately 33K. A narrowly scoped first prompt is:

```text
Read lib/example.rb. Analyze only the method named example_method.
Identify possible bugs and explain your reasoning. Do not modify any files.
```

Focused prompts matter on CPU-only hardware. Ask the agent to read the relevant
method or file rather than an entire repository. Treat its answer as a draft
that requires human verification.

Exit Pi normally, then exit the jail shell. No host source file should have
changed.

## 11. Everyday Blackship operations

Start and stop manually:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml up ollama
# blackship -c /usr/local/etc/blackship-ai/blackship.toml down ollama
# blackship -c /usr/local/etc/blackship-ai/blackship.toml restart ollama
```

The read-only source volume attaches on start and detaches on stop.

Observe status without entering the jail:

```sh
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml ps --host
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml health ollama
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml stats ollama
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml audit ollama
```

Inspect enforced resource rules on the host:

```sh
# rctl 'jail:blackship-ai-ollama'
# rctl -hu 'jail:blackship-ai-ollama'
```

Create a ZFS-backed checkpoint before changing packages or agent configuration:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml \
    snapshot create ollama before-update
```

This guide intentionally leaves autostart off. For a workstation experiment,
manual start reduces background resource consumption and keeps the source mount
absent when the agent is not needed.

## 12. Changing the attached repository

Stop the jail before changing a manifest volume:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml down ollama
```

Edit only the single `volumes` entry, then validate and preview:

```toml
[jails.mount]
volumes = ["/home/example/src/another-project:/workspace/project:ro"]
```

```sh
$ blackship -c /usr/local/etc/blackship-ai/blackship.toml check
# blackship -c /usr/local/etc/blackship-ai/blackship.toml up ollama --dry-run
# blackship -c /usr/local/etc/blackship-ai/blackship.toml up ollama
```

Do not broaden the mount to an entire home directory for convenience. If an
agent genuinely needs to modify code, create a disposable clone inside the
jail instead of changing the host mount to read-write. Review the diff, copy
only the intended patch out, and destroy the disposable data afterward.

## 13. Clean removal

Stopping a jail leaves its filesystem and downloaded models intact:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml down ollama
```

Permanent removal is different. It destroys the jail root and, with
`--volumes`, its Blackship-owned storage. It does not delete the read-only host
source directory, but it does delete downloaded models and jail-local agent
state:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml rm ollama --volumes
```

After permanent removal, delete the `[[jails]]` block from the manifest. When
no jail uses the network, remove it separately:

```sh
# blackship -c /usr/local/etc/blackship-ai/blackship.toml \
    network destroy ai-private
```

Keep or remove the release cache according to whether other Blackship projects
use it.

## Security checklist

Before trusting the arrangement, verify every item:

- The manifest and Jailfile are root-owned and not writable by the agent.
- The source mount names one repository, not a home directory or filesystem.
- The source mount is read-only, `nosuid`, and `noexec`.
- Pi runs as the unprivileged `ai` account.
- Ollama listens only on `127.0.0.1:11434` inside the jail.
- `blackship ports ollama` reports no published ports.
- `ollama_use_vulkan=0`; no host GPU devices are exposed.
- RCTL is enabled and the memory, CPU, and process ceilings are present.
- The temporary PF egress anchor is empty after model provisioning.
- A live HTTPS request from the jail fails after egress is removed.
- The model is already present locally before the network is closed.
- Model output is reviewed as untrusted advice.

## Limitations

This design protects against accidental host modification and reduces the
consequences of a misbehaving local agent. It does not protect against a
FreeBSD kernel vulnerability reachable through jail-visible system calls. It
also cannot prevent disclosure of mounted source while Internet egress is
enabled. That is why the egress window is short and the source mount is kept
read-only.

CPU-only local inference is slow, and smaller models can make convincing
technical mistakes. Isolation and model quality are separate concerns. A
securely confined answer can still be wrong.

GPU acceleration through a custom devfs ruleset and Vulkan is technically
possible, but it expands the host kernel-driver attack surface and is outside
this conservative profile.

## Reference material

- Blackship repository and command reference:
  https://github.com/seuros/blackship
- FreeBSD Handbook, Jails and Containers:
  https://docs.freebsd.org/en/books/handbook/jails/
- FreeBSD Handbook, PF firewall:
  https://docs.freebsd.org/en/books/handbook/firewalls/
- FreeBSD Ollama port history and options:
  https://www.freshports.org/misc/ollama/
- Pi coding agent:
  https://github.com/earendil-works/pi
- Ollama context-length documentation:
  https://github.com/ollama/ollama/blob/main/docs/faq.mdx

## Reproducible example files

The editable source accompanying this PDF includes validated examples under
`docs/examples/blackship-ai/`:

- `Jailfile`
- `blackship.toml.example`
- `pi-models.json`
- `pi-settings.json`
- `pf-egress.conf.example`

Blackship 0.5.0 accepts the supplied Jailfile, and both JSON files pass `jq`
validation. Adapt the example identifiers, paths, release, subnet, ZFS pool,
resource ceiling, and external PF interface before using them.
