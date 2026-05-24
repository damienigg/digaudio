# Principes fondateurs de digaudio

Ces principes guident **toutes** les décisions de design et d'implémentation dans ce projet. Ils priment sur les conventions par défaut et sur l'ajout de fonctionnalités "au cas où".

## 1. Léger, performant, jamais redondant

Le code doit rester léger et performant. Aucune redondance tolérée : **si une logique apparaît au moins deux fois, elle doit être extraite en fonction réutilisable**. Pas de copier-coller, pas de variantes "presque identiques".

## 2. Le minimum de lignes pour un résultat valide

À résultat équivalent, **la solution la plus courte gagne toujours**. Pas d'abstractions prématurées, pas de couches d'indirection "au cas où", pas de helpers à usage unique. Si trois lignes suffisent, n'en écris pas dix.

## 3. Fixer la cause racine, jamais les symptômes

Quand un bug apparaît, **remonter à la cause racine** et la corriger là. Interdiction de patcher les effets : pas de `try/except` qui masquent, pas de valeurs par défaut qui cachent un état invalide, pas de contournements ad hoc. Si la racine n'est pas comprise, le diagnostic n'est pas terminé.

---

Ces règles ne sont pas négociables — elles définissent ce qu'est "du bon code" dans ce repo.
