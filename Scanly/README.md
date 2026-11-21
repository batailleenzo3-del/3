# 📄 Scanly — le guide complet (version 1.0)

Ce dossier contient **tout** : le projet Xcode prêt à ouvrir, l'icône, l'achat intégré (même code que Swipe Photos et Subs), les textes App Store en 5 langues, un studio de captures d'écran et la politique de confidentialité.
Lis ce guide dans l'ordre. Chaque étape est expliquée clic par clic.

---

## Sommaire

1. [Ce que fait l'app (et pourquoi elle va se vendre)](#1-ce-que-fait-lapp-et-pourquoi-elle-va-se-vendre)
2. [La charte de ton profil App Store](#2-la-charte-de-ton-profil-app-store)
3. [Contenu du dossier](#3-contenu-du-dossier)
4. [Installer l'app sur ton iPhone](#4-installer-lapp-sur-ton-iphone)
5. [Tester l'achat sans payer](#5-tester-lachat-sans-payer)
6. [Publier sur l'App Store](#6-publier-sur-lapp-store)
7. [Dépannage](#7-dépannage)

---

## 1. Ce que fait l'app (et pourquoi elle va se vendre)

**Le besoin** : tout le monde doit un jour envoyer un papier « en PDF » : justificatif de domicile, fiche de paie, contrat signé, ordonnance, facture pour la mutuelle, dossier de location… Et retrouver ce papier six mois plus tard.

**Le marché** : « scanner » et « pdf » font partie des recherches les plus tapées de l'App Store. Mais presque toutes les apps du classement font la même chose : essai gratuit puis **abonnement de 5 à 10 € par semaine**, ou un **filigrane** sur chaque PDF. Les avis 1 étoile en sont remplis.

**Pourquoi Scanly** : *toutes les fonctions, pas de filigrane, pas d'abonnement, rien ne quitte l'iPhone*. C'est exactement l'image de ton profil, et c'est un argument qu'on comprend en une seconde dans les captures.

### Les fonctions
| Écran | Ce qu'on y trouve |
|---|---|
| **Documents** (accueil) | Tous les scans en grille avec miniature, **recherche dans le nom ET dans le texte des pages** (l'extrait trouvé s'affiche sous le document), favoris, tri (récents, nom, nombre de pages) |
| **Scanner** | Le scanner d'Apple (VisionKit) : **détection automatique des bords**, redressement, plusieurs pages d'affilée. Le filtre « Auto » blanchit le fond comme une photocopie |
| **Importer** | Photos (jusqu'à 50 d'un coup) ou **PDF / images depuis Fichiers** |
| **Un document** | Les pages (toucher = plein écran avec zoom), nom suggéré à partir du texte (« Facture N° 2026-118 »), et 5 boutons : **Partager, Texte, Signer, Pages, Ajouter** |
| **Partager** | **PDF recherchable** (texte sélectionnable dans n'importe quel lecteur), **protégé par mot de passe** si on veut, ou images JPEG, ou texte. 3 tailles : haute qualité, équilibrée (e-mail), légère (formulaires en ligne limités). Mail, Messages, AirDrop, Fichiers, **Imprimer** |
| **Texte** | Le texte reconnu, page par page, sélectionnable, bouton **Tout copier** |
| **Signer** | Dessiner sa signature une fois (gardée pour la prochaine fois), choisir la page, la placer au doigt, pincer pour agrandir, encre noire ou bleue |
| **Pages** | Réordonner en glissant, supprimer, **tourner**, changer le filtre d'une page (sans perte : l'original est gardé) |
| **Sélection** (icône ✓ en haut) | **Fusionner** plusieurs documents en un PDF (dans l'ordre touché), partager ou supprimer en lot |
| **⚙︎ Réglages** | Version illimitée, filtre par défaut, taille d'export, **verrouillage Face ID**, ma signature, 8 couleurs + transparence du verre, thème, vibrations, tutoriel, noter l'app |
| **💡** | Idées & bugs (même écran que Swipe Photos et Subs), envoi par Mail |

### 100 % sur l'iPhone
- La reconnaissance du texte (OCR) utilise **Vision**, le moteur d'Apple intégré à l'iPhone, en français, anglais, espagnol, allemand et italien. **Aucun serveur, fonctionne en mode avion.**
- Avec le verrouillage, l'app demande Face ID à chaque ouverture et **cache les documents dans le sélecteur d'apps**.
- Rien n'est envoyé nulle part. Pas de compte, pas de cloud, pas de pisteur.

### Le modèle économique (le même que Swipe Photos et Subs)
- **10 documents gratuits**, sans limite de temps, avec **toutes les fonctions** (signature, mot de passe, fusion, Face ID…) et **sans filigrane**.
- Au 11ᵉ, l'écran de paiement s'ouvre : **achat unique à vie (4,99 €)**, Restaurer mes achats, partage familial.
- Supprimer un document libère une place (c'est honnête, et ceux qui scannent souvent achèteront).

### Ce qui n'est pas inclus (et pourquoi)
- **Synchronisation iCloud entre appareils** : nécessite CloudKit, qui **ne fonctionne pas avec un Apple ID gratuit**. Excellente mise à jour 1.1 une fois ton compte développeur payant actif. Les documents sont déjà inclus dans la sauvegarde iCloud de l'iPhone.
- **Dossiers** : la recherche dans le texte + les favoris couvrent le besoin pour la 1.0. Idée de mise à jour.

---

## 2. La charte de ton profil App Store

> **Que du vrai. Paiement unique. Pas de blabla.**

| Règle | Swipe Photos | Subs | Scanly |
|---|---|---|---|
| **Paiement unique**, jamais d'abonnement | 4,99 € à vie | 4,99 € à vie | 4,99 € à vie |
| **Version gratuite vraiment utilisable** | 100 swipes | 5 abonnements, 3 échéances | 10 documents, toutes les fonctions, sans filigrane |
| **Pas de pub, pas de pisteur, pas de compte** | ✓ | ✓ | ✓ |
| **Rien ne quitte l'iPhone** | ✓ | ✓ | ✓ (OCR sur l'appareil) |
| **Même design** : fond sombre, Liquid Glass, 8 couleurs, même écran de paiement, même 💡 | Néon | Émeraude | **Océan** |
| **Même icône** : deux cartes inclinées sur fond sombre | rose | vert | **bleu** |
| **5 langues** : FR, EN, ES, DE, IT | ✓ | ✓ | ✓ |

Le bloc de fin de description (déjà dans la fiche) :
```
Achat unique. Pas d'abonnement. Pas de pub. Rien ne quitte ton iPhone.
```

---

## 3. Contenu du dossier

```
Scanly/
├── README.md                       ← ce guide
├── Scanly.xcodeproj                ← DOUBLE-CLIQUE ICI pour ouvrir le projet
├── Info.plist                      ← infos de l'app (appareil photo, Face ID : déjà rempli)
├── Scanly.storekit                 ← achat de test (pour essayer sans payer)
├── Scanly/                         ← le code de l'app
│   ├── AppConfig.swift             ← ⚠️ À PERSONNALISER avant publication (e-mail, liens…)
│   ├── ScanlyApp.swift             ← point de départ
│   ├── ContentView.swift           ← tutoriel → bibliothèque, verrouillage Face ID
│   ├── LibraryView.swift           ← écran principal : documents, recherche, scanner, import, sélection
│   ├── DocumentView.swift          ← un document : pages, zoom, actions
│   ├── ExportSheet.swift           ← partager (PDF, mot de passe, images, texte) + texte reconnu
│   ├── PagesEditor.swift           ← réordonner, tourner, filtres, supprimer
│   ├── SignatureViews.swift        ← dessiner et placer la signature
│   ├── DocumentScanner.swift       ← le scanner d'Apple (VisionKit) + feuille de partage
│   ├── DocumentStore.swift         ← la bibliothèque (fichiers, pages, fusion…)
│   ├── ImageProcessing.swift       ← filtres, rotation, signature sur l'image
│   ├── TextRecognizer.swift        ← lecture du texte (Vision, sur l'iPhone)
│   ├── PDFExporter.swift           ← fabrication des PDF recherchables, images, texte
│   ├── AppLock.swift               ← Face ID et écran masqué
│   ├── SettingsView.swift          ← réglages
│   ├── PaywallView.swift           ← écran de paiement (comme Swipe Photos et Subs)
│   ├── PurchaseManager.swift       ← achat intégré (StoreKit 2, même code)
│   ├── FeedbackView.swift          ← Idées & bugs (même code)
│   ├── OnboardingView.swift        ← tutoriel
│   ├── Models.swift                ← document, page, filtres, qualité
│   ├── Components.swift            ← cartes, boutons, vibrations
│   ├── Effects.swift               ← couleurs, Liquid Glass, fonds, confettis (même code)
│   ├── Localization.swift          ← langue, dates
│   ├── Strings.swift               ← tous les textes dans les 5 langues
│   ├── Assets.xcassets             ← icône + couleur
│   └── fr/en/es/de/it.lproj        ← nom sous l'icône + messages d'autorisation
└── AppStore/
    ├── Fiche-App-Store.md          ← nom, description, mots-clés (5 langues), achat intégré, notes pour Apple
    ├── studio-captures.html        ← crée tes captures App Store (s'ouvre dans Safari)
    └── politique-de-confidentialite.html ← à mettre en ligne (obligatoire)
```

---

## 4. Installer l'app sur ton iPhone

1. **Décompresse** `Scanly.zip` et mets le dossier **Scanly** dans **Documents** (à côté de SwipePhotos et Subs).
2. **Double-clique** sur `Scanly.xcodeproj`.
3. Colonne de gauche → icône bleue **Scanly** → sous **TARGETS** : **Scanly** → onglet **Signing & Capabilities** → **Team** : *Enzo Bataille (Personal Team)*.
   - Erreur sur le Bundle Identifier ? Mets `com.enzobataille.scanly2026`.
4. Branche l'iPhone, choisis **ton iPhone** en haut (**pas un simulateur** : le simulateur n'a pas d'appareil photo), clique sur **▶︎**.

> L'app commence par le **tutoriel** (4 pages), puis l'écran **Documents** avec le bouton **Scanner**.
> L'accès à l'appareil photo est demandé au premier scan. Rien d'autre n'est demandé.

---

## 5. Tester l'achat sans payer

Comme pour Swipe Photos et Subs, le projet est en **mode démo** : lancé avec ▶︎ depuis Xcode, l'achat utilise `Scanly.storekit` (produit à **4,99 €**) avec la **vraie fenêtre de paiement Apple** (mention « Environment: Xcode »), sans aucun paiement réel.

### Remplir l'app en 2 secondes
⚙︎ **Réglages** → tout en bas, **🧪 Mode test** → **Ajouter 3 documents d'exemple** (une facture, un contrat de 2 pages, un ticket de caisse, avec du vrai texte : essaie de chercher « loyer » ou « 1 284 »). Marche aussi dans le simulateur. **Tout effacer** pour repartir de zéro.

### Tester le paiement
1. Crée 10 documents (exemples + quelques scans), puis touche **Scanner** → l'écran de paiement s'ouvre.
2. Touche **Débloquer pour 4,99 €** → fenêtre Apple → confirme : c'est débloqué.
3. Pour recommencer : 🧪 Mode test → **Revenir à la version gratuite**, et dans Xcode **Debug → StoreKit → Manage Transactions** → supprime l'achat.

### À essayer absolument
- Scanne une facture → regarde le bouton **« Nommer … »** qui propose le titre lu sur la feuille.
- Cherche un mot qui est **dans** la feuille (pas dans le nom) → le document sort, avec l'extrait.
- **Partager** → PDF avec mot de passe → ouvre-le dans Fichiers : le mot de passe est demandé.
- **Signer** → dessine, place, valide.
- ⚙︎ → **Verrouiller avec Face ID** → quitte l'app et reviens.

> La section 🧪 Mode test n'apparaît **que** quand l'app est lancée depuis Xcode : elle n'existe pas dans la version App Store.

### Si le prix ne s'affiche pas (« Prix indisponible · Réessayer »)
Lance l'app **avec ▶︎ depuis Xcode**. Sinon : **Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration** → **Scanly.storekit**. Un bouton 🧪 de secours apparaît aussi sur l'écran de paiement.

---

## 6. Publier sur l'App Store

Le compte développeur payant (99 €/an) sert pour **toutes** tes apps.

### 6.1 Personnaliser `AppConfig.swift`
- `privacyPolicyURL` : l'adresse de ta politique de confidentialité en ligne (voir 6.2).
- `supportEmail` : ton adresse de contact.
- `feedbackEmail` : ⚠️ **ton adresse e-mail** qui recevra les idées et bugs (remplace `ton.email@exemple.com`).
- `proProductID` : déjà rempli (`com.enzobataille.scanly.unlimited`). Garde-le tel quel.
- `appStoreID` : à remplir **après** la création de l'app. Pas obligatoire pour la 1ʳᵉ version.

### 6.2 Politique de confidentialité (obligatoire)
1. Ouvre `AppStore/politique-de-confidentialite.html` avec **TextEdit**, remplace `[TON E-MAIL DE CONTACT]` (6 fois ; la date est déjà remplie).
2. Mets-la en ligne comme pour tes autres apps (Notion ou Google Doc public), copie l'adresse dans `AppConfig.swift` et dans App Store Connect.

### 6.3 Créer l'app et l'achat intégré
1. <https://appstoreconnect.apple.com> → **Apps** → **+** → **Nouvelle app** : iOS, nom `Scanly – Scanner PDF & texte`, langue Français, Bundle ID `com.enzobataille.scanly`, SKU `scanly001`.
   - Nom déjà pris ? Essaie `Scanly – Scan PDF sans abo` ou ajoute un mot (le nom doit être unique sur tout l'App Store).
2. **Prix et disponibilité** → **Gratuit**.
3. **Achats intégrés** → **+** → **Non consommable** → `com.enzobataille.scanly.unlimited` → **4,99 €** (détails dans `AppStore/Fiche-App-Store.md`).

### 6.4 Remplir la fiche
- Textes en **5 langues** : copie-colle depuis `AppStore/Fiche-App-Store.md`.
- **Catégorie** : **Productivité**.
- **Captures** : iPhone 6,9" **et** iPad 13", via `AppStore/studio-captures.html`. ⚠️ Pas de vrais papiers personnels sur les captures.
- **Confidentialité** : « Aucune donnée collectée ». **Âge** : 4+.
- **Notes pour Apple** : copie le bloc de la fiche.

### 6.5 Envoyer l'app
1. **Signing & Capabilities** → **Team** : ton **compte payant**.
2. En haut d'Xcode : **Any iOS Device (arm64)**.
3. **Product → Archive** → **Distribute App** → **App Store Connect** → **Distribute**.
4. Dans App Store Connect : version 1.0 → **Build** → **+**. Ajoute aussi l'**achat intégré** à la version.
5. **Ajouter pour vérification** → **Soumettre**.

### 6.6 Si Apple refuse
- **2.3.7 (marques)** : un nom de marque dans le nom, le sous-titre ou les mots-clés → enlève-le.
- **4.3 (spam / app déjà vue)** : réponds en mettant en avant ce qui est différent : OCR et recherche sur l'appareil, PDF recherchables, mot de passe, signature, Face ID, aucune donnée collectée, pas d'abonnement, 5 langues.
- **3.1.1 (achat)** : vérifie que l'achat intégré est ajouté à la version.

---

## 7. Dépannage

| Problème | Solution |
|---|---|
| Erreur rouge à la compilation | Clique sur l'erreur, copie le texte (ou fais une photo) et envoie-le à Claude |
| `Signing … requires a development team` | Partie 4, étape 3 |
| `Failed Registering Bundle Identifier` | Change le Bundle Identifier (ajoute des chiffres) |
| « Appareil photo indisponible » | Tu es sur le simulateur : utilise l'iPhone, ou importe des photos / les documents d'exemple |
| L'appareil photo ne s'ouvre pas | Réglages iPhone → Scanly → **Appareil photo** → activé |
| Le texte n'est pas trouvé tout de suite | La lecture du texte prend 1 à 2 secondes par page juste après le scan (« Lecture du texte… ») |
| PDF trop lourd pour un formulaire | Partager → **Fichier léger** |
| « Prix indisponible · Réessayer » | Lance avec ▶︎ depuis Xcode (partie 5) |
| L'app ne s'ouvre plus après 7 jours | Compte gratuit : rebranche l'iPhone et clique sur ▶︎. **Tes documents sont conservés.** |
