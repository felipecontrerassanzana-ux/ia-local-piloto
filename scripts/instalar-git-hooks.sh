#!/bin/sh
# Instala los git hooks versionados de scripts/hooks/ en .git/hooks/ de este repo.
# Hace falta correr esto una vez por cada copia local del repo (clonar no alcanza,
# git no versiona .git/hooks/ — limitación de git, no de este proyecto).

REPO_ROOT="$(git rev-parse --show-toplevel)"

cp "$REPO_ROOT/scripts/hooks/pre-commit" "$REPO_ROOT/.git/hooks/pre-commit"
chmod +x "$REPO_ROOT/.git/hooks/pre-commit"

echo "Hook pre-commit instalado en .git/hooks/pre-commit."
echo "A partir de ahora, cualquier commit que toque un .ps1 corre scripts/_verificar-sintaxis.ps1 automáticamente."
