#!/usr/bin/env bash

set -Eeuo pipefail

readonly INSTALLER_VERSION="1.0.0"
readonly REPOSITORY="nouhailler/huggor-downloads"
readonly RELEASES_URL="https://github.com/${REPOSITORY}/releases"
readonly API_URL="https://api.github.com/repos/${REPOSITORY}"
readonly MARKER="# Managed by HF Explorer universal installer."

install_root="${HUGGOR_INSTALL_ROOT:-${HOME:-}/.local}"
with_desktop=true
release_tag="${HUGGOR_RELEASE_TAG:-}"
action="install"
temporary_directory=""

say() {
    printf 'HF Explorer · %s\n' "$*"
}

warn() {
    printf 'HF Explorer · avertissement : %s\n' "$*" >&2
}

fail() {
    printf 'HF Explorer · erreur : %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Installateur Linux de HF Explorer (Huggor) ${INSTALLER_VERSION}

Usage :
  install.sh [options]
  install.sh --uninstall [options]

Options :
  --release VERSION   Installer une release précise (exemple : 0.3.0).
  --prefix CHEMIN     Racine d'installation (défaut : ~/.local).
  --no-desktop        Ne pas créer de lanceur dans le menu des applications.
  --uninstall         Désinstaller HF Explorer du profil utilisateur.
  -h, --help          Afficher cette aide.

L'installation ne demande pas sudo. Le code est placé dans
~/.local/lib/huggor et la commande dans ~/.local/bin/huggor.
Au premier lancement, les dépendances Python sont installées dans un
environnement isolé (connexion Internet nécessaire).
Les favoris et le cache restent dans ~/.local/share/hf-explorer : ils survivent
aux mises à jour et à la désinstallation.
EOF
}

cleanup() {
    if [[ -n "$temporary_directory" && -d "$temporary_directory" ]]; then
        rm -rf -- "$temporary_directory"
    fi
}
trap cleanup EXIT

