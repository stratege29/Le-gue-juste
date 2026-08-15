# Audit — Scanner de reçus

Audit du 13/08/2026 sur la fonctionnalité introduite en `3f2c892`
(*feat(expenses): scan receipts to split items between participants*).

**Périmètre** : `ReceiptParser`, `ReceiptScannerService`, `ReceiptScannerScreen`,
`ReceiptItemsAssignmentScreen`, et l'intégration dans `AddExpenseScreen`.

**Méthode** : lecture de code + exécution du parser sur ~25 tickets synthétiques
(FR/EUR, CI/XOF, restaurants, supermarchés, sorties OCR bruitées) + tests widget
pilotant l'écran d'affectation jusqu'au `ReceiptScanResult`.

**Tests ajoutés** : [test/receipt_parser_test.dart](../test/receipt_parser_test.dart),
[test/receipt_text_layout_test.dart](../test/receipt_text_layout_test.dart) et
[test/receipt_items_assignment_test.dart](../test/receipt_items_assignment_test.dart).

**Suivi des correctifs** — BUG-1 à BUG-6 ont tous été **corrigés** après
l'audit ; leurs tests sont actifs et servent de garde anti-régression. Suite
complète : 176 passent, 0 `skip`. Les points UX de la dernière section restent
ouverts.

---

## Verdict

