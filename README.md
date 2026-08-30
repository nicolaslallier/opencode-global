# opencode : un serveur, des agents partagés, un provider central

Tout ce dossier s'installe dans `~/.config/opencode`, qui est la config **globale**
d'opencode : elle est fusionnée avec la config de chaque projet, donc les agents
définis ici sont disponibles dans **tous** tes dépôts sans rien recopier.

## Installation

```bash
cd ~/OpenCode/opencode-global
./install.sh
```

Le script est idempotent et sauvegarde tout ce qu'il remplace (`*.bak-<date>`). Il :

1. vérifie qu'`opencode` est dans le PATH ;
2. écrit `~/.config/opencode/opencode.json` (provider + serveur + permissions) ;
3. copie les agents dans `~/.config/opencode/agents/` (+ un lien `agent` → `agents`,
   parce que selon la version opencode lit l'un ou l'autre) ;
4. interroge Ollama sur `http://192.168.2.41:11434` et remplit la liste réelle des
   modèles. Le modèle principal est **épinglé à `ollama-remote/qwen3.8:27b-mlx`** et n'est
   jamais réécrit automatiquement : si le serveur ne le sert pas, le script te le dit
   et sort en code 2 au lieu de le remplacer en douce. Seul `small_model`, laissé en
   `PLACEHOLDER`, est choisi automatiquement (le plus petit modèle disponible) ;
5. installe un LaunchAgent qui démarre `opencode serve` au login et le relance s'il
   meurt ;
6. attend que `http://127.0.0.1:4099/doc` réponde et te le confirme.

Pour un autre Ollama : `OLLAMA_URL=http://autre-hote:11434 ./install.sh`.

## Le modèle mental

`opencode` n'est pas un binaire monolithique : quand tu le lances, il démarre **un
serveur + une TUI qui parle à ce serveur**. Ici on inverse : le serveur tourne une
fois pour toutes en arrière-plan, et chaque client s'y **rattache** avec
`opencode attach`.

```
                   ~/.config/opencode/opencode.json  ──┐
                   ~/.config/opencode/agents/*.md    ──┤ (config globale, lue au démarrage)
                                                       ▼
  TUI ────────────┐                        ┌──────────────────────┐        ┌──────────────┐
  opencode run ───┼──► 127.0.0.1:4099 ────►│  opencode serve      │───────►│ Ollama       │
  script / curl ──┤    (HTTP + OpenAPI)    │  (LaunchAgent)       │        │ 192.168.2.41 │
  autre machine ──┘                        └──────────────────────┘        └──────────────┘
```

Un seul endroit définit les agents. Un seul endroit définit le modèle. Les clients
n'ont plus de config propre.

## Utilisation

Ajoute une fois à ton `~/.zshrc` :

```bash
source ~/.config/opencode/shell-aliases.sh
```

Puis, depuis n'importe quel projet :

| Commande | Effet |
|---|---|
| `oc` | TUI rattachée au serveur, dans le dossier courant |
| `occ` | idem, en reprenant la dernière session |
| `ocr "ta demande"` | prompt one-shot, sans TUI |
| `ocA infra "monte la stack"` | lance un agent précis |
| `ocstatus` | le serveur répond-il ? |
| `oclogs` | suit les logs du serveur |

Sans les alias, l'équivalent brut est :

```bash
opencode attach http://127.0.0.1:4099 --dir "$PWD"
opencode run --attach http://127.0.0.1:4099 --dir "$PWD" --agent review "relis le dernier commit"
```

## Les agents installés

Agents **génériques**, utiles partout :

| Agent | Rôle | Écriture |
|---|---|---|
| `review` | revue de code, constats classés, rien n'est modifié | non |
| `security` | revue sécurité : vulnérabilité exploitable, chemin d'attaque, correctif | non |
| `docs` | README / AGENTS.md / docstrings à partir du code réel | oui |
| `test` | écrit les tests, les fait passer, diagnostique la suite | oui |
| `python` | data/ML : pandas, numpy, scikit-learn, PyTorch — uv, ruff, mypy, pytest | oui |
| `python-backend` | Python de service : FastAPI, Pydantic, SQLAlchemy, async — uv, ruff, mypy, pytest | oui |

Agents **taillés pour tes dépôts** (chacun connaît déjà les commandes réelles du repo,
tirées de son `AGENTS.md`) :

