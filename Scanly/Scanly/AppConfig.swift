//
//  AppConfig.swift
//  ⚠️ Les réglages à personnaliser avant de publier l'app (voir README, partie 6).
//

import Foundation

nonisolated enum AppConfig {

    // MARK: À remplir avant publication

    /// Adresse web de ta politique de confidentialité (ex : "https://www.notion.so/…").
    /// Laisse vide pour masquer le lien dans les Réglages.
    static let privacyPolicyURL = ""

    /// Ton adresse e-mail de contact. Laisse vide pour masquer le bouton « Contacter ».
    static let supportEmail = ""

    /// Adresse qui reçoit les idées et signalements de bugs (bouton 💡).
    /// ⚠️ Remplace ce placeholder par ta vraie adresse.
    static let feedbackEmail = "ton.email@exemple.com"

    /// L'identifiant numérique de l'app sur l'App Store (« Identifiant Apple », ex : "6740000000").
    static let appStoreID = ""

    // MARK: Achat intégré (version illimitée)

    /// Identifiant de l'achat intégré (non consommable, à vie) à créer dans App Store Connect.
    /// Doit être identique dans App Store Connect et dans Scanly.storekit.
    /// Le prix (4,99 €) se règle uniquement dans App Store Connect, jamais dans le code.
    static let proProductID = "com.enzobataille.scanly.unlimited"

    /// Nombre de documents enregistrés gratuitement. Toutes les fonctions (scan, texte,
    /// signature, fusion, mot de passe, Face ID) sont gratuites : pas de filigrane, jamais.
    static let freeDocumentLimit = 10

    // MARK: Images

    /// Taille maximale (en pixels, côté le plus long) des pages enregistrées.
    static let maxPageDimension: CGFloat = 3000
}
