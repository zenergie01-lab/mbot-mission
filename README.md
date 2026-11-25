# 🤖 mBot Mission

Jeu éducatif pour apprendre à programmer le robot **mBot** (Makeblock) en technologie au collège (cycle 4).
Un seul fichier HTML, sans installation, qui fonctionne aussi hors ligne.

## Ce que fait le jeu

- **🎮 Télécommande** : piloter le robot au clavier, puis transformer ses gestes en programme.
- **🧩 Programme** : blocs aux mêmes noms que les cartes papier de la séquence (Avancer, Reculer, Tourner, LED, Bip, Attendre, Répéter, Si… alors / Sinon / Fin), exécution animée et pas à pas.
- **17 niveaux, 6 ceintures** (blanche → noire) : séquence, marche arrière, barrières de couleur, boucles, capteurs, suivi de ligne, labyrinthe. À partir de la ceinture verte, le circuit change au hasard : seul un programme avec capteurs réussit partout.
- **⚔️ Duel 2 joueurs** : course à la télécommande ou duel de programmes à blocs limités.
- **🛠 Atelier** : dessiner, tester et partager ses circuits.
- **🏆 Gamification** : XP et niveaux joueur, boulons 🔩, garage (peintures, accessoires, traînées), 24 trophées, défi du jour, classements (poste, classe, établissement).
- **🤖 Pour le vrai mBot** : traduction du programme en blocs **mBlock 5** et en **code Arduino** (bibliothèque Makeblock `MeMCore.h`), avec réglages des durées.

## Vérification du code Arduino

Le code généré utilise les classes de la bibliothèque officielle
[Makeblock-Libraries](https://github.com/Makeblock-official/Makeblock-Libraries) :
`MeDCMotor(M1/M2)`, `MeRGBLed` (broche 13), `MeBuzzer` (broche 8), `MeUltrasonicSensor(PORT_3)`,
`MeLineFollower(PORT_2)`, `MeLightSensor(PORT_6)`, bouton de la carte sur `A7`.
Sens des moteurs identique au firmware d'usine (`MotorL.run(-v)` pour avancer).
Programmes de test compilés et liés pour ATmega328P (Arduino Uno / mCore) avec avr-gcc 14.1 : OK.

Suiveur de ligne (`readSensors()`) : 0 = les deux capteurs sur le noir, 1 = capteur 1 (gauche) seul sur le noir,
2 = capteur 2 (droit) seul sur le noir, 3 = les deux sur le blanc. À vérifier sur chaque robot en mode « En direct ».

## Classement en ligne (facultatif)

1. Dans Supabase Studio (SQL Editor), coller et exécuter `supabase/mbot_mission.sql`.
   Personnaliser à la fin du script le **code de classe** et le **nom de l'établissement**.
2. Dans Vercel, définir `SUPABASE_URL` et `SUPABASE_ANON_KEY` : le relais `api/rpc.js` ajoute la clé côté serveur (pas de souci CORS, clé absente du code public).
3. Donner le code de classe aux élèves : ils le saisissent sur l'écran d'accueil.

Sans clé, le jeu fonctionne entièrement hors ligne (classement « Ce poste »).

## Données personnelles (RGPD)

- Collecte minimale : prénom + initiale du nom, classe, établissement, points de jeu, apparence du robot.
- Pas de nom de famille, pas d'e-mail, pas de mot de passe, pas de cookie, pas de publicité, pas de traceur.
- Sans code de classe, rien ne quitte l'ordinateur (stockage local du navigateur).
- Avec code : envoi au serveur Supabase du professeur (hébergé en Europe), uniquement via 3 fonctions RPC ;
  les tables ne sont pas lisibles directement.
- Durée : année scolaire, puis suppression (requêtes prêtes à la fin du script SQL).
- Penser à informer le chef d'établissement et, si besoin, le délégué à la protection des données (DPO) académique,
  qui tient le registre des traitements.

## Côté professeur

- Code prof (déblocage de tous les niveaux) : constante `CODE_PROF` en tête du script de `index.html` (par défaut `mbot`).
- Bilan élève : bouton 💾 Bilan (fichier `CLASSE_Prenom_mBot_Mission_date.html`).

---
Conçu pour la séquence « mBot : du robot qui étonne au robot que je programme » — Technologie cycle 4.


## Avis et commentaires (v3)

Le bouton violet **💬 Ton avis** (en bas à gauche) ouvre un formulaire :
- qui je suis ;
- le sujet ;
- une note sur 5 ;
- la difficulté ;
- un message ;
- un courriel facultatif, jamais demandé aux élèves.

Les avis sont enregistrés dans la table `mbot.avis` de Supabase, via le relais `/api/rpc` (fonction `mbot_avis`). Ils ne sont pas lisibles depuis le jeu.

**Lire les avis** : Supabase Studio → Table Editor → schéma `mbot` → `avis`, ou les requêtes en fin de `supabase/mbot_mission_v3_avis.sql`.
