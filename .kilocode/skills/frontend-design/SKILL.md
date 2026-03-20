---
name: frontend-design
description: >
  Guide pour créer des interfaces frontend distinctives et de haute qualité.
  Évite les designs génériques "AI slop" (Inter + dégradés violets).
  Couvre la typographie, les couleurs, le motion, les arrière-plans et les patterns UI.
---

# Frontend Design

Ce skill guide la création d'interfaces frontend distinctives et de production qui évitent les esthétiques génériques "AI slop".

## Principes clés

### 1. Typographie

**Éviter les polices génériques :**
- ❌ Inter, Roboto, Arial, Open Sans, Lato, polices système par défaut

**Privilégier les polices distinctives :**
- 💻 **Code aesthetic :** JetBrains Mono, Fira Code, Space Grotesk
- 📰 **Editorial :** Playfair Display, Crimson Pro, Fraunces
- 🚀 **Startup :** Clash Display, Satoshi, Cabinet Grotesq
- ⚙️ **Technique :** IBM Plex family, Source Sans 3
- ✨ **Distinctive :** Bricolage Grotesque, Obviously, Newsreader

**Principes de pairage :**
- Contraste élevé = intéressant
- Display + monospace, serif + sans géométrique
- Variable font avec différents poids
- Utiliser les extrêmes : 100/200 vs 800/900, pas 400 vs 600
- Sauts de taille 3x+, pas 1.5x

### 2. Couleur & Thème

**S'engager dans une esthétique cohérente :**
- Utiliser les variables CSS pour la cohérence
- Couleurs dominantes avec accents tranchants
- Palettes timides et uniformément distribuées = ❌

**Inspirations :**
- Thèmes d'IDE (VS Code, Sublime)
- Esthétiques culturelles
- Mouvements de design (Brutalism, Swiss Style, etc.)

**Thèmes prédéfinis :**

```markdown
### Solarpunk
- Palettes chaudes et optimistes (verts, dorés, tons terreux)
- Formes organiques mélangées à des éléments techniques
- Motifs et textures inspirés de la nature
- Atmosphère lumineuse et pleine d'espoir
- Typographie rétro-futuriste

### Cyberpunk
- Néon sur fond sombre, typographie monospace
- Effets glitch, lignes de balayage
- Atmosphère high-tech dystopique

### Editorial
- Titres en serif, grille magazine
- Palette mute, citations en exergue
- Style publication imprimée

### Dark OLED Luxury
- Fond noir #000 pur, accents or/crème
- Serif fin, esthétique premium

### Brutalism
- Polices système, bordures visibles
- Pas de coins arrondis, couleurs vives
- Anti-design volontaire

### Retro-Futuristic
- Dégradés de maille, chrome
- Formes géométriques, violet/bleu
- Esthétique années 80-90
```

### 3. Motion (Animation)

**Solutions CSS-only pour HTML :**
- Animations pour effets et micro-interactions
- `animation-delay` pour révélations échelonnées
- Transitions sur `:hover`, `:focus`

**Pour React :**
- Utiliser la bibliothèque Motion (Framer Motion)
- Prioriser les moments à fort impact
- Une orchestration de chargement de page bien réalisée crée plus de plaisir que des micro-interactions dispersées

**Techniques clés :**
- Page load avec révélations échelonnées
- `animation-delay` pour séquencer
- Physics-based animations (spring)

### 4. Récupération et intégration d'images externes

Si une URL de site est transmise, récupérer automatiquement les images pour les intégrer :

**Workflow de récupération :**
```bash
# 1. Identifier les images sur le site source
curl -s "$URL" | grep -oE 'https?://[^"]+\.(jpg|jpeg|png|gif|webp)' | sort -u > images.txt

# 2. Télécharger les images
mkdir -p assets/images/external
while read img; do
  wget -q -P assets/images/external "$img"
done < images.txt

# 3. Optimiser les images (optionnel)
# Utiliser sharp, imagemin ou squoosh pour réduire la taille
```

**Intégration dans le design :**
- Analyser le sujet/thème des images récupérées
- Adapter la palette de couleurs pour matcher les images
- Utiliser les images comme :
  - Hero backgrounds (avec overlay sombre pour le texte)
  - Gallery/grid masonry
  - Cards avec images en arrière-plan
  - Thumbnails avec lazy loading

**Attribution et droits :**
- Vérifier les licences des images si usage commercial
- Mentionner la source si nécessaire
- Privilégier les images libres de droits (Unsplash, Pexels) comme fallback

