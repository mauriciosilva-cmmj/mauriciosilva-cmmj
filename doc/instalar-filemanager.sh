#!/bin/sh
# FileManager installer: run with the ZIP alongside this script on the SD card.
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
archive="$base/FileManager-atualizado.zip"
apps=/mnt/SDCARD/Apps
target="$apps/FileManager"
stamp=$(date +%Y%m%d-%H%M%S)
backup="$apps/FileManager-backup-$stamp-$$"
stage="$apps/.FileManager-instalar-$$"
log="$apps/FileManager-instalacao.log"
fail() { printf '%s\n' "$*" | tee -a "$log" >&2; exit 1; }
[ -d /mnt/SDCARD ] || { echo 'Cartao SD nao encontrado em /mnt/SDCARD.' >&2; exit 1; }
mkdir -p "$apps"
: > "$log"
command -v unzip >/dev/null 2>&1 || fail 'O comando unzip nao esta disponivel no console.'
[ -f "$archive" ] || fail "ZIP nao encontrado ao lado do instalador: $archive"
command -v sha256sum >/dev/null 2>&1 || fail "O comando sha256sum nao esta disponivel no console."
printf "%s  %s\n" "021c03d2998575f1d1881981af28e599949f61185bb3c97b7c9e25d39a4d7a2c" "$archive" | sha256sum -c - >> "$log" 2>&1 || fail "O ZIP nao corresponde a esta versao do instalador."
[ ! -L "$target" ] || fail 'A pasta de destino e um link simbolico; instalacao interrompida.'
mkdir "$stage" || fail 'Nao foi possivel criar a pasta temporaria.'
cleanup() {
    case "$stage" in "$apps"/.FileManager-instalar-[0-9]*) rm -rf -- "$stage";; esac
}
trap cleanup EXIT HUP INT TERM
printf 'Conferindo pacote...\n' | tee -a "$log"
unzip -t "$archive" >> "$log" 2>&1 || fail 'O ZIP esta incompleto ou danificado.'
unzip -q "$archive" -d "$stage" >> "$log" 2>&1 || fail 'Falha ao extrair o pacote.'
src="$stage/FileManager"
[ -f "$src/DinguxCommander" ] && [ -f "$src/launch.sh" ] && [ -f "$src/res/consoles.tsv" ] || fail 'O pacote nao contem os arquivos esperados.'
if command -v sha256sum >/dev/null 2>&1; then
    (cd "$src" && sha256sum -c SHA256SUMS.txt) >> "$log" 2>&1 || fail 'As somas de verificacao nao conferem.'
fi
if [ -d "$target" ]; then
    printf 'Criando backup em %s\n' "$backup" | tee -a "$log"
    mkdir "$backup" || fail 'Nao foi possivel criar o backup; nada foi alterado.'
    cp -R "$target/." "$backup/" || fail 'Falha no backup; nada foi alterado.'
fi
mkdir -p "$target" "$target/lib" "$target/res" "$target/licenses" || fail 'Nao foi possivel criar as pastas do aplicativo.'
# Install the executable last, using a rename so a failed copy cannot leave a truncated executable.
cp -R "$src/lib/." "$target/lib/" || fail "Falha nas bibliotecas. Backup: $backup"
for file in "$src"/res/*; do
    name=${file##*/}
    [ -f "$file" ] || continue
    # Existing user-edited metadata takes priority.
    [ "$name" = consoles.tsv ] && [ -f "$target/res/consoles.tsv" ] && continue
    cp "$file" "$target/res/$name" || fail "Falha nos recursos. Backup: $backup"
done
cp -R "$src/licenses/." "$target/licenses/" || fail "Falha nas licencas. Backup: $backup"
for name in config.json trimui.cfg; do
    [ -e "$target/$name" ] || cp "$src/$name" "$target/$name" || fail "Falha em $name. Backup: $backup"
done
for name in commander.png commanderr.png; do
    cp "$src/$name" "$target/$name" || fail "Falha no icone $name. Backup: $backup"
done
cp "$src/LEIA-ME.txt" "$target/LEIA-ME.txt" || fail "Falha na documentacao. Backup: $backup"
cp "$src/launch.sh" "$target/launch.sh.novo" || fail "Falha no launcher. Backup: $backup"
cp "$src/DinguxCommander" "$target/DinguxCommander.novo" || fail "Falha no executavel. Backup: $backup"
chmod +x "$target/launch.sh.novo" "$target/DinguxCommander.novo" || fail "Falha ao marcar arquivos executaveis. Backup: $backup"
mv -f "$target/launch.sh.novo" "$target/launch.sh" || fail "Falha no launcher. Backup: $backup"
mv -f "$target/DinguxCommander.novo" "$target/DinguxCommander" || fail "Falha no executavel. Backup: $backup"
sync
printf 'Instalacao concluida em %s\n' "$target" | tee -a "$log"
[ ! -d "$backup" ] || printf 'Backup anterior: %s\n' "$backup" | tee -a "$log"
printf 'Preferencias e atalhos existentes foram preservados. Icones anteriores estao no backup.\n' | tee -a "$log"
