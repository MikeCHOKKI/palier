# Palier : identité visuelle

Application familiale de progression (dépenses, sport, habitudes), aux couleurs Ekim mais sans le logo
Ekim. Nom et symbole choisis le 07/11/2026 parmi trois pistes (voir `propositions/`).

## Le symbole

Trois marches et un point cyan arrivé sur la plus haute : chacun progresse marche après marche, en
argent, en forme et en habitudes. Le point est la personne.

Construction (boîte 568 × 662, coordonnées dans `sources/palier-symbole.svg`) : marches de 160 px de
large et de haut, la dernière de 192 px pour porter le point ; coins extérieurs arrondis par un trait
de 56 px du même bleu ; point de 58 px de rayon, centré au-dessus de la dernière marche.

## Fichiers

| Fichier | Usage |
|---|---|
| `sources/palier-symbole.svg` | Symbole sur fond sombre |
| `sources/palier-symbole-clair.svg` | Symbole sur fond clair (point cyan foncé) |
| `sources/palier-symbole-mono.svg` | Une seule couleur (blanc), à recolorer |
| `sources/palier-icone.svg` | Icône carrée arrondie (README, présentation) |
| `sources/android-*.svg` | Icône adaptative Android : avant-plan, arrière-plan, monochrome (icône à thème) |
| `sources/demarrage.svg` | Écran de démarrage Android 12+ (1152 px, contenu dans le cercle de 768 px) |
| `exports/` | Les mêmes en PNG, rendus par Inkscape |
| `charte.html` / `charte.png` | Planche de contrôle : masques Android, zone sûre, 48 px, logotype, couleurs |

L'avant-plan Android tient dans la zone sûre de 66 dp : rayon du dessin 297 px pour 313 px permis
(mesuré sur `exports/android/android-avant-plan.png`).

## Couleurs

| Rôle | Valeur |
|---|---|
| Fond profond | `#020913` |
| Bleu nuit (fond de l'application et de l'icône) | `#111827` |
| Indigo (surfaces) | `#172D4F` |
| Bleu acier (marches, couleur principale) | `#0A6A9E` |
| Cyan (point, accent) | `#02D1E8` |
| Cyan sur fond clair | `#0093AB` |
| Clair | `#F4F7FA` |

Le cyan est réservé à ce qui compte : la personne dans le symbole, un objectif atteint, l'action
principale. Il ne sert jamais de couleur de texte sur fond clair.

## Typographie

Unbounded (titres et logotype) et Manrope (texte), toutes deux sous licence OFL. Le logotype reste
en texte tant que les fichiers de police ne sont pas embarqués ; il sera vectorisé ensuite.

## Ne pas faire

- Changer les proportions des marches ou décoller le point de la dernière marche.
- Poser le symbole couleur sur un fond moyen (bleu acier, indigo) : utiliser la version une couleur.
- Ajouter une ombre, un contour ou un dégradé au symbole.
