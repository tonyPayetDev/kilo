---
name: webapp-testing
description: >
  Teste les applications web et les jeux avec Playwright.
  À utiliser pour vérifier la fonctionnalité frontend, déboguer le comportement UI,
  capturer des screenshots, ou faire du QA testing.
  Supporte l'automatisation navigateur headless.
metadata:
  author: misskim (adapté par Claude)
  version: "1.0"
  origin: Playwright Testing Skill pour MiniPC/Claude Code
---

# Webapp Testing avec Playwright

Testez vos applications web et jeux en utilisant Playwright en mode headless.

## Environnement

- **Navigateur:** Chromium headless
- **Usage:** QA, tests fonctionnels, screenshots, capture de logs console
- **Protocole:** MCP (Model Context Protocol) ou scripts Python direct

## Arbre de décision

```
Test cible → HTML statique ?
├─ Oui → Lire le fichier directement
│        → Automatiser avec Playwright
└─ Non (Webapp dynamique) → Serveur en cours ?
    ├─ Non → Démarrer le serveur d'abord
    └─ Oui → Pattern Reconnaissance-Action:
        1. Naviguer + attendre networkidle
        2. Screenshot ou inspection DOM
        3. Identifier les sélecteurs
        4. Exécuter les actions
```

## Patterns clés

### Reconnaissance puis Action

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto('http://localhost:PORT')
    page.wait_for_load_state('networkidle')  # Obligatoire !

    # 1. Reconnaissance: comprendre le DOM
    page.screenshot(path='/tmp/inspect.png', full_page=True)

    # 2. Explorer les sélecteurs
    buttons = page.locator('button').all()

    # 3. Action: interagir avec les éléments identifiés
    page.click('text=Start Game')

    browser.close()
```

### Test QA de jeux

```python
# Vérifier le chargement du jeu
page.goto('http://localhost:9877/game.html')
page.wait_for_load_state('networkidle')

# Vérifier le rendu canvas
canvas = page.locator('canvas')
assert canvas.is_visible()

# Tester les interactions
page.click('canvas', position={'x': 400, 'y': 300})
page.wait_for_timeout(1000)

# Vérifier les changements de score/état
score = page.locator('#score').inner_text()
page.screenshot(path='/tmp/game-test.png')

# Capturer les erreurs console
errors = []
page.on('console', lambda msg: errors.append(msg.text) if msg.type == 'error' else None)
```

## Commandes essentielles

### Installation Playwright
```bash
npm install -g @playwright/mcp@latest
# ou
pip install playwright
playwright install
```

### Lancer un test
```bash
# Via MCP
claude mcp add playwright npx '@playwright/mcp@latest'

# Via script Python
python3 test_webapp.py
```

## Cas d'usage courants

### 1. Vérifier le rendu visuel
```python
page.goto('http://localhost:3000')
page.wait_for_load_state('networkidle')
page.screenshot(path='/tmp/homepage.png', full_page=True)
```

### 2. Tester un formulaire
```python
page.goto('http://localhost:3000/contact')
page.fill('input[name="name"]', 'Test User')
page.fill('input[name="email"]', 'test@example.com')
page.click('button[type="submit"]')
page.wait_for_selector('.success-message')
```

### 3. Capturer les erreurs JavaScript
```python
errors = []
page.on('pageerror', lambda err: errors.append(str(err)))
page.on('console', lambda msg: errors.append(msg.text) if msg.type == 'error' else None)
page.goto('http://localhost:3000')
print(f"Erreurs détectées: {len(errors)}")
```

### 4. Tester le responsive
```python
# Mobile
page.set_viewport_size({'width': 375, 'height': 667})
page.screenshot(path='/tmp/mobile.png')

# Desktop
page.set_viewport_size({'width': 1920, 'height': 1080})
page.screenshot(path='/tmp/desktop.png')
```

## ⚠️ Bonnes pratiques

- **Toujours attendre `networkidle`** pour les apps dynamiques avant d'inspecter le DOM
- **Utiliser `headless=True`** pour l'exécution automatique (CI/CD)
- **Capturer des screenshots** à chaque étape critique pour le debugging
- **Vérifier la visibilité** avant de cliquer: `expect(page.locator('button')).to_be_visible()`
- **Utiliser des sélecteurs robustes:** préférer `data-testid` ou le texte plutôt que les classes CSS

## Débogage

```python
# Mode visible (non-headless) pour déboguer
browser = p.chromium.launch(headless=False, slow_mo=1000)

# Console logs en temps réel
page.on('console', lambda msg: print(f"CONSOLE: {msg.type}: {msg.text}"))

# Pause pour inspection manuelle
page.pause()  # Nécessite headless=False
```

## Ressources

- [Playwright Docs](https://playwright.dev/python/)
- [Selectors best practices](https://playwright.dev/python/docs/selectors)
- [Assertions](https://playwright.dev/python/docs/test-assertions)

---

**Note:** Ce skill fonctionne avec le Playwright MCP Server officiel de Microsoft.
