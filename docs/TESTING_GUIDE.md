# Guide de Test - Authentification et Administration

## Prérequis

### 1. Exécuter les scripts SQL dans Supabase

Avant de tester, exécutez ces scripts dans l'éditeur SQL de votre dashboard Supabase (https://supabase.com/dashboard > Votre projet > SQL Editor) :

1. **Script de correction du système d'authentification** : 
   ```
   supabase/migrations/02_fix_auth_system.sql
   ```

2. **Script d'insertion des activités initiales** :
   ```
   supabase/migrations/03_seed_activities.sql
   ```

---

## Étape 2 : Tester le Flux Complet

### 2.1 Connexion Admin

1. Ouvrez l'application : `http://localhost:3000` (ou le port indiqué)
2. Connectez-vous avec un compte administrateur existant
3. Vérifiez que vous voyez le menu "Admin" dans la sidebar

### 2.2 Créer un nouvel utilisateur (Admin → TeamManagement)

1. Allez dans **Admin > Gestion d'équipe**
2. Cliquez sur **"Créer un utilisateur"**
3. Remplissez les champs :
   - Email : `test.doctor@example.com`
   - Mot de passe : `TestDoctor123!`
   - Nom du médecin : `Dr. Test Doctor`
   - Spécialité : `Radiologie`
   - Rôle : Sélectionnez un rôle (ex: "Médecin")
4. Cliquez sur **"Créer"**
5. Vérifiez que l'utilisateur apparaît dans la liste avec :
   - Son identifiant (email)
   - Son nom
   - Son rôle

### 2.3 Tester la connexion du nouvel utilisateur

1. Déconnectez-vous (bouton dans la sidebar)
2. Connectez-vous avec le nouveau compte :
   - Email : `test.doctor@example.com`
   - Mot de passe : `TestDoctor123!`
3. Vérifiez que vous êtes redirigé vers le Dashboard
4. Allez dans **Mon Profil**
5. Vérifiez que vous voyez :
   - Le nom du médecin (Dr. Test Doctor)
   - L'email du compte
   - Le rôle assigné
   - Les sections d'absences et préférences

### 2.4 Modifier un utilisateur (côté admin)

1. Reconnectez-vous en tant qu'admin
2. Allez dans **Admin > Gestion d'équipe**
3. Cliquez sur l'icône d'édition (✏️) d'un utilisateur
4. Modifiez :
   - Le rôle
   - Le nom du médecin
5. Sauvegardez
6. Vérifiez que les changements sont visibles

### 2.5 Supprimer un utilisateur (côté admin)

1. Dans **Gestion d'équipe**, cliquez sur l'icône de suppression (🗑️)
2. Confirmez la suppression
3. Vérifiez que l'utilisateur n'apparaît plus dans la liste

---

## Étape 3 : Suppression d'Activités

### 3.1 Accéder à la gestion des activités

1. Allez dans **Activités**
2. Cliquez sur le bouton **"Gérer"** en haut à droite

### 3.2 Créer une activité test

1. Dans le panneau qui s'ouvre :
   - Nom : `Activité Test`
   - Rythme : `Demi-journée`
   - Groupe d'Équité : `Équité indépendante`
2. Cliquez sur **"Ajouter"**
3. Vérifiez qu'elle apparaît dans les onglets

### 3.3 Modifier une activité

1. Dans la section **"Gérer les activités existantes"**
2. Cliquez sur **"Modifier"** sur l'activité créée
3. Changez :
   - Le nom
   - Le groupe d'équité
4. Cliquez sur **"Sauver"**

### 3.4 Supprimer une activité

1. Cliquez sur **"Supprimer"** sur l'activité
2. Le bouton devient **"Confirmer ?"** (rouge)
3. Cliquez à nouveau pour confirmer
4. Vérifiez que l'activité a disparu

**Note** : Les activités système (marquées "Système") ne peuvent pas être supprimées.

---

## Étape 4 : Tableaux d'Équité par Groupe

### 4.1 Groupes d'Équité disponibles

| Groupe | Description | Couleur |
|--------|-------------|---------|
| Unity + Astreinte | Activités de garde combinées | Orange |
| Supervision Workflow | Supervision hebdomadaire | Vert |
| Équité indépendante | Comptage séparé par activité | Violet |

### 4.2 Tester l'affichage des tableaux

1. Dans **Activités**, sélectionnez un onglet d'activité
2. Descendez jusqu'à la section **"Équité & Répartition par Groupe"**
3. Vérifiez que le tableau affiché correspond au groupe de l'activité :

   - **Activité du groupe "Unity + Astreinte"** → Tableau orange avec colonnes Unity, Astreinte, Score Pondéré
   - **Activité du groupe "Workflow"** → Tableau vert avec Supervision (Semaines)
   - **Activité "Équité indépendante"** → Tableau violet avec comptage spécifique à cette activité

### 4.3 Regroupement d'activités

1. Créez deux activités avec le même groupe (ex: "Unity + Astreinte")
2. Sélectionnez l'une d'elles
3. Vérifiez que le tableau d'équité affiche :
   - Le titre du groupe
   - La liste des activités regroupées
   - Les totaux combinés

---

## Résumé des Fonctionnalités Implémentées

### ✅ Authentification
- [x] Déconnexion → redirection vers /login
- [x] Profil utilisateur affiché dans la sidebar
- [x] Page Profile liée au médecin via profile.doctor_id

### ✅ Administration (TeamManagement)
- [x] Créer un compte utilisateur + profil médecin lié
- [x] Afficher la liste avec email, nom, rôle
- [x] Modifier le rôle et le nom du médecin
- [x] Supprimer un utilisateur (et son médecin lié)

### ✅ Gestion des Activités
- [x] Créer une activité avec groupe d'équité
- [x] Modifier le nom et le groupe d'équité
- [x] Supprimer une activité (sauf système)
- [x] Protection des activités système

### ✅ Tableaux d'Équité
- [x] Affichage dynamique selon le groupe de l'activité
- [x] Groupe "Unity + Astreinte" : tableau combiné
- [x] Groupe "Workflow" : tableau supervision
- [x] Groupe "Indépendante" : comptage par activité
- [x] Liste des activités regroupées affichée

---

## Dépannage

### L'utilisateur créé ne peut pas se connecter
- Vérifiez que le script `02_fix_auth_system.sql` a été exécuté
- Vérifiez les politiques RLS sur la table `profiles`

### Le profil médecin ne s'affiche pas
- Vérifiez que `profile.doctor_id` est bien lié dans la table `profiles`
- Vérifiez que le médecin existe dans la table `doctors`

### Les activités initiales n'apparaissent pas
- Exécutez le script `03_seed_activities.sql`
- Rechargez la page

### Erreur lors de la suppression d'activité
- Vérifiez que l'activité n'est pas marquée comme "système"
- Vérifiez les contraintes de clé étrangère dans la base de données
