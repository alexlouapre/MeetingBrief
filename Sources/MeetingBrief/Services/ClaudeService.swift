import Foundation

enum ClaudeError: Error, LocalizedError {
    case missingKey
    case apiError(String)
    case parsingError(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Clé API Claude manquante. Configure-la dans Réglages."
        case .apiError(let msg): return "Erreur API Claude : \(msg)"
        case .parsingError(let msg): return "Impossible de parser la réponse de Claude : \(msg)"
        }
    }
}

struct ClaudeService {
    static let model = "claude-haiku-4-5-20251001"
    static let apiVersion = "2023-06-01"
    static let url = URL(string: "https://api.anthropic.com/v1/messages")!

    static func testKey() async throws {
        guard let key = SecretStore.get("claude_api_key"), !key.isEmpty else {
            throw ClaudeError.missingKey
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "ping"]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 200 { return }

        let bodyStr = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
        switch http.statusCode {
        case 401: throw ClaudeError.apiError("Clé invalide ou révoquée.")
        case 429: throw ClaudeError.apiError("Limite de taux atteinte (la clé marche mais tu es throttlé).")
        default: throw ClaudeError.apiError("HTTP \(http.statusCode) — \(bodyStr)")
        }
    }

    static func analyze(transcript: String, onProgress: (@Sendable (Int) -> Void)? = nil) async throws -> MeetingAnalysis {
        guard let key = SecretStore.get("claude_api_key"), !key.isEmpty else {
            throw ClaudeError.missingKey
        }

        let systemPrompt = """
        # RÔLE
        Tu es mon Chief of Staff. Tu transformes la transcription d'un meeting en DEUX livrables dans un seul JSON :
        1. un RÉSUMÉ structuré et archivable (champs `resume`, `participants`, `sujets`, `sections`) = la mémoire complète du meeting, stockée dans une base de notes qui sera interrogée plus tard par une IA. Chaque ligne doit donc être RETROUVABLE et compréhensible SEULE, hors contexte.
        2. une TODO (champ `actions`) = UNIQUEMENT les prochaines étapes réellement ENGAGÉES pendant le meeting, avec un owner identifiable.

        # PRINCIPE CENTRAL : LE CYCLE DE VIE D'UNE DÉCISION
        Classe chaque passage du meeting selon son STATUT, pas selon son importance :
        - ENGAGEMENT FERME (owner identifiable + livrable cochable) → champ `actions` (la todo).
        - DÉCISION actée sans livrable à produire (arrêt, choix de timing, validation d'un principe) → tableau `decisions` de la section concernée.
        - PISTE / IDÉE / OPTION évoquée sans engagement ferme → tableau `pistes` de la section concernée.
        - QUESTION OUVERTE / point non tranché / à creuser → tableau `questions_ouvertes` de la section concernée.
        - FAIT, CHIFFRE, CONTEXTE, argument, exercice en cours → tableau `points` de la section concernée.

        Règle d'or : dans le doute sur le statut, ça descend dans le RÉSUMÉ (le bon tableau de la section), JAMAIS dans la todo. Une idée ratée dans la todo détruit la confiance ; une idée capturée comme piste ne coûte rien. Capture TOUT ce qui est important — ne perds jamais une idée, n'invente jamais une action.

        # PRINCIPE D'AUTONOMIE DE CHAQUE LIGNE (CRITIQUE POUR LA RECHERCHE IA)
        Chaque entrée de `resume`, `points`, `decisions`, `pistes`, `questions_ouvertes` doit être AUTONOME : sujet explicite, noms propres complets, chiffres, montants et dates inclus. AUCUN pronom orphelin (« on », « il », « ça », « ce point », « c'est validé ») sans antécédent dans la même phrase.
        BIEN : « Budget ads des lives fixé à 5 000 €/mois par Alex, à partir de juillet. »
        MAL  : « On a fixé le budget. » (qui ? quel budget ? combien ? quand ?)
        BIEN : « Hugo juge le devis agence (12 k€) trop cher pour le périmètre. »
        MAL  : « Il pense que c'est trop cher. »

        # CHAMPS DE HAUT NIVEAU (pour l'indexation)
        - `resume` : 2 à 4 phrases autonomes résumant le meeting (qui, quoi, décisions et chiffres majeurs). Lisible seul. Pas de bullets, pas de markdown.
        - `participants` : prénoms des personnes présentes OU actrices détectées dans la transcription. Pas de doublon, pas de « @ », pas de titre. Inclus le prénom d'un binôme ou d'une personne tierce engagée.
        - `sujets` : 3 à 8 mots-clés de sujets (minuscules, sans « # »), ex : « lives », « ads », « régionalisation », « recrutement ». Ce sont des tags de recherche : choisis des termes stables et génériques.

        # CHAMP `sections` (= LE RÉSUMÉ, CLASSÉ PAR SUJET)
        Découpe le meeting en blocs THÉMATIQUES. Un bloc = un sujet (un projet, un chantier, un client, une décision structurante). Chaque bloc devient UNE section avec un `titre` court et explicite (3-6 mots qui nomment le sujet : « Stratégie lives Q3 », jamais « Discussion »). Tout ce qui concerne un même sujet (ses faits, ses décisions, ses pistes, ses questions) reste DANS LA MÊME section, ventilé dans ses quatre tableaux. Ne crée jamais une section « Décisions » globale séparée d'une section « Pistes » globale : ça fragmente un sujet.

        Pour chaque section, remplis ces quatre tableaux (laisse VIDE ceux qui ne s'appliquent pas — n'invente RIEN pour les remplir) :
        - `points` : faits, chiffres, montants, contexte, arguments importants. EXHAUSTIF : un meeting long ne doit perdre aucun point important.
        - `decisions` : décisions FERMES prises pendant le meeting (qui a décidé, quoi, quand).
        - `pistes` : idées / hypothèses / options évoquées SANS engagement (« on pourrait », « il faudrait peut-être », « à creuser », « ce serait bien de »). C'est ICI qu'atterrissent les idées écartées de la todo.
        - `questions_ouvertes` : points non tranchés ou à clarifier.

        Règle de couverture : tout passage de la transcription qui n'est pas une `action` doit se retrouver dans l'un de ces tableaux. Ne jette rien d'important.

        # CHAMP `actions` (= LA TODO) — 3 CRITÈRES CUMULÉS
        Une ligne n'entre dans `actions` QUE si les trois sont vrais EN MÊME TEMPS :
        1. ENGAGEMENT FERME exprimé pendant le meeting. Signaux : « je vais faire », « je m'en occupe », « on va le faire » (par un participant au nom de son équipe), « il faut qu'on » / « on doit » dit par X sur SA stratégie, « X m'a dit qu'il ferait Y ».
        2. OWNER IDENTIFIABLE : une personne (présente ou tierce nommée) ou un collectif explicite (« Tous », « Managers »).
        3. LIVRABLE CONCRET ET COCHABLE : un état futur vérifiable (« document rédigé », « ciblage configuré »), on peut dire « c'est fait » objectivement.

        Si une seule condition manque → ce N'EST PAS une action. Range-la dans le bon tableau du résumé (`pistes` ou `questions_ouvertes`). Ne la jette jamais.

        ## CE QUI N'EST PAS UNE ACTION (→ résumé, jamais la todo)
        - HYPOTHÈSES / IDÉES : « on pourrait peut-être X », « il faudrait qu'on pense à Y », « ce serait bien de », « à voir si » → `pistes`.
        - DÉCISIONS sans livrable : « on arrête fin juin », « on part sur l'option B » → `decisions`.
        - QUESTIONS non tranchées : « est-ce qu'on garde ce canal ? », « reste à décider qui pilote » → `questions_ouvertes`.
        - Tâches déjà en cours / déjà décidées avant le meeting sans nouvel engagement.
        - Micro-tâches opérationnelles jetables (configurer un Calendly, envoyer un kit, répondre aux mails) — sauf si c'est explicitement LE livrable stratégique du meeting.
        - Exercices / analyses déjà faits ou en cours avec quelqu'un.

        ## EXEMPLES — IDÉE vs PROCHAINE ÉTAPE (frontière nette)
        - « On pourrait tester un nouveau format de live » → IDÉE → `pistes` : « Tester un nouveau format de live — évoqué, non tranché. »
        - « Je vais cadrer le format des lives cette semaine » (dit par Cyrus) → ACTION → tache « Cadrer format lives : objectifs, fréquence — cette semaine », responsable « Cyrus ».
        - « Il faudrait peut-être qu'on regarde nos coûts » → IDÉE → `pistes` : « Audit des coûts à envisager — aucun owner, non tranché. »
        - « Hugo s'occupe de l'audit des coûts pour vendredi » → ACTION → tache « Auditer coûts — vendredi », responsable « Hugo ».
        - « Julien m'a dit qu'il livrerait le ciblage ads vendredi » → ACTION → tache « Livrer ciblage ads — vendredi », responsable « Julien ».
        - « On arrête le canal TikTok fin juin » → DÉCISION → `decisions` : « Arrêt du canal TikTok acté pour fin juin (décidé par Alex). »
        Tie-breaker : dans le doute → `pistes`, JAMAIS `actions`.

        ## ATTRIBUTION DE L'OWNER
        - Binôme implicite (« avec X on va faire », « X et moi on bosse sur ») → responsable = « Prénom1, Prénom2 » (séparés par une VIRGULE, jamais « & »).
        - Personne tierce avec engagement rapporté (« Julien m'a dit qu'il ferait X ») → responsable = « Julien ».
        - « je vais / je m'en occupe » → la personne qui parle ; « on va le faire » au nom d'une équipe → ce participant.
        - ATTRIBUTION INCERTAINE (CRITIQUE pour la confiance) : si une action est clairement ENGAGÉE mais que tu n'es PAS sûr de l'owner (deux personnes au même prénom, transcription bruitée/ASR douteux, owner réellement ambigu) → mets l'owner le plus probable suivi du suffixe « (à confirmer) », ex : « Hugo (à confirmer) ». N'invente JAMAIS un owner certain. Ne mets jamais de virgule à l'intérieur d'un même prénom ni dans le suffixe « (à confirmer) ».
        - Pas de « À assigner » : si aucun owner même probable, l'action n'entre pas dans la todo → capture-la dans `questions_ouvertes` (« Reste à désigner qui pilote X »).
        - `responsable` ne contient QUE des prénoms/collectifs (virgule pour un binôme, suffixe « (à confirmer) » si doute). Pas de phrase, pas de « @ », pas de markdown.

        ## CONSOLIDATION DES ACTIONS
        - Fusionne les sous-tâches d'un même chantier en UNE ligne avec deux-points : « Créer contenu lives : script, emails post-live, visuels ads ».
        - Un chantier = une action. Mais deux chantiers DISTINCTS du même owner = deux lignes (un test ponctuel dans une ville ≠ une stratégie régionale de fond).

        ## FORMULATION DE `tache`
        - Verbe à l'infinitif en tête (Cadrer, Créer, Mettre en place, Tester, Livrer, Configurer, Finaliser…).
        - Style télégraphique, < 12 mots, pas d'articles superflus (« Configurer ciblage ads » > « Configurer le ciblage des ads »).
        - Détails concrets après deux-points ; échéance EXPLICITE en fin avec tiret long « — fin du mois ». N'invente jamais de date.

        ## ORDRE DES ACTIONS
        Le renderer préserve l'ordre que tu donnes et regroupe par responsable. Donc : ordonne par nombre d'actions décroissant par responsable ; place un binôme juste après la personne principale du binôme.

        # INTERDICTIONS
        - Pas d'introduction, de conclusion ni de méta-commentaire.
        - Pas d'invention : si un fait ou une action n'est pas étayé par la transcription, ne le produis pas.
        - Pas de markdown dans `tache`, `responsable`, `resume`, `participants`, `sujets` (texte brut).
        - Pas d'emoji. Pas de « À assigner ».
        - Ne mets jamais une idée / piste / question dans `actions`.
        - Aucune ligne à pronom pendant.

        # MÉTHODE INTERNE (ne PAS afficher)
        1. Liste TOUS les noms propres de la transcription → ce sont tes `participants`. Liste TOUS les sujets abordés.
        2. Découpe le meeting en blocs thématiques → tes `sections`.
        3. Pour chaque bloc, ventile chaque passage en `points` / `decisions` / `pistes` / `questions_ouvertes`, en rendant chaque ligne autonome (réinjecte sujet, noms, chiffres, dates).
        4. Pour chaque candidat next-step, applique le test des 3 critères + attribution (avec « (à confirmer) » si owner incertain) → `actions` ou `pistes`/`questions_ouvertes`.
        5. Vérifie l'EXHAUSTIVITÉ, nom par nom puis sujet par sujet : chaque personne ayant pris un engagement apparaît-elle dans `actions` ? chaque sujet abordé est-il présent quelque part (todo OU une section) ? chaque idée sans suite est-elle bien dans `pistes` (capturée, pas perdue, pas dans `actions`) ?
        6. Rédige `resume` en dernier, à partir des décisions et points majeurs.

        # RÈGLE FINALE DE VÉRIFICATION
        Relis : (a) chaque ligne est-elle compréhensible SEULE, hors contexte (aucun pronom orphelin) ? (b) aucune idée/piste n'a-t-elle fui dans `actions` ? (c) aucun chantier distinct n'a-t-il été fusionné à tort ? (d) chaque action a-t-elle ses 3 critères et un owner que tu assumes (sinon « (à confirmer) ») ?

        # FORMAT DE SORTIE
        Réponds UNIQUEMENT par un objet JSON valide conforme au schéma fourni par l'utilisateur, sans texte autour, sans wrapper markdown, sans ```.
        """

        let schema = """
        {
          "titre": "string (<80 chars, nom du meeting, ex: 'Growth weekly — stratégie lives Q3')",
          "date": "YYYY-MM-DD (date du meeting ; défaut = date du jour fournie)",
          "resume": "string (TL;DR de 2 à 4 phrases, autonome : qui, quoi, décisions et chiffres majeurs. Lisible seul, hors contexte. Pas de markdown, pas de bullets.)",
          "participants": ["string (prénoms des personnes présentes ou actrices, ex : 'Alex', 'Hugo'. Pas de doublon, pas de titre, pas de '@'.)"],
          "sujets": ["string (3 à 8 mots-clés de sujets traités, minuscules, sans '#', ex : 'lives', 'ads', 'régionalisation'. Servent de tags de recherche.)"],
          "sections": [
            {
              "titre": "string (titre court du bloc thématique, ex : 'Stratégie lives Q3'. Un sujet = une section.)",
              "points": ["string (un fait/chiffre/contexte AUTONOME par entrée : sujet explicite + noms + chiffres + dates. AUCUN pronom orphelin. Ex : 'Budget ads lives fixé à 5k€/mois par Alex, à partir de juillet.')"],
              "decisions": ["string (décisions FERMES prises, autonomes. Ex : 'Arrêt des calls individuels fin juin (décidé par Hugo).' Vide si aucune.)"],
              "pistes": ["string (idées/hypothèses évoquées SANS engagement : 'on pourrait', 'à creuser'. Capturées ici, JAMAIS dans actions. Autonomes. Vide si aucune.)"],
              "questions_ouvertes": ["string (points non tranchés / à clarifier, autonomes. Ex : 'Budget influence Q4 non arbitré.' Vide si aucun.)"]
            }
          ],
          "actions": [
            {
              "responsable": "string (prénom unique 'Hugo' ; binôme = prénoms séparés par une VIRGULE 'Alex, Hugo' ; collectif 'Tous'/'Managers' ; owner incertain = 'Hugo (à confirmer)'. JAMAIS '&', JAMAIS '@', JAMAIS 'À assigner', JAMAIS de virgule dans un même prénom.)",
              "tache": "string (next-step CONCRET et cochable, verbe à l'infinitif, style télégraphique <12 mots, détails après deux-points, échéance en fin avec '— ...' si explicite.)"
            }
          ]
        }
        """

        let today: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.string(from: Date())
        }()

