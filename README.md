# MeetingBrief

App **menu-bar macOS** qui transforme un transcript de réunion en note **Obsidian** structurée + message **Slack**, en un clic.

## Flow

1. Clic sur l'icône dans la barre des menus
2. Coller le transcript
3. Claude extrait : **sujets**, **décisions**, **actions**
4. Valider / éditer
5. La note est écrite dans le vault Obsidian + un message part sur Slack

## Stack

- SwiftUI + `MenuBarExtra` (macOS 13+)
- Swift Package Manager (pas d'Xcode project nécessaire)
- Claude API (`claude-sonnet-4-6`)
- Slack Web API (bot token)
- Keychain macOS pour les secrets (clé Claude, token Slack)
- UserDefaults pour les préférences non-sensibles (chemin Obsidian, channel Slack)

## Prérequis

- macOS 13 (Ventura) ou supérieur
- Xcode command-line tools : `xcode-select --install`
- Une clé API Claude (`sk-ant-…`) — [console.anthropic.com](https://console.anthropic.com)
- Un Slack Bot Token (`xoxb-…`) — voir ci-dessous

## Lancer l'app

```bash
cd MeetingBrief
swift run
```

L'icône (🔍 document) apparaît dans la barre des menus. Clic → popover.
Pour quitter l'app, clic sur la croix dans le header du popover.

## Créer l'app Slack (5 min, une fois)

1. [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → *From scratch*
2. Nom : `MeetingBrief`, workspace de ton choix
3. **OAuth & Permissions** → *Bot Token Scopes* → ajouter :
   - `chat:write` — poster des messages
   - `channels:read` — lister les channels publics
   - `groups:read` — lister les channels privés
4. **Install to Workspace** → autoriser → copier le *Bot User OAuth Token* (`xoxb-…`)
5. Inviter le bot dans le(s) channel(s) cible(s) : `/invite @MeetingBrief` dans Slack

Colle le token dans l'app (Réglages) puis clique *"Charger les channels"*.

## Configuration

Dans l'app, clique sur ⚙︎ :

| Champ            | Stockage     | Exemple                       |
| ---------------- | ------------ | ----------------------------- |
| Clé API Claude   | Keychain     | `sk-ant-…`                    |
| Slack Bot Token  | Keychain     | `xoxb-…`                      |
| Channel Slack    | UserDefaults | `#ops-meetings`               |
| Dossier Obsidian | UserDefaults | `~/BriocheBrain/1-notes`      |

## Format de la note générée

```markdown
---
type: meeting
date: 2026-04-17
titre: Réunion kickoff X
---

# Réunion kickoff X

## Résumé
…

## Sujets
- Sujet 1
- Sujet 2

## Décisions
- **[Greg]** Partir sur la v2 — _implications : refonte API_

## Actions
- [ ] **[Alex]** Préparer le plan — échéance : 2026-04-24

## Transcript brut
<details>…</details>
```

Les cases `- [ ]` sont compatibles avec le plugin Obsidian *Tasks*.
Le nom de fichier est `YYYY-MM-DD-titre-slugifie.md`.

## Build

```bash
swift build               # debug
swift build -c release    # release (binaire dans .build/release/MeetingBrief)
swift run                 # compile + lance
```

## Limites MVP (volontairement simples)

- Pas de sandbox, pas de signature → le binaire tourne uniquement sur ta machine. Pour distribuer, il faudra signer/notariser.
- Le binaire `swift run` n'est pas un `.app` standalone ; il faut relancer depuis le terminal après un reboot. Pour un lancement auto, on bundlera en `.app` plus tard.
- Pas de persistance des transcripts : quand l'app est relancée, l'écran d'input est vide.
- Édition inline simple (ajout/suppression/modification d'items), pas de drag & drop.

## Licence

MIT.
