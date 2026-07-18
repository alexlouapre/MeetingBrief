# MeetingBrief

App **menu-bar macOS** qui transforme un transcript de réunion en note **Obsidian** structurée + message **Slack**, en un clic.

## Installation en une commande

```bash
curl -fsSL https://raw.githubusercontent.com/alexlouapre/MeetingBrief/main/scripts/remote-install.sh | bash
```

Ça vérifie les prérequis, clone le repo, compile en release, installe `MeetingBrief.app` dans `/Applications` et active le lancement auto à la session. Au premier lancement, un **onboarding guidé** te fait configurer la clé Claude, le dossier Obsidian et (optionnellement) Slack.

> **Signature :** le build est compilé localement depuis les sources et signé ad-hoc. Comme le binaire n'est jamais téléchargé tel quel, il ne porte pas d'attribut quarantine — Gatekeeper ne bloque pas ce chemin d'installation.

## Flow

1. Copie le transcript de ton meeting (Granola, Zoom, Teams…)
2. Clique l'icône MeetingBrief dans la barre des menus et colle (clic ou ⌘V)
3. L'analyse démarre automatiquement — Claude extrait **résumé**, **sections**, **décisions**, **actions**
4. La note part **directement** dans ton vault Obsidian (aucune étape de validation)
5. L'app te propose ensuite la destination Slack (la dernière utilisée est pré-sélectionnée) — **rien ne part sur Slack sans ton clic**. Si le popover est fermé, une petite fenêtre flottante + une notification servent de rappel.

Préfères-tu relire avant d'écrire la note ? Active **Réglages → Flux → « Étape de validation avant envoi »** pour restaurer l'écran de relecture. Tu peux aussi désactiver complètement la publication Slack, ou relancer l'onboarding.

## Stack

- SwiftUI + `MenuBarExtra`, design **Liquid Glass** (macOS 26+)
- Swift Package Manager (pas d'Xcode project nécessaire)
- Claude API (`claude-sonnet-5`)
- Slack Web API (bot token)
- Fichier local chiffré par FileVault pour les secrets (`~/Library/Application Support/MeetingBrief/secrets.json`, permissions 600)
- UserDefaults pour les préférences non-sensibles (chemin Obsidian, destinations Slack, toggles de flux)

## Prérequis

- macOS 26 (Tahoe) ou supérieur
- Xcode command-line tools : `xcode-select --install` (Swift 6.2+)
- Une clé API Claude (`sk-ant-…`) — [console.anthropic.com](https://console.anthropic.com)
- Un Slack Bot Token (`xoxb-…`) — optionnel, voir ci-dessous

## Installation depuis un clone local

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
   - `users:read` — lister les utilisateurs (envoi en DM)
   - `im:write` — ouvrir une conversation DM
4. **Install to Workspace** → autoriser → copier le *Bot User OAuth Token* (`xoxb-…`)
5. Inviter le bot dans le(s) channel(s) cible(s) : `/invite @MeetingBrief` dans Slack

Colle le token dans l'onboarding (ou Réglages) puis clique *"Charger les destinations"*.

## Configuration

Tout se configure dans l'onboarding au premier lancement, puis via ⚙︎ :

| Champ              | Stockage     | Exemple                       |
| ------------------ | ------------ | ----------------------------- |
| Clé API Claude     | secrets.json | `sk-ant-…`                    |
| Slack Bot Token    | secrets.json | `xoxb-…`                      |
| Destinations Slack | UserDefaults | `#ops-meetings`, `@alex`      |
| Dossier Obsidian   | UserDefaults | `~/BriocheBrain/1-notes`      |
| Étape de validation| UserDefaults | off (flux direct) par défaut  |
| Publication Slack  | UserDefaults | on par défaut                 |

## Format de la note générée

```markdown
---
type: meeting
date: 2026-04-17
titre: Réunion kickoff X
participants:
  - Alex
  - Greg
tags:
  - projet-x
---

# Réunion kickoff X

> [!summary] Résumé
> …

### Sujet 1
- Point discuté
- Autre point

**Décisions**
- Partir sur la v2

**Pistes / idées**
- …

**Questions ouvertes**
- …

### Actions

**Alex**
[ ] Préparer le plan

**Greg**
[ ] Refonte API
```

Les actions sont groupées par responsable. Le nom de fichier est `YYYY-MM-DD-titre-slugifie.md` (suffixe `-2`, `-3`… si une note du même nom existe déjà — jamais d'écrasement).

## Build

```bash
swift build               # debug
swift build -c release    # release (binaire dans .build/release/MeetingBrief)
swift run                 # compile + lance
```

## Limites

- Signature ad-hoc uniquement (pas de notarization Apple) — sans conséquence via l'install depuis les sources (voir plus haut).
- Pas de persistance du transcript : si l'app crash pendant l'analyse, le paste est perdu. Workaround : garde le transcript dans ton presse-papiers jusqu'à l'envoi. En cas d'échec d'écriture de la note (dossier invalide…), le transcript et l'analyse sont conservés dans l'app avec un bouton « Réessayer ».
- Édition inline simple (ajout/suppression/modification d'items), pas de drag & drop.

## Licence

MIT.