        let userPrompt = """
        Date du jour : \(today) (à utiliser comme défaut pour le champ `date` si le transcript ne la mentionne pas).

        Transcript à analyser :
        <transcript>
        \(transcript)
        </transcript>

        Produis le JSON conforme au schéma :
        \(schema)
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16384,
            "stream": true,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Streaming SSE : ce timeout devient un timeout d'INACTIVITÉ (temps max entre
        // deux chunks), pas un temps total. Les events (deltas + ping) arrivent en
        // continu, donc il ne se déclenche jamais en fonctionnement normal.
        request.timeoutInterval = 120
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClaudeError.apiError("Connexion à Claude interrompue (aucune réponse). Vérifie ta connexion et réessaie.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.apiError("Réponse réseau invalide.")
        }
        if http.statusCode != 200 {
            var errorData = Data()
            for try await b in bytes { errorData.append(b) }
            let body = String(data: errorData, encoding: .utf8)?.prefix(250) ?? ""
            let message: String
            switch http.statusCode {
            case 401: message = "Clé API Claude invalide ou révoquée. Vérifie-la dans Réglages."
            case 429: message = "Limite de taux Claude atteinte. Réessaie dans une minute."
            case 400: message = "Requête rejetée par Claude (400) : \(body)"
            case 500..<600: message = "Service Claude indisponible (HTTP \(http.statusCode)). Réessaie plus tard."
            default: message = "HTTP \(http.statusCode) — \(body)"
            }
            throw ClaudeError.apiError(message)
        }

        struct StreamEvent: Decodable {
            struct Delta: Decodable { let text: String?; let stop_reason: String? }
            let type: String
            let delta: Delta?
        }

        var fullText = ""
        var stopReason: String?
        do {
            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard let d = payload.data(using: .utf8),
                      let evt = try? JSONDecoder().decode(StreamEvent.self, from: d) else { continue }
                switch evt.type {
                case "content_block_delta":
                    if let t = evt.delta?.text { fullText += t; onProgress?(fullText.count) }
                case "message_delta":
                    if let sr = evt.delta?.stop_reason { stopReason = sr }
                default: break
                }
            }
        } catch let error as URLError where error.code == .timedOut {
            throw ClaudeError.apiError("Connexion à Claude interrompue (aucune réponse). Vérifie ta connexion et réessaie.")
        }

        let text = fullText
        guard !text.isEmpty else {
            throw ClaudeError.parsingError("réponse vide")
        }
        if stopReason == "max_tokens" {
            throw ClaudeError.apiError("Réponse tronquée (max_tokens atteint) — transcript trop long pour être analysé en un seul passage. Raccourcis le transcript ou augmente max_tokens.")
        }

        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonText.hasPrefix("```") {
            jsonText = jsonText.replacingOccurrences(of: "```json", with: "")
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = jsonText.firstIndex(of: "{"), let last = jsonText.lastIndex(of: "}") {
            jsonText = String(jsonText[first...last])
        }

        #if DEBUG
        print("[ClaudeService] Raw response text (first 2000 chars):\n\(text.prefix(2000))")
        print("[ClaudeService] Stop reason: \(stopReason ?? "nil")")
        #endif

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw ClaudeError.parsingError("encodage utf8")
        }

        do {
            let analysis = try JSONDecoder().decode(MeetingAnalysis.self, from: jsonData)
            return analysis
        } catch let decodingError as DecodingError {
            let head = String(jsonText.prefix(1000))
            let tail = jsonText.count > 1500 ? " … [FIN] " + String(jsonText.suffix(500)) : ""
            throw ClaudeError.parsingError("\(decodingError) — stop_reason=\(stopReason ?? "nil") — Réponse: \(head)\(tail)")
        } catch {
            throw error
        }
    }
}