La **répartition** (moteur d'affectation par article → montants par personne) est
correcte et robuste : vérifiée sur EUR/XOF, parts inégales, arrondis
indivisibles, 7 participants. La somme des parts est **toujours exactement** égale
au total, donc `SplitCalculator.validateSplits` passe systématiquement.

L'**extraction** (parser OCR) était le maillon faible : plusieurs défauts
gonflaient le montant sans que rien ne le signale clairement à l'utilisateur —
sur une app de partage de dépenses, c'est le type d'erreur qui coûte de l'argent
réel. Les six sont corrigés. Sur le corpus de tickets de l'audit, la somme des
articles tombe désormais exactement sur le total détecté (FR/EUR : 14,89 contre
33,18 avant ; CI/XOF : 13 750 contre 21 750 avant), sauf sur le ticket
restaurant où subsiste l'en-tête « Table 12 Couverts 3 » — bruit connu, non
corrigé, signalé par la bannière d'écart.

`dart analyze` : 0 erreur, 0 warning (6 `info` de style).

---

## Bugs — impact monétaire

### BUG-1 · La ligne « SOUS-TOTAL » est comptée comme un article — **critique** · ✅ corrigé

[receipt_parser.dart:72](../lib/features/expenses/data/services/receipt_parser.dart#L72)

```dart
if (_isTotalLine(line) && !_subtotalPattern.hasMatch(line)) {
```

`_subtotalPattern` empêche bien « SOUS-TOTAL 14,89 » d'être pris pour le total,
mais la ligne **retombe ensuite dans l'extraction d'articles** : elle est ajoutée
comme un article « Sous-total » à 14,89 €. Un ticket de supermarché FR normal
(qui affiche presque toujours un sous-total) est donc **doublé**.

Observé : `Pain 2,00 / SOUS-TOTAL 2,00 / TOTAL 2,00` → 2 articles, somme 4,00 €.

Correctif appliqué : le `continue` couvre désormais **toute** ligne de total,
sous-total compris ; seule l'extraction de `detectedTotal` reste conditionnée à
l'absence de « sous-total ».

### BUG-2 · Un nom finissant par un chiffre crée un prix fantôme — **élevé** · ✅ corrigé

[receipt_parser.dart:116](../lib/features/expenses/data/services/receipt_parser.dart#L116)

`_trailingPrice` accepte n'importe quel nombre en fin de ligne, y compris quand
il fait partie du nom du produit. « YAOURT NATURE X8 » (sans prix) devient
« Yaourt Nature X » à **8,00 €**. Idem « MOUCHOIRS N2 » → 2,00 €.

Correctif appliqué : `_trailingPrice` est préfixé de `(?:^|\s)`, donc un nombre
collé à une lettre n'occupe plus le créneau du prix. Les prix légitimes restent
détectés, y compris collés à leur devise (« Savon 500F ») ou dans un nom qui
contient déjà des chiffres (« Riz 5kg 7500F », « Pack coca 6 4,50 »).

### BUG-3 · Une remise devient un article positif — **élevé** · ✅ corrigé

`REMISE FIDELITE -0,50` → article « Remise - » à **+0,50 €**. Le signe moins
n'est jamais capturé (il reste dans le nom), donc une réduction **augmente** le
total au lieu de le baisser — double erreur (2× le montant de la remise).
Même chose pour la notation entre parenthèses `(0,50)`, où la ligne est
simplement ignorée.

Correctif appliqué : `_trailingPrice` capture le signe dans un groupe dédié, le
montant est conservé **négatif**, et le nom est propre (« Remise »). En aval,
`ReceiptItemsAssignmentScreen` accepte les parts négatives (filtre `!= 0` au lieu
de `> 0`), autorise un prix négatif à l'édition, et refuse de valider un reçu
dont le total tombe à 0 ou moins.

### BUG-5 · « 2 x Yaourt 3,40 » facture 6,80 — **élevé** · ✅ corrigé

[receipt_parser.dart:149](../lib/features/expenses/data/services/receipt_parser.dart#L149)

Sur un ticket français, le montant en fin de ligne quantité est le **total de
ligne**, pas le prix unitaire. Le parser stocke `price = 3,40` **et**
`quantity = 2`, et `ReceiptItem.total` renvoie `price * quantity` = 6,80 €.

Correctif appliqué : quand une quantité est détectée en tête de ligne,
`price = lineTotal / qty`, donc `price * quantity` reconstitue le total de ligne.

### BUG-4 · « A PAYER » seul n'est pas reconnu comme total — **moyen** · ✅ corrigé

`_totalPatterns` couvre `net a payer` mais pas « A PAYER » nu, très courant en
France. Conséquence double : `detectedTotal` reste `null` (donc **aucune bannière
d'écart** ne peut alerter) et la ligne est ajoutée comme article.

Correctif appliqué : ajout du motif `(?:^|\s)[aà]\s+payer\b` (non ancré par `\b`
avant la voyelle, car `à` n'est pas un caractère de mot ASCII), qui couvre
« A PAYER », « À PAYER » et « NET A PAYER ».

Reste ouvert dans la même famille : un produit contenant le mot « total »
(« Total Recall DVD 12,00 ») est avalé comme ligne de total et **disparaît** des
articles.

---

## Bugs — extraction / couverture

### BUG-6 · Layout 2 colonnes ML Kit → 0 article — **élevé** · ✅ corrigé

[receipt_scanner_service.dart:20](../lib/features/expenses/data/services/receipt_scanner_service.dart#L20)

```dart
return ReceiptParser.parse(result.text);
```

`RecognizedText.text` concatène les **blocs** dans l'ordre de détection. Sur un
ticket à deux colonnes bien séparées (libellés à gauche, prix à droite — cas
fréquent des tickets de caisse), ML Kit renvoie souvent tous les libellés puis
tous les prix. Le parsing ligne à ligne ne peut alors apparier aucun couple :
résultat **0 article**, message « Aucun article détecté », l'utilisateur croit
que sa photo est mauvaise.

Correctif appliqué : nouveau
[`ReceiptTextLayout`](../lib/features/expenses/data/services/receipt_text_layout.dart).
`ReceiptScannerService` parcourt désormais `result.blocks[].lines[]`, trie les
lignes par position verticale, les regroupe en rangées dès qu'elles partagent
≥ 50 % de la hauteur de la plus courte, ordonne chaque rangée de gauche à droite
et les joint par deux espaces avant de parser. `result.text` ne sert plus que de
repli quand aucun bloc n'est renvoyé. Bénéfice secondaire : l'ordre de lecture ne
dépend plus de l'ordre des blocs, y compris sur un ticket à une seule colonne.

### Bruit d'en-tête non filtré — **moyen**

`Table 12   Couverts 3` (en-tête de ticket restaurant) devient un article à
3,00 €. `_skipPatterns` couvre `client|caisse|ticket|n°|numero` mais pas
`table|couverts|serveur|place`.

### Nettoyage des noms imparfait — **faible**

Résidus cosmétiques : « Boeuf 0,850 Kg X », « Espresso .............. »,
« Remise - ». Sans impact monétaire, mais peu soigné dans la liste d'articles.

### Filtre `price < 0,05` — **faible, assumé**

[receipt_parser.dart:125](../lib/features/expenses/data/services/receipt_parser.dart#L125)
écarte « Sac plastique 0,03 ». Volontaire (anti-bruit code-barres), à documenter
plutôt qu'à corriger.

---

## UX / robustesse

### Le retour arrière depuis l'affectation perd le scan — **moyen**

[receipt_scanner_screen.dart:218](../lib/features/expenses/presentation/screens/receipt_scanner_screen.dart#L218)

Si l'utilisateur revient en arrière depuis l'écran d'affectation, le
`ScannedReceipt` est jeté et il doit **reprendre la photo**. Le résultat OCR
devrait être conservé dans le state pour permettre un « réessayer ».

### Erreur de permission affichée en brut — **moyen**

[receipt_scanner_screen.dart:232](../lib/features/expenses/presentation/screens/receipt_scanner_screen.dart#L232)

```dart
SnackbarManager.showError(context, "Erreur lors du scan: $e");
```

Un refus de permission caméra remonte `PlatformException(camera_access_denied,
…)` tel quel dans une UI française. Il faudrait distinguer le cas permission et
proposer d'ouvrir les réglages (`permission_handler` est déjà une dépendance du
projet).

### Modèle OCR non encore téléchargé (Android) — **moyen**

Le manifeste déclare `com.google.mlkit.vision.DEPENDENCIES = ocr`, ce qui délègue
le téléchargement du modèle à Play Services. Au premier lancement sur un appareil
neuf (ou hors ligne), la reconnaissance peut renvoyer un texte vide → le message
affiché est « Aucun article détecté », trompeur. Distinguer ce cas.

### Double lancement du picker — **faible**

`_processing` n'est mis à `true` qu'**après** `pickImage`. Deux taps rapides sur
« Prendre une photo » lancent deux pickers.

### Photo temporaire jamais supprimée — **faible**

Le fichier copié par `image_picker` dans le cache n'est pas supprimé après OCR.
Les photos de reçus s'accumulent dans le cache de l'app.

### Thème sombre non géré — **moyen**

L'app expose un `darkTheme` ([app.dart:55](../lib/app.dart#L55)), mais l'écran
d'affectation code en dur `Colors.white` pour les cartes d'articles
([:261](../lib/features/expenses/presentation/screens/receipt_items_assignment_screen.dart#L261)),
la barre de résumé ([:421](../lib/features/expenses/presentation/screens/receipt_items_assignment_screen.dart#L421))
et la bottom sheet d'édition
([:598](../lib/features/expenses/presentation/screens/receipt_items_assignment_screen.dart#L598)).
En mode sombre, ces surfaces restent blanches.

### Décimales affichées en XOF — **faible**

`toStringAsFixed(2)` partout → « 13 750.00 FCFA ». Le franc CFA n'a pas de
subdivision ; l'affichage devrait suivre la devise.

---

## Ce qui est solide

- **Moteur de répartition** — la somme des parts égale exactement le total dans
  tous les cas testés (dont 13,33 € à 3, et 12 articles à 0,07 € sur 7
  personnes). `_absorbRoundingDrift` verse le résidu à la plus grosse part, ce
  qui garde `validateSplits` (tolérance 0,01) satisfait.
- **Garde-fous d'affectation** — validation bloquée si un article n'a aucun
  participant, ou si la liste est vide.
- **Bannière d'écart** — s'affiche bien dès que `detectedTotal` diverge de plus
  de 0,50 de la somme des articles. C'est le principal filet contre les bugs
  d'extraction restants ; depuis le correctif BUG-4, elle n'est plus neutralisée
  par un `detectedTotal` à `null` sur les tickets « A PAYER ».
- **Cycle de vie** — `TextRecognizer` fermé dans un `finally`, gardes `mounted`
  correctes après chaque `await`, contrôleurs `dispose()`és.
- **Vie privée** — OCR 100 % **on-device**, aucune image ni texte de reçu envoyé
  à un serveur, `rawText` non persisté. Les libellés iOS/Android sont explicites.
- **Parsing des montants** — virgule/point décimal, séparateurs de milliers
  (espace, espace insécable, point), suffixes `€ EUR FCFA XOF CFA F` : corrects
  sur tous les cas testés, y compris `12 500,50`.

---

## Priorisation suggérée

| # | Bug | Impact | Effort | État |
|---|-----|--------|--------|------|
| 1 | BUG-1 sous-total compté deux fois | Ticket doublé | Trivial | ✅ corrigé |
| 2 | BUG-5 quantité × total de ligne | Surfacturation ×N | Faible | ✅ corrigé |
| 3 | BUG-3 remise en positif | Erreur de signe | Faible | ✅ corrigé |
| 4 | BUG-4 « A PAYER » | Perte du filet de sécurité | Trivial | ✅ corrigé |
| 5 | BUG-2 prix fantôme (`X8`) | Montant inventé | Moyen | ✅ corrigé |
| 6 | BUG-6 layout 2 colonnes | Fonctionnalité inutilisable sur certains tickets | Moyen | ✅ corrigé |
| 7 | Erreur permission en brut | UX | Faible | ⚠️ ouvert |
| 8 | Thème sombre | UX | Faible | ⚠️ ouvert |