**Exemple d'intégration CSS :**
```css
.hero {
  background-image: linear-gradient(rgba(0,0,0,0.5), rgba(0,0,0,0.5)), 
                    url('assets/images/external/hero.jpg');
  background-size: cover;
  background-position: center;
}

.gallery {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
}

.gallery img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: var(--radius-md);
}
```

### 5. Arrière-plans

**Créer atmosphère et profondeur :**
- ❌ Pas de couleurs unies par défaut
- ✅ Dégradés CSS en couches
- ✅ Patterns géométriques
- ✅ Effets contextuels qui correspondent à l'esthétique globale
- ✅ Gradients animés subtils
- ✅ Textures et motifs

**Techniques :**
```css
/* Gradient subtil */
background: linear-gradient(135deg, 
  hsl(220, 30%, 8%) 0%, 
  hsl(240, 25%, 12%) 50%, 
  hsl(260, 20%, 10%) 100%
);

/* Pattern géométrique */
background-image: 
  radial-gradient(circle at 20% 50%, rgba(120, 119, 198, 0.3) 0%, transparent 50%),
  radial-gradient(circle at 80% 80%, rgba(255, 119, 198, 0.15) 0%, transparent 50%);
```

## Anti-Patterns à éviter

### ❌ "AI Slop" Aesthetic
- Polices Inter sur fond blanc
- Dégradés violets sur blanc
- Cards avec ombres douces partout
- Layouts prévisibles et génériques
- Design cookie-cutter sans caractère spécifique au contexte

### ✅ Alternatives créatives
- Varier entre thèmes clairs et sombres
- Différentes polices pour chaque projet
- Différentes esthétiques selon le contexte
- Penser en dehors des sentiers battus !

## Workflow recommandé

```
1. /frontend-design          → Activer ce skill
2. Récupérer images (si URL) → Télécharger et analyser les images externes
3. Choisir une direction      → Editorial, Cyberpunk, Brutalist, etc.
4. Sélectionner typographie   → Google Fonts ou Adobe Fonts
5. Définir le système couleur → OKLCH ou HSL, matcher avec les images
6. Concevoir le layout        → Grid CSS, pas juste flexbox
7. Ajouter motion             → CSS animations ou Motion
8. Tester responsive          → Mobile-first
```

**Si une URL est fournie :**
- Scraper les images du site source
- Adapter la palette de couleurs aux images récupérées
- Intégrer les images dans le design (hero, gallery, cards)
- Optimiser les images pour le web

## Variables CSS Recommandées

```css
:root {
  /* Couleurs - utiliser OKLCH ou HSL */
  --color-primary: oklch(0.6 0.2 250);
  --color-background: oklch(0.995 0.005 250);
  --color-foreground: oklch(0.15 0.02 250);
  --color-muted: oklch(0.94 0.01 250);
  --color-border: oklch(0.88 0.015 250);
  
  /* Typographie */
  --font-display: 'Playfair Display', serif;
  --font-body: 'Source Sans 3', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  
  /* Espacement - grille 4px */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-3: 0.75rem;
  --space-4: 1rem;
  --space-6: 1.5rem;
  --space-8: 2rem;
  --space-12: 3rem;
  --space-16: 4rem;
  
  /* Rayons */
  --radius-none: 0;
  --radius-sm: 0.125rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
}
```

## Exemples de prompts

### Prompt complet
```
Crée une landing page pour un restaurant italien avec :
- Thème : Editorial chaleureux
- Typographie : Playfair Display (titres) + Source Sans 3 (body)
- Couleurs : Tons terreux (ocre, terracotta) avec accents vert olive
- Arrière-plan : Texture subtile de papier vieilli
- Motion : Révélations échelonnées au scroll
- PAS de dégradés violets, PAS d'Inter
```

### Prompt minimal efficace
```
Design brutaliste pour un portfolio de photographe.
Polices système uniquement, bordures visibles, pas de coins arrondis.
```

## Ressources

### Polices (Google Fonts)
- https://fonts.google.com/
- Filtres : Display, Serif, Monospace

### Inspiration couleurs
- https://coolors.co/
- https://colorhunt.co/
- Thèmes VS Code populaires

### Patterns & Textures
- https://www.magicpattern.design/
- CSS gradients : https://cssgradient.io/

### Motion
- https://motion.dev/ (React)
- https://gsap.com/ (JavaScript avancé)
- CSS animations : https://animate.style/

---

Source : Anthropic Frontend Aesthetics Cookbook
Version : 1.0 - Mars 2026
