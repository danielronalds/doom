# Agent shell

Private Doom module for [agent-shell](https://github.com/xenodium/agent-shell),
with Pi and Claude ACP backends.

## Enable

In `~/.config/doom/init.el`, inside `doom!`:

```elisp
:private
(agent-shell +pi +claude)
```

- `+pi`: enable Pi and its keybinding.
- `+claude`: enable Claude and its keybinding.

Enable either or both flags. The agent chooser lists only enabled backends.
The module installs `agent-shell`, `acp`, and `shell-maker`; `agent-shell` uses
its upstream Git repository for Pi support.

## Install backends

Install the adapters separately (the module does not run npm):

```bash
npm install -g pi-acp @agentclientprotocol/claude-agent-acp
```

Pi also requires the `pi` CLI (Node.js 22+ and Pi v0.81.0+ per the adapter's
current requirements). If needed:

```bash
npm install -g @earendil-works/pi-coding-agent
```

Run `pi` in a terminal and configure your providers/authentication before using
it in Emacs. The adapter launches `pi --mode rpc` and uses Pi's configuration.
See [pi-acp](https://github.com/svkozak/pi-acp) for compatibility and limitations.

For a Claude subscription, install [Claude Code](https://code.claude.com/docs/en/overview)
and run `claude` in a terminal once to sign in. The adapter can also use API-key
authentication; see the agent-shell documentation. Do not put API keys in this
repository.

Then run:

```bash
doom sync
doom env   # If Emacs does not inherit the terminal's executable PATH.
```

Restart Emacs. `doom doctor` checks for the enabled backends' executables.
Checks assume the default executable names; custom adapter commands may require
adjusting the checks.

## Usage

Open a file in your project, then:

| Key | Command |
| --- | --- |
| `SPC a a` | `agent-shell` (choose/reuse an agent) |
| `SPC a s` | `agent-shell-send-region` (insert selection into last-used project shell) |
| `SPC a t` | `agent-shell-toggle` (show/hide the pane without ending the session) |
| `SPC a p` | `agent-shell-pi-start-agent` (`+pi`) |
| `SPC a c` | `agent-shell-anthropic-start-claude-code` (`+claude`) |

The same commands are available via `M-x`. Agent shells open in a right-hand
side window, using approximately 40% of the frame width and keeping your editor
window visible. Tool details are collapsed by default. The current activity
group shows its members while running, then collapses when the turn ends.
Use `RET` on a heading to fold/unfold it.

The header shows cumulative session cost once the ACP backend reports a nonzero
amount. Backends that do not report cost cannot display this indicator.

Provider settings can be overridden in your main `config.el` using
`after! agent-shell`. The module uses default login/authentication settings and
does not automatically approve tool requests.
