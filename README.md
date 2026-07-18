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
- Fichier local chiffré par FileVault pour les secrets (`~/Library/Application Support/MeetingBrief/secrets.json`, permissions 600)
- UserDefaults pour les préférences non-sensibles (chemin Obsidian, channel Slack)

## Prérequis

- macOS 13 (Ventura) ou supérieur
- Xcode command-line tools : `xcode-select --install`
- Une clé API Claude (`sk-ant-…`) — [console.anthropic.com](https://console.anthropic.com)
- Un Slack Bot Token (`xoxb-…`) — voir ci-dessous

## Installation (daily driver)

```bash
cd MeetingBrief
./scripts/install.sh
```

Ça :
1. Compile le binaire en release
2. Empaquette en `MeetingBrief.app` (bundle macOS signé ad-hoc)
3. Copie dans `/Applications`
4. Active le lancement auto à la session (via LaunchAgent)
5. Lance l'app immédiatement

L'icône 🔍 apparaît dans la barre des menus. Au prochain reboot, l'app démarrera toute seule.

**Désinstaller :**
```bash
launchctl unload ~/Library/LaunchAgents/io.poppins.meetingbrief.plist
rm -rf /Applications/MeetingBrief.app ~/Library/LaunchAgents/io.poppins.meetingbrief.plist
```

## Lancer en mode dev

Pour itérer sur le code sans installer :

```bash
swift run
```

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
| Clé API Claude   | secrets.json | `sk-ant-…`                    |
| Slack Bot Token  | secrets.json | `xoxb-…`                      |
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

## Limites MVP

- Signature ad-hoc uniquement (pas de notarization Apple). Gatekeeper peut afficher un avertissement au premier lancement — clic-droit sur l'app → *Ouvrir* pour bypass une fois.
- Pas de persistance du transcript : si l'app crash pendant l'analyse, le paste est perdu. Workaround : garde le transcript dans ton presse-papiers jusqu'à l'envoi.
- Édition inline simple (ajout/suppression/modification d'items), pas de drag & drop.

## Licence

MIT.
