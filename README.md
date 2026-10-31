# HF Explorer (Huggor) — téléchargements officiels

Ce dépôt public contient l'installateur et les binaires officiels de
[HF Explorer](https://github.com/nouhailler/huggor) (dépôt `huggor`), l'application
web pour explorer, comparer et évaluer les modèles du Hugging Face Hub.

## Installation Linux

L'installateur télécharge la dernière release, vérifie sa somme SHA-256, puis
installe HF Explorer dans `~/.local` sans utiliser `sudo` :

```bash
curl -fsSL https://raw.githubusercontent.com/nouhailler/huggor-downloads/main/install.sh | bash
```

Lancez ensuite l'application avec la commande :

```bash
huggor
```

et ouvrez <http://127.0.0.1:7860> dans votre navigateur. Au premier lancement, une
connexion Internet est nécessaire pour installer les dépendances Python dans un
environnement isolé : gardez le terminal ouvert. Si `huggor` n'est pas trouvé,
ajoutez `~/.local/bin` à votre `PATH`.

Pour inspecter le script avant de l'exécuter :

```bash
curl -fsSL https://raw.githubusercontent.com/nouhailler/huggor-downloads/main/install.sh -o /tmp/install-huggor.sh
less /tmp/install-huggor.sh
bash /tmp/install-huggor.sh
```

Options : `--release 0.3.0` (version précise), `--prefix CHEMIN` (racine
d'installation), `--no-desktop` (pas d'entrée dans le menu des applications),
`--help`. Exemple :

```bash
curl -fsSL https://raw.githubusercontent.com/nouhailler/huggor-downloads/main/install.sh | bash -s -- --release 0.3.0
```

### Prérequis

- Linux, avec `python3` en version 3.10 ou supérieure et son module `venv`
  (Debian/Ubuntu : `sudo apt install python3-venv`) ;
- `curl`, `tar`, `sha256sum` et `flock` (présents par défaut sur la plupart des distributions) ;
- `dpkg-deb` ou `ar` pour ouvrir l'archive ;
- une connexion Internet au premier lancement.

Le paquet est indépendant de l'architecture (`all`) : le code est du Python pur.

## Mise à jour

Relancez la commande d'installation : elle remplace le code par la dernière
release. Vos favoris et votre cache (`~/.local/share/hf-explorer/`) sont conservés.

## Désinstallation

```bash
curl -fsSL https://raw.githubusercontent.com/nouhailler/huggor-downloads/main/install.sh | bash -s -- --uninstall
```

Vos favoris, votre cache et l'environnement Python restent dans
`~/.local/share/hf-explorer/` ; supprimez ce dossier vous-même pour les effacer.

## Téléchargement manuel

Le paquet Debian/Ubuntu `hf-explorer_X.Y.Z_all.deb` est disponible dans les
[releases](https://github.com/nouhailler/huggor-downloads/releases/latest), avec
son fichier `.sha256` :

```bash
sha256sum -c hf-explorer_X.Y.Z_all.deb.sha256
sudo apt install ./hf-explorer_X.Y.Z_all.deb
```

## Sécurité

- l'installateur refuse un paquet dont le SHA-256 ne correspond pas ;
- les téléchargements passent uniquement par HTTPS (TLS 1.2 minimum) ;
- aucun jeton ni secret n'est incorporé dans ce dépôt ;
- l'installation est limitée au profil utilisateur (aucun `sudo`).

Signalement d'une vulnérabilité : voir
[SECURITY.md](https://github.com/nouhailler/huggor/blob/main/SECURITY.md).

## Plateformes

- Linux : installation universelle via `install.sh` ;
- Debian/Ubuntu : paquet `.deb` ;
- macOS, Windows : aucune distribution officielle pour le moment (l'application
  se lance depuis les sources, voir le [dépôt principal](https://github.com/nouhailler/huggor)).