| Agent | Dépôt | Ce qu'il sait déjà |
|---|---|---|
| `infra` | `Infra` | cibles `make`, NGINX `:443` par hostname, CA auto-signée, `.env` intouchable, `provision-app` |
| `heaven-backend` | `Heaven-backend` | tout passe par `uv`, `uv run pytest`, fixture `LiveServer`, `uv.lock` commité |
| `heaven-frontend` | `Heaven-frontend` | Vite + `tsc`, pas de linter ni de tests — il le dit au lieu d'inventer |
| `dragonwarrior` | `DragonWarrior` | repo pré-scaffold : aucune commande n'existe encore |
| `ai` | `AI` | images Docker sous Colima, `make build NAME=`, image `opencode` à version épinglée, `clean`/`prune` destructifs |

`build` et `plan` restent les agents primaires natifs d'opencode ; `python` est un agent
primaire supplémentaire, sélectionnable au Tab dans la TUI. Les autres sont des
*subagents* : tu les appelles avec `@review`, `@security`, `@python-backend`, `@infra`, … dans la
TUI, ou avec `--agent` en ligne de commande.

`python` et `python-backend` ne se recouvrent pas : le premier fait du data/ML (pandas, sklearn,
PyTorch), le second du code de service (APIs, base de données, async).

Pour en ajouter un : dépose un `.md` dans `~/.config/opencode/agents/` (ou
`opencode agent create`). Il est immédiatement visible dans tous les projets.

## Modifier la config

- **Changer de modèle par défaut** : édite `model` / `small_model` dans
  `~/.config/opencode/opencode.json` (format `ollama-remote/<tag>`). Une valeur écrite à la
  main est respectée par `refresh-models.py` ; remets-la à `ollama-remote/PLACEHOLDER` si tu
  veux qu'il rechoisisse tout seul.
- **Rafraîchir la liste des modèles** après un `ollama pull` :
  `python3 ~/.config/opencode/refresh-models.py`
- **Un agent sur un autre modèle** : ajoute `model: ollama-remote/<tag>` dans le front-matter
  du `.md`. C'est le seul endroit où déroger au provider central.
- **Redémarrer le serveur** :
  `launchctl kickstart -k gui/$(id -u)/net.famillelallier.opencode`
- **Le désactiver** :
  `launchctl bootout gui/$(id -u)/net.famillelallier.opencode`

## LSP

Le champ `lsp` est **opt-in** depuis opencode 1.18.x : s'il est absent, le serveur
journalise `all LSPs are disabled` et aucun serveur de langage n'est lancé. La config
met donc :

```json
"lsp": true
```

ce qui active les ~37 serveurs intégrés (pyright, typescript, gopls, rust-analyzer,
bash, yaml-ls, dockerfile, terraform, eslint, …). Chacun ne démarre qu'à la demande,
et seulement si les trois conditions sont réunies :

1. le fichier ouvert a une extension connue du serveur (`.py` → pyright, `.ts` →
   typescript, …) ;
2. un marqueur de racine est trouvé en remontant l'arborescence (`pyproject.toml`,
   `package-lock.json`, `go.mod`, `Cargo.toml`, …) ;
3. le binaire est trouvé **dans le PATH du serveur** — sinon opencode le télécharge
   lui-même (npm) quand c'est possible.

Le point 3 est le piège en mode LaunchAgent : le serveur n'hérite pas du PATH du
shell, seulement de celui du plist. Il contient maintenant `~/.local/bin` (uv, pipx)
et `~/Library/pnpm` en plus des chemins Homebrew.

Vérifier ce qui tourne :

```bash
curl -s --get --data-urlencode "directory=$PWD" http://127.0.0.1:4099/lsp
```

(liste vide tant qu'aucun fichier n'a été ouvert dans cette session — les clients sont
créés paresseusement). Et pour voir la décision au démarrage :

```bash
grep 'LSP' ~/.local/share/opencode/log/opencode.log | tail -5
```

Pour n'en désactiver qu'un, ou en surcharger un :

```json
"lsp": {
  "eslint": { "disabled": true },
  "pyright": { "command": ["pyright-langserver", "--stdio"], "extensions": [".py", ".pyi"] }
}
```

Un objet **n'annule pas** les serveurs intégrés : il les active tous, puis applique tes
surcharges.

## Notes