while (($#)); do
    case "$1" in
        --release)
            (($# >= 2)) || fail "--release attend un numéro de version."
            release_tag="$2"
            shift 2
            ;;
        --prefix)
            (($# >= 2)) || fail "--prefix attend un chemin."
            install_root="$2"
            shift 2
            ;;
        --no-desktop)
            with_desktop=false
            shift
            ;;
        --uninstall)
            action="uninstall"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "option inconnue : $1"
            ;;
    esac
done

[[ -n "${HOME:-}" ]] || fail "la variable HOME n'est pas définie."

app_directory="${install_root}/lib/huggor"
version_path="${app_directory}/VERSION"
binary_directory="${install_root}/bin"
binary_path="${binary_directory}/huggor"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
desktop_directory="${data_home}/applications"
desktop_path="${desktop_directory}/io.github.nouhailler.huggor.desktop"
user_data_directory="${data_home}/hf-explorer"

uninstall_huggor() {
    if [[ -f "$binary_path" ]] && grep -qxF "$MARKER" "$binary_path"; then
        rm -f -- "$binary_path"
    elif [[ -e "$binary_path" ]]; then
        warn "${binary_path} n'est pas le lanceur créé par cet installateur et a été conservé."
    fi

    if [[ -f "$version_path" ]]; then
        rm -rf -- "${app_directory}/app" "${app_directory}/launcher" "$version_path"
        rmdir --ignore-fail-on-non-empty "$app_directory" 2>/dev/null || true
    elif [[ -d "$app_directory" ]]; then
        warn "${app_directory} n'a pas été créé par cet installateur et a été conservé."
    fi
    rm -f -- "$desktop_path"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$desktop_directory" >/dev/null 2>&1 || true
    fi
    say "désinstallation terminée."
    say "vos favoris, votre cache et l'environnement Python restent dans ${user_data_directory} ;"
    say "supprimez ce dossier vous-même pour les effacer."
}

if [[ "$action" == "uninstall" ]]; then
    uninstall_huggor
    exit 0
fi

for command_name in curl grep install mktemp sha256sum tar awk sed python3 flock; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "commande requise introuvable : ${command_name}"
done

python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' \
    || fail "Python 3.10 ou supérieur est requis (trouvé : $(python3 --version 2>&1))."
python3 -c 'import venv, ensurepip' >/dev/null 2>&1 \
    || fail "le module venv de Python est absent (Debian/Ubuntu : sudo apt install python3-venv)."

if ! command -v dpkg-deb >/dev/null 2>&1 && ! command -v ar >/dev/null 2>&1; then
    fail "ni dpkg-deb ni ar n'est disponible pour ouvrir l'archive (binutils)."
fi

curl_options=(--fail --location --silent --show-error --retry 3)
if [[ "${HUGGOR_TEST_ALLOW_FILE:-0}" != "1" ]]; then
    curl_options+=(--proto '=https' --tlsv1.2)
fi

if [[ -z "$release_tag" ]]; then
    say "recherche de la dernière release…"
    latest_url="$(curl "${curl_options[@]}" --output /dev/null \
        --write-out '%{url_effective}' "${RELEASES_URL}/latest")" \
        || fail "impossible de déterminer la dernière release (aucune release publiée ?)."
    release_tag="${latest_url##*/}"
fi
[[ "$release_tag" == v* ]] || release_tag="v${release_tag}"
version="${release_tag#v}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "numéro de version invalide : ${version} (format attendu : X.Y.Z)."

asset_name="hf-explorer_${version}_all.deb"
asset_url="${HUGGOR_DEB_URL:-${RELEASES_URL}/download/${release_tag}/${asset_name}}"
checksum_url="${HUGGOR_CHECKSUM_URL:-${asset_url}.sha256}"

temporary_directory="$(mktemp -d)"
downloaded_deb="${temporary_directory}/${asset_name}"
downloaded_checksum="${temporary_directory}/${asset_name}.sha256"

say "téléchargement de HF Explorer ${version}…"
curl "${curl_options[@]}" "$asset_url" --output "$downloaded_deb" \
    || fail "téléchargement impossible. Vérifiez que la release est publique et que ${asset_name} existe."

expected_sha256="${HUGGOR_DEB_SHA256:-}"
if [[ -z "$expected_sha256" ]] \
    && curl "${curl_options[@]}" "$checksum_url" --output "$downloaded_checksum" 2>/dev/null; then
    expected_sha256="$(awk 'NR == 1 {print $1}' "$downloaded_checksum")"
fi

if [[ -z "$expected_sha256" ]]; then
    release_metadata_url="${HUGGOR_RELEASE_METADATA_URL:-${API_URL}/releases/tags/${release_tag}}"
    release_json="$(curl "${curl_options[@]}" \
        -H 'Accept: application/vnd.github+json' \
        -H 'X-GitHub-Api-Version: 2022-11-28' \
        -H 'User-Agent: HuggorLinuxInstaller' \
        "$release_metadata_url")" \
        || fail "impossible de lire les métadonnées d'intégrité GitHub."
    normalized_json="$(printf '%s' "$release_json" \
        | tr -d '\n\r' \
        | sed -E 's/"name"[[:space:]]*:[[:space:]]*/"name":/g; s/"digest"[[:space:]]*:[[:space:]]*/"digest":/g')"
    asset_section="${normalized_json#*\"name\":\"${asset_name}\"}"
    [[ "$asset_section" != "$normalized_json" ]] \
        || fail "la release ne contient pas l'artefact ${asset_name}."
    asset_section="${asset_section%%\"name\":*}"
    expected_sha256="$(printf '%s' "$asset_section" \
        | sed -nE 's/.*"digest":"sha256:([0-9a-fA-F]{64})".*/\1/p')"
fi

[[ "$expected_sha256" =~ ^[0-9a-fA-F]{64}$ ]] \
    || fail "aucune somme SHA-256 fiable n'est publiée pour ${asset_name}."

actual_sha256="$(sha256sum "$downloaded_deb" | awk '{print $1}')"
[[ "${actual_sha256,,}" == "${expected_sha256,,}" ]] \
    || fail "la somme SHA-256 du paquet ne correspond pas à la release."
say "intégrité SHA-256 vérifiée."

extracted="${temporary_directory}/extracted"
mkdir -p "$extracted"
if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -x "$downloaded_deb" "$extracted" \
        || fail "impossible d'ouvrir le paquet."
else
    (
        cd "$temporary_directory"
        ar x "$downloaded_deb"
        data_archive="$(ls data.tar.* 2>/dev/null | head -n 1)"
        [[ -n "$data_archive" ]] || exit 1
        tar -xf "$data_archive" -C "$extracted"
    ) || fail "impossible d'ouvrir le paquet (archive zstd : installez zstd)."
fi

source_app="${extracted}/usr/share/hf-explorer"
source_launcher="${extracted}/usr/bin/hf-explorer"
[[ -f "${source_app}/app.py" && -f "$source_launcher" ]] \
    || fail "le paquet ne contient pas l'application attendue."

if [[ -d "$app_directory" && ! -f "$version_path" ]]; then
    fail "${app_directory} existe déjà et n'a pas été créé par cet installateur."
fi
rm -rf -- "${app_directory}/app" "${app_directory}/launcher"
install -d "$app_directory" "$binary_directory"
cp -R -- "$source_app" "${app_directory}/app"
install -m 0755 "$source_launcher" "${app_directory}/launcher"
printf '%s\n' "$version" >"$version_path"

printf -v quoted_app_directory '%q' "${app_directory}/app"
printf -v quoted_launcher '%q' "${app_directory}/launcher"
cat >"$binary_path" <<EOF
#!/usr/bin/env bash
${MARKER}
export HF_EXPLORER_APP_DIR=${quoted_app_directory}
exec ${quoted_launcher} "\$@"
EOF
chmod 0755 "$binary_path"

if [[ "$with_desktop" == true ]]; then
    install -d "$desktop_directory"
    cat >"$desktop_path" <<EOF
[Desktop Entry]
Type=Application
Name=HF Explorer
Comment=Rechercher et examiner les modèles du Hugging Face Hub
Exec=${binary_path}
TryExec=${binary_path}
Icon=applications-science
Terminal=true
Categories=Development;Science;
EOF
    chmod 0644 "$desktop_path"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$desktop_directory" >/dev/null 2>&1 || true
    fi
fi

say "HF Explorer ${version} est installé."
say "commande : ${binary_path}"
say "au premier lancement, les dépendances Python sont installées (Internet requis)."
case ":${PATH}:" in
    *":${binary_directory}:"*) ;;
    *) warn "ajoutez ${binary_directory} à PATH pour lancer l'application avec la commande 'huggor'." ;;
esac
say "pour désinstaller : curl -fsSL https://raw.githubusercontent.com/${REPOSITORY}/main/install.sh | bash -s -- --uninstall"
