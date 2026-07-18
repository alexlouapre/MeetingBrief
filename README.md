# MeetingBrief

App **menu-bar macOS** qui transforme un transcript de réunion en note **Obsidian** structurée + message **Slack**, en un clic.

## Installation en une commande

```bash
curl -fsSL https://raw.githubusercontent.com/alexlouapre/MeetingBrief/main/scripts/remote-install.sh | bash
```

Ça vérifie les prérequis, clone le repo, compile en release, installe `MeetingBrief.app` dans `/Applications` et active le lancement auto à la session. Au premier lancement, un **onboarding guidé** te fait configurer la clé Claude, le dossier Obsidian et (optionnellement) Slack.

Le script vérifie et **installe automatiquement** ce qui manque (dont les Xcode command-line tools). Il te demandera **une fois** ton mot de passe admin pour l'installation des outils système — c'est normal, macOS l'exige.

> **Signature :** le build est compilé localement depuis les sources et signé ad-hoc. Comme le binaire n'est jamais téléchargé tel quel, il ne porte pas d'attribut quarantine — Gatekeeper ne bloque pas ce chemin d'installation.

## Installer via ton assistant Claude (zéro terminal)

Pas à l'aise avec le terminal ? Copie-colle ce bloc à ton assistant Claude (Claude Code, ou Claude dans le bureau) :

> Installe l'app macOS MeetingBrief pour moi. Lance cette commande et suis-la jusqu'au bout :
> ```
> curl -fsSL https://raw.githubusercontent.com/alexlouapre/MeetingBrief/main/scripts/remote-install.sh | bash
> ```
> Si les Xcode command-line tools manquent, le script les installe tout seul via `softwareupdate` — il aura besoin de mon mot de passe admin une seule fois (demande-le-moi si besoin, ou dis-moi de taper `! sudo -v` pour l'autoriser). Si l'install bascule sur la fenêtre graphique, préviens-moi de cliquer « Installer ». Quand c'est fini, dis-moi que l'icône 🔍 doit apparaître dans ma barre des menus, puis guide-moi dans l'onboarding (fournisseur + clé API, dossier Obsidian, Slack optionnel).

Ce que ton assistant fera pour toi :
1. Vérifie macOS 26+ et installe les command-line tools si absents (mot de passe admin demandé une fois).
2. Clone, compile et installe `MeetingBrief.app` dans `/Applications` + active le lancement auto.
3. Te laisse la main pour l'onboarding (les clés API et réglages restent privés, jamais partagés).

La seule chose que macOS ne peut **jamais** automatiser : ton mot de passe admin (ou un clic « Installer ») pour poser les outils système. Ton assistant te demandera ce geste unique au bon moment.

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
- LLM configurable : **Claude (Anthropic)** par défaut, ou tout serveur **compatible OpenAI** (voir [Modèle & fournisseur](#modèle--fournisseur))
- Slack Web API (bot token)
- Fichier local chiffré par FileVault pour les secrets (`~/Library/Application Support/MeetingBrief/secrets.json`, permissions 600)
- UserDefaults pour les préférences non-sensibles (chemin Obsidian, destinations Slack, toggles de flux)

## Prérequis

- macOS 26 (Tahoe) ou supérieur
- Xcode command-line tools (Swift 6.2+) — **installés automatiquement** par l'installeur si absents (mot de passe admin demandé une fois) ; sinon manuellement via `xcode-select --install`
- Une clé API Claude (`sk-ant-…`) — [console.anthropic.com](https://console.anthropic.com) — ou la clé d'un fournisseur compatible OpenAI (voir [Modèle & fournisseur](#modèle--fournisseur))
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

## Modèle & fournisseur

Le modèle n'est **plus une constante en dur** : c'est un réglage utilisateur (onboarding ou **Réglages → Modèle & fournisseur**). Deux dialectes API sont supportés :

- **Claude (Anthropic)** — défaut. Clé `sk-ant-…` depuis [console.anthropic.com](https://console.anthropic.com), modèle par défaut `claude-sonnet-5`.
- **Compatible OpenAI** — tout serveur exposant `POST /chat/completions` : OpenAI, OpenRouter, Groq, Mistral, DeepSeek, ou un modèle **local** (Ollama / LM Studio). Tu fournis :
  - le **modèle** (ex : `gpt-4o`, `mistral-large-latest`, `llama3.1:8b`) ;
  - l'**URL de base** (vide → `https://api.openai.com/v1` ; OpenRouter → `https://openrouter.ai/api/v1` ; Ollama local → `http://localhost:11434/v1`) ;
  - la **clé API** du provider (pour un serveur local sans auth, mets n'importe quelle valeur non vide).

La clé vit dans `secrets.json` (**une par dialecte** : `claude_api_key` / `openai_api_key` — basculer de provider ne perd pas l'autre clé), l'URL de base et le modèle dans UserDefaults. Rien n'est commité dans git.

> **Caveat qualité.** Le prompt d'analyse et le schéma JSON strict sont exigeants. Les modèles forts (Claude, GPT-4o / o-series, gros modèles ouverts) les gèrent bien. Les **petits modèles locaux** peuvent renvoyer du JSON invalide → erreur de parsing (gérée proprement, rien n'est perdu : réessaie ou change de modèle).
>
> **Limite connue :** MeetingBrief envoie `max_tokens` (accepté par OpenRouter, Ollama, Groq, Mistral, gpt-4o). Les tout derniers modèles OpenAI stricts (o-series, gpt-5) exigent `max_completion_tokens` et rejettent la requête (400).

## Configuration

Tout se configure dans l'onboarding au premier lancement, puis via ⚙︎ :

| Champ                     | Stockage     | Exemple                          |
| ------------------------- | ------------ | -------------------------------- |
| Fournisseur LLM           | UserDefaults | `anthropic` / `openai_compatible`|
| Modèle                    | UserDefaults | `claude-sonnet-5`, `gpt-4o`      |
| URL de base (openai only) | UserDefaults | `http://localhost:11434/v1`      |
| Clé API Claude            | secrets.json | `sk-ant-…`                       |
| Clé API compatible OpenAI | secrets.json | `sk-…`                           |
| Slack Bot Token           | secrets.json | `xoxb-…`                         |
| Destinations Slack        | UserDefaults | `#ops-meetings`, `@alex`         |
| Dossier Obsidian          | UserDefaults | `~/BriocheBrain/1-notes`         |
| Étape de validation       | UserDefaults | off (flux direct) par défaut     |
| Publication Slack         | UserDefaults | on par défaut                    |

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