- Le port est **4099**, pas 4096 : le conteneur Docker `opencode` (dépôt `AI`, sous
  Colima) publie déjà `127.0.0.1:4096`. Tant que les deux visaient 4096, c'est le
  conteneur qui gagnait — le LaunchAgent bouclait sur `ServeError` (adresse occupée)
  et `oc` parlait en fait à un opencode conteneurisé sans provider, sans agents et
  sans LSP, pendant que `ocstatus` affichait UP grâce au tunnel. Si tu changes le port
  ici, change-le partout : `opencode.json`, le plist, `shell-aliases.sh`, `diag.sh`,
  `fix-service.sh`.
- Le serveur écoute sur `127.0.0.1` : rien n'est exposé au réseau. Pour y accéder
  depuis une autre machine, passe `hostname` à `0.0.0.0` dans le bloc `server` **et**
  mets un mot de passe (`OPENCODE_SERVER_PASSWORD` dans le `EnvironmentVariables` du
  plist) — sinon n'importe qui sur le LAN a un shell sur ton Mac via l'outil `bash`.
- Les permissions sont sur `ask` pour `edit` et `bash`. Un agent qui doit tourner sans
  surveillance a besoin de son propre `permission: allow` dans son `.md`.
- Ollama doit écouter sur le réseau côté 192.168.2.41 (`OLLAMA_HOST=0.0.0.0:11434`),
  sinon `refresh-models.py` échouera avec un timeout.
- `opencode web` remplace `serve` si tu veux en plus une interface web sur le même
  port ; il suffit de changer `serve` en `web` dans le plist.

## Dépannage

### « il ne prend pas mon modèle Ollama distant »

La cause la plus probable : **l'id de provider `ollama` est déjà pris**. opencode
découvre tout seul un Ollama sur `http://127.0.0.1:11434` et l'enregistre sous l'id
`ollama` ; comme les configs sont *fusionnées* et non remplacées, un bloc
`provider.ollama` maison entre en collision avec cet auto-détecté, qui pointe sur
localhost. D'où un provider qui existe mais qui ne parle pas à la bonne machine.

La config utilise donc l'id **`ollama-remote`**, et met l'auto-détecté hors jeu avec
`"disabled_providers": ["ollama"]`. Les modèles s'écrivent `ollama-remote/<tag>`.

Autres causes, dans l'ordre où les vérifier — `./diag.sh` fait les dix contrôles d'un
coup et affiche exactement ce que le serveur a chargé :

```bash
cd ~/OpenCode/opencode-global && ./diag.sh
```

1. Ollama n'écoute que sur loopback côté `.40` → il faut `OLLAMA_HOST=0.0.0.0:11434`.
2. Le tag du modèle n'existe pas tel quel (`ollama list` sur le `.40` fait foi).
3. Une config de projet (`./opencode.json`, `./.opencode/`) ou la variable
   `OPENCODE_CONFIG_CONTENT` écrase la globale — elles gagnent sur `~/.config`.
4. Le serveur tourne encore avec l'ancienne config : il relit tout au démarrage
   seulement. `launchctl kickstart -k gui/$(id -u)/net.famillelallier.opencode`.
5. `@ai-sdk/openai-compatible` n'a pas pu être téléchargé au premier lancement
   (opencode le récupère à la volée) — visible dans
   `~/Library/Logs/opencode-serve.err.log`.

### « il utilise le mauvais modèle »

Ordre de priorité d'opencode au démarrage :

1. le drapeau `--model` / `-m` ;
2. le champ `model` de `opencode.json` ;
3. **le dernier modèle utilisé** ;
4. un classement interne.

Le point 3 est le piège : une session **déjà créée** garde le modèle avec lequel elle
a été ouverte. Changer la config ne la rattrape pas — ça ne vaut que pour les sessions
neuves. Donc : `oc` (session neuve) et non `occ` (reprise), ou `/models` dans la TUI
pour changer à la volée.

Si même une session neuve prend le mauvais modèle, la config ne gagne pas et il faut
forcer :

```bash
cd ~/OpenCode/opencode-global && ./pin-model.sh qwen3.8:27b-mlx
```

Ce script écrit le modèle dans `opencode.json` **et** dans le front-matter de chaque
agent (le front-matter d'un agent bat la config globale), met la source à jour pour
qu'un futur `./install.sh` ne défasse rien, et redémarre le serveur. Sans argument, il
réapplique le modèle déjà présent dans la config.

`./diag.sh` (points 10 et 11) montre d'où vient le modèle retenu : ce que dit la
config, ce que le serveur a chargé, et les modèles mémorisés dans
`~/.local/share/opencode`.
