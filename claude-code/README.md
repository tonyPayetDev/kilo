# Claude Code dans le navigateur via Coolify

Ce dossier est une alternative séparée à Kilo CLI. Il utilise **code-server** (VS Code dans le navigateur) et installe **Claude Code** en tant qu'utilisateur non-root.

## Déploiement Coolify

1. Dans Coolify, créer une ressource **Docker Compose** à partir du dépôt `tonyPayetDev/kilo`, branche `feature/claude-code-coolify`.
2. Configurer le chemin du fichier Compose : `/claude-code/docker-compose.yml` et son dossier de construction : `claude-code` (vérifier le contexte de build selon la version de Coolify).
3. Définir **PASSWORD** dans les variables d'environnement de Coolify avec un mot de passe long, unique, généré aléatoirement. Ne jamais le committer sur GitHub.
4. Configurer un domaine HTTPS privé pointant vers le service `claude-code` sur le port **8080**. Ne pas publier de port HTTP brut sur le VPS.
5. **Important :** placer le domaine derrière Cloudflare Access ou un VPN/Tailscale, en plus du mot de passe de code-server. Avant de déployer, vérifier que le VPS et le compte Coolify ont été assainis après l'incident de sécurité.
6. Une fois connecté, ouvrir Terminal > New Terminal dans code-server, puis exécuter `claude --version` et `claude`.
7. Se connecter via `/login` ou ajouter `ANTHROPIC_API_KEY` via les secrets Coolify si votre mode d'accès le nécessite. Ne jamais enregistrer de clé en dépôt Git.
8. Vérifier la persistance en redémarrant le conteneur : les fichiers de `/home/coder/project` et l'état de `/home/coder/.claude` doivent être conservés.

**Sécurité :** Claude Code peut modifier des fichiers et exécuter des commandes dans ce conteneur. Ne pas monter le socket Docker, le répertoire /root, ni les clés SSH de l'hôte. Ne pas exposer directement le service au public. Réutiliser les volumes précédemment compromis est déconseillé. Éviter les modes de contournement des permissions.

**Limites :** il s'agit d'un projet préparé pour le déploiement, pas d'un déploiement réalisé. L'image `latest` devra être figée à une version/digest contrôlé avant usage en production. Aucun test de build sur le VPS n'a été effectué.
